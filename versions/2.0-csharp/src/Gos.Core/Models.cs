using System.Text.RegularExpressions;

namespace Gos.Core;

public enum SendMode { RandomTyping, KeyAssisted, Memory }
public sealed record TargetSnapshot(int Id, string Name, uint Ped = 0);
public sealed record NearbyPlayer(int Id, string Name, double Distance);
public sealed record ActionDefinition(string Key, string Name, string Description, bool RequiresTarget,
    bool ForceMemory, string[] Lines, string[] Aliases);

public sealed class AppSettings
{
    public int SchemaVersion { get; set; } = 1;
    public string Name { get; set; } = "Лукашенко";
    public string Rank { get; set; } = "лейтенант полиции";
    public string Department { get; set; } = "ГАИ";
    public string IntroRole { get; set; } = "сотрудником ГАИ";
    public string ChatLogNickname { get; set; } = "";
    public string ChatLogPath { get; set; } = "";
    public string ExpectedModuleHash { get; set; } = "";
    public SendMode SendMode { get; set; } = SendMode.RandomTyping;
    public int MinCps { get; set; } = 40;
    public int MaxCps { get; set; } = 90;
    public int LineDelayMs { get; set; } = 900;
    public bool HideFromCapture { get; set; } = true;
    public bool AutoId { get; set; } = true;
    public bool AutoRevive { get; set; } = true;
    public bool AutoChase { get; set; } = true;
    public bool HudVisible { get; set; } = true;
    public bool NearbyVisible { get; set; } = true;
    public int NearbyRadius { get; set; } = 30;
    public int NearbyRefreshMs { get; set; } = 500;
    public Dictionary<string, string> Hotkeys { get; set; } = new(StringComparer.OrdinalIgnoreCase) { ["menu"]="F10", ["palette"]="Alt+T" };
    public Dictionary<string, string[]> ActionTemplates { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public List<Scenario> Scenarios { get; set; } = [];

    public void Normalize()
    {
        SchemaVersion = 1;
        Name = SingleLine(Name, 80); Rank = SingleLine(Rank, 80); Department = SingleLine(Department, 40);
        IntroRole = SingleLine(IntroRole, 100); ChatLogNickname = SingleLine(ChatLogNickname, 48);
        ChatLogPath = (ChatLogPath ?? "").Trim();
        ExpectedModuleHash = (ExpectedModuleHash ?? "").Trim().ToUpperInvariant();
        if (ExpectedModuleHash.Length != 0 && !Regex.IsMatch(ExpectedModuleHash, "^[0-9A-F]{64}$"))
            throw new InvalidDataException("SHA-256 модуля должен состоять из 64 шестнадцатеричных символов.");
        if (!Enum.IsDefined(SendMode)) SendMode = SendMode.RandomTyping;
        MinCps = Math.Clamp(MinCps, 1, 500); MaxCps = Math.Clamp(MaxCps, MinCps, 500);
        LineDelayMs = Math.Clamp(LineDelayMs, 0, 10000);
        NearbyRadius = Math.Clamp(NearbyRadius, 1, 300);
        NearbyRefreshMs = Math.Clamp(NearbyRefreshMs, 200, 5000);
        Hotkeys = new(Hotkeys ?? [], StringComparer.OrdinalIgnoreCase);
        Hotkeys.TryAdd("menu","F10"); Hotkeys.TryAdd("palette","Alt+T");
        foreach (var key in Hotkeys.Keys.ToArray()) Hotkeys[key] = SingleLine(Hotkeys[key], 80);
        ActionTemplates = new(ActionTemplates ?? [], StringComparer.OrdinalIgnoreCase);
        foreach (var (key, lines) in ActionTemplates)
        {
            if (lines is null || lines.Length > 100 || lines.Any(x => x is null || x.Length > 512 || x.IndexOfAny(['\r','\n','\0']) >= 0))
                throw new InvalidDataException($"Некорректный шаблон действия: {key}");
        }
        Scenarios ??= [];
        if (Scenarios.Count > 100) throw new InvalidDataException("Не более 100 сценариев.");
        HashSet<string> ids = new(StringComparer.Ordinal);
        foreach (var scenario in Scenarios)
        {
            if (scenario is null) throw new InvalidDataException("Пустой сценарий.");
            scenario.Validate();
            if (!ids.Add(scenario.Id)) throw new InvalidDataException("Повторяется ID сценария.");
        }
    }
    private static string SingleLine(string? text, int length)
    {
        var value = (text ?? "").Replace('\r',' ').Replace('\n',' ').Replace('\0',' ').Trim();
        return value.Length <= length ? value : value[..length];
    }
}

public sealed class Scenario
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Name { get; set; } = "Новый сценарий";
    public List<ScenarioStep> Steps { get; set; } = [];
    public void Validate()
    {
        if (string.IsNullOrWhiteSpace(Id) || Id.Length > 80 || string.IsNullOrWhiteSpace(Name) || Name.Length > 100)
            throw new InvalidDataException("Укажите название и идентификатор сценария.");
        if (Steps is null || Steps.Count is 0 or > 100) throw new InvalidDataException("В сценарии должно быть от 1 до 100 шагов.");
        foreach (var step in Steps) { if(step is null) throw new InvalidDataException("Пустой шаг."); step.Validate(); }
        if (Steps.Sum(x => (long)x.DelayMs) > 600000) throw new InvalidDataException("Суммарная пауза сценария превышает 10 минут.");
    }
}
public sealed class ScenarioStep
{
    public string Kind { get; set; } = "send";
    public string Text { get; set; } = "";
    public int DelayMs { get; set; }
    public static ScenarioStep Send(string text) => new() {Text = text};
    public static ScenarioStep Wait(int milliseconds) => new() {Kind = "wait", DelayMs = milliseconds};
    public void Validate()
    {
        if (Kind is not ("send" or "wait" or "notice" or "key")) throw new InvalidDataException($"Неизвестный тип шага: {Kind}");
        if (DelayMs < 0 || DelayMs > 120000) throw new InvalidDataException("Пауза должна быть от 0 до 120000 мс.");
        if (Text is null || Text.Length > 512 || Text.IndexOfAny(['\r','\n','\0']) >= 0) throw new InvalidDataException("Шаг должен содержать одну строку до 512 символов.");
        if ((Kind is "send" or "notice") && string.IsNullOrWhiteSpace(Text)) throw new InvalidDataException("Введите текст шага.");
        if (Kind == "key" && Text is not ("Down" or "Up" or "Enter" or "Home" or "End"))
            throw new InvalidDataException("Разрешены только Down, Up, Enter, Home и End.");
    }
}

public static class Template
{
    public static string Expand(string text, AppSettings settings, TargetSnapshot? target)
    {
        if (text.Contains("{id}", StringComparison.OrdinalIgnoreCase) && target is null)
            throw new InvalidOperationException("Сначала выберите ID игрока.");
        var replacements = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase)
        {
            ["id"] = target?.Id.ToString(System.Globalization.CultureInfo.InvariantCulture) ?? "",
            ["name"] = settings.Name, ["rank"] = settings.Rank, ["department"] = settings.Department,
            ["introRole"] = settings.IntroRole, ["targetName"] = target?.Name ?? ""
        };
        return Regex.Replace(text, "\\{([a-zA-Z]+)\\}", match => replacements.TryGetValue(match.Groups[1].Value, out var value)
            ? value : throw new InvalidDataException($"Неизвестная переменная: {match.Value}"));
    }
}
