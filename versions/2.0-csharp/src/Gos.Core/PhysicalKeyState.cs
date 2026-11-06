namespace Gos.Core;

/// <summary>State from physical hook packets, independent of layout and pre-callback GetAsyncKeyState timing.</summary>
public sealed class PhysicalKeyState
{
    readonly HashSet<int> held=[];
    public void Update(int key,bool down,bool injected)
    {
        if(injected||key is <1 or >254)return;
        if(down)held.Add(key);else held.Remove(key);
    }
    public HotkeyModifiers Modifiers =>
        (held.Overlaps([0x10,0xA0,0xA1])?HotkeyModifiers.Shift:0) |
        (held.Overlaps([0x11,0xA2,0xA3])?HotkeyModifiers.Control:0) |
        (held.Overlaps([0x12,0xA4,0xA5])?HotkeyModifiers.Alt:0) |
        (held.Overlaps([0x5B,0x5C])?HotkeyModifiers.Windows:0);
    public bool IsDown(int key)=>held.Contains(key);
}
