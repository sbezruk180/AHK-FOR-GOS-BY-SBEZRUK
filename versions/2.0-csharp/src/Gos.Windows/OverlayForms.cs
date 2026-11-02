using Gos.Core;

namespace Gos.Windows;

public sealed class HudForm : GosForm
{
    private readonly IAppController app;
    private string lastContent = "";
    public HudForm(IAppController controller)
    {
        app = controller; Passive = true; TopMost = true; ShowInTaskbar = false;
        Text = "GOS · HUD"; FormBorderStyle = FormBorderStyle.None; Size = new Size(310, 150);
        StartPosition = FormStartPosition.Manual; Location = new Point(24, 30);
    }
    public void RefreshState()
    {
        if (IsDisposed) return;
        if (!app.Settings.HudVisible || !app.IsGameActive) { if (Visible) Hide(); return; }
        WindowPolicy.Apply(this, app.Settings.HideFromCapture, true);
        string content = $"{app.Target}/{app.Candidate}/{app.Status}/{app.Settings.SendMode}";
        bool wasHidden = !Visible;
        if (wasHidden) Show();
        if (wasHidden || lastContent != content) { lastContent = content; Invalidate(); }
    }
    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e); var g = e.Graphics;
        using var body = Theme.Body(10); using var small = Theme.Body(9); using var title = Theme.Heading(12);
        using var border = new Pen(Theme.Border); g.DrawRectangle(border, 0, 0, Width - 1, Height - 1);
        TextRenderer.DrawText(g, "GOS", title, new Rectangle(16, 12, 100, 24), Theme.Accent);
        string mode = app.Settings.SendMode switch { SendMode.Memory => "ПАМЯТЬ", SendMode.KeyAssisted => "ПО КЛАВИШАМ", _ => "ПЕЧАТЬ" };
        TextRenderer.DrawText(g, mode, small, new Rectangle(126, 15, 164, 22), Theme.Muted, TextFormatFlags.Right);
        string selected = app.Target is { } target ? $"ID {target.Id} · {target.Name}" : "Цель не выбрана";
        TextRenderer.DrawText(g, selected, body, new Rectangle(16, 43, Width - 32, 24), Theme.Text, TextFormatFlags.EndEllipsis);
        string candidate = app.Candidate is { } offer ? $"ID {offer.Id} · {offer.Name}  —  F1 / F2" : "ПКМ на игроке — предложить ID";
        TextRenderer.DrawText(g, candidate, small, new Rectangle(16, 73, Width - 32, 24), app.Candidate == null ? Theme.Muted : Theme.Good, TextFormatFlags.EndEllipsis);
        TextRenderer.DrawText(g, app.Status, small, new Rectangle(16, 105, Width - 32, 32), Theme.Muted, TextFormatFlags.WordBreak | TextFormatFlags.EndEllipsis);
    }
    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x84) { m.Result = (nint)2; return; }
        base.WndProc(ref m);
    }
}

