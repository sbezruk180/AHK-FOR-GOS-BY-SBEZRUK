using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

namespace Gos.Windows;

public static class Theme
{
    public static readonly Color Background = Color.FromArgb(15, 18, 27);
    public static readonly Color Panel = Color.FromArgb(23, 28, 41);
    public static readonly Color Surface = Color.FromArgb(33, 39, 56);
    public static readonly Color Border = Color.FromArgb(57, 66, 87);
    public static readonly Color Text = Color.FromArgb(239, 242, 250);
    public static readonly Color Muted = Color.FromArgb(174, 184, 205);
    public static readonly Color Accent = Color.FromArgb(145, 125, 255);
    public static readonly Color AccentFill = Color.FromArgb(95, 71, 207);
    public static readonly Color Good = Color.FromArgb(116, 224, 184);
    public static readonly Color Danger = Color.FromArgb(255, 151, 168);
    public static Font Body(float size = 10) => new("Segoe UI", size, FontStyle.Regular);
    public static Font Heading(float size = 18) => new("Segoe UI", size, FontStyle.Bold);

    public static void Style(Control control)
    {
        control.Font = Body();
        control.ForeColor = Text;
        if (control is TextBoxBase or ListBox or ListView or ComboBox or NumericUpDown)
            control.BackColor = Surface;
        else if (control is not GosButton) control.BackColor = Panel;
        if (control is TextBoxBase text) text.BorderStyle = BorderStyle.FixedSingle;
        if (control is ListBox list) { list.BorderStyle = BorderStyle.FixedSingle; list.ItemHeight = 25; }
        if (control is ComboBox combo) combo.FlatStyle = FlatStyle.Flat;
        if (control is ListView view) { view.BorderStyle = BorderStyle.FixedSingle; view.FullRowSelect = true; view.HideSelection = false; }
        foreach (Control child in control.Controls) Style(child);
    }

    public static Label Label(string text, bool heading = false) => new()
    {
        Text = text, ForeColor = heading ? Text : Muted, AutoSize = true,
        Font = heading ? Heading() : Body(), Margin = new Padding(0, 0, 0, 12)
    };

    public static GosButton Button(string text, Action action, bool primary = false)
    {
        var button = new GosButton { Text = text, Primary = primary, AutoSize = false, Size = new Size(160, 38) };
        button.Click += (_, _) => action();
        return button;
    }
}

public sealed class GosButton : Button
{
    [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
    public bool Primary { get; set; }
    private bool hovered;
    public GosButton()
    {
        FlatStyle = FlatStyle.Flat; FlatAppearance.BorderSize = 0;
        ForeColor = Theme.Text; BackColor = Theme.Surface; Font = Theme.Body();
        Cursor = Cursors.Hand; Margin = new Padding(0, 0, 10, 10);
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true);
    }
    protected override void OnMouseEnter(EventArgs e) { hovered = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hovered = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.Clear(Parent?.BackColor ?? Theme.Panel);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        var rect = new Rectangle(1, 1, Math.Max(1, Width - 3), Math.Max(1, Height - 3));
        var fill = Primary ? Theme.AccentFill : Theme.Surface;
        if (hovered && Enabled) fill = ControlPaint.Light(fill, .12f);
        using var path = new GraphicsPath();
        const int corner = 12;
        path.AddArc(rect.Left, rect.Top, corner, corner, 180, 90);
        path.AddArc(rect.Right - corner, rect.Top, corner, corner, 270, 90);
        path.AddArc(rect.Right - corner, rect.Bottom - corner, corner, corner, 0, 90);
        path.AddArc(rect.Left, rect.Bottom - corner, corner, corner, 90, 90); path.CloseFigure();
        using var brush = new SolidBrush(fill); e.Graphics.FillPath(brush, path);
        if (Focused && ShowFocusCues) { using var pen = new Pen(Theme.Accent, 2); e.Graphics.DrawPath(pen, path); }
        TextRenderer.DrawText(e.Graphics, Text, Font, rect, Enabled ? Theme.Text : Theme.Muted,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
    }
}

/// <summary>One policy for every top-level window, including policy changes after creation.</summary>
public static class WindowPolicy
{
    private sealed class PolicyState { public nint Handle; public bool Hidden, Passive, Applied; }
    private static readonly System.Runtime.CompilerServices.ConditionalWeakTable<Form, PolicyState> states = new();
    public static string CaptureStatus { get; private set; } = "Статус захвата ещё не проверен";
    public static void Apply(Form form, bool hideFromCapture, bool passive)
    {
        if (form.IsDisposed) return;
        var handle = form.Handle;
        var previous = states.GetValue(form, _ => new PolicyState());
        if (previous.Applied && previous.Handle == handle && previous.Hidden == hideFromCapture && previous.Passive == passive) return;
        previous.Handle = handle; previous.Hidden = hideFromCapture; previous.Passive = passive; previous.Applied = true;
        try
        {
            int style = GetWindowLong(handle, -20);
            style = passive ? style | 0x08000000 : style & ~0x08000000;
            SetWindowLong(handle, -20, style);
            SetWindowPos(handle, 0, 0, 0, 0, 0, 0x37);
            bool accepted = SetWindowDisplayAffinity(handle, hideFromCapture ? 0x11u : 0u);
            bool read = GetWindowDisplayAffinity(handle, out uint actual);
            CaptureStatus = accepted && read && actual == (hideFromCapture ? 0x11u : 0u)
                ? hideFromCapture ? "Windows: защита захвата включена; запись OBS проверяется отдельно" : "Windows: защита захвата выключена"
                : "Windows не подтвердила режим захвата (код " + Marshal.GetLastWin32Error() + ")";
        }
        catch (EntryPointNotFoundException) { CaptureStatus = "Эта Windows не поддерживает защиту захвата"; }
    }
    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")] private static extern int GetWindowLong(nint hwnd, int index);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")] private static extern int SetWindowLong(nint hwnd, int index, int value);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool SetWindowDisplayAffinity(nint hwnd, uint affinity);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool GetWindowDisplayAffinity(nint hwnd, out uint affinity);
    [DllImport("user32.dll")] private static extern bool SetWindowPos(nint hwnd, nint after, int x, int y, int w, int h, uint flags);
}

