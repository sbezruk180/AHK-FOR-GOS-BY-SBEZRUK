using Gos.Core;

namespace Gos.Windows;

/// <summary>Desktop settings and a no-activate in-game shell share the same real actions.</summary>
public sealed class ShellForm : GosForm
{
    private readonly IAppController app;
    private readonly Panel content = new() { Dock = DockStyle.Fill, Padding = new Padding(24), BackColor = Theme.Background };
    private readonly Label footer = new() { Dock = DockStyle.Bottom, Height = 48, Padding = new Padding(18, 8, 18, 4), ForeColor = Theme.Muted };
    private readonly Dictionary<string, GosButton> navigation = new();
    private TextBoxBase? editing;
    private readonly List<Action> saveFields = new();
    private bool settingsDirty;
    private bool builderDirty;
    private bool bindingsDirty;
    private Label? modeLabel, connectionLabel;
    private readonly ToolTip hints = new() { InitialDelay = 500, ReshowDelay = 100, AutoPopDelay = 8000 };
    private string currentPage = "Действия";
    private Label? targetLabel;
    public bool IsInputOpen => Visible;

    public ShellForm(IAppController controller)
    {
        app = controller; Text = "GOS · рабочее место"; MinimumSize = new Size(800, 580); Size = new Size(1120, 800);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.None; Padding = new Padding(1);
        var titlebar = new Panel { Dock = DockStyle.Top, Height = 40, BackColor = Theme.Panel };
        var title = new Label { Text = "GOS  /  РАБОЧЕЕ МЕСТО", AutoSize = false, Dock = DockStyle.Fill,
            Padding = new Padding(18, 11, 0, 0), ForeColor = Theme.Muted, Font = Theme.UiBody(9) };
        Point dragOrigin = Point.Empty, windowOrigin = Point.Empty; bool dragging = false;
        void DragTitle(object? sender, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left || sender is not Control source) return;
            dragOrigin = Cursor.Position; windowOrigin = Location; dragging = true; source.Capture = true;
        }
        void MoveTitle(object? sender, MouseEventArgs e)
        {
            if (dragging) Location = new Point(windowOrigin.X + Cursor.Position.X - dragOrigin.X, windowOrigin.Y + Cursor.Position.Y - dragOrigin.Y);
        }
        void EndDrag(object? sender, MouseEventArgs e)
        { dragging = false; if (sender is Control source) source.Capture = false; }
        foreach (Control source in new Control[] { titlebar, title })
        { source.MouseDown += DragTitle; source.MouseMove += MoveTitle; source.MouseUp += EndDrag; source.MouseCaptureChanged += (_, _) => { if (!source.Capture) dragging = false; }; }
        var hide = Theme.Button("—", Hide); hide.Dock = DockStyle.Right; hide.Width = 46; hide.Margin = Padding.Empty;
        var close = Theme.Button("×", () => { editing = null; Hide(); }); close.Dock = DockStyle.Right; close.Width = 46; close.Margin = Padding.Empty;
        titlebar.Controls.Add(title); titlebar.Controls.Add(hide); titlebar.Controls.Add(close);
        var sidebar = new Panel { Dock = DockStyle.Left, Width = 176, BackColor = Theme.Panel, Padding = new Padding(14, 22, 14, 12) };
        var brand = Theme.Label("GOS", true); brand.Font = Theme.UiHeading(25); brand.ForeColor = Theme.Accent; brand.Location = new Point(20, 24);
        var version = Theme.Label("AMAZING ONLINE"); version.Font = Theme.UiBody(9); version.Location = new Point(20, 70);
        sidebar.Controls.Add(brand); sidebar.Controls.Add(version);
        string[] pages = ["Действия", "Клавиши", "Конструктор", "Законы", "Настройки", "О приложении"];
        for (int i = 0; i < pages.Length; i++)
        {
            string page = pages[i]; var button = Theme.Button(page, () => Navigate(page)); button.Size = new Size(148, 42); button.Location = new Point(14, 124 + i * 49);
            navigation[page] = button; sidebar.Controls.Add(button);
        }
        var stop = Theme.Button("Остановить · Pause", app.Cancel); stop.ForeColor = Theme.Danger; stop.Dock = DockStyle.Bottom; sidebar.Controls.Add(stop);
        Controls.Add(content); Controls.Add(sidebar); Controls.Add(footer); Controls.Add(titlebar);
        FormClosing += (_, e) => { if (e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; editing = null; Hide(); } };
        app.Changed += StateChanged; Disposed += (_, _) => { app.Changed -= StateChanged; hints.Dispose(); };
        VisibleChanged += (_, _) => { if (!Visible) { editing = null; app.CancelHotkeyCapture(); } };
        Navigate("Действия");
    }

    public void ShowPassive()
    {
        Configure(app.IsGameActive, app.Settings.HideFromCapture);
        if (!Visible) Show(); else Invalidate();
        if (!Passive) Activate();
        StateChanged();
    }
    internal void SyncGameMode(bool active)
    {
        if(!Visible||Passive==active)return;
        editing=null;app.CancelHotkeyCapture();Configure(active,app.Settings.HideFromCapture);
        StateChanged();
    }
    private void StateChanged()
    {
        if (IsDisposed || !IsHandleCreated) return;
        if (InvokeRequired) { BeginInvoke((Action)StateChanged); return; }
        string selected = app.Target is { } target ? $"ID {target.Id} · {target.Name}" : "Цель не выбрана";
        if (targetLabel != null) targetLabel.Text = selected;
        if (modeLabel != null) modeLabel.Text = ModeText(app.Settings.SendMode);
        if (connectionLabel != null) { connectionLabel.Text = app.ConnectionStatus; hints.SetToolTip(connectionLabel, app.ConnectionStatus); connectionLabel.ForeColor = app.IsGameActive ? Theme.Good : Theme.Muted; }
        footer.Text = editing != null && Passive ? "Ввод в выделенное поле · Ctrl+A — выделить · Esc — закончить ввод" : app.Status;
        WindowPolicy.Apply(this, app.Settings.HideFromCapture, Passive);
    }
    public void ReviewPage(string page) => Navigate(page);
    private void Navigate(string page)
    {
        if (currentPage == "Клавиши" && bindingsDirty) { app.Notify("Есть несохранённые клавиши. Сохраните их или отмените изменения."); return; }
        if (currentPage == "Настройки" && settingsDirty)
        {
            app.Notify("Есть несохранённые настройки. Нажмите «Сохранить» или «Отменить изменения»."); return;
        }
        if (currentPage == "Конструктор" && builderDirty)
        {
            app.Notify("Есть несохранённый сценарий. Сохраните его или нажмите «Отменить правки»."); return;
        }
        app.CancelHotkeyCapture();
        currentPage = page; editing = null; targetLabel = null; modeLabel = null; connectionLabel = null; saveFields.Clear();
        foreach (Control c in content.Controls.Cast<Control>().ToArray()) c.Dispose();
        content.Controls.Clear();
        foreach (var pair in navigation) { pair.Value.Primary = pair.Key == page; pair.Value.Invalidate(); }
        if (page == "Действия") BuildActions();
        else if (page == "Клавиши") BuildBindings();
        else if (page == "Конструктор") BuildBuilder();
        else if (page == "Законы") BuildLaws();
        else if (page == "Настройки") BuildSettings();
        else BuildAbout();
        StateChanged();
    }
    private FlowLayoutPanel Stack(string title, string hint)
    {
        var stack = new ResponsiveStack();
        content.Controls.Add(stack);
        var heading = Theme.Label(title, true); stack.Controls.Add(heading);
        var help = Theme.Label(hint); stack.Controls.Add(help);
        return stack;
    }
    private static string ModeText(SendMode mode) => mode switch { SendMode.Memory => "Через память", SendMode.KeyAssisted => "Клавиша → символ", _ => "Случайная печать" };
    private static string BindText(string? value) => string.IsNullOrWhiteSpace(value) ? "Не назначено" : HotkeyChord.TryParse(value, out var chord) ? chord.Display : "Назначьте заново";
    private void BuildActions()
    {
        var stack = Stack("Действия", "Частые команды и выбранная цель — всё под рукой.");
        var context = new SurfacePanel { Height = 72, Margin = new Padding(0, 0, 0, 12) };
        Label Cap(string text) => new() { Text = text, AutoSize = false, Font = Theme.UiBody(8), ForeColor = Theme.Muted, Height = 17 };
        Label Value() => new() { AutoSize = false, Font = Theme.UiHeading(10), ForeColor = Theme.Text, Height = 25, AutoEllipsis = true };
        var targetCap = Cap("ВЫБРАННАЯ ЦЕЛЬ"); var modeCap = Cap("ОТПРАВКА"); var connectionCap = Cap("СВЯЗЬ С ИГРОЙ");
        targetLabel = Value(); modeLabel = Value(); connectionLabel = Value();
        context.Controls.AddRange([targetCap, targetLabel, modeCap, modeLabel, connectionCap, connectionLabel]);
        context.SizeChanged += (_, _) =>
        {
            int P(int value) => (int)Math.Round(value * context.DeviceDpi / 96f);
            int unit = Math.Max(P(90), (context.ClientSize.Width - P(48)) / 3);
            var captions = new[] { targetCap, modeCap, connectionCap }; var values = new[] { targetLabel, modeLabel, connectionLabel };
            for (int i = 0; i < 3; i++) { captions[i].SetBounds(P(14) + i * (unit + P(10)), P(12), unit, P(17)); values[i]!.SetBounds(P(14) + i * (unit + P(10)), P(34), unit, P(25)); }
        };
        stack.Controls.Add(context);
        var toolbar = Row(); toolbar.Margin = new Padding(0, 0, 0, 8);
        var search = new TextBox { Width = 400, PlaceholderText = "Найти действие или команду…", Name = "action-search", AccessibleName = "Поиск действий", MaxLength = 100 }; Register(search); toolbar.Controls.Add(search);
        var editTarget = Theme.Button("Выбрать ID", () => { }); editTarget.Width = 120; toolbar.Controls.Add(editTarget);
        var keys = Theme.Button("Настроить клавиши", () => Navigate("Клавиши")); keys.Width = 160; toolbar.Controls.Add(keys);
        stack.Controls.Add(toolbar);
        var manualRow = Row(); manualRow.Visible = false; manualRow.Margin = new Padding(0, 0, 0, 10);
        var manual = new TextBox { Width = 90, MaxLength = 4, PlaceholderText = "ID: 0–1003", Name = "manual-target" }; Register(manual); manualRow.Controls.Add(manual);
        manualRow.Controls.Add(Theme.Button("Применить ID", () => { if (int.TryParse(manual.Text, out int id) && id is >= 0 and <= 1003) { app.SetManualTarget(id); manualRow.Visible = false; } else app.Notify("ID: число от 0 до 1003."); }));
        manualRow.Controls.Add(Theme.Button("Сбросить цель", app.ClearTarget)); stack.Controls.Add(manualRow);
        editTarget.Click += (_, _) => { manualRow.Visible = !manualRow.Visible; if (manualRow.Visible && !Passive) manual.Focus(); };
        var grid = new CardGrid(82); stack.Controls.Add(grid);
        var empty = Theme.Label("Ничего не найдено. Попробуйте название действия или команду."); empty.Visible = false; empty.Name = "actions-empty"; stack.Controls.Add(empty);
        var cards = new Dictionary<Control, ActionDefinition>();
        foreach (var action in ActionCatalog.All)
        {
            var card = new SurfacePanel { Height = 82, Name = "action-" + action.Key };
            var title = new Label { Text = action.Name, Font = Theme.UiHeading(10.5f), ForeColor = Theme.Text, AutoEllipsis = true };
            var description = new Label { Text = action.Description, Font = Theme.UiBody(9), ForeColor = Theme.Muted, AutoEllipsis = true };
            var badge = new Label { Text = BindText(app.Settings.Hotkeys.GetValueOrDefault(action.Key)), Font = Theme.UiBody(9), ForeColor = Theme.Accent, AutoEllipsis = true };
            var run = Theme.Button(action.Key == "rights-gui" ? "Открыть" : "Выполнить", () => _ = Execute(() => app.RunAsync(action.Key)));
            run.Name = "action-run-" + action.Key; run.AccessibleName = "Выполнить: " + action.Name; run.Size = new Size(104, 28);
            hints.SetToolTip(description, action.Description); hints.SetToolTip(run, action.Description);
            card.Controls.AddRange([title, description, badge, run]);
            card.SizeChanged += (_, _) =>
            {
                int P(int value) => (int)Math.Round(value * card.DeviceDpi / 96f);
                title.SetBounds(P(14), P(9), Math.Max(P(80), card.Width - P(28)), P(21));
                description.SetBounds(P(14), P(31), Math.Max(P(80), card.Width - P(28)), P(18));
                badge.SetBounds(P(14), P(55), Math.Max(P(70), card.Width - P(135)), P(20));
                run.SetBounds(card.Width - P(116), P(49), P(104), P(28));
            };
            cards[card] = action;
        }
        grid.SetCards(cards.Keys);
        search.TextChanged += (_, _) =>
        {
            var matches = ActionCatalog.Search(search.Text.Trim().TrimStart('!', '/')).Select(a => a.Key).ToHashSet(StringComparer.Ordinal);
            grid.Filter(card => matches.Contains(cards[card].Key)); empty.Visible = matches.Count == 0;
        };
    }

    private void BuildBindings()
    {
        bindingsDirty = false;
        var draft = new Dictionary<string, string>(app.Settings.Hotkeys, StringComparer.OrdinalIgnoreCase);
        var stack = Stack("Клавиши", "Нажмите «Назначить», затем нужное сочетание. Esc — отменить запись, Delete — снять назначение.");
        var instructions = Theme.Label("F1/F2 — выбор Auto ID · Pause — остановка действий. Новые назначения начнут работать после сохранения.");
        instructions.ForeColor = Theme.Accent; stack.Controls.Add(instructions);
        var conflict = Theme.Label(""); conflict.Name = "bind-conflicts"; stack.Controls.Add(conflict);
        var grid = new CardGrid(79); stack.Controls.Add(grid);
        var values = new Dictionary<string, Label>(); var assignButtons = new Dictionary<string, GosButton>();
        var rows = new List<Control>(); string? pending = null;
        var entries = new[] { (Key: "menu", Name: "Открыть / закрыть меню"), (Key: "palette", Name: "Окно текстовых команд") }
            .Concat(ActionCatalog.All.Select(a => (a.Key, a.Name))).ToArray();
        void RefreshBindings()
        {
            var duplicates = entries.Where(e => HotkeyChord.TryParse(draft.GetValueOrDefault(e.Key, ""), out var chord) && !chord.IsEmpty)
                .GroupBy(e => { HotkeyChord.TryParse(draft.GetValueOrDefault(e.Key, ""), out var chord); return chord.Canonical; }, StringComparer.OrdinalIgnoreCase)
                .Where(g => g.Count() > 1).SelectMany(g => g.Select(e => e.Key)).ToHashSet();
            var invalid = entries.Where(e => !HotkeyChord.TryParse(draft.GetValueOrDefault(e.Key, ""), out var parsed) || parsed.IsReserved).Select(e => e.Key).ToHashSet();
            foreach (var entry in entries)
            {
                values[entry.Key].Text = pending == entry.Key ? "Нажмите сочетание…" : BindText(draft.GetValueOrDefault(entry.Key));
                values[entry.Key].ForeColor = duplicates.Contains(entry.Key) || invalid.Contains(entry.Key) ? Theme.Danger : pending == entry.Key ? Theme.Good : Theme.Accent;
                assignButtons[entry.Key].Text = pending == entry.Key ? "Отмена" : "Назначить";
                assignButtons[entry.Key].Primary = pending == entry.Key; assignButtons[entry.Key].Invalidate();
            }
            conflict.Text = invalid.Count > 0 ? "Есть некорректные или зарезервированные клавиши. Назначьте их заново." : duplicates.Count == 0 ? "Сочетания не конфликтуют" : "Одно сочетание назначено нескольким действиям. Измените выделенные назначения.";
            conflict.ForeColor = duplicates.Count == 0 && invalid.Count == 0 ? Theme.Muted : Theme.Danger;
        }
        foreach (var entry in entries)
        {
            string key = entry.Key; var card = new SurfacePanel { Height = 79 };
            var title = new Label { Text = entry.Name, Font = Theme.UiHeading(10), ForeColor = Theme.Text, AutoEllipsis = true };
            var value = new Label { Name = "bind-value-" + key, Font = Theme.UiBody(10), ForeColor = Theme.Accent, AutoEllipsis = true };
            var assign = Theme.Button("Назначить", () => { }); assign.Name = "bind-capture-" + key; assign.AccessibleName = "Назначить клавишу: " + entry.Name; assign.Size = new Size(100, 30);
            var clear = Theme.Button("×", () => { app.CancelHotkeyCapture(); draft[key] = ""; bindingsDirty = true; pending = null; RefreshBindings(); });
            clear.Name = "bind-clear-" + key; clear.AccessibleName = "Снять клавишу: " + entry.Name; clear.Size = new Size(30, 30); hints.SetToolTip(clear, "Снять назначение");
            assign.Click += (_, _) =>
            {
                if (pending == key) { app.CancelHotkeyCapture(); pending = null; RefreshBindings(); return; }
                app.CancelHotkeyCapture(); editing = null; pending = key; RefreshBindings();
                app.BeginHotkeyCapture(key, captured =>
                {
                    if (IsDisposed || card.IsDisposed) return;
                    if (captured != null) { draft[key] = captured; bindingsDirty = true; }
                    pending = null; RefreshBindings();
                });
            };
            card.Controls.AddRange([title, value, assign, clear]);
            card.SizeChanged += (_, _) =>
            {
                int P(int dip) => (int)Math.Round(dip * card.DeviceDpi / 96f);
                title.SetBounds(P(14), P(9), Math.Max(P(80), card.Width - P(28)), P(22));
                value.SetBounds(P(14), P(42), Math.Max(P(50), card.Width - P(166)), P(24));
                assign.SetBounds(card.Width - P(146), P(37), P(100), P(30)); clear.SetBounds(card.Width - P(40), P(37), P(30), P(30));
            };
            values[key] = value; assignButtons[key] = assign; rows.Add(card);
        }
        grid.SetCards(rows); RefreshBindings();
        var buttons = Toolbar(); content.Controls.Add(buttons);
        var save = Theme.Button("Сохранить клавиши", () =>
        {
            app.CancelHotkeyCapture();
            try { var next = ProfileStore.Copy(app.Settings); next.Hotkeys = new(draft, StringComparer.OrdinalIgnoreCase); app.ApplySettings(next); bindingsDirty = false; Navigate("Клавиши"); }
            catch (Exception ex) { app.Notify("Клавиши: " + ex.Message); }
        }, true); save.Name = "bind-save";
        var cancel = Theme.Button("Отменить изменения", () => { app.CancelHotkeyCapture(); bindingsDirty = false; Navigate("Клавиши"); }); cancel.Name = "bind-cancel";
        buttons.Controls.Add(save); buttons.Controls.Add(cancel);
    }

    private void BuildBuilder()
    {
        builderDirty = false;
        var stack = Stack("Конструктор", "Сообщения, паузы и уведомления. Подстановки: {id}, {name}, {rank}, {department}. Паузы не меняют скорость печати.");
        var scenarios = new ComboBox { Width = 300, DropDownStyle = ComboBoxStyle.DropDownList };
        Theme.Style(scenarios); stack.Controls.Add(scenarios);
        var name = Input("Название сценария", stack, "Новый сценарий");
        var steps = new ListBox { Width = 680, Height = 155 }; Theme.Style(steps); stack.Controls.Add(steps);
        var kind = "send";
        string KindName() => kind switch { "send" => "сообщение", "wait" => "пауза", "notice" => "уведомление", _ => "клавиша меню" };
        var kindButton = Theme.Button("Шаг: сообщение", () => { }); kindButton.Width = 240;
        kindButton.Click += (_, _) => { kind = kind == "send" ? "wait" : kind == "wait" ? "notice" : kind == "notice" ? "key" : "send"; kindButton.Text = "Шаг: " + KindName(); };
        stack.Controls.Add(kindButton);
        var text = Input("Текст сообщения / уведомления; для клавиши: Down, Up, Enter, Home, End", stack, "/me предъявил удостоверение.");
        var delay = Input("Длительность паузы, миллисекунды", stack, "1000");
        var working = new List<ScenarioStep>(); string? selectedId = null;
        bool loadingScenario = false, restoringSelection = false;
        int previousSelection = 0;
        void RefreshSteps()
        {
            int selected = steps.SelectedIndex; steps.Items.Clear();
            foreach (var step in working) steps.Items.Add(step.Kind == "wait" ? $"Пауза · {step.DelayMs} мс" : (step.Kind == "notice" ? "Уведомление · " : step.Kind == "key" ? "Клавиша · " : "Сообщение · ") + step.Text);
            if (steps.Items.Count > 0) steps.SelectedIndex = Math.Clamp(selected, 0, steps.Items.Count - 1);
        }
        void FillScenarios()
        {
            builderDirty = false;
            scenarios.Items.Clear(); scenarios.Items.Add("+ Новый сценарий");
            foreach (var item in app.Settings.Scenarios) scenarios.Items.Add(item.Name);
            scenarios.SelectedIndex = 0;
        }
        scenarios.SelectedIndexChanged += (_, _) =>
        {
            if (restoringSelection || scenarios.SelectedIndex < 0) return;
            if (builderDirty)
            {
                restoringSelection = true; scenarios.SelectedIndex = previousSelection; restoringSelection = false;
                app.Notify("Сохраните сценарий или отмените правки перед выбором другого."); return;
            }
            previousSelection = scenarios.SelectedIndex; loadingScenario = true;
            if (scenarios.SelectedIndex <= 0) { selectedId = null; name.Text = "Новый сценарий"; working.Clear(); }
            else
            {
                var value = app.Settings.Scenarios[scenarios.SelectedIndex - 1]; selectedId = value.Id; name.Text = value.Name;
                working = value.Steps.Select(s => new ScenarioStep { Kind = s.Kind, Text = s.Text, DelayMs = s.DelayMs }).ToList();
            }
            RefreshSteps(); loadingScenario = false;
        };
        name.TextChanged += (_, _) => { if (!loadingScenario) builderDirty = true; };
        var editRow = Row(); stack.Controls.Add(editRow);
        editRow.Controls.Add(Theme.Button("Добавить шаг", () =>
        {
            if (!int.TryParse(delay.Text, out int ms) || ms < 0 || ms > 120000) { app.Notify("Пауза: от 0 до 120000 мс."); return; }
            if (working.Count >= 100) { app.Notify("В сценарии допускается до 100 шагов."); return; }
            builderDirty = true; working.Add(new ScenarioStep { Kind = kind, Text = text.Text, DelayMs = kind == "wait" ? ms : 0 }); RefreshSteps(); steps.SelectedIndex = working.Count - 1;
        }));
        editRow.Controls.Add(Theme.Button("Изменить шаг", () =>
        {
            if (steps.SelectedIndex < 0) { app.Notify("Выберите шаг в списке."); return; }
            if (!int.TryParse(delay.Text, out int ms) || ms < 0 || ms > 120000) { app.Notify("Пауза: от 0 до 120000 мс."); return; }
            builderDirty = true; working[steps.SelectedIndex] = new ScenarioStep { Kind = kind, Text = text.Text, DelayMs = kind == "wait" ? ms : 0 }; RefreshSteps();
        }));
        editRow.Controls.Add(Theme.Button("Удалить шаг", () => { if (steps.SelectedIndex >= 0) { builderDirty = true; working.RemoveAt(steps.SelectedIndex); RefreshSteps(); } }));
        editRow.Controls.Add(Theme.Button("Выше", () => { int i = steps.SelectedIndex; if (i > 0) { builderDirty = true; (working[i], working[i - 1]) = (working[i - 1], working[i]); RefreshSteps(); steps.SelectedIndex = i - 1; } }));
        editRow.Controls.Add(Theme.Button("Ниже", () => { int i = steps.SelectedIndex; if (i >= 0 && i + 1 < working.Count) { builderDirty = true; (working[i], working[i + 1]) = (working[i + 1], working[i]); RefreshSteps(); steps.SelectedIndex = i + 1; } }));
        steps.SelectedIndexChanged += (_, _) =>
        {
            if (steps.SelectedIndex < 0) return;
            var step = working[steps.SelectedIndex]; text.Text = step.Text; delay.Text = step.DelayMs.ToString(); kind = step.Kind;
            kindButton.Text = "Шаг: " + KindName();
        };
        var buttons = Toolbar(); content.Controls.Add(buttons);
        var secondary = Row(); stack.Controls.Add(secondary);
        Scenario Draft() => new() { Id = selectedId ?? Guid.NewGuid().ToString("N"), Name = name.Text.Trim(), Steps = working.Select(s => new ScenarioStep { Kind = s.Kind, Text = s.Text, DelayMs = s.DelayMs }).ToList() };
        buttons.Controls.Add(Theme.Button("Сохранить сценарий", () =>
        {
            if (string.IsNullOrWhiteSpace(name.Text) || working.Count == 0) { app.Notify("Введите название и добавьте хотя бы один шаг."); return; }
            var draft = Draft(); var settings = ProfileStore.Copy(app.Settings); int index = settings.Scenarios.FindIndex(s => s.Id == draft.Id);
            if (index < 0) settings.Scenarios.Add(draft); else settings.Scenarios[index] = draft;
            try { app.ApplySettings(settings); selectedId = draft.Id; FillScenarios(); scenarios.SelectedIndex = app.Settings.Scenarios.FindIndex(s => s.Id == draft.Id) + 1; }
            catch (Exception ex) { app.Notify("Не удалось сохранить: " + ex.Message); }
        }, true));
        buttons.Controls.Add(Theme.Button("Предпросмотр", () => ShowDocument("Предпросмотр сценария", string.Join(Environment.NewLine, working.Select(s => s.Kind == "wait" ? $"Пауза {s.DelayMs} мс" : s.Kind + ": " + s.Text)))));
        buttons.Controls.Add(Theme.Button("Выполнить", () => _ = Execute(() => app.RunScenarioAsync(Draft()))));
        secondary.Controls.Add(Theme.Button("Удалить сценарий", () =>
        {
            if (selectedId == null) return;
            try { var settings = ProfileStore.Copy(app.Settings); settings.Scenarios.RemoveAll(s => s.Id == selectedId); app.ApplySettings(settings); FillScenarios(); }
            catch (Exception ex) { app.Notify("Не удалось удалить сценарий: " + ex.Message); }
        }));
        secondary.Controls.Add(Theme.Button("Отменить правки", () => { builderDirty = false; Navigate("Конструктор"); }));
        FillScenarios();
    }

    private void BuildLaws()
    {
        var pane = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3, BackColor = Theme.Background };
        pane.RowStyles.Add(new RowStyle(SizeType.Absolute, 48)); pane.RowStyles.Add(new RowStyle(SizeType.Absolute, 44)); pane.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); content.Controls.Add(pane);
        pane.Controls.Add(Theme.Label("Законодательство", true), 0, 0);
        var search = new TextBox { Dock = DockStyle.Fill, PlaceholderText = "Поиск по всем документам: статья, слово или фраза", MaxLength = 160 }; Register(search); pane.Controls.Add(search, 0, 1);
        var split = new SplitContainer { Dock = DockStyle.Fill, SplitterDistance = 240, BackColor = Theme.Background };
        var list = new ListBox { Dock = DockStyle.Fill }; Theme.Style(list);
        var body = new RichTextBox { Dock = DockStyle.Fill, ReadOnly = true, BorderStyle = BorderStyle.None, WordWrap = true, DetectUrls = false }; Register(body);
        split.Panel1.Controls.Add(list); split.Panel2.Controls.Add(body); pane.Controls.Add(split, 0, 2);
        var documents = app.Laws.Documents.ToList();
        foreach (var doc in documents) list.Items.Add(doc.Name);
        list.SelectedIndexChanged += (_, _) => { if (list.SelectedIndex >= 0 && list.SelectedIndex < documents.Count) { body.Text = documents[list.SelectedIndex].Text; body.SelectionStart = 0; } };
        if (list.Items.Count > 0) list.SelectedIndex = 0;
        var timer = new System.Windows.Forms.Timer { Interval = 180 };
        search.TextChanged += (_, _) => { timer.Stop(); timer.Start(); };
        timer.Tick += (_, _) =>
        {
            timer.Stop();
            if (string.IsNullOrWhiteSpace(search.Text)) { if (list.SelectedIndex >= 0) body.Text = documents[list.SelectedIndex].Text; return; }
            var hits = app.Laws.Search(search.Text).Take(30).ToList();
            body.Text = hits.Count == 0 ? "Совпадений нет. Попробуйте часть слова или номер статьи." : string.Join(Environment.NewLine + Environment.NewLine, hits.Select(h => h.Document + Environment.NewLine + h.Text));
            body.SelectionStart = 0;
        };
        search.Disposed += (_, _) => { timer.Stop(); timer.Dispose(); };
    }

    private static FlowLayoutPanel Toolbar() => new() { Dock = DockStyle.Top, Height = 50, AutoSize = false, WrapContents = false, BackColor = Theme.Background, Margin = Padding.Empty };
    private void BuildSettings()
    {
        settingsDirty = false;
        var draft = ProfileStore.Copy(app.Settings);
        var fieldValues = new Dictionary<string, string>();
        var apply = new Dictionary<string, Action>();
        var host = new Panel { Dock = DockStyle.Fill, BackColor = Theme.Background };
        var sections = Toolbar(); sections.Height = 47;
        var toolbar = Toolbar();
        content.Controls.Add(host); content.Controls.Add(sections); content.Controls.Add(toolbar);
        string currentSection = "Профиль";
        var sectionButtons = new Dictionary<string, GosButton>();
        void Render(string section)
        {
            editing = null; currentSection = section;
            foreach (Control child in host.Controls.Cast<Control>().ToArray()) child.Dispose(); host.Controls.Clear();
            foreach (var pair in sectionButtons) { pair.Value.Primary = pair.Key == section; pair.Value.Invalidate(); }
            var stack = new ResponsiveStack(); host.Controls.Add(stack);
            stack.Controls.Add(Theme.Label("Настройки · " + section, true));
            stack.Controls.Add(Theme.Label("Изменения применяются после сохранения. Переключение разделов сохраняет черновик."));
            void S(string label, Func<string> get, Action<string> set)
            {
                if (!fieldValues.ContainsKey(label)) fieldValues[label] = get();
                var input = Input(label, stack, fieldValues[label]);
                input.TextChanged += (_, _) => { fieldValues[label] = input.Text; settingsDirty = true; };
                apply[label] = () => set(fieldValues[label].Trim());
            }
            void N(string label, Func<int> get, Action<int> set, int min, int max)
            {
                S(label, () => get().ToString(), value => { if (!int.TryParse(value, out int number) || number < min || number > max) throw new ArgumentException($"{label}: от {min} до {max}."); set(number); });
            }
            void B(string label, Func<bool> get, Action<bool> set)
            {
                var box = new CheckBox { Text = label, Checked = get(), AutoSize = true, Font = Theme.UiBody(10), ForeColor = Theme.Text, Margin = new Padding(0, 8, 0, 12) };
                box.CheckedChanged += (_, _) => { set(box.Checked); settingsDirty = true; }; stack.Controls.Add(box);
            }
            if (section == "Профиль")
            {
                S("Фамилия / имя персонажа", () => draft.Name, v => draft.Name = v);
                S("Звание", () => draft.Rank, v => draft.Rank = v);
                S("Организация", () => draft.Department, v => draft.Department = v);
                S("Должность в представлении — «являюсь …»", () => draft.IntroRole, v => draft.IntroRole = v);
                S("Свой Nick_Name в игре", () => draft.ChatLogNickname, v => draft.ChatLogNickname = v);
                S("Путь к chatlog.txt", () => draft.ChatLogPath, v => draft.ChatLogPath = v);
            }
            else if (section == "Отправка")
            {
                stack.Controls.Add(Theme.Label("Способ отправки", true));
                foreach (var mode in new[] { SendMode.RandomTyping, SendMode.KeyAssisted, SendMode.Memory })
                {
                    var pick = Theme.Button(ModeText(mode), () => { draft.SendMode = mode; settingsDirty = true; Render(currentSection); }, draft.SendMode == mode);
                    pick.Width = 440; stack.Controls.Add(pick);
                }
                stack.Controls.Add(Theme.Label("Представление, остановка и права используют память независимо от выбранного режима."));
                N("Скорость от, символов/сек", () => draft.MinCps, v => draft.MinCps = v, 1, 500);
                N("Скорость до, символов/сек", () => draft.MaxCps, v => draft.MaxCps = v, 1, 500);
                N("Пауза между сообщениями, мс", () => draft.LineDelayMs, v => draft.LineDelayMs = v, 0, 10000);
                S("SHA-256 совместимой azmp.dll — необязательно", () => draft.ExpectedModuleHash, v => draft.ExpectedModuleHash = v);
            }
            else
            {
                B("Скрывать окна от поддерживаемого захвата OBS", () => draft.HideFromCapture, v => draft.HideFromCapture = v);
                B("Показывать HUD", () => draft.HudVisible, v => draft.HudVisible = v);
                B("Предлагать ID при наведении — F1 / F2", () => draft.AutoId, v => draft.AutoId = v);
                B("Предлагать ID после реанимации", () => draft.AutoRevive, v => draft.AutoRevive = v);
                B("Предлагать ID из событий преследования", () => draft.AutoChase, v => draft.AutoChase = v);
                stack.Controls.Add(Theme.Label("Для событий игры укажите путь к chatlog.txt в разделе «Профиль». Свой Nick_Name помогает распознавать сообщения о вашем персонаже."));
                B("Показывать игроков рядом", () => draft.NearbyVisible, v => draft.NearbyVisible = v);
                N("Радиус списка окружающих, м", () => draft.NearbyRadius, v => draft.NearbyRadius = v, 1, 300);
                N("Обновление списка окружающих, мс", () => draft.NearbyRefreshMs, v => draft.NearbyRefreshMs = v, 200, 5000);
            }
        }
        foreach (var section in new[] { "Профиль", "Отправка", "Оверлеи" })
        {
            var button = Theme.Button(section, () => Render(section)); button.Width = 156; sections.Controls.Add(button); sectionButtons[section] = button;
        }
        var save = Theme.Button("Сохранить", () =>
        {
            try { foreach (var action in apply.Values) action(); if (draft.MinCps > draft.MaxCps) throw new ArgumentException("Минимальная скорость не может превышать максимальную."); app.ApplySettings(draft); settingsDirty = false; editing = null; }
            catch (Exception ex) { app.Notify("Настройки: " + ex.Message); }
        }, true); save.Name = "settings-save"; toolbar.Controls.Add(save);
        var cancel = Theme.Button("Отменить изменения", () => { settingsDirty = false; Navigate("Настройки"); }); cancel.Name = "settings-cancel"; toolbar.Controls.Add(cancel);
        toolbar.Controls.Add(Theme.Button("Импорт INI", () =>
        {
            if (settingsDirty) { app.Notify("Сохраните или отмените черновик перед импортом."); return; }
            if (Passive) { app.Notify("Для выбора INI откройте меню на рабочем столе: системный диалог забирает фокус игры."); return; }
            using var dialog = new OpenFileDialog { Filter = "Профили AHK (*.ini)|*.ini", Title = "Импорт старого профиля" };
            if (dialog.ShowDialog(this) == DialogResult.OK) { app.ImportLegacy(dialog.FileName); settingsDirty = false; Navigate("Настройки"); }
        }));
        Render(currentSection);
    }

    private void BuildAbout()
    {
        var stack = Stack("AHK FOR GOS · 2.0 preview 2", "Самостоятельное приложение на C# / .NET 10. Старая версия AHK остаётся отдельно.");
        var notes = new TextBox { Width = 680, Height = 380, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical,
            Text = "Быстрый старт\r\nF10 — меню · Alt+T — команды · F1/F2 — Auto ID · Pause — отмена.\r\nНазначение сочетаний — раздел «Клавиши»: нажмите «Назначить» и физическое сочетание.\r\n\r\nВо время игры окна не активируются: выберите поле мышью и вводите текст. Esc завершает ввод или скрывает меню.\r\n\r\nПолноэкранный режим\r\nВнешние окна работают поверх игры через Windows/DWM. Настоящий эксклюзивный DirectX fullscreen может не показывать такие окна; используйте полноэкранный режим без рамки. Перехват графики игры в приложение не встроен.\r\n\r\nПамять и совместимость\r\nАдреса перенесены из исходников; конкретный клиент Amazing необходимо проверить отдельно. Неопределённая отправка автоматически не повторяется.\r\n\r\nOBS\r\nУспешный флаг Windows не доказывает результат видеозаписи. Проверьте используемый источник OBS.\r\n\r\nПриложение не является официальной программой Amazing. Соблюдайте правила сервера." };
        Register(notes); stack.Controls.Add(notes);
        stack.Controls.Add(Theme.Label(WindowPolicy.CaptureStatus));
        var status = Theme.Label(app.ConnectionStatus + Environment.NewLine + app.Status); status.MaximumSize = new Size(680, 0); stack.Controls.Add(status);
    }
    private TextBox Input(string label, Control parent, string value)
    {
        parent.Controls.Add(Theme.Label(label));
        var input = new TextBox { Text = value, Width = 560, Height = 30, MaxLength = 4096, Margin = new Padding(0, 0, 0, 14) }; Register(input); parent.Controls.Add(input); return input;
    }
    private void Register(TextBoxBase field)
    {
        Theme.Style(field); field.MouseDown += (_, _) => { editing = field; footer.Text = Passive ? "Поле выбрано · Esc — закончить ввод" : app.Status; };
    }
    private static FlowLayoutPanel Row() => new() { Width = 700, Height = 42, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, WrapContents = true, BackColor = Theme.Background, Margin = new Padding(0, 8, 0, 12) };
    private async Task Execute(Func<Task> action) { try { await action(); } catch (Exception ex) { app.Notify(ex.Message); } }
    private void ShowDocument(string title, string text) { var doc = new ReferenceForm(app, title, text); doc.ShowReference(); }
    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e); using var border = new Pen(Theme.Border); e.Graphics.DrawRectangle(border, 0, 0, Width - 1, Height - 1);
    }
    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x84)
        {
            var point = PointToClient(new Point(unchecked((short)(long)m.LParam), unchecked((short)((long)m.LParam >> 16))));
            int edge = Math.Max(5, (int)(6 * DeviceDpi / 96f));
            bool left = point.X < edge, right = point.X >= ClientSize.Width - edge;
            bool top = point.Y < edge, bottom = point.Y >= ClientSize.Height - edge;
            if (left || right || top || bottom)
            {
                m.Result = (nint)(top ? left ? 13 : right ? 14 : 12 : bottom ? left ? 16 : right ? 17 : 15 : left ? 10 : 11);
                return;
            }
        }
        base.WndProc(ref m);
    }
    public bool HandleKey(KeyStroke key)
    {
        if (!Visible || !Passive || key.Injected) return false;
        if (key.Down && key.VirtualKey == (int)Keys.Escape) { if (editing != null) editing = null; else Hide(); return true; }
        if (editing != null && !editing.IsDisposed) return PassiveTyping.Edit(editing, key);
        if (key.Down && key.VirtualKey is (int)Keys.PageDown or (int)Keys.PageUp)
        {
            foreach (Control control in content.Controls) if (control is FlowLayoutPanel scroll) scroll.AutoScrollPosition = new Point(0, -scroll.AutoScrollPosition.Y + (key.VirtualKey == (int)Keys.PageDown ? 300 : -300));
        }
        // While the passive menu is open, game movement must not receive typed letters.
        return true;
    }
}
