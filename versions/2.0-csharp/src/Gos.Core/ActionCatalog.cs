using System.Text;

namespace Gos.Core;

public static class ActionCatalog
{
    public static IReadOnlyList<ActionDefinition> All { get; } = Array.AsReadOnly(new[]
    {
        new ActionDefinition("intro", "Представиться", "Представление от имени персонажа. Всегда отправляется через память.", false, true,
            ["Здравия желаю, являюсь {introRole}, {rank} {name}."], ["предст", "представление", "intro", "introduce"]),
        new ActionDefinition("chase", "Начать преследование", "Открыть преследование без указания ID.", false, false, ["/chase"], ["погоня", "chase"]),
        new ActionDefinition("chase-id", "Преследовать выбранного", "Начать преследование выбранного ID.", true, false, ["/chase {id}"], ["chaseid", "погоняид"]),
        new ActionDefinition("deject", "Высадить из автомобиля", "Высадить выбранного игрока командой /deject.", true, false, ["/deject {id}"], ["dejected", "deject", "высадить"]),
        new ActionDefinition("cuff", "Надеть наручники", "Команда /cuff для выбранного игрока.", true, false, ["/cuff {id}"], ["наручники", "cuff"]),
        new ActionDefinition("incar", "Посадить в автомобиль", "RP посадки и команда /incar для выбранного игрока.", true, false,
            ["/me подошел к патрульному автомобилю.", "/me открыл дверь патрульного автомобиля.",
             "/me аккуратно посадил задержанного в автомобиль.", "/me пристегнул задержанного ремнем безопасности.",
             "/do Задержанный находится на заднем сиденье патрульного автомобиля.", "/incar {id}"], ["посадить", "incar"]),
        new ActionDefinition("stop", "Потребовать остановку", "Два требования остановки через память. Интервал между запусками — 30 секунд.", false, true,
            ["/m [{department}] Водитель, примите вправо и остановитесь у обочины.", "/m [{department}] Заглушите двигатель и оставайтесь в автомобиле."], ["остановка", "стоп", "stop"]),
        new ActionDefinition("sos", "Вызвать помощь", "Открыть /sos и подтвердить пункт меню стрелкой вниз и Enter.", false, false, ["/sos"], ["сос", "помощь", "sos"]),
        new ActionDefinition("rights", "Зачитать права", "Пять сообщений через память. Паузы между сообщениями настраиваются отдельно от скорости печати.", false, true,
            ["Вы имеете право на отказ от дачи показаний против себя и своих близких.",
             "Вы имеете право на ознакомление со всеми протоколами, составленными при задержании.",
             "Вы имеете право на адвоката, переводчика и медицинскую помощь. Вам они будут предоставлены в ИВС.",
             "Вы имеете право на один телефонный звонок.",
             "Если вы желаете обжаловать задержание, можете оставить жалобу на официальном портале области."], ["права", "rights", "миранда"]),
        new ActionDefinition("rights-gui", "Памятка прав", "Открыть права в отдельном окне. Сообщения в игру не отправляются.", false, false, [], ["правгуи", "правагуи", "rights-gui"])
    });
    public static ActionDefinition? Find(string query)
    {
        query = Normalize(query.Trim().TrimStart('!', '/'));
        return All.FirstOrDefault(x => Normalize(x.Key) == query || Normalize(x.Name) == query || x.Aliases.Any(a => Normalize(a) == query));
    }
    public static IReadOnlyList<ActionDefinition> Search(string query)
    {
        var terms = Normalize(query).Split(' ',StringSplitOptions.RemoveEmptyEntries);
        if (terms.Length == 0) return All;
        return All.Select(x => (Item:x, Hay:Normalize(x.Name + " " + x.Key + " " + x.Description + " " + string.Join(' ',x.Aliases))))
            .Where(x => terms.All(t=>x.Hay.Contains(t,StringComparison.Ordinal)))
            .OrderByDescending(x=> Normalize(x.Item.Key) == Normalize(query) ? 2 : Normalize(x.Item.Name).StartsWith(Normalize(query),StringComparison.Ordinal) ? 1 : 0)
            .Select(x=>x.Item).ToArray();
    }
    public static List<ScenarioStep> StepsFor(ActionDefinition action, AppSettings settings)
    {
        if (action.Key == "rights-gui") return [];
        var lines = settings.ActionTemplates.TryGetValue(action.Key, out var custom) ? custom : action.Lines;
        var steps = lines.Where(x=>!string.IsNullOrWhiteSpace(x)).Select(ScenarioStep.Send).ToList();
        if (action.Key == "incar" && custom is not null && !steps.Any(x=>x.Text.StartsWith("/incar ",StringComparison.OrdinalIgnoreCase)))
            steps.Add(ScenarioStep.Send("/incar {id}"));
        if (action.Key == "sos")
            steps.AddRange([ScenarioStep.Wait(300), new() {Kind="key",Text="Down"}, ScenarioStep.Wait(300),new() {Kind="key",Text="Enter"}]);
        return steps;
    }
    public static string Normalize(string text) => text.ToLowerInvariant().Replace('ё','е').Normalize(NormalizationForm.FormKC);
}