public class GosForm : Form
{
    [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
    public bool Passive { get; protected set; }
    protected override bool ShowWithoutActivation => Passive;
    public GosForm()
    {
        Font = Theme.Body(); BackColor = Theme.Background; ForeColor = Theme.Text;
        AutoScaleMode = AutoScaleMode.Dpi; DoubleBuffered = true;
    }
    protected override CreateParams CreateParams
    {
        get { var cp = base.CreateParams; cp.ExStyle |= 0x80; if (Passive) cp.ExStyle |= 0x08000000; return cp; }
    }
    protected override void WndProc(ref Message m)
    {
        if (Passive && m.Msg == 0x21) { m.Result = (nint)3; return; }
        base.WndProc(ref m);
    }
    protected void Configure(bool passive, bool hidden)
    {
        Passive = passive; TopMost = passive;
        WindowPolicy.Apply(this, hidden, passive);
    }
    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        var work = Screen.FromControl(this).WorkingArea;
        if (Width > work.Width) Width = work.Width;
        if (Height > work.Height) Height = work.Height;
        Location = new Point(Math.Clamp(Left, work.Left, Math.Max(work.Left, work.Right - Width)),
            Math.Clamp(Top, work.Top, Math.Max(work.Top, work.Bottom - Height)));
    }
}

