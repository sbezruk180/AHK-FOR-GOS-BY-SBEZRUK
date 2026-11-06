using Gos.Core;

internal static class HotkeyTests
{
    public static void Run(Action<bool,string> check)
    {
        check(HotkeyChord.Parse("Alt+T")==new HotkeyChord(0x54,HotkeyModifiers.Alt),"Hotkeys parse existing Alt+T without character-layout conversion");
        check(HotkeyChord.Parse(" shift + control + f5 ").Canonical=="Ctrl+Shift+F5","Hotkeys normalize legacy modifier order and spacing");
        check(HotkeyChord.Parse("Alt+Е")==HotkeyChord.Parse("Alt+T"),"Legacy Cyrillic key resolves to the same physical Russian keyboard position");
        check(HotkeyChord.Parse("Ctrl+D1")==HotkeyChord.Parse("Ctrl+1"),"Legacy digit aliases have one physical identity");
        check(HotkeyChord.Parse("None").IsEmpty&&HotkeyChord.Parse("").Display=="Не назначено","Unassigned hotkeys are explicit");
        check(!HotkeyChord.TryParse("Ctrl",out _)&&!HotkeyChord.TryParse("Win+T",out _)&&!HotkeyChord.TryParse("Alt+Ctrl+Ctrl+T",out _)&&!HotkeyChord.TryParse("A+B",out _),"Reject modifier-only, Windows, duplicated-modifier and multiple-main-key strings");
        check(HotkeyChord.Parse("F1").IsReserved&&!HotkeyChord.Parse("Ctrl+F1").IsReserved,"Only bare F1/F2/Pause are reserved");
        check(HotkeyChord.Parse("Control+T")==HotkeyChord.Parse("Ctrl+T"),"Duplicates compare parsed chords rather than spelling");
        bool roundTrips=true;
        for(int vk=1;vk<255;vk++)
        {
            var chord=new HotkeyChord(vk,HotkeyModifiers.Control|HotkeyModifiers.Alt);
            if(chord.IsValid)roundTrips &= HotkeyChord.TryParse(chord.Canonical,out var parsed)&&parsed==chord;
        }
        check(roundTrips,"Every supported physical key survives canonical serialization");
        var session=new HotkeyCaptureSession();var results=new List<HotkeyCaptureResult>();session.Completed+=results.Add;
        session.Begin("cuff");
        check(session.Process(0xA2,true,false,false,HotkeyModifiers.None)&&session.IsCapturing,"Recording consumes left Ctrl and waits for main key");
        session.Process(0x54,true,false,false,HotkeyModifiers.Control);
        check(results.Count==1&&results[0].Chord==HotkeyChord.Parse("Ctrl+T")&&!session.IsCapturing&&session.IsActive,"Physical main key records chord and starts release drain");
        check(session.Process(0x54,true,false,true,HotkeyModifiers.Control)&&results.Count==1,"Held main key cannot re-record or launch action");
        check(session.Process(0x54,false,false,false,HotkeyModifiers.Control)&&session.IsActive,"Recorded main-key up is consumed");
        check(session.Process(0xA2,false,false,false,HotkeyModifiers.None)&&!session.IsActive,"Recorded modifier up is consumed and ends capture ownership");
        check(!session.Process(0x54,true,false,false,HotkeyModifiers.None),"Ordinary dispatch resumes only after release");
        session.Begin("intro");session.Process(0x70,true,false,false,HotkeyModifiers.None);
        check(session.IsCapturing&&session.Error!=null&&results.Count==1,"Reserved F1 produces useful validation and keeps recording");
        session.Process(0x70,false,false,false,HotkeyModifiers.None);session.Process(0x1B,true,false,false,HotkeyModifiers.None);
        check(results[^1].Cancelled&&session.IsActive,"Escape cancels recording while retaining its key-up ownership");
        session.Process(0x1B,false,false,false,HotkeyModifiers.None);
        session.Begin("intro");session.Process(0x2E,true,false,false,HotkeyModifiers.None);
        check(!results[^1].Cancelled&&results[^1].Chord is {IsEmpty:true},"Delete explicitly clears an assignment");
        session.Process(0x2E,false,false,false,HotkeyModifiers.None);
        session.Begin("menu");
        check(!session.Process(0x79,true,true,false,HotkeyModifiers.None)&&session.IsCapturing,"Injected keys cannot assign a shortcut");
        session.Process(0x79,true,false,false,HotkeyModifiers.None);
        check(results[^1].ActionKey=="menu"&&results[^1].Chord==HotkeyChord.Parse("F10"),"F10 can be assigned without triggering menu toggle");
        session.Process(0x79,false,false,false,HotkeyModifiers.None);
        session.Begin("palette");
        check(!session.Process(0xA4,false,false,false,HotkeyModifiers.None),"Unmatched pre-recording modifier up passes through instead of sticking Alt");
        check(session.Process(0x41,true,false,true,HotkeyModifiers.None)&&!session.Process(0x41,false,false,false,HotkeyModifiers.None),"Auto-repeat from a pre-held key does not steal its matching key-up");
        session.Process(0x5B,true,false,false,HotkeyModifiers.None);
        session.Process(0x54,true,false,false,HotkeyModifiers.Windows);
        check(session.IsCapturing&&session.Error!=null,"Windows chords never become game bindings");
    }
}
