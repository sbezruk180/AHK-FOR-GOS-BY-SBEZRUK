using Gos.Core;
namespace Gos.Windows;

public sealed class AppController : IAppController, IDisposable
{
    readonly GameMemory game = new();
    readonly ProfileStore store;
    readonly ChatTransport transport;
    readonly AutomationRunner runner;
    readonly ChatLogWatcher log = new();
    readonly KeyboardHook keyboard;
    readonly System.Windows.Forms.Timer timer = new() { Interval=35 };
    readonly SynchronizationContext ui;
    readonly string dataDir;
    readonly int uiThreadId=Environment.CurrentManagedThreadId;
    readonly System.Collections.Concurrent.ConcurrentQueue<string> diagnosticLines=new(); long flushDue;
    readonly HashSet<int> consumedKeys=[];
    readonly Dictionary<string,long> eventTimes=[];
    ShellForm? shell; CommandForm? command; HudForm? hud; NearbyForm? nearby;
    bool polling, disposed, wasActive, stopRunning;
    long nearbyDue,logDue,lastStop=long.MinValue/2;
    TargetSnapshot? rejected;
    TargetSnapshot? eventCandidate; long eventCandidateUntil;
    string lastPublished="";
    public AppSettings Settings {get;private set;}
    public string Status {get;private set;}="Готово · F10 — меню · Alt+T — команды · Pause — отмена";
    public TargetSnapshot? Target {get;private set;}
    public TargetSnapshot? Candidate {get;private set;}
    public IReadOnlyList<NearbyPlayer> Nearby {get;private set;}=[];
    public LawLibrary Laws {get;}=new();
    public bool IsGameActive=>game.IsActive;
    public event Action? Changed;
    public AppController(string directory)
    {
        dataDir=directory;store=new(directory);Settings=store.Load();Settings.Normalize();if(store.Warning is {} warning)Status=warning;
        ui=SynchronizationContext.Current??new WindowsFormsSynchronizationContext();
        transport=new(game);runner=new(transport);
        runner.StatusChanged+=Notify; transport.Progress+=Notify;
        keyboard=new();keyboard.KeyInput+=HandleKey;keyboard.CallbackError+=e=>Notify("Обработчик клавиатуры: "+e.Message);
        timer.Tick+=async(_,_)=>await TickAsync();
        game.ExpectedHash=Settings.ExpectedModuleHash;
        game.ChatCallLaunched+=()=>{if(Volatile.Read(ref stopRunning))Interlocked.Exchange(ref lastStop,Environment.TickCount64);};
    }
    public void Attach(ShellForm window,CommandForm palette,HudForm overlay,NearbyForm list)
    {shell=window;command=palette;hud=overlay;nearby=list;timer.Start();}
    public void Notify(string text)
    {
        if(disposed)return;
        if(Environment.CurrentManagedThreadId!=uiThreadId){ui.Post(_=>Notify(text),null);return;}
        Status=text; Changed?.Invoke();
        if(!text.StartsWith("Клавишный ввод:",StringComparison.Ordinal)&&diagnosticLines.Count<256)diagnosticLines.Enqueue($"{DateTimeOffset.Now:O} {text}");
    }
    public void ApplySettings(AppSettings draft)
    {
        var next=ProfileStore.Copy(draft); next.Normalize();ValidateHotkeys(next);
        runner.Cancel(); store.Save(next); Settings=next; game.ExpectedHash=next.ExpectedModuleHash;
        foreach(Form form in Application.OpenForms) WindowPolicy.Apply(form,Settings.HideFromCapture,IsGameActive);
        Notify("Настройки сохранены");
    }
    public void SaveSettings()
    {
        try
        {
            Settings.Normalize();ValidateHotkeys(Settings);store.Save(Settings);game.ExpectedHash=Settings.ExpectedModuleHash;
            foreach(Form form in Application.OpenForms) WindowPolicy.Apply(form,Settings.HideFromCapture,IsGameActive);
            Notify("Настройки сохранены");
        } catch(Exception e) {Notify("Не удалось сохранить: "+e.Message);throw;}
    }
    static void ValidateHotkeys(AppSettings settings)
    {
        var combinations=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach(var pair in settings.Hotkeys)
        {
            if(string.IsNullOrWhiteSpace(pair.Value))continue;
            var normalized=ParseHotkey(pair.Value).ToString();
            if(!combinations.Add(normalized))throw new InvalidOperationException("Одинаковая клавиша назначена дважды: "+pair.Value);
            if(normalized is "F1" or "F2" or "Pause")throw new InvalidOperationException("F1/F2 и Pause зарезервированы для ID и отмены.");
        }
    }
    public void ImportLegacy(string path)
    {
        Cancel();
        try {var draft=ProfileStore.Copy(Settings);if(!store.TryImportLegacy(path,draft)){Notify("Поддерживаемые данные профиля в файле не найдены.");return;} ApplySettings(draft);Notify("Профиль импортирован. Проверьте имя, бинды и шаблоны; исходный INI сохранён.");}
        catch(Exception e){Notify("Импорт: "+e.Message);}
    }
    public async Task RunAsync(string key)
    {
        if(key=="rights-gui"){new RightsForm(this).ShowReference();return;}
        var action=ActionCatalog.All.FirstOrDefault(a=>a.Key==key);
        if(action==null){Notify("Команда не найдена");return;}
        if(action.RequiresTarget && Target==null){Notify("Выберите ID: наведитесь на игрока и нажмите F1 либо задайте ID в меню.");return;}
        if(!IsGameActive){Notify("Вернитесь в GTA. Действия не отправляются в другие приложения.");return;}
        if(runner.IsBusy){Notify("Завершите действие или нажмите Pause.");return;}
        transport.GuardTarget=action.RequiresTarget?Target:null;
        if(key=="stop")
        {
            var left=30000-(Environment.TickCount64-lastStop);
            if(left>0){Notify($"Требование остановки: ещё {(left+999)/1000} сек. Другие действия доступны.");return;}
            if(runner.IsBusy){Notify("Завершите действие или нажмите Pause.");return;}
            stopRunning=true;
        }
        try {await runner.RunAsync(ActionCatalog.StepsFor(action,Settings),Settings,Target,action.ForceMemory);}
        catch(OperationCanceledException){Notify("Действие отменено");}
        catch(Exception e){Notify(e.Message);}
        finally {if(key=="stop")stopRunning=false;}
    }
    public async Task RunScenarioAsync(Scenario scenario)
    {
        if(!IsGameActive){Notify("Сценарий можно запустить только в активной GTA.");return;}
        if(runner.IsBusy){Notify("Завершите действие или нажмите Pause.");return;}
        transport.GuardTarget=scenario.Steps.Any(s=>s.Text.Contains("{id}",StringComparison.OrdinalIgnoreCase))?Target:null;
        try {await runner.RunAsync(scenario.Steps,Settings,Target);}
        catch(OperationCanceledException){Notify("Сценарий отменён");}catch(Exception e){Notify(e.Message);}
    }
    public void Cancel(){runner.Cancel();Notify("Остановлено. Новые шаги отменены.");}
    public void AcceptTarget()
    {if(Candidate is null)return;runner.Cancel();Target=Candidate;Candidate=null;eventCandidate=null;rejected=null;Notify($"Выбрана цель: {Target.Name} [{Target.Id}]");}
    public void RejectTarget(){rejected=Candidate;Candidate=null;eventCandidate=null;Changed?.Invoke();}
    public void SetManualTarget(int id)
    {if(id is <0 or >1003){Notify("ID: от 0 до 1003");return;}runner.Cancel();Target=new(id,"Вручную");Candidate=null;Notify($"Выбран ID {id}");}
    public void ClearTarget(){runner.Cancel();Target=null;Candidate=null;rejected=null;Changed?.Invoke();}
    async Task TickAsync()
    {
        if(polling||disposed)return;polling=true;
        try
        {
            long now=Environment.TickCount64;
            var snapshot=await Task.Run(()=>
            {
                if(now>=flushDue)
                {
                    flushDue=now+1000;var logs=new List<string>();while(diagnosticLines.TryDequeue(out string? line))logs.Add(line);
                    if(logs.Count>0)try{var path=Path.Combine(dataDir,"session.log");if(File.Exists(path)&&new FileInfo(path).Length>262144)File.WriteAllText(path,"");File.AppendAllLines(path,logs);}catch(IOException){}catch(UnauthorizedAccessException){}
                }
                game.Refresh();bool active=game.IsActive;
                var aim=active&&Settings.AutoId&&KeyboardHook.IsKeyDown(0x02)&&game.IsChatOpen==false?game.ReadAimTarget():null;
                IReadOnlyList<NearbyPlayer>? players=null;
                if(active&&Settings.NearbyVisible&&now>=nearbyDue) players=game.ReadNearby(Settings.NearbyRadius);
                return(active,aim,players);
            });
            if(disposed)return;
            if(!snapshot.active)
            {
                if(wasActive){runner.Cancel();Target=null;Candidate=null;Nearby=[];command?.CloseInput();}
                wasActive=false;hud?.Hide();nearby?.Hide();return;
            }
            wasActive=true;
            if(snapshot.aim is not null)
            {
                if(rejected?.Id!=snapshot.aim.Id||rejected?.Ped!=snapshot.aim.Ped)rejected=null;
                if((Target?.Id!=snapshot.aim.Id||Target?.Ped!=snapshot.aim.Ped)&&rejected==null)Candidate=snapshot.aim;
                else Candidate=null;
            }
            else {Candidate=now<eventCandidateUntil?eventCandidate:null;rejected=null;}
            if(snapshot.players is not null){Nearby=snapshot.players;nearbyDue=now+Settings.NearbyRefreshMs;}
            if(now>=logDue)
            {
                logDue=now+400;
                try
                {
                    foreach(var hit in log.Poll(Settings.ChatLogPath,Settings.ChatLogNickname))
                    {
                        if(hit.Kind=="chase"&&!Settings.AutoChase||hit.Kind=="revive"&&!Settings.AutoRevive)continue;
                        var eventKey=hit.Kind+":"+hit.Id;
                        if(eventTimes.TryGetValue(eventKey,out long last)&&now-last<5000)continue;
                        if(eventTimes.Count>64)eventTimes.Clear();eventTimes[eventKey]=now;
                        eventCandidate=Candidate=new(hit.Id,hit.Name);eventCandidateUntil=now+10000;Notify($"Событие {hit.Kind}: ID {hit.Id}. F1 — принять / F2 — отказ. Команда автоматически не отправляется.");
                    }
                }catch(IOException){}catch(UnauthorizedAccessException){}
            }
            hud?.RefreshState();nearby?.RefreshState();
            var published=$"{Target?.Id}/{Candidate?.Id}/{Nearby.Count}/{game.Status}";
            if(published!=lastPublished){lastPublished=published;Changed?.Invoke();}
        }
        catch(Exception e){Notify("Связь с игрой: "+e.Message);}
        finally{polling=false;}
    }
    bool HandleKey(KeyStroke stroke)
    {
        if(stroke.Injected||disposed)return false;
        if(!stroke.Down&&consumedKeys.Remove(stroke.VirtualKey))return true;
        bool ownsFocus=Application.OpenForms.Cast<Form>().Any(f=>f.ContainsFocus);
        if(!IsGameActive && !ownsFocus && !runner.IsBusy)return false;
        if(stroke.Down&&stroke.VirtualKey==0x13&&!stroke.Repeat)
        {runner.Cancel();command?.CloseInput();consumedKeys.Add(stroke.VirtualKey);Notify("Отменено клавишей Pause");return true;}
        if(!IsGameActive && !ownsFocus)return false;
        if(stroke.Down&&!stroke.Repeat)
        {
            foreach(var toggle in new[]{"menu","palette"})
            {
                if(!Settings.Hotkeys.TryGetValue(toggle,out var combination)||!Matches(combination,stroke.VirtualKey))continue;
                runner.Cancel();consumedKeys.Add(stroke.VirtualKey);
                if(toggle=="menu"){command?.CloseInput();if(shell?.Visible==true)shell.Hide();else shell?.ShowPassive();}
                else {if(command?.IsOpen==true)command.CloseInput();else command?.Open();}
                return true;
            }
        }
        bool handled=false;
        if(transport.IsAssisting && stroke.Down && stroke.VirtualKey is 0x1B or 0x11 or 0x12 or 0x5B or 0x5C or 0xA2 or 0xA3 or 0xA4 or 0xA5)
        {runner.Cancel();Notify("Печать остановлена клавишей отмены/модификатором.");handled=stroke.VirtualKey==0x1B;}
        else if(transport.IsAssisting) handled=transport.ConsumeKey(stroke);
        else if(Application.OpenForms.OfType<ReferenceForm>().LastOrDefault(f=>f.Visible&&f.Passive) is {} reference)handled=reference.HandleKey(stroke);
        else if(command?.IsOpen==true) handled=command.HandleKey(stroke);
        else if(stroke.Down&&!stroke.Repeat&&Candidate!=null&&stroke.VirtualKey is 0x70 or 0x71)
        {if(stroke.VirtualKey==0x70)AcceptTarget();else RejectTarget();handled=true;}
        else if(shell?.Visible==true && IsGameActive) handled=shell.HandleKey(stroke);
        if(handled){if(stroke.Down)consumedKeys.Add(stroke.VirtualKey);return true;}
        if(!stroke.Down||stroke.Repeat)return consumedKeys.Contains(stroke.VirtualKey);
        foreach(var pair in Settings.Hotkeys)
        {
            if(!Matches(pair.Value,stroke.VirtualKey))continue;
            consumedKeys.Add(stroke.VirtualKey);
            if(pair.Key=="menu")
            {
                if(shell?.Visible==true)shell.Hide();else {runner.Cancel();shell?.ShowPassive();}
            }
            else if(pair.Key=="palette"){runner.Cancel();command?.Open();}
            else _=RunAsync(pair.Key);
            return true;
        }
        return false;
    }
    static Keys ParseHotkey(string value)
    {
        try {return (Keys)(new KeysConverter().ConvertFromInvariantString(value)??Keys.None);}
        catch(Exception){throw new InvalidOperationException("Неверная клавиша: "+value+". Пример: Alt+1 или Ctrl+F5.");}
    }
    static bool Matches(string value,int vk)
    {
        if(string.IsNullOrWhiteSpace(value))return false;
        Keys expected;try{expected=ParseHotkey(value);}catch(InvalidOperationException){return false;}
        Keys mods=Keys.None;
        if(KeyboardHook.IsKeyDown(0x10))mods|=Keys.Shift;
        if(KeyboardHook.IsKeyDown(0x11))mods|=Keys.Control;
        if(KeyboardHook.IsKeyDown(0x12))mods|=Keys.Alt;
        return expected==(mods|(Keys)vk);
    }
    public void Dispose()
    {disposed=true;timer.Stop();timer.Dispose();runner.Dispose();keyboard.Dispose();transport.Dispose();game.Dispose();}
}
