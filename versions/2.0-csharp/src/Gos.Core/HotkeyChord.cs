using System.Globalization;

namespace Gos.Core;

[Flags]
public enum HotkeyModifiers { None = 0, Shift = 1, Control = 2, Alt = 4, Windows = 8 }

/// <summary>A physical virtual-key chord. Character layout is used only for legacy text migration.</summary>
public readonly record struct HotkeyChord(int VirtualKey, HotkeyModifiers Modifiers = HotkeyModifiers.None)
{
    private static readonly Dictionary<string, int> KeyNames = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Backspace"]=0x08,["Back"]=0x08,["Tab"]=0x09,["Enter"]=0x0D,["Return"]=0x0D,
        ["Pause"]=0x13,["CapsLock"]=0x14,["Capital"]=0x14,["Esc"]=0x1B,["Escape"]=0x1B,
        ["Space"]=0x20,["Spacebar"]=0x20,["PageUp"]=0x21,["PgUp"]=0x21,["Prior"]=0x21,
        ["PageDown"]=0x22,["PgDn"]=0x22,["Next"]=0x22,["End"]=0x23,["Home"]=0x24,
        ["Left"]=0x25,["Up"]=0x26,["Right"]=0x27,["Down"]=0x28,
        ["PrintScreen"]=0x2C,["Snapshot"]=0x2C,["Insert"]=0x2D,["Ins"]=0x2D,["Delete"]=0x2E,["Del"]=0x2E,
        ["Multiply"]=0x6A,["NumMultiply"]=0x6A,["Add"]=0x6B,["NumAdd"]=0x6B,
        ["Separator"]=0x6C,["Subtract"]=0x6D,["NumSubtract"]=0x6D,["Decimal"]=0x6E,["NumDecimal"]=0x6E,
        ["Divide"]=0x6F,["NumDivide"]=0x6F,["NumLock"]=0x90,["ScrollLock"]=0x91,["Scroll"]=0x91,
        ["Oem1"]=0xBA,["OemSemicolon"]=0xBA,["OemPlus"]=0xBB,
        ["OemComma"]=0xBC,["OemMinus"]=0xBD,["OemPeriod"]=0xBE,["Oem2"]=0xBF,["OemQuestion"]=0xBF,
        ["Oem3"]=0xC0,["Oemtilde"]=0xC0,["Oem4"]=0xDB,["OemOpenBrackets"]=0xDB,
        ["Oem5"]=0xDC,["OemPipe"]=0xDC,["Oem6"]=0xDD,["OemCloseBrackets"]=0xDD,
        ["Oem7"]=0xDE,["OemQuotes"]=0xDE,["Oem8"]=0xDF,["Oem102"]=0xE2,["OemBackslash"]=0xE2
    };

    public bool IsEmpty => VirtualKey == 0 && Modifiers == HotkeyModifiers.None;
    public bool IsReserved => Modifiers == HotkeyModifiers.None && VirtualKey is 0x70 or 0x71 or 0x13;
    public bool IsValid => IsEmpty || (IsAssignableKey(VirtualKey) && (Modifiers & ~AllowedModifiers) == 0);
    private const HotkeyModifiers AllowedModifiers = HotkeyModifiers.Control | HotkeyModifiers.Alt | HotkeyModifiers.Shift;
    public string Canonical => IsEmpty ? "" : Prefix(Modifiers) + KeyName(VirtualKey);
    public string Display => IsEmpty ? "Не назначено" : Canonical;
    public override string ToString() => Canonical;
    public bool Matches(int virtualKey, HotkeyModifiers modifiers) => !IsEmpty && virtualKey == VirtualKey && modifiers == Modifiers;

    public static HotkeyModifiers ModifierFor(int key) => key switch
    {
        0x10 or 0xA0 or 0xA1 => HotkeyModifiers.Shift,
        0x11 or 0xA2 or 0xA3 => HotkeyModifiers.Control,
        0x12 or 0xA4 or 0xA5 => HotkeyModifiers.Alt,
        0x5B or 0x5C => HotkeyModifiers.Windows,
        _ => HotkeyModifiers.None
    };
    public static bool IsAssignableKey(int key) =>
        key is >= 0x30 and <= 0x39 or >= 0x41 and <= 0x5A or >= 0x60 and <= 0x6F or >= 0x70 and <= 0x87
        || key is 0x08 or 0x09 or 0x0D or 0x13 or 0x14 or 0x1B or 0x20 or >= 0x21 and <= 0x28 or 0x2C or 0x2D or 0x2E or 0x90 or 0x91
        || key is >= 0xBA and <= 0xC0 or >= 0xDB and <= 0xDF or 0xE2;
    public static HotkeyChord Parse(string? value)
    {
        if (TryParse(value, out var chord)) return chord;
        throw new InvalidDataException("Не удалось прочитать сочетание клавиш «" + value + "». Назначьте его нажатием заново.");
    }
    public static bool TryParse(string? value, out HotkeyChord chord)
    {
        chord = default;
        value = value?.Trim();
        if (string.IsNullOrEmpty(value) || value.Equals("None", StringComparison.OrdinalIgnoreCase) || value is "Не назначено" or "Нет") return true;
        var pieces=value.Split('+',StringSplitOptions.TrimEntries);
        if(pieces.Any(string.IsNullOrEmpty))return false;
        int key=0;HotkeyModifiers modifiers=HotkeyModifiers.None;
        foreach(string part in pieces)
        {
            var modifier=part.ToUpperInvariant() switch { "CTRL" or "CONTROL" or "CONTROLKEY"=>HotkeyModifiers.Control,"ALT" or "MENU"=>HotkeyModifiers.Alt,"SHIFT" or "SHIFTKEY"=>HotkeyModifiers.Shift,_=>HotkeyModifiers.None };
            if(modifier!=HotkeyModifiers.None)
            {
                if((modifiers&modifier)!=0)return false;
                modifiers|=modifier;continue;
            }
            if(key!=0 || !TryKey(part,out key))return false;
        }
        chord=new(key,modifiers);
        return key!=0&&chord.IsValid;
    }
    private static bool TryKey(string value,out int key)
    {
        key=0;
        if(value.Length==1)
        {
            char character=char.ToUpperInvariant(value[0]);
            if(character is >= 'A' and <= 'Z' or >= '0' and <= '9'){key=character;return true;}
            const string russian="ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁ";
            int[] physical=[0x51,0x57,0x45,0x52,0x54,0x59,0x55,0x49,0x4F,0x50,0xDB,0xDD,0x41,0x53,0x44,0x46,0x47,0x48,0x4A,0x4B,0x4C,0xBA,0xDE,0x5A,0x58,0x43,0x56,0x42,0x4E,0x4D,0xBC,0xBE,0xC0];
            int at=russian.IndexOf(character);if(at>=0){key=physical[at];return true;}
        }
        if(value.Length==2&&char.ToUpperInvariant(value[0])=='D'&&value[1] is >= '0' and <= '9'){key=value[1];return true;}
        if(value.StartsWith('F')||value.StartsWith('f'))
            if(int.TryParse(value.AsSpan(1),NumberStyles.None,CultureInfo.InvariantCulture,out int f)&&f is >=1 and <=24){key=0x6F+f;return true;}
        if(value.StartsWith("NumPad",StringComparison.OrdinalIgnoreCase)||value.StartsWith("Num",StringComparison.OrdinalIgnoreCase))
        {
            var digits=value.StartsWith("NumPad",StringComparison.OrdinalIgnoreCase)?value[6..]:value[3..];
            if(digits.Length==1&&digits[0] is >= '0' and <= '9'){key=0x60+digits[0]-'0';return true;}
        }
        return KeyNames.TryGetValue(value,out key);
    }
    private static string Prefix(HotkeyModifiers modifiers) => ((modifiers&HotkeyModifiers.Control)!=0?"Ctrl+":"")
        + ((modifiers&HotkeyModifiers.Alt)!=0?"Alt+":"") + ((modifiers&HotkeyModifiers.Shift)!=0?"Shift+":"");
    private static string KeyName(int key)
    {
        if(key is >=0x30 and <=0x39 or >=0x41 and <=0x5A)return ((char)key).ToString();
        if(key is >=0x70 and <=0x87)return "F"+(key-0x6F).ToString(CultureInfo.InvariantCulture);
        if(key is >=0x60 and <=0x69)return "NumPad"+(key-0x60).ToString(CultureInfo.InvariantCulture);
        return key switch
        {
            0x08=>"Backspace",0x09=>"Tab",0x0D=>"Enter",0x13=>"Pause",0x14=>"CapsLock",0x1B=>"Esc",0x20=>"Space",
            0x21=>"PageUp",0x22=>"PageDown",0x23=>"End",0x24=>"Home",0x25=>"Left",0x26=>"Up",0x27=>"Right",0x28=>"Down",
            0x2C=>"PrintScreen",0x2D=>"Insert",0x2E=>"Delete",0x6A=>"Multiply",0x6B=>"Add",0x6C=>"Separator",0x6D=>"Subtract",0x6E=>"Decimal",0x6F=>"Divide",0x90=>"NumLock",0x91=>"ScrollLock",
            0xBA=>"Oem1",0xBB=>"OemPlus",0xBC=>"OemComma",0xBD=>"OemMinus",0xBE=>"OemPeriod",0xBF=>"Oem2",0xC0=>"Oem3",0xDB=>"Oem4",0xDC=>"Oem5",0xDD=>"Oem6",0xDE=>"Oem7",0xDF=>"Oem8",0xE2=>"Oem102",
            _=>"Invalid"
        };
    }
}

