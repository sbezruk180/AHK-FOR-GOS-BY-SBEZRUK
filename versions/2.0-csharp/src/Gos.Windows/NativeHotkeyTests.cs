using System.Runtime.InteropServices;
using Gos.Core;
namespace Gos.Windows;

internal static class NativeHotkeyTests
{
    // Genuine Win32 packets on our own window. Only this test adapter removes the
    // injected flag to exercise the production physical-key route without hardware.
    // Normal application execution always ignores injected hotkeys.
    public static void Run(Action<string,bool> check,string output)
    {
        using var window=new Form{Text="Owned hotkey fixture",Size=new(430,180)};
        using var text=new TextBox{Dock=DockStyle.Fill,Multiline=true};window.Controls.Add(text);
        window.Show();window.Activate();text.Focus();Application.DoEvents();
        check("Hotkey fixture owns native foreground",Native.GetForegroundWindow()==window.Handle);
        var requests=new List<string>();
        var path=Path.Combine(output,"hotkey-fixture");
        using var app=new AppController(path,new(()=>Native.GetForegroundWindow()==window.Handle,key=>requests.Add(key)));
        using var hook=new KeyboardHook();var held=new HashSet<int>();
        hook.KeyInput+=stroke=>
        {
            bool repeat=stroke.Down&&!held.Add(stroke.VirtualKey);
            if(!stroke.Down)held.Remove(stroke.VirtualKey);
            return app.ProcessTestKey(stroke with {Injected=false,Repeat=repeat});
        };
        void Packet(int key,bool down)
        {
            var packet=new Native.Input{Type=1,Data=new Native.InputUnion{Keyboard=new Native.KeyboardInput{VirtualKey=(ushort)key,Flags=down?0u:2u}}};
            if(Native.SendInput(1,[packet],Marshal.SizeOf<Native.Input>())!=1)throw new InvalidOperationException("Owned hotkey fixture injection failed");
            for(int i=0;i<3;i++){Application.DoEvents();Thread.Sleep(5);}
        }
        void Tap(int key){Packet(key,true);Packet(key,false);}
        void Chord(int modifier,int key,bool repeat=false){Packet(modifier,true);Packet(key,true);if(repeat)Packet(key,true);Packet(key,false);Packet(modifier,false);}
        string? captured=null;int completed=0;
        app.BeginHotkeyCapture("intro",value=>{captured=value;completed++;});
        Chord(0xA2,0x4B,true);
        check("Native press records Ctrl+K without typed key names",captured=="Ctrl+K"&&completed==1);
        check("Recording never executes action or leaks characters",requests.Count==0&&text.TextLength==0);
        check("Recording changes draft only",!app.Settings.Hotkeys.ContainsKey("intro"));
        var draft=ProfileStore.Copy(app.Settings);draft.Hotkeys["intro"]=captured!;draft.Hotkeys["cuff"]="Alt+1";app.ApplySettings(draft);
        check("Captured binding persisted",new ProfileStore(path).Load().Hotkeys["intro"]=="Ctrl+K");
        Chord(0xA2,0x4B,true);
        check("Physical route invokes action once per press",requests.SequenceEqual(new[]{"intro"}));
        check("Bound key does not enter native text box",text.TextLength==0);
        var layout=KeyboardHook.CaptureLayout();
        try
        {
            nint russian=Native.LoadKeyboardLayout("00000419",0);KeyboardHook.RestoreLayout(russian);
            Chord(0xA3,0x4B);
            check("Same physical hotkey works under Russian layout",requests.SequenceEqual(new[]{"intro","intro"}));
        }
        finally{KeyboardHook.RestoreLayout(layout);}
        Chord(0xA4,0x31);
        check("Alt plus top-row digit invokes cuff, not mouse key",requests.Count==3&&requests[^1]=="cuff");
        draft=ProfileStore.Copy(app.Settings);draft.Hotkeys["rights"]="Ctrl+F1";app.ApplySettings(draft);
        // Supply a candidate without reading a game process, then exercise real routing.
        typeof(AppController).GetProperty(nameof(AppController.Candidate))!.SetValue(app,new TargetSnapshot(17,"Fixture"));
        Chord(0xA2,0x70);
        check("Modified F1 executes binding without accepting Auto ID",requests.Count==4&&requests[^1]=="rights"&&app.Candidate?.Id==17&&app.Target==null);
        Tap(0x70);
        check("Bare F1 still accepts Auto ID",app.Target?.Id==17&&app.Candidate==null&&requests.Count==4);
        int before=requests.Count;
        app.BeginHotkeyCapture("menu",value=>captured=value);Tap(0x79);
        check("F10 can be recorded without toggling menu",captured=="F10"&&!app.IsCapturingHotkey&&requests.Count==before);
        app.BeginHotkeyCapture("incar",value=>captured=value);Tap(0x13);
        check("Reserved Pause cannot become accidental binding",app.IsCapturingHotkey);
        Tap(0x1B);check("Esc cancels recording",!app.IsCapturingHotkey&&captured==null);
        app.BeginHotkeyCapture("cuff",value=>captured=value);Tap(0x2E);
        check("Delete records explicit unassignment",captured=="");
        var duplicate=ProfileStore.Copy(app.Settings);duplicate.Hotkeys["cuff"]="Control+K";
        bool rejected=false;try{app.ApplySettings(duplicate);}catch(InvalidOperationException){rejected=true;}
        check("Duplicate physical chord rejected transactionally",rejected&&app.Settings.Hotkeys["cuff"]=="Alt+1"&&new ProfileStore(path).Load().Hotkeys["cuff"]=="Alt+1");
        draft=ProfileStore.Copy(app.Settings);draft.Hotkeys["cuff"]="";app.ApplySettings(draft);Chord(0xA4,0x31);
        check("Cleared binding no longer executes",requests.Count==before);
        // Pass events with their true injected flag directly: no production action allowed.
        app.ProcessTestKey(new(0xA2,true,true,false));app.ProcessTestKey(new(0x4B,true,true,false));
        check("Production route ignores injected hotkeys",requests.Count==before);
    }
}