internal static class PassiveTyping
{
    [DllImport("user32.dll")] private static extern bool GetKeyboardState(byte[] state);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(nint hwnd, out uint pid);
    [DllImport("user32.dll")] private static extern nint GetForegroundWindow();
    [DllImport("user32.dll")] private static extern nint GetKeyboardLayout(uint thread);
    [DllImport("user32.dll")] private static extern uint MapVirtualKeyEx(uint code, uint type, nint layout);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int ToUnicodeEx(uint vk, uint scan, byte[] state, System.Text.StringBuilder buffer, int length, uint flags, nint layout);
    public static string Text(int key)
    {
        if (key < 0x20 || key == (int)Keys.Delete) return "";
        var state = new byte[256]; GetKeyboardState(state);
        foreach (int modifier in new[] { 0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5 })
            if (KeyboardHook.IsKeyDown(modifier)) state[modifier] |= 0x80;
        uint thread = GetWindowThreadProcessId(GetForegroundWindow(), out _);
        nint layout = GetKeyboardLayout(thread);
        var text = new System.Text.StringBuilder(8);
        int count = ToUnicodeEx((uint)key, MapVirtualKeyEx((uint)key, 0, layout), state, text, 8, 4, layout);
        return count > 0 ? text.ToString(0, count) : "";
    }
    public static bool Edit(TextBoxBase field, KeyStroke key)
    {
        if (!key.Down) return true;
        if (field.ReadOnly)
        {
            if (key.VirtualKey == (int)Keys.Down || key.VirtualKey == (int)Keys.PageDown) field.SelectionStart = Math.Min(field.TextLength, field.SelectionStart + 400);
            else if (key.VirtualKey == (int)Keys.Up || key.VirtualKey == (int)Keys.PageUp) field.SelectionStart = Math.Max(0, field.SelectionStart - 400);
            field.ScrollToCaret(); return true;
        }
        if (KeyboardHook.IsKeyDown((int)Keys.ControlKey))
        {
            if (key.VirtualKey == (int)Keys.A) { field.SelectAll(); return true; }
            if (key.VirtualKey is (int)Keys.C or (int)Keys.X or (int)Keys.V)
            {
                try
                {
                    if (key.VirtualKey == (int)Keys.V && Clipboard.ContainsText())
                    {
                        string value = Clipboard.GetText();
                        if (!field.Multiline) value = value.Replace("\r", "").Replace("\n", " ");
                        int available = field.MaxLength - (field.TextLength - field.SelectionLength);
                        if (available > 0) field.SelectedText = value[..Math.Min(available, value.Length)];
                    }
                    else if (key.VirtualKey is (int)Keys.C or (int)Keys.X && field.SelectionLength > 0)
                    { Clipboard.SetText(field.SelectedText); if (key.VirtualKey == (int)Keys.X) field.SelectedText = ""; }
                }
                catch (ExternalException) { /* A busy clipboard must not break the keyboard hook. */ }
                return true;
            }
        }
        if (key.VirtualKey == (int)Keys.Back)
        {
            if (field.SelectionLength > 0) field.SelectedText = "";
            else if (field.SelectionStart > 0) { field.SelectionStart--; field.SelectionLength = 1; field.SelectedText = ""; }
            return true;
        }
        if (key.VirtualKey == (int)Keys.Delete)
        {
            if (field.SelectionLength == 0 && field.SelectionStart < field.TextLength) field.SelectionLength = 1;
            field.SelectedText = ""; return true;
        }
        if (key.VirtualKey is (int)Keys.Left or (int)Keys.Right or (int)Keys.Home or (int)Keys.End)
        {
            field.SelectionStart = key.VirtualKey == (int)Keys.Home ? 0 : key.VirtualKey == (int)Keys.End ? field.TextLength
                : Math.Clamp(field.SelectionStart + (key.VirtualKey == (int)Keys.Left ? -1 : 1), 0, field.TextLength);
            field.SelectionLength = 0; return true;
        }
        if (key.VirtualKey == (int)Keys.Enter) { if (field.Multiline) field.SelectedText = Environment.NewLine; return true; }
        if (KeyboardHook.IsKeyDown((int)Keys.ControlKey) || KeyboardHook.IsKeyDown((int)Keys.Menu)) return true;
        string text = Text(key.VirtualKey);
        if (field.TextLength - field.SelectionLength + text.Length <= field.MaxLength) field.SelectedText = text;
        field.ScrollToCaret(); return true;
    }
}


/// <summary>A vertical page whose content width never exceeds its visible viewport.</summary>
internal sealed class ResponsiveStack : FlowLayoutPanel
{
    private bool arranging;
    private readonly Dictionary<Control, int> preferredWidths = new();
    public ResponsiveStack()
    {
        Dock = DockStyle.Fill; FlowDirection = FlowDirection.TopDown; WrapContents = false;
        AutoScroll = true; BackColor = Theme.Background;
        DoubleBuffered = true;
    }
    protected override void OnControlAdded(ControlEventArgs e)
    {
        preferredWidths[e.Control!] = e.Control!.Width;
        base.OnControlAdded(e); PerformLayout();
    }
    protected override void OnControlRemoved(ControlEventArgs e)
    {
        preferredWidths.Remove(e.Control!); base.OnControlRemoved(e);
    }
    protected override void OnLayout(LayoutEventArgs levent)
    {
        if (arranging || ClientSize.Width < 40) { base.OnLayout(levent); return; }
        arranging = true;
        try
        {
            // Always reserve a vertical scrollbar so appearing/disappearing scrollbars
            // cannot make a previous content width overflow the next layout.
            int available = Math.Max(100, ClientSize.Width - Padding.Horizontal - SystemInformation.VerticalScrollBarWidth - 6);
            foreach (Control child in Controls)
            {
                int width = Math.Max(60, available - child.Margin.Horizontal);
                if (child is Label or CheckBox)
                {
                    child.MaximumSize = new Size(width, 0);
                }
                else if (child is FlowLayoutPanel row)
                {
                    row.MaximumSize = new Size(width, 0);
                    row.MinimumSize = new Size(width, 0);
                    row.Width = width;
                    row.AutoSizeMode = AutoSizeMode.GrowAndShrink;
                }
                else if (child is Panel)
                {
                    child.Width = width;
                }
                else
                {
                    int desired = preferredWidths.GetValueOrDefault(child, width);
                    child.Width = Math.Min(width, Math.Max(60, desired));
                }
            }
            AutoScrollMinSize = Size.Empty;
            base.OnLayout(levent);
        }
        finally { arranging = false; }
    }
}
