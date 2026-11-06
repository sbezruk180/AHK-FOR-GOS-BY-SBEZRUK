using System.Runtime.InteropServices;
using Gos.Core;
namespace Gos.Windows;

// Native UI and own-process keyboard/ABI checks. No GTA process or server is simulated as tested.
internal static class NativeSelfTest
{
    public static int Run(string output)
    {
        Directory.CreateDirectory(output);var lines=new List<string>();int failures=0;
        File.WriteAllText(Path.Combine(output,"native-report.txt"),"START | Native verification\n");
        void Check(string name,bool pass){var line=$"{(pass?"PASS":"FAIL")} | {name}";lines.Add(line);File.AppendAllText(Path.Combine(output,"native-report.txt"),line+"\n");if(!pass)failures++;}
        try
        {
            Check("Shipping host is x86",IntPtr.Size==4);
            var app=new FixtureController();
            using var shell=new ShellForm(app);shell.ShowPassive();Application.DoEvents();
            Check("Real shell created",shell.IsHandleCreated&&shell.Visible);
            void Image(Form form,string name)
            {using var bitmap=new Bitmap(Math.Max(1,form.Width),Math.Max(1,form.Height));form.DrawToBitmap(bitmap,new Rectangle(Point.Empty,bitmap.Size));bitmap.Save(Path.Combine(output,name+".png"));}
            foreach(var page in new[]{"Действия","Клавиши","Конструктор","Законы","Настройки","О приложении"})
            {
                var nav=Descendants(shell).OfType<Button>().First(b=>b.Text==page);nav.PerformClick();Application.DoEvents();
                Check("Page opens: "+page,shell.Controls.Count>0);
                Check("No horizontal scrolling: "+page,Descendants(shell).OfType<FlowLayoutPanel>().Where(f=>f.AutoScroll).All(f=>!f.HorizontalScroll.Visible));Image(shell,page switch {"Действия"=>"actions","Клавиши"=>"hotkeys","Конструктор"=>"builder","Законы"=>"laws","Настройки"=>"settings",_=>"about"});
            }
            shell.ReviewPage("Клавиши");Application.DoEvents();
            Button BindButton(string name)=>Descendants(shell).OfType<Button>().First(b=>b.Name==name);
            BindButton("bind-capture-intro").PerformClick();
            Check("Assign button starts capture for chosen action",app.IsCapturingHotkey&&app.RecordingAction=="intro");
            app.CompleteCapture("Ctrl+K");
            Check("Recorded key remains a draft",!app.Settings.Hotkeys.ContainsKey("intro"));
            Check("Recorded key displayed on binding card",Descendants(shell).First(c=>c.Name=="bind-value-intro").Text=="Ctrl+K");
            BindButton("bind-save").PerformClick();Application.DoEvents();
            Check("Save applies recorded binding",app.Settings.Hotkeys.GetValueOrDefault("intro")=="Ctrl+K");
            BindButton("bind-clear-intro").PerformClick();BindButton("bind-cancel").PerformClick();Application.DoEvents();
            Check("Cancel discards key removal",app.Settings.Hotkeys.GetValueOrDefault("intro")=="Ctrl+K");
            Check("No editable hotkey-name text fields",!Descendants(shell).OfType<TextBoxBase>().Any(t=>!t.ReadOnly));
            Image(shell,"hotkeys");
            shell.ReviewPage("Настройки");Application.DoEvents();
            var originalName=app.Settings.Name;
            Descendants(shell).OfType<TextBox>().First().Text="Тестовый персонаж";
            Descendants(shell).OfType<Button>().First(b=>b.Text=="Отправка").PerformClick();Application.DoEvents();
            Image(shell,"settings-send");
            Descendants(shell).OfType<Button>().First(b=>b.Text=="Профиль").PerformClick();Application.DoEvents();
            Check("Settings draft survives section switch",Descendants(shell).OfType<TextBox>().First().Text=="Тестовый персонаж"&&app.Settings.Name==originalName);
            Descendants(shell).OfType<Button>().First(b=>b.Name=="settings-cancel").PerformClick();Application.DoEvents();
            Check("Settings cancel restores saved identity",Descendants(shell).OfType<TextBox>().First().Text==originalName);
            shell.ReviewPage("Действия");Application.DoEvents();
            var search=Descendants(shell).OfType<TextBox>().First(t=>t.Name=="action-search");search.Text="/cuff";Application.DoEvents();
            Check("Action search filters to requested command",Descendants(shell).OfType<Button>().Where(b=>b.Name.StartsWith("action-run-")&&b.Visible).Select(b=>b.Name).SequenceEqual(new[]{"action-run-cuff"}));
            search.Text="";
            shell.Size=new(800,580);shell.ReviewPage("Клавиши");Application.DoEvents();Image(shell,"hotkeys-small");
            Check("Small binding page has vertical-only scrolling",Descendants(shell).OfType<FlowLayoutPanel>().Where(f=>f.AutoScroll).All(f=>!f.HorizontalScroll.Visible));
            shell.Size=new(1120,800);
            shell.SyncGameMode(true);Application.DoEvents();
            Check("Menu switches to passive mode for gameplay",shell.Passive&&(GetWindowLong(shell.Handle,-20)&0x08000000)!=0);
            shell.SyncGameMode(false);shell.Activate();Application.DoEvents();
            Check("Menu accepts desktop activation after leaving game",!shell.Passive&&(GetWindowLong(shell.Handle,-20)&0x08000000)==0&&Native.GetForegroundWindow()==shell.Handle);
            foreach(Form form in Application.OpenForms)
            {WindowPolicy.Apply(form,false,false);Check("OBS Off clears affinity",Native.GetWindowDisplayAffinity(form.Handle,out uint value)&&value==0);}
            app.GameActive=true;
            using var palette=new CommandForm(app);palette.Open();Application.DoEvents();
            Check("Palette no-activate style",(GetWindowLong(palette.Handle,-20)&0x08000000)!=0);
            palette.HandleKey(new((int)Keys.Enter,true,false,false));Check("Empty Enter sends nothing",app.Runs==0);
            palette.HandleKey(new((int)Keys.Escape,true,false,false));Check("Escape closes palette",!palette.IsOpen);
            app.GameActive=true;app.Settings.HideFromCapture=false;
            using var hud=new HudForm(app);hud.RefreshState();Application.DoEvents();Image(hud,"hud");
            Check("HUD no-activate",(GetWindowLong(hud.Handle,-20)&0x08000000)!=0);
            using var nearby=new NearbyForm(app);nearby.RefreshState();Application.DoEvents();Image(nearby,"nearby");
            Check("Nearby displays fixture rows",nearby.Visible&&nearby.Height>=100);
            using var rights=new RightsForm(app);rights.ShowReference();Application.DoEvents();Image(rights,"rights");
            Check("Rights reference never sends",app.Runs==0);
            app.GameActive=false;hud.RefreshState();nearby.RefreshState();Check("Overlays hide outside game",!hud.Visible&&!nearby.Visible);
            rights.SyncGameMode(false);rights.Activate();Descendants(rights).OfType<RichTextBox>().Single().Focus();Application.DoEvents();
            Check("Reference returns to desktop interaction",!rights.Passive&&(GetWindowLong(rights.Handle,-20)&0x08000000)==0);
            KeyboardHook.PressKey((int)Keys.Escape);for(int i=0;i<5;i++){Application.DoEvents();Thread.Sleep(10);}
            Check("Escape closes desktop reference while text has focus",rights.IsDisposed);
            if(!rights.IsDisposed)rights.Hide();palette.Hide();shell.Hide();
            using(var inputWindow=new Form{Text="Owned input fixture",Size=new(420,160)})
            using(var input=new TextBox{Dock=DockStyle.Fill,Multiline=true})
            {
                inputWindow.Controls.Add(input);inputWindow.Show();inputWindow.Activate();input.Focus();Application.DoEvents();
                if(Native.GetForegroundWindow()==inputWindow.Handle)
                {
                    using var hook=new KeyboardHook();int physicalLikeCallbacks=0;
                    hook.KeyInput+=key=>{if(key.Injected)physicalLikeCallbacks++;return false;};
                    var layout=KeyboardHook.CaptureLayout();
                    try {KeyboardHook.TypeCharacter('a');Application.DoEvents();KeyboardHook.TypeCharacter('я');Application.DoEvents();Check("Actual scan-code English/Russian input",input.Text=="aя");Check("Injected hook events do not look physical",physicalLikeCallbacks>0);}
                    finally {KeyboardHook.RestoreLayout(layout);}
                }
                else {Check("Native foreground fixture acquired",false);}
            }
            NativeHotkeyTests.Run(Check,output);
            if(IntPtr.Size==4)TestStub(Check);
        }
        catch(Exception e){lines.Add("FAIL | unexpected: "+e);failures++;}
        lines.Add($"RESULT | failed={failures}");
        File.WriteAllLines(Path.Combine(output,"native-report.txt"),lines);
        return failures==0?0:1;
    }
    static IEnumerable<Control> Descendants(Control root)
    {foreach(Control c in root.Controls){yield return c;foreach(var child in Descendants(c))yield return child;}}
    static void TestStub(Action<string,bool> check)
    {
        nint memory=VirtualAlloc(0,4096,0x3000,0x40);if(memory==0)throw new InvalidOperationException("Owned ABI allocation failed");
        nint thread=0; bool safeToFree=true;
        try
        {
            // Own stdcall function writes its argument into our marker; returns nonzero EAX.
            // mov eax,[esp+4]; mov [absolute marker],eax; mov eax,123; ret4
            uint marker=unchecked((uint)(nuint)(memory+256));
            byte[] callee=[0x8B,0x44,0x24,0x04,0xA3,0,0,0,0,0xB8,123,0,0,0,0xC2,4,0];
            BitConverter.GetBytes(marker).CopyTo(callee,5);Marshal.Copy(callee,0,memory,callee.Length);
            var code=GameMemory.BuildChatStub(0x12345678,unchecked((uint)(nuint)memory));
            Marshal.Copy(code,0,memory+64,code.Length);FlushInstructionCache(GetCurrentProcess(),memory,4096);
            thread=CreateThread(0,0,memory+64,0,0,out _);
            bool ended=thread!=0&&Native.WaitForSingleObject(thread,3000)==0;
            check("Original x86 stdcall executes on owned process",ended);
            if(!ended){safeToFree=false;throw new InvalidOperationException("Owned stub did not finish; memory retained until exit");}
            check("Stub receives exact argument",unchecked((uint)Marshal.ReadInt32(memory+256))==0x12345678);
            check("Stub normal-return marker independent of callee EAX",Native.GetExitCodeThread(thread,out uint result)&&result==0);
        }
        finally {if(thread!=0)Native.CloseHandle(thread);if(safeToFree)VirtualFree(memory,0,0x8000);}
    }
    [DllImport("user32.dll",EntryPoint="GetWindowLongW")]static extern int GetWindowLong(nint h,int index);
    [DllImport("kernel32.dll")]static extern nint VirtualAlloc(nint address,nuint size,uint type,uint protect);
    [DllImport("kernel32.dll")]static extern bool VirtualFree(nint address,nuint size,uint type);
    [DllImport("kernel32.dll")]static extern nint GetCurrentProcess();
    [DllImport("kernel32.dll")]static extern bool FlushInstructionCache(nint process,nint address,nuint size);
    [DllImport("kernel32.dll")]static extern nint CreateThread(nint attributes,nuint stack,nint start,nint parameter,uint flags,out uint id);
    sealed class FixtureController : IAppController
    {
        public AppSettings Settings{get;private set;}=new();public string Status=>"Проверка Windows GUI · игра не используется";public string ConnectionStatus=>"Тестовые данные, не игровой клиент";
        public TargetSnapshot? Target=>new(42,"Alex_Smirnov");public TargetSnapshot? Candidate=>new(17,"Ivan_Petrov");
        public bool GameActive;public bool IsGameActive=>GameActive;
        public IReadOnlyList<NearbyPlayer> Nearby=>[new(42,"Alex_Smirnov",4.3),new(17,"Ivan_Petrov",12.8)];
        public LawLibrary Laws{get;}=new();public event Action? Changed;public int Runs;
        public Task RunAsync(string key){Runs++;return Task.CompletedTask;}public Task RunScenarioAsync(Scenario s){Runs++;return Task.CompletedTask;}
        public void Cancel(){}public void AcceptTarget(){}public void RejectTarget(){}public void SaveSettings(){}
        public void ApplySettings(AppSettings draft){Settings=ProfileStore.Copy(draft);Changed?.Invoke();}public void SetManualTarget(int id){}public void ClearTarget(){}
        public void Notify(string t){Changed?.Invoke();}public void ImportLegacy(string p){}
        public bool IsCapturingHotkey=>captureCallback!=null;
        Action<string?>? captureCallback;
        public string? RecordingAction;
        public void BeginHotkeyCapture(string key,Action<string?> callback){RecordingAction=key;captureCallback=callback;}
        public void CancelHotkeyCapture(){CompleteCapture(null);}
        public void CompleteCapture(string? value){var callback=captureCallback;captureCallback=null;callback?.Invoke(value);}
    }
}