public sealed class NearbyForm : GosForm
{
    private readonly IAppController app;
    private string lastContent = "";
    public NearbyForm(IAppController controller)
    {
        app = controller; Passive = true; TopMost = true; ShowInTaskbar = false;
        Text = "GOS · Игроки рядом"; FormBorderStyle = FormBorderStyle.None; Size = new Size(270, 115);
        StartPosition = FormStartPosition.Manual; Location = new Point(Math.Max(0, Screen.PrimaryScreen!.WorkingArea.Right - Width - 24), 70);
    }
    public void RefreshState()
    {
        if (IsDisposed) return;
        if (!app.Settings.NearbyVisible || !app.IsGameActive) { if (Visible) Hide(); return; }
        int height = 88 + Math.Min(12, app.Nearby.Count) * 24;
        if (Height != height) Height = height;
        WindowPolicy.Apply(this, app.Settings.HideFromCapture, true);
        string content = $"{app.Settings.NearbyRadius}/{app.Nearby.Count}/" + string.Join(';', app.Nearby.Take(12).Select(p => $"{p.Id}:{p.Name}:{p.Distance:0.0}"));
        bool wasHidden = !Visible;
        if (wasHidden) Show();
        if (wasHidden || lastContent != content) { lastContent = content; Invalidate(); }
    }
    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e); using var title = Theme.Heading(11); using var body = Theme.Body(9); using var border = new Pen(Theme.Border);
        e.Graphics.DrawRectangle(border, 0, 0, Width - 1, Height - 1);
        TextRenderer.DrawText(e.Graphics, $"Рядом · {app.Nearby.Count}", title, new Rectangle(14, 12, 170, 24), Theme.Text);
        TextRenderer.DrawText(e.Graphics, $"{app.Settings.NearbyRadius} м", body, new Rectangle(180, 15, 72, 22), Theme.Muted, TextFormatFlags.Right);
        int y = 44;
        foreach (var player in app.Nearby.Take(12))
        {
            TextRenderer.DrawText(e.Graphics, $"{player.Id} · {player.Name}", body, new Rectangle(14, y, 192, 22), Theme.Text, TextFormatFlags.EndEllipsis);
            TextRenderer.DrawText(e.Graphics, $"{player.Distance:0.0} м", body, new Rectangle(202, y, 54, 22), Theme.Good, TextFormatFlags.Right); y += 24;
        }
        string note = app.Nearby.Count == 0 ? "В радиусе нет доступных игроков" : app.Nearby.Count > 12 ? $"Показаны 12 ближайших из {app.Nearby.Count}" : "Только игроки, доступные в памяти клиента";
        TextRenderer.DrawText(e.Graphics, note, body, new Rectangle(14, Height - 31, Width - 28, 26), Theme.Muted, TextFormatFlags.EndEllipsis);
    }
    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x84) { m.Result = (nint)2; return; }
        base.WndProc(ref m);
    }
}

public sealed class CommandForm : GosForm
{
    private readonly IAppController app;
    private string query = "";
    private int selected;
    private sealed record CommandRow(string Name, string Key, Scenario? Scenario = null);
    private List<CommandRow> results = new();
    private readonly HashSet<int> consumed = new();
    public bool IsOpen => Visible;
    public CommandForm(IAppController controller)
    {
        app = controller; Passive = true; TopMost = true; Text = "GOS · Команды"; ShowInTaskbar = false;
        FormBorderStyle = FormBorderStyle.None; Size = new Size(580, 410); StartPosition = FormStartPosition.CenterScreen;
    }
    public void Open()
    {
        query = ""; selected = 0; UpdateResults(); Configure(app.IsGameActive, app.Settings.HideFromCapture);
        if (!Visible) Show();
        if (!Passive) Activate();
        Invalidate();
    }
    public void CloseInput() { query = ""; Hide(); }
    private void UpdateResults()
    {
        string search = query.Trim().TrimStart('!', '/');
        var exact = ActionCatalog.Find(search);
        results = ActionCatalog.Search(search).OrderByDescending(a => a.Key == exact?.Key)
            .Select(a => new CommandRow(a.Name, a.Key)).ToList();
        foreach (var scenario in app.Settings.Scenarios)
            if (search.Length == 0 || scenario.Name.Contains(search, StringComparison.OrdinalIgnoreCase))
                results.Add(new CommandRow("Сценарий · " + scenario.Name, "", scenario));
        results = results.Take(7).ToList();
        selected = Math.Clamp(selected, 0, Math.Max(0, results.Count - 1)); Invalidate();
    }
    public bool HandleKey(KeyStroke key)
    {
        if (key.Injected) return false;
        if (!key.Down && consumed.Remove(key.VirtualKey)) return true;
        if (!Visible) return false;
        if (!key.Down) return true;
        consumed.Add(key.VirtualKey);
        if (key.VirtualKey == (int)Keys.Escape) { CloseInput(); return true; }
        if (key.VirtualKey == (int)Keys.Back) { if (query.Length > 0) query = query[..^1]; selected = 0; UpdateResults(); return true; }
        if (key.VirtualKey == (int)Keys.Up) { selected = Math.Max(0, selected - 1); Invalidate(); return true; }
        if (key.VirtualKey == (int)Keys.Down) { selected = Math.Min(Math.Max(0, results.Count - 1), selected + 1); Invalidate(); return true; }
        if (key.VirtualKey == (int)Keys.Tab) { if (results.Count > 0) { query = results[selected].Scenario?.Name ?? results[selected].Name; UpdateResults(); } return true; }
        if (key.VirtualKey == (int)Keys.Enter)
        {
            UpdateResults();
            if (query.Trim().Length == 0 || results.Count == 0) return true;
            var action = results[selected]; CloseInput(); _ = Run(action); return true;
        }
        if (query.Length < 160 && !KeyboardHook.IsKeyDown((int)Keys.ControlKey) && !KeyboardHook.IsKeyDown((int)Keys.Menu))
        { string text = PassiveTyping.Text(key.VirtualKey); query += text; selected = 0; UpdateResults(); }
        return true;
    }
    private async Task Run(CommandRow action)
    {
        try { if (action.Scenario is { } scenario) await app.RunScenarioAsync(scenario); else await app.RunAsync(action.Key); }
        catch (Exception ex) { app.Notify(ex.Message); }
    }
    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e); using var heading = Theme.Heading(14); using var body = Theme.Body(11); using var small = Theme.Body(9);
        using var pen = new Pen(Theme.Border); e.Graphics.DrawRectangle(pen, 0, 0, Width - 1, Height - 1);
        TextRenderer.DrawText(e.Graphics, "Команды", heading, new Point(22, 18), Theme.Text);
        TextRenderer.DrawText(e.Graphics, query.Length == 0 ? "Введите название или !команду…" : query + "│", body, new Rectangle(22, 62, Width - 44, 32), query.Length == 0 ? Theme.Muted : Theme.Text, TextFormatFlags.EndEllipsis);
        for (int i = 0; i < results.Count; i++)
        {
            var bounds = new Rectangle(14, 110 + i * 34, Width - 28, 32);
            if (i == selected) { using var fill = new SolidBrush(Theme.Surface); e.Graphics.FillRectangle(fill, bounds); }
            TextRenderer.DrawText(e.Graphics, results[i].Name, body, new Rectangle(24, bounds.Top + 5, Width - 48, 26), i == selected ? Theme.Accent : Theme.Text, TextFormatFlags.EndEllipsis);
        }
        if (results.Count == 0) TextRenderer.DrawText(e.Graphics, "Ничего не найдено. Попробуйте другое название.", body, new Point(22, 122), Theme.Muted);
        TextRenderer.DrawText(e.Graphics, "↑ ↓ — выбор · Tab — дополнить · Enter — выполнить · Esc — закрыть", small, new Rectangle(22, Height - 38, Width - 44, 25), Theme.Muted, TextFormatFlags.EndEllipsis);
    }
}

