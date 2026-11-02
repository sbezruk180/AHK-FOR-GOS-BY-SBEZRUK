using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Gos.Windows;

public readonly record struct KeyStroke(int VirtualKey, bool Down, bool Injected, bool Repeat);

/// <summary>One process-wide hook; subscribers run briefly on the owning UI message thread.</summary>
public sealed class KeyboardHook : IDisposable
{
    private readonly Native.HookProc callback;
    private readonly HashSet<int> held = [];
    private nint hook;
    public event Func<KeyStroke, bool>? KeyInput;
    public event Action<Exception>? CallbackError;

    public KeyboardHook()
    {
        callback = ProcessKey;
        hook = Native.SetWindowsHookEx(13, callback, Native.GetModuleHandle(null), 0);
        if (hook == 0) throw new Win32Exception(Marshal.GetLastWin32Error(), "Не удалось установить обработчик клавиатуры.");
    }

    private nint ProcessKey(int code, nint message, nint pointer)
    {
        if (code < 0) return Native.CallNextHookEx(hook, code, message, pointer);
        try
        {
            var data = Marshal.PtrToStructure<Native.LowLevelKeyboard>(pointer);
            var down = message == 0x100 || message == 0x104;
            var up = message == 0x101 || message == 0x105;
            if (!down && !up) return Native.CallNextHookEx(hook, code, message, pointer);
            var injected = (data.Flags & 0x12) != 0;
            var key = (int)data.VirtualKey;
            var repeat = !injected && down && !held.Add(key);
            if (!injected && up) held.Remove(key);
            var stroke = new KeyStroke(key, down, injected, repeat);
            var handled = false;
            if (KeyInput is { } subscribers)
                foreach (Func<KeyStroke, bool> handler in subscribers.GetInvocationList())
                    handled |= handler(stroke);
            if (handled) return 1;
        }
        catch (Exception error)
        {
            // Never throw across an unmanaged hook boundary or swallow a real key on failure.
            try { CallbackError?.Invoke(error); } catch { }
        }
        return Native.CallNextHookEx(hook, code, message, pointer);
    }

    public static bool IsKeyDown(int key) => (Native.GetAsyncKeyState(key) & 0x8000) != 0;

    public static void PressKey(int key)
    {
        if (key is < 1 or > 254) throw new ArgumentOutOfRangeException(nameof(key));
        SendVirtualKey(key, false);
        try { Thread.Sleep(12); }
        finally { SendVirtualKey(key, true); }
    }

    private static void SendVirtualKey(int key, bool up)
    {
        var input = new Native.Input { Type = 1, Data = new Native.InputUnion {
            Keyboard = new Native.KeyboardInput { VirtualKey = (ushort)key, Flags = up ? 2u : 0u } } };
        Send([input]);
    }

    /// <summary>
    /// Real scan-code typing (not paste). Switches the foreground thread between loaded
    /// English/Russian layouts only when needed. Caller captures/restores layout per message.
    /// Unsupported characters fail explicitly; no unreliable Unicode-packet fallback in GTA.
    /// </summary>
    public static void TypeCharacter(char character)
    {
        if (char.IsControl(character) || char.IsSurrogate(character))
            throw new ArgumentException("Управляющие символы и emoji не поддерживаются игровым чатом.");
        var foreground = Native.GetForegroundWindow();
        var thread = Native.GetWindowThreadProcessId(foreground, out _);
        var layout = Native.GetKeyboardLayout(thread);
        var mapping = Native.VkKeyScanEx(character, layout);
        if (mapping == -1)
        {
            var desired = character is >= '\u0400' and <= '\u04FF' ? "00000419" : "00000409";
            layout = Native.LoadKeyboardLayout(desired, 0);
            if (layout == 0 || Native.VkKeyScanEx(character, layout) == -1)
                throw new InvalidOperationException($"Символ «{character}» отсутствует в поддерживаемой раскладке.");
            RestoreLayout(layout);
            if (Native.GetKeyboardLayout(thread) != layout)
                throw new InvalidOperationException("Игра не приняла смену раскладки; печать остановлена.");
            mapping = Native.VkKeyScanEx(character, layout);
        }
        if (foreground != Native.GetForegroundWindow()) throw new InvalidOperationException("Окно изменилось во время печати.");
        var modifiers = (mapping >> 8) & 0xFF;
        // CapsLock reverses the alphabetic Shift relation; punctuation/digits are unaffected.
        if (char.IsLetter(character) && (Native.GetKeyState(0x14) & 1) != 0) modifiers ^= 1;
        if ((modifiers & ~7) != 0) throw new InvalidOperationException("Неподдерживаемая комбинация раскладки.");
        int[] keys = [0x10, 0x11, 0x12];
        var pressed = new List<int>(3);
        try
        {
            // Never release a physically held modifier; abort rather than change a user's chord.
            for (var i = 0; i < keys.Length; i++)
            {
                var needed = (modifiers & (1 << i)) != 0;
                if (IsKeyDown(keys[i]) && !needed)
                    throw new InvalidOperationException("Отпустите Shift/Ctrl/Alt перед печатью.");
                if (needed && !IsKeyDown(keys[i])) { SendVirtualKey(keys[i], false); pressed.Add(keys[i]); }
            }
            var scan = Native.MapVirtualKeyEx((uint)(mapping & 0xFF), 0, layout);
            if (scan == 0) throw new InvalidOperationException("Не удалось получить scan-code символа.");
            var input = new Native.Input { Type = 1, Data = new Native.InputUnion { Keyboard = new Native.KeyboardInput {
                ScanCode = (ushort)scan, Flags = 8 } } };
            Send([input]);
            try { Thread.Sleep(10); }
            finally { input.Data.Keyboard.Flags |= 2; Send([input]); }
        }
        finally
        {
            for (var i = pressed.Count - 1; i >= 0; i--) SendVirtualKey(pressed[i], true);
        }
    }

    public static nint CaptureLayout()
    {
        var thread = Native.GetWindowThreadProcessId(Native.GetForegroundWindow(), out _);
        return Native.GetKeyboardLayout(thread);
    }

    public static void RestoreLayout(nint layout)
    {
        if (layout == 0) return;
        var window = Native.GetForegroundWindow();
        if (Native.SendMessageTimeout(window, 0x50, 0, layout, 2, 250, out _) == 0)
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Окно не ответило на смену раскладки.");
    }

    private static void Send(Native.Input[] inputs)
    {
        if (Native.SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<Native.Input>()) != inputs.Length)
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Windows отклонила ввод. Проверьте одинаковый уровень прав игры и приложения.");
    }

    public void Dispose()
    {
        if (hook == 0) return;
        Native.UnhookWindowsHookEx(hook); hook = 0; held.Clear();
        GC.KeepAlive(callback);
    }
}
