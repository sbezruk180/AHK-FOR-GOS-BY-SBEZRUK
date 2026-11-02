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
    private string currentPage = "Действия";
    private Label? targetLabel;
    public bool IsInputOpen => Visible;

    public ShellForm(IAppController controller)
    {
        app = controller; Text = "AHK FOR GOS · 2.0 / C#"; MinimumSize = new Size(760, 540); Size = new Size(1080, 760);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.None; Padding = new Padding(1);
        var titlebar = new Panel { Dock = DockStyle.Top, Height = 40, BackColor = Theme.Panel };
        var title = new Label { Text = "AHK FOR GOS  /  2.0", AutoSize = false, Dock = DockStyle.Fill,
            Padding = new Padding(18, 11, 0, 0), ForeColor = Theme.Muted, Font = Theme.Body(9) };
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
        var sidebar = new Panel { Dock = DockStyle.Left, Width = 184, BackColor = Theme.Panel, Padding = new Padding(14, 22, 14, 12) };
        var brand = Theme.Label("GOS", true); brand.Font = Theme.Heading(25); brand.ForeColor = Theme.Accent; brand.Location = new Point(20, 24);
        var version = Theme.Label("Личное рабочее место"); version.Font = Theme.Body(9); version.Location = new Point(20, 70);
        sidebar.Controls.Add(brand); sidebar.Controls.Add(version);
        string[] pages = ["Действия", "Конструктор", "Законы", "Настройки", "О приложении"];
        for (int i = 0; i < pages.Length; i++)
        {
            string page = pages[i]; var button = Theme.Button(page, () => Navigate(page)); button.Size = new Size(156, 42); button.Location = new Point(14, 128 + i * 52);
            navigation[page] = button; sidebar.Controls.Add(button);
        }
        var stop = Theme.Button("Остановить · Pause", app.Cancel); stop.ForeColor = Theme.Danger; stop.Dock = DockStyle.Bottom; sidebar.Controls.Add(stop);
        Controls.Add(content); Controls.Add(sidebar); Controls.Add(footer); Controls.Add(titlebar);
        FormClosing += (_, e) => { if (e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; editing = null; Hide(); } };
        app.Changed += StateChanged; Disposed += (_, _) => app.Changed -= StateChanged;
        Navigate("Действия");
    }

    public void ShowPassive()
    {
        Configure(app.IsGameActive, app.Settings.HideFromCapture);
        if (!Visible) Show(); else Invalidate();
        if (!Passive) Activate();
        StateChanged();
    }
    private void StateChanged()
    {
        if (IsDisposed || !IsHandleCreated) return;
        if (InvokeRequired) { BeginInvoke((Action)StateChanged); return; }
        string selected = app.Target is { } target ? $"ID {target.Id} · {target.Name}" : "Цель не выбрана";
        if (targetLabel != null) targetLabel.Text = selected;
        footer.Text = editing != null && Passive ? "Ввод в выделенное поле · Ctrl+A — выделить · Esc — закончить ввод" : app.Status;
        WindowPolicy.Apply(this, app.Settings.HideFromCapture, Passive);
    }
    public void ReviewPage(string page) => Navigate(page);
    private void Navigate(string page)
    {
        if (currentPage == "Настройки" && settingsDirty)
        {
            app.Notify("Есть несохранённые настройки. Нажмите «Сохранить» или «Отменить изменения»."); return;
        }
        if (currentPage == "Конструктор" && builderDirty)
        {
            app.Notify("Есть несохранённый сценарий. Сохраните его или нажмите «Отменить правки»."); return;
        }
        currentPage = page; editing = null; targetLabel = null; saveFields.Clear();
        foreach (Control c in content.Controls.Cast<Control>().ToArray()) c.Dispose();
        content.Controls.Clear();
        foreach (var pair in navigation) { pair.Value.Primary = pair.Key == page; pair.Value.Invalidate(); }
        if (page == "Действия") BuildActions();
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
    private void BuildActions()
    {
        var stack = Stack("Действия", "Выберите цель через Auto ID, затем выполните нужное действие. F1 — принять, F2 — отклонить.");
        targetLabel = Theme.Label(""); targetLabel.ForeColor = Theme.Good; stack.Controls.Add(targetLabel);
        var targetRow = Row();
        var manual = new TextBox { Width = 100, MaxLength = 4, PlaceholderText = "ID" }; Register(manual); targetRow.Controls.Add(manual);
        targetRow.Controls.Add(Theme.Button("Выбрать ID", () => { if (int.TryParse(manual.Text, out int id) && id is >= 0 and <= 1003) app.SetManualTarget(id); else app.Notify("ID: число от 0 до 1003."); }));
        targetRow.Controls.Add(Theme.Button("Сбросить цель", app.ClearTarget)); stack.Controls.Add(targetRow);
        var cancel = Theme.Button("Отменить всё · Pause", app.Cancel); cancel.Width = 240; stack.Controls.Add(cancel);
        foreach (var action in ActionCatalog.All)
        {
            var card = new Panel { Width = Math.Max(300, content.Width - 48), Height = 88, BackColor = Theme.Panel, Margin = new Padding(0, 0, 0, 10) };
            var title = Theme.Label(action.Name); title.ForeColor = Theme.Text; title.Font = Theme.Heading(11); title.Location = new Point(16, 10); card.Controls.Add(title);
            var description = Theme.Label(action.Description);
            description.AutoSize = false; description.SetBounds(16, 36, Math.Max(140, card.Width - 180), 45); card.Controls.Add(description);
            var run = Theme.Button(action.Key == "rights-gui" ? "Открыть" : "Выполнить", () => _ = Execute(() => app.RunAsync(action.Key)), true);
            run.Size = new Size(130, 38); run.Location = new Point(card.Width - 148, 24); run.Anchor = AnchorStyles.Right | AnchorStyles.Top; card.Controls.Add(run);
            description.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right; stack.Controls.Add(card);
        }
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
        var buttons = Row(); stack.Controls.Add(buttons);
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
        buttons.Controls.Add(Theme.Button("Удалить сценарий", () =>
        {
            if (selectedId == null) return;
            try { var settings = ProfileStore.Copy(app.Settings); settings.Scenarios.RemoveAll(s => s.Id == selectedId); app.ApplySettings(settings); FillScenarios(); }
            catch (Exception ex) { app.Notify("Не удалось удалить сценарий: " + ex.Message); }
        }));
        buttons.Controls.Add(Theme.Button("Отменить правки", () => { builderDirty = false; Navigate("Конструктор"); }));
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

    private void BuildSettings()
    {
        settingsDirty = false;
        var draft = ProfileStore.Copy(app.Settings);
        var stack = Stack("Настройки", "Изменения применяются только кнопкой «Сохранить». Прежние INI можно импортировать без изменения исходного файла.");
        string S(Func<string> get, Action<string> set, string label) { var input = Input(label, stack, get()); input.TextChanged += (_, _) => settingsDirty = true; saveFields.Add(() => set(input.Text.Trim())); return input.Text; }
        void B(Func<bool> get, Action<bool> set, string label) { var box = new CheckBox { Text = label, Checked = get(), AutoSize = true, ForeColor = Theme.Text, Margin = new Padding(0, 5, 0, 12) }; box.CheckedChanged += (_, _) => settingsDirty = true; stack.Controls.Add(box); saveFields.Add(() => set(box.Checked)); }
        void N(Func<int> get, Action<int> set, string label, int min, int max) { var field = Input(label, stack, get().ToString()); field.TextChanged += (_, _) => settingsDirty = true; saveFields.Add(() => { if (!int.TryParse(field.Text, out int v) || v < min || v > max) throw new ArgumentException($"{label}: от {min} до {max}."); set(v); }); }
        S(() => draft.Name, v => draft.Name = v, "Фамилия / имя персонажа");
        S(() => draft.Rank, v => draft.Rank = v, "Звание для представления и докладов");
        S(() => draft.Department, v => draft.Department = v, "Организация");
        S(() => draft.IntroRole, v => draft.IntroRole = v, "Должность в представлении — «являюсь …»");
        var mode = draft.SendMode;
        string ModeName() => mode switch { SendMode.Memory => "Через память", SendMode.KeyAssisted => "Одна физическая клавиша — один нужный символ", _ => "Печать со случайной скоростью" };
        var select = Theme.Button(ModeName(), () => { }); select.Width = 560;
        select.Click += (_, _) => { mode = mode == SendMode.RandomTyping ? SendMode.KeyAssisted : mode == SendMode.KeyAssisted ? SendMode.Memory : SendMode.RandomTyping; select.Text = ModeName(); settingsDirty = true; };
        stack.Controls.Add(Theme.Label("Способ отправки — нажмите, чтобы переключить")); stack.Controls.Add(select); saveFields.Add(() => draft.SendMode = mode);
        N(() => draft.MinCps, v => draft.MinCps = v, "Минимальная скорость, символов/сек", 1, 500);
        N(() => draft.MaxCps, v => draft.MaxCps = v, "Максимальная скорость, символов/сек", 1, 500);
        N(() => draft.LineDelayMs, v => draft.LineDelayMs = v, "Пауза между сообщениями, мс", 0, 10000);
        B(() => draft.HideFromCapture, v => draft.HideFromCapture = v, "Скрывать окна от поддерживаемого захвата OBS");
        B(() => draft.HudVisible, v => draft.HudVisible = v, "Показывать HUD");
        B(() => draft.AutoId, v => draft.AutoId = v, "Предлагать ID при наведении — F1 / F2");
        B(() => draft.AutoRevive, v => draft.AutoRevive = v, "Подставлять предложение ID после события реанимации");
        B(() => draft.AutoChase, v => draft.AutoChase = v, "Подставлять предложение ID из событий преследования");
        B(() => draft.NearbyVisible, v => draft.NearbyVisible = v, "Показывать игроков рядом");
        N(() => draft.NearbyRadius, v => draft.NearbyRadius = v, "Радиус списка окружающих, м", 1, 300);
        N(() => draft.NearbyRefreshMs, v => draft.NearbyRefreshMs = v, "Обновление списка окружающих, мс", 200, 5000);
        S(() => draft.ChatLogNickname, v => draft.ChatLogNickname = v, "Свой Nick_Name в chatlog.txt — для фильтрации своих событий");
        S(() => draft.ChatLogPath, v => draft.ChatLogPath = v, "Путь к chatlog.txt для автоматизаций");
        S(() => draft.ExpectedModuleHash, v => draft.ExpectedModuleHash = v, "SHA-256 совместимой azmp.dll — необязательно, проверяется строго если задан");
        stack.Controls.Add(Theme.Label("Горячие клавиши", true));
        stack.Controls.Add(Theme.Label("Формат: Alt+T, Ctrl+F8, F10. Pause — аварийная отмена. F1/F2 — ответ Auto ID."));
        S(() => draft.Hotkeys.GetValueOrDefault("menu", "F10"), v => draft.Hotkeys["menu"] = v, "Открыть / закрыть меню");
        S(() => draft.Hotkeys.GetValueOrDefault("palette", "Alt+T"), v => draft.Hotkeys["palette"] = v, "Открыть окно команд");
        foreach (var action in ActionCatalog.All)
        {
            string key = action.Key;
            S(() => draft.Hotkeys.TryGetValue(key, out string? value) ? value : "", v => { if (v.Length == 0) draft.Hotkeys.Remove(key); else draft.Hotkeys[key] = v; }, action.Name);
        }
        var buttons = Row(); buttons.Dock = DockStyle.Top; buttons.Height = 52; buttons.AutoSize = false;
        content.Controls.Add(buttons);
        buttons.Controls.Add(Theme.Button("Сохранить", () =>
        {
            try
            {
                foreach (var save in saveFields) save();
                if (draft.MinCps > draft.MaxCps) throw new ArgumentException("Минимальная скорость не может превышать максимальную.");
                app.ApplySettings(draft); settingsDirty = false; editing = null;
            }
            catch (Exception ex) { app.Notify("Настройки: " + ex.Message); }
        }, true));
        buttons.Controls.Add(Theme.Button("Отменить изменения", () => { settingsDirty = false; Navigate("Настройки"); }));
        buttons.Controls.Add(Theme.Button("Импорт INI", () =>
        {
            if (Passive) { app.Notify("Для выбора INI откройте меню на рабочем столе: системный диалог забирает фокус игры."); return; }
            using var dialog = new OpenFileDialog { Filter = "Профили AHK (*.ini)|*.ini", Title = "Импорт старого профиля" };
            if (dialog.ShowDialog(this) == DialogResult.OK) { app.ImportLegacy(dialog.FileName); settingsDirty = false; Navigate("Настройки"); }
        }));
    }

    private void BuildAbout()
    {
        var stack = Stack("AHK FOR GOS · 2.0", "Самостоятельное приложение на C# / .NET 10. Старая версия AHK остаётся отдельно.");
        var notes = new TextBox { Width = 680, Height = 380, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical,
            Text = "Быстрый старт\r\nF10 — меню · Alt+T — команды · F1/F2 — Auto ID · Pause — отмена.\r\n\r\nВо время игры окна не активируются: выберите поле мышью и вводите текст. Esc завершает ввод или скрывает меню.\r\n\r\nПолноэкранный режим\r\nВнешние окна работают поверх игры через Windows/DWM. Настоящий эксклюзивный DirectX fullscreen может не показывать такие окна; используйте полноэкранный режим без рамки. Перехват графики игры в приложение не встроен.\r\n\r\nПамять и совместимость\r\nАдреса перенесены из исходников; конкретный клиент Amazing необходимо проверить отдельно. Неопределённая отправка автоматически не повторяется.\r\n\r\nOBS\r\nУспешный флаг Windows не доказывает результат видеозаписи. Проверьте используемый источник OBS.\r\n\r\nПриложение не является официальной программой Amazing. Соблюдайте правила сервера." };
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