public class ReferenceForm : GosForm
{
    protected readonly IAppController App;
    private readonly RichTextBox body;
    public ReferenceForm(IAppController app, string title, string text)
    {
        App = app; Text = title; Size = new Size(700, 600); StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(380, 300);
        var heading = new Label { Dock = DockStyle.Top, Height = 56, Text = title, Padding = new Padding(18, 14, 18, 0), Font = Theme.Heading(15), ForeColor = Theme.Accent };
        body = new RichTextBox { Text = text, Dock = DockStyle.Fill, ReadOnly = true, WordWrap = true, DetectUrls = false, BorderStyle = BorderStyle.None, BackColor = Theme.Panel, ForeColor = Theme.Text, Font = Theme.Body(11) };
        var close = Theme.Button("Закрыть · Esc", Close); close.Dock = DockStyle.Bottom;
        Controls.Add(body); Controls.Add(heading); Controls.Add(close);
    }
    public void ShowReference() { Configure(App.IsGameActive, App.Settings.HideFromCapture); Show(); }
    public bool HandleKey(KeyStroke key)
    {
        if (!Visible || !Passive || key.Injected) return false;
        if (key.Down && key.VirtualKey == (int)Keys.Escape) { Close(); return true; }
        return PassiveTyping.Edit(body, key);
    }
}

public sealed class RightsForm : ReferenceForm
{
    public RightsForm(IAppController controller) : base(controller, "Права задержанного", string.Join(Environment.NewLine + Environment.NewLine,
        ActionCatalog.All.First(a => a.Key == "rights").Lines.Select(line => Template.Expand(line, controller.Settings, controller.Target)))) { }
}
