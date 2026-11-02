using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace Gos.Windows;

/// <summary>Win32 interop shared by the input, memory and passive windows.</summary>
public static class Native
{
    public const uint WdaExcludeFromCapture = 0x11;
    public const uint WdaNone = 0;
    public const uint WaitObject0 = 0, WaitTimeout = 258, StillActive = 259;
    public const uint MemCommit = 0x1000, MemReserve = 0x2000, MemRelease = 0x8000;
    public const uint PageReadWrite = 4, PageExecuteRead = 0x20;
    public const uint ReadAccess = 0x0410, WriteAccess = 0x043A;
    [DllImport("user32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetWindowDisplayAffinity(nint hwnd, uint affinity);
    [DllImport("user32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetWindowDisplayAffinity(nint hwnd, out uint affinity);
    [DllImport("user32.dll")] public static extern nint GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(nint window, out uint processId);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] public static extern short GetKeyState(int key);
    [DllImport("user32.dll")] public static extern nint GetKeyboardLayout(uint threadId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern nint LoadKeyboardLayout(string layout, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern short VkKeyScanEx(char character, nint layout);
    [DllImport("user32.dll")] public static extern uint MapVirtualKeyEx(uint code, uint mapType, nint layout);
    [DllImport("user32.dll", SetLastError = true)] public static extern nint SendMessageTimeout(nint window, uint message, nuint wparam, nint lparam, uint flags, uint timeout, out nuint result);
    [DllImport("kernel32.dll", SetLastError = true)] public static extern SafeProcessHandle OpenProcess(uint access, [MarshalAs(UnmanagedType.Bool)] bool inherit, uint processId);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetExitCodeProcess(SafeProcessHandle process, out uint exitCode);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsWow64Process(SafeProcessHandle process, [MarshalAs(UnmanagedType.Bool)] out bool wow64);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ReadProcessMemory(SafeProcessHandle process, nint address, byte[] buffer, nuint count, out nuint bytesRead);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool WriteProcessMemory(SafeProcessHandle process, nint address, byte[] buffer, nuint count, out nuint bytesWritten);
    [DllImport("kernel32.dll", SetLastError = true)] public static extern nuint VirtualQueryEx(SafeProcessHandle process, nint address, out MemoryBasicInformation information, nuint length);
    [DllImport("kernel32.dll", SetLastError = true)] public static extern nint VirtualAllocEx(SafeProcessHandle process, nint address, nuint size, uint allocationType, uint protection);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool VirtualProtectEx(SafeProcessHandle process, nint address, nuint size, uint protection, out uint oldProtection);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool VirtualFreeEx(SafeProcessHandle process, nint address, nuint size, uint freeType);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool FlushInstructionCache(SafeProcessHandle process, nint address, nuint size);
    [DllImport("kernel32.dll", SetLastError = true)] public static extern nint CreateRemoteThread(SafeProcessHandle process, nint attributes, nuint stackSize, nint startAddress, nint parameter, uint flags, out uint threadId);
    [DllImport("kernel32.dll", SetLastError = true)] public static extern uint WaitForSingleObject(nint handle, uint milliseconds);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetExitCodeThread(nint thread, out uint code);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CloseHandle(nint handle);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern nint GetModuleHandle(string? name);
    public delegate nint HookProc(int code, nint wparam, nint lparam);
    [DllImport("user32.dll", SetLastError = true)] public static extern nint SetWindowsHookEx(int id, HookProc callback, nint module, uint threadId);
    [DllImport("user32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool UnhookWindowsHookEx(nint hook);
    [DllImport("user32.dll")] public static extern nint CallNextHookEx(nint hook, int code, nint wparam, nint lparam);
    [DllImport("user32.dll", SetLastError = true)] public static extern uint SendInput(uint count, [In] Input[] inputs, int size);

    [StructLayout(LayoutKind.Sequential)]
    public struct MemoryBasicInformation
    {
        public nint BaseAddress, AllocationBase;
        public uint AllocationProtect;
        public nuint RegionSize;
        public uint State, Protect, Type;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct LowLevelKeyboard { public uint VirtualKey, ScanCode, Flags, Time; public nuint ExtraInfo; }
    [StructLayout(LayoutKind.Sequential)]
    public struct Input { public uint Type; public InputUnion Data; }
    [StructLayout(LayoutKind.Explicit)]
    public struct InputUnion
    {
        [FieldOffset(0)] public KeyboardInput Keyboard;
        [FieldOffset(0)] public MouseInput Mouse;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct KeyboardInput { public ushort VirtualKey, ScanCode; public uint Flags, Time; public nuint ExtraInfo; }
    [StructLayout(LayoutKind.Sequential)]
    public struct MouseInput { public int X, Y; public uint MouseData, Flags, Time; public nuint ExtraInfo; }
}