public sealed record HotkeyCaptureResult(string ActionKey, HotkeyChord? Chord, bool Cancelled, string? Error = null);

/// <summary>UI-thread state machine. The hook calls this before ordinary command dispatch.</summary>
public sealed class HotkeyCaptureSession
{
    private string? actionKey;
    private readonly HashSet<int> owned=[];
    public bool IsCapturing=>actionKey!=null;
    public bool IsActive=>IsCapturing||owned.Count>0;
    public string? ActionKey=>actionKey;
    public string? Error {get;private set;}
    public event Action<HotkeyCaptureResult>? Completed;
    public event Action? Changed;
    public void Begin(string key)
    {
        if(string.IsNullOrWhiteSpace(key))throw new ArgumentException("Требуется действие.",nameof(key));
        actionKey=key;Error=null;Changed?.Invoke();
    }
    public void Cancel()
    {
        if(actionKey is not {} key)return;
        actionKey=null;Error=null;Completed?.Invoke(new(key,null,true));Changed?.Invoke();
    }
    public bool Process(int virtualKey,bool down,bool injected,bool repeat,HotkeyModifiers modifiers)
    {
        if(injected)return false;
        if(!down)
        {
            bool handled=owned.Remove(virtualKey);
            if(handled)Changed?.Invoke();
            return handled;
        }
        if(!IsActive)return false;
        // Own only keys whose down event was suppressed. Never suppress an unmatched
        // modifier up that Windows already saw before recording started.
        if(repeat)return true;
        owned.Add(virtualKey);
        if(!IsCapturing)return true;
        Error=null;
        var ownModifier=HotkeyChord.ModifierFor(virtualKey);
        if(ownModifier!=HotkeyModifiers.None)
        {
            if(ownModifier==HotkeyModifiers.Windows)Error="Сочетания с Win не назначаются. Отпустите Win и нажмите другое сочетание.";
            Changed?.Invoke();return true;
        }
        var key=actionKey!;
        if(virtualKey==0x1B&&modifiers==HotkeyModifiers.None){Cancel();return true;}
        if(virtualKey==0x2E&&modifiers==HotkeyModifiers.None)
        {actionKey=null;Completed?.Invoke(new(key,default(HotkeyChord),false));Changed?.Invoke();return true;}
        var chord=new HotkeyChord(virtualKey,modifiers);
        if(!chord.IsValid||chord.IsReserved)
        {Error=chord.IsReserved?"F1/F2 и Pause зарезервированы. Нажмите другое сочетание.":"Это сочетание не поддерживается. Нажмите другое.";Changed?.Invoke();return true;}
        actionKey=null;Completed?.Invoke(new(key,chord,false));Changed?.Invoke();return true;
    }
}
