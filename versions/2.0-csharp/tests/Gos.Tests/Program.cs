using Gos.Core;
using System.Text;
using System.Text.Json;

internal static class Program
{
    private static int count;
    private static readonly string Root=Path.Combine(Path.GetTempPath(),"GosCore-"+Guid.NewGuid().ToString("N"));
    private static void Check(bool condition,string name)
    {count++; if(!condition)throw new Exception("FAIL "+name);Console.WriteLine("PASS "+name);}
    private static void Throws<T>(Action action,string name) where T:Exception
    {try{action();}catch(T){Check(true,name);return;}throw new Exception("FAIL missing exception: "+name);}
    private static async Task ThrowsAsync<T>(Func<Task> action,string name) where T:Exception
    {try{await action();}catch(T){Check(true,name);return;}throw new Exception("FAIL missing exception: "+name);}
    public static async Task<int> Main(string[] args)
    {
        try
        {
            Directory.CreateDirectory(Root);
            Settings(); Catalog(); Laws(); Profiles(); Events(); HotkeyTests.Run(Check); ChatLogTests.Run(Check); PhysicalKeys(); await Runner(); await Assisted();
            Console.WriteLine($"RESULT: {count} passed, 0 failed; Core only, actual game/OBS/Win32 not exercised.");
            return 0;
        }
        catch(Exception error){Console.Error.WriteLine(error);return 1;}
        finally {if(Directory.Exists(Root))Directory.Delete(Root,true);}
    }
    private static async Task Assisted()
    {
        var gate=new AssistedInput();gate.Begin(3);
        gate.Press(true,false);gate.Press(true,false);gate.Press(true,false);
        using var timeout=new CancellationTokenSource(2000);
        await gate.WaitAsync(timeout.Token);await gate.WaitAsync(timeout.Token);await gate.WaitAsync(timeout.Token);
        Check(true,"Three rapid presses produce three characters without loss");
        gate.End();Check(!gate.Press(true,false),"Assisted input releases keys when inactive");
        gate.Begin(1);gate.Press(true,true);gate.Press(false,false);
        using var cancel=new CancellationTokenSource(30);
        await ThrowsAsync<OperationCanceledException>(()=>gate.WaitAsync(cancel.Token),"Key repeat and key-up do not grant a character");
        gate.Press(true,false);gate.End();gate.Begin(1);
        using var cancel2=new CancellationTokenSource(30);
        await ThrowsAsync<OperationCanceledException>(()=>gate.WaitAsync(cancel2.Token),"Presses cannot leak into next chat message");gate.End();
    }
    private static void PhysicalKeys()
    {
        var state=new PhysicalKeyState();state.Update(0xA2,true,false);state.Update(0xA3,true,false);state.Update(0xA2,false,false);
        Check(state.Modifiers==HotkeyModifiers.Control,"Right Ctrl remains held after left Ctrl release");
        state.Update(0xA3,false,false);state.Update(0xA4,true,true);
        Check(state.Modifiers==HotkeyModifiers.None,"Injected modifier cannot affect physical hotkeys");
        state.Update(0xA5,true,false);state.Update(0xA1,true,false);
        Check(HotkeyChord.Parse("Shift+Alt+1").Matches(0x31,state.Modifiers),"Physical Shift/Alt packets match chord without text conversion");
        state.Update(0xA5,false,false);state.Update(0xA1,false,false);Check(state.Modifiers==HotkeyModifiers.None,"Modifier releases restore physical state");
    }
    private static void Settings()
    {
        var settings=new AppSettings{MinCps=90,MaxCps=20,LineDelayMs=-1,NearbyRadius=0,NearbyRefreshMs=1,Name="A\nB",Hotkeys=[]};
        settings.Normalize();
        Check(settings.MinCps==90&&settings.MaxCps==90&&settings.LineDelayMs==0,"Normalize typing bounds independently of action delays");
        Check(settings.NearbyRadius==1&&settings.NearbyRefreshMs==200,"Normalize nearby refresh avoids busy polling");
        Check(settings.Name=="A B","Identity cannot inject another chat line");
        Check(settings.Hotkeys["menu"]=="F10"&&settings.Hotkeys["palette"]=="Alt+T","Default menu and palette survive empty migrated dictionary");
        settings.ExpectedModuleHash="bad";Throws<InvalidDataException>(settings.Normalize,"Reject malformed expected DLL hash");
        new Scenario{Steps=[ScenarioStep.Send("/me test"),ScenarioStep.Wait(300)]}.Validate();Check(true,"Structured scenario accepts explicit send and wait");
        Throws<InvalidDataException>(()=>new ScenarioStep{Kind="run",Text="cmd.exe"}.Validate(),"Reject executable or unknown step kinds");
        Throws<InvalidDataException>(()=>new ScenarioStep{Kind="key",Text="LWin"}.Validate(),"Key steps have an explicit navigation whitelist");
        Throws<InvalidDataException>(()=>new ScenarioStep{Kind="wait",DelayMs=120001}.Validate(),"Unbounded wait rejected");
        Throws<InvalidDataException>(()=>new ScenarioStep{Text="hello\n/kill"}.Validate(),"Embedded newline command injection rejected");
        var duplicate=new AppSettings{Scenarios=[new(){Id="same",Steps=[ScenarioStep.Wait(0)]},new(){Id="same",Steps=[ScenarioStep.Wait(0)]}]};
        Throws<InvalidDataException>(duplicate.Normalize,"Duplicate scenario IDs rejected");
    }
    private static void Catalog()
    {
        Check(ActionCatalog.All.Count==10 && ActionCatalog.All.Select(x=>x.Key).Distinct().Count()==10,"All ten requested action entries present once");
        foreach(var key in new[]{"intro","stop","rights"})Check(ActionCatalog.Find(key)!.ForceMemory,"Required memory route: "+key);
        Check(ActionCatalog.Find("!права")?.Key=="rights"&&ActionCatalog.Find("dejected")?.Key=="deject","Russian and English command aliases");
        Check(ActionCatalog.Find(" !права ")?.Key=="rights","Command whitespace handled");
        Check(ActionCatalog.Find("rights-gui")!.Lines.Length==0,"Rights GUI never sends chat by catalogue");
        var settings=new AppSettings();var target=new TargetSnapshot(0,"First_Player");
        Check(Template.Expand("/cuff {id}",settings,target)=="/cuff 0","Player ID zero is valid");
        Throws<InvalidOperationException>(()=>Template.Expand("/cuff {id}",settings,null),"Target required placeholder rejects missing target");
        Throws<InvalidDataException>(()=>Template.Expand("{unknown}",settings,target),"Unknown placeholders fail visibly");
        Check(ActionCatalog.Search("наручники").Any(x=>x.Key=="cuff"),"Action discovery by task name");
        var sos=ActionCatalog.StepsFor(ActionCatalog.Find("sos")!,settings);
        Check(sos.Count==5&&sos[0].Text=="/sos"&&sos[1].DelayMs==300&&sos[2].Text=="Down"&&sos[4].Text=="Enter","SOS keeps actual original menu key sequence");
        settings.ActionTemplates["incar"]=["/me custom RP"];
        Check(ActionCatalog.StepsFor(ActionCatalog.Find("incar")!,settings).Last().Text=="/incar {id}","Custom incar RP retains mechanical command");
    }
    private static void Laws()
    {
        var library=new LawLibrary();
        Check(library.Documents.Count==20,"All twenty laws actually embedded");
        Check(library.Documents.Single(d=>d.Key=="VU").Name.Contains("внутренних дел")&&library.Documents.Single(d=>d.Key=="VV").Name.Contains("вертикали"),"Law titles match actual original documents");
        Check(library.Documents.All(d=>d.Text.Length>100 && !d.Text.Contains('\uFFFD')),"All law corpora decode as original Cyrillic");
        Check(library.Search("ук").All(x=>x.Document.EndsWith("(UK)"))&&library.Search("ук").Count>0,"Russian document alias scopes legal search");
        Check(library.Search("полиции").Count>0,"Law text search returns actual source lines");
        Check(library.Search("unlikelykeyword_938082").Count==0,"No fabricated search results");
        Check(library.Search("Статья").Count<=100,"Law search output bounded");
        Throws<ArgumentException>(()=>library.Search(new string('x',201)),"Search query bounded");
    }
    private static void Profiles()
    {
        var folder=Path.Combine(Root,"profile");var store=new ProfileStore(folder);
        var settings=store.Load();settings.Name="Сотрудник";settings.Scenarios.Add(new(){Name="Тест",Steps=[ScenarioStep.Send("Привет, {name}!")]});
        store.Save(settings);
        var loaded=store.Load();Check(loaded.Name==settings.Name&&loaded.Scenarios[0].Steps[0].Text=="Привет, {name}!","Cyrillic settings and scenarios persist");
        settings.Name="Вторая версия";store.Save(settings);File.WriteAllText(store.FilePath,"{broken");
        var backup=store.Load();Check(backup.Name=="Сотрудник"&&store.Warning!=null,"Corrupt JSON recovers previous valid backup without silent reset");
        store.Save(backup);Check(Directory.GetFiles(folder,"*.corrupt-*").Length==1,"Recovery retains corrupt primary for manual investigation");
        File.WriteAllText(store.FilePath,"{\"SchemaVersion\":2}");File.Delete(store.FilePath+".bak");
        Throws<NotSupportedException>(()=>store.Load(),"Newer settings schema not silently overwritten");
        File.WriteAllText(store.FilePath+".bak","{\"SchemaVersion\":1}");
        Throws<NotSupportedException>(()=>store.Load(),"Newer primary cannot downgrade via old backup");
        Throws<NotSupportedException>(()=>store.Save(new()),"Saving cannot overwrite newer-version primary");
        Check(File.ReadAllText(store.FilePath).Contains("\"SchemaVersion\":2"),"Rejected downgrade preserves primary bytes");
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        var cp=Encoding.GetEncoding(1251);string Hex(string s)=>"H1:"+cp.GetByteCount(s)+":"+Convert.ToHexString(cp.GetBytes(s));
        var ini=Path.Combine(Root,"legacy.ini");
        var source="[Profiles]\r\nLast=Основной\r\n[Profile_Основной]\r\nSurname=Тестов\r\nRank=капитан\r\nIntroRole=сотрудником\r\nBind_Intro=!2\r\nBind_Cuff=+^а\r\nRP_Rights="+Hex("Первая строка.\nВторая строка.")+"\r\n[UI]\r\nProfileMode=ГАИ\r\nOBSHideWindows=Off\r\n[ChatLog]\r\nPlayerNickname="+Hex("Test_Player")+"\r\n";
        File.WriteAllBytes(ini,cp.GetBytes(source));var original=File.ReadAllBytes(ini);var imported=new AppSettings();
        Check(store.TryImportLegacy(ini,imported),"Selected legacy profile recognized");
        Check(imported.Name=="Тестов"&&imported.Rank=="капитан полиции"&&imported.ChatLogNickname=="Test_Player","Legacy identity and H1 nickname adapted");
        Check(imported.ActionTemplates["rights"].SequenceEqual(new[]{"Первая строка.","Вторая строка."}),"Legacy multiline H1 RP preserved");
        Check(!imported.HideFromCapture&&imported.Department=="ГАИ","Legacy global UI values retained");
        Check(imported.Hotkeys["intro"]=="Alt+2"&&imported.Hotkeys["cuff"]=="Ctrl+Shift+F","Legacy AHK modifier and physical Cyrillic key converted");
        Check(File.ReadAllBytes(ini).SequenceEqual(original),"Import never modifies original INI");
        using (var sample=typeof(Program).Assembly.GetManifestResourceStream("Gos.Tests.LegacyDefault.ini")!)
        using (var output=File.Create(ini)) sample.CopyTo(output);
        var real=new AppSettings();
        Check(store.TryImportLegacy(ini,real)&&real.Name=="Лукашенко","Actual bundled old profile imports without interpreter");
        Check(real.ActionTemplates["rights"].Length==5&&real.ActionTemplates["stop"].Length==2,"Actual old H1 rights and stop lines retained");
        File.WriteAllBytes(ini,cp.GetBytes("[Profile_Тест]\nRP_Rights=Одна{NL}Две{NL}{RAW_NL}\n"));
        var old=new AppSettings();store.TryImportLegacy(ini,old);
        Check(old.ActionTemplates["rights"].SequenceEqual(new[]{"Одна","Две","{NL}"}),"Pre-H1 newline escaping preserved without double decoding");
        File.WriteAllBytes(ini,cp.GetBytes("[Profile_Основной]\nSurname=Новое\nRP_Rights=H1:4:00\n"));
        Throws<InvalidDataException>(()=>store.TryImportLegacy(ini,imported),"Malformed H1 rejected");
        Check(imported.Name=="Тестов","Failed import has no partial live mutation");
        Check(!store.TryImportLegacy(Path.Combine(Root,"missing.ini"),imported),"Missing import is explicitly unsuccessful");
    }
    private static void Events()
    {
        Check(ChatEventParser.Parse("Other_Player[7] говорит: Вы начали преследование Target_Player[42]", "Own_Player")==null,"Foreign quoted server text cannot offer target");
        Check(ChatEventParser.Parse("Other_Player[7] говорит: Own_Player начал преследование Target_Player[42]", "Own_Player")==null,"Mentioning own nickname in chat is not own event");
        Check(ChatEventParser.Parse("[12:30:25] Вы начали преследование Target_Player[42]", "Own_Player")?.Id==42,"Timestamped own server event accepted");

        Check(ChatEventParser.Parse("Вы начали преследование Test_Player[42]","") is {Kind:"chase",Id:42},"Own chase event offers exact ID");
        Check(ChatEventParser.Parse("Other_Player[7] начал преследование Test_Player[42]","Own_Player")==null,"Foreign chase does not automate");
        Check(ChatEventParser.Parse("Own_Player[7] начал преследование Test_Player[42]","Own_Player")?.Id==42,"Two-ID event chooses target rather than own ID");
        Check(ChatEventParser.Parse("Вы спасли Test_Player[0]","") is {Kind:"revive",Id:0},"Revive accepts ID zero");
        Check(ChatEventParser.Parse("Вы спасли Test_Player[999999]","")==null,"Impossible player ID rejected");
        Check(ChatEventParser.Parse("Вы спасли Test_Player","")==null,"Nickname alone does not invent an ID");
    }
    private static async Task Runner()
    {
        var transport=new TestTransport();using var runner=new AutomationRunner(transport);var settings=new AppSettings{LineDelayMs=0};
        await runner.RunAsync([ScenarioStep.Send("Первое"),ScenarioStep.Send("Второе")],settings,null,true);
        Check(transport.Lines.SequenceEqual(new[]{"Первое","Второе"})&&transport.Modes.All(m=>m==SendMode.Memory),"Actual sequence preserves all lines and forced memory route");
        Check(!runner.IsBusy,"Completion releases runner");
        transport.Reset();
        await ThrowsAsync<InvalidOperationException>(()=>runner.RunAsync([ScenarioStep.Send("Первое"),ScenarioStep.Send("/cuff {id}")],settings,null),"Validate late missing target before any send");
        Check(transport.Lines.Count==0,"Invalid second step cannot partially send first");
        var pending=runner.RunAsync([ScenarioStep.Wait(10000),ScenarioStep.Send("must not send")],settings,null);
        await ThrowsAsync<InvalidOperationException>(()=>runner.RunAsync([ScenarioStep.Send("other")],settings,null),"Concurrent action rejected rather than queued");
        runner.Cancel();await ThrowsAsync<OperationCanceledException>(()=>pending,"Cancel interrupts wait");
        Check(transport.Lines.Count==0&&!runner.IsBusy,"No delayed message after cancellation");
        transport.FailAfter=1;
        await ThrowsAsync<IOException>(()=>runner.RunAsync([ScenarioStep.Send("sent"),ScenarioStep.Send("unknown"),ScenarioStep.Send("must not send")],settings,null),"Transport failure stops dependent messages");
        Check(transport.Attempts==2&&transport.Lines.SequenceEqual(new[]{"sent"}),"No automatic retry of unknown transport result");
        transport.Reset();transport.FailAfter=null;
        var holding=new HoldingTransport();using(var isolated=new AutomationRunner(holding))
        {
            settings.Name="Исходное";
            var work=isolated.RunAsync([ScenarioStep.Send("{name}"),ScenarioStep.Send("{name}")],settings,null);
            await holding.Started.Task;
            settings.Name="Изменено";holding.Release.TrySetResult();await work;
            Check(holding.Lines.SequenceEqual(new[]{"Исходное","Исходное"}),"Live settings edits cannot alter an executing scenario");
        }
        var delayed=new BlockingTransport();using(var cancellable=new AutomationRunner(delayed))
        {
            var work=cancellable.RunAsync([ScenarioStep.Send("in flight"),ScenarioStep.Send("must not send")],settings,null);
            await delayed.Started.Task;cancellable.Cancel();
            await ThrowsAsync<OperationCanceledException>(()=>work,"Cancel interrupts cooperative transport operation");
            Check(delayed.Attempts==1&&!cancellable.IsBusy,"Cancelled in-flight transport has no follow-up step");
        }
        runner.StatusChanged+=_=>throw new Exception("observer error");
        await runner.RunAsync(ActionCatalog.StepsFor(ActionCatalog.Find("sos")!,settings),settings,null);
        Check(transport.Keys.SequenceEqual(new[]{"Down","Enter"}),"SOS emits real key transport calls");
        Check(transport.Lines.SequenceEqual(new[]{"/sos"}),"Observer exception does not change send semantics");
        runner.Dispose();await ThrowsAsync<ObjectDisposedException>(()=>runner.RunAsync([ScenarioStep.Send("never")],settings,null),"Disposed runner cannot restart");
    }
    private sealed class HoldingTransport:IMessageTransport
    {
        public TaskCompletionSource Started=new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource Release=new(TaskCreationOptions.RunContinuationsAsynchronously);
        public List<string> Lines=[];
        public async Task SendAsync(string text,SendMode mode,AppSettings settings,CancellationToken token)
        {if(Lines.Count==0){Started.TrySetResult();await Release.Task.WaitAsync(token);}Lines.Add(text);}
    }
    private sealed class BlockingTransport:IMessageTransport
    {
        public TaskCompletionSource Started=new(TaskCreationOptions.RunContinuationsAsynchronously);public int Attempts;
        public async Task SendAsync(string text,SendMode mode,AppSettings settings,CancellationToken token)
        {Attempts++;Started.TrySetResult();await Task.Delay(10000,token);}
    }
    private sealed class TestTransport:IMessageTransport,IKeyTransport
    {
        public List<string> Lines {get;}=[];public List<string> Keys {get;}=[];public List<SendMode> Modes {get;}=[];
        public int Attempts;public int? FailAfter;
        public Task SendAsync(string text,SendMode mode,AppSettings settings,CancellationToken cancellationToken)
        {cancellationToken.ThrowIfCancellationRequested();Attempts++;if(FailAfter is not null&&Lines.Count>=FailAfter)throw new IOException("Unknown result");Lines.Add(text);Modes.Add(mode);return Task.CompletedTask;}
        public Task PressKeyAsync(string key,CancellationToken cancellationToken){cancellationToken.ThrowIfCancellationRequested();Keys.Add(key);return Task.CompletedTask;}
        public void Reset(){Lines.Clear();Keys.Clear();Modes.Clear();Attempts=0;}
    }
}
