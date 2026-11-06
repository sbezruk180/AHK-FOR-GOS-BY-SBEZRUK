using System.Buffers.Binary;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using Gos.Core;
using Microsoft.Win32.SafeHandles;

namespace Gos.Windows;

/// <summary>
/// External PE32 adapter for the exact AZMP/R3 layout preserved in UDF.ahk.
/// Structural compatibility is not a claim of compatibility with every client build.
/// No nearest-player guesses, injected overlay DLL, AHK runtime or automatic send retry.
/// </summary>
public sealed class GameMemory : IDisposable
{
    private const int MaxPlayers = 1004;
    private const uint SampInfoOffset = 0x26E8DC, InputInfoOffset = 0x26E8F4;
    private const uint GtaPedPool = 0xB74490, PedSize = 0x7C4;
    private readonly object sync = new();
    // Scalar pointer reads dominate HUD scans. All access runs under sync; no per-pointer heap array.
    private readonly byte[] scalarReadBuffer = new byte[4];
    private SafeProcessHandle? process;
    private uint processId, moduleBase, moduleSize;
    private string modulePath = "", expectedHash = "", hashKey = "";
    private bool hashMatches, disposed;
    private long lastRefresh;
    private int cachedId = -1;
    private uint cachedPed, cachedInfo, cachedPool;
    private long cachedAt;
    public event Action? ChatCallLaunched;
    private string status = "Игра не запущена";
    private PendingCall? pending;
    private static readonly Encoding Cp1251;

    private sealed record PendingCall(nint Thread, nint Code, nint Text);
    private readonly record struct PedPool(uint Objects, uint Flags, uint Count);
    private readonly record struct Position(float X, float Y, float Z);

    static GameMemory()
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        Cp1251 = Encoding.GetEncoding(1251, EncoderFallback.ExceptionFallback, DecoderFallback.ExceptionFallback);
    }

    public string ExpectedHash
    {
        get => Volatile.Read(ref expectedHash);
        set { Volatile.Write(ref expectedHash, value?.Trim() ?? ""); Interlocked.Exchange(ref lastRefresh, 0); }
    }
    public string Status => Volatile.Read(ref status);
    public bool IsActive
    {
        get
        {
            // Keyboard cancellation and passive UI must not wait on a remote call.
            // Discovery/validation runs in Refresh on the controller's worker.
            var pid = Volatile.Read(ref processId);
            if (pid == 0) return false;
            Native.GetWindowThreadProcessId(Native.GetForegroundWindow(), out var activePid);
            return activePid == pid;
        }
    }
    /// <summary>null is an incomplete read, never silently interpreted as a closed chat.</summary>
    public bool? IsChatOpen
    {
        get
        {
            lock (sync)
            {
                Refresh();
                if (moduleBase == 0 || !BuildAllowed()) return null;
                var input = ReadUInt(moduleBase + InputInfoOffset);
                if (!Pointer(input) || !TryReadUInt(input + 0x61, out var raw)) return null;
                return raw != 0;
            }
        }
    }

    public void Refresh()
    {
        lock (sync)
        {
            if (disposed) return;
            ReapPending();
            var now = Environment.TickCount64;
            var alive = process is { IsInvalid: false, IsClosed: false }
                && Native.GetExitCodeProcess(process, out var code) && code == Native.StillActive;
            if (!alive && process != null) ReleaseProcess();
            if (now - lastRefresh < 1000) return;
            lastRefresh = now;
            try
            {
                if (process == null)
                {
                    var candidates = Process.GetProcessesByName("gta_sa");
                    try
                    {
                        foreach (var candidate in candidates)
                        {
                            var opened = Native.OpenProcess(Native.ReadAccess, false, (uint)candidate.Id);
                            if (opened.IsInvalid) { opened.Dispose(); continue; }
                            if (Environment.Is64BitOperatingSystem && (!Native.IsWow64Process(opened, out var wow64) || !wow64))
                            { opened.Dispose(); continue; }
                            process = opened; processId = (uint)candidate.Id; break;
                        }
                    }
                    finally { foreach (var candidate in candidates) candidate.Dispose(); }
                    if (process == null) { status = "gta_sa.exe не найден или доступ запрещён"; return; }
                }
                using var game = Process.GetProcessById((int)processId);
                ProcessModule? azmp = null;
                foreach (ProcessModule module in game.Modules)
                    if (string.Equals(module.ModuleName, "azmp.dll", StringComparison.OrdinalIgnoreCase)) { azmp = module; break; }
                if (azmp == null)
                { moduleBase = moduleSize = 0; status = "Клиент azmp.dll ещё не загружен"; ResetCache(); return; }
                var address = unchecked((ulong)(nuint)azmp.BaseAddress);
                if (address > uint.MaxValue || address + (uint)azmp.ModuleMemorySize > 0x1_0000_0000UL)
                    throw new InvalidOperationException("Требуется 32-битный модуль игры.");
                if (moduleBase != (uint)address || modulePath != azmp.FileName)
                { ResetCache(); hashKey = ""; }
                moduleBase = (uint)address; moduleSize = (uint)azmp.ModuleMemorySize; modulePath = azmp.FileName;
                if (!ReadPe32()) throw new InvalidOperationException("Структура azmp.dll не соответствует исходному PE32.");
                if (!BuildAllowed()) return;
                status = pending != null ? "Предыдущий вызов ещё выполняется; повтор заблокирован"
                    : expectedHash.Length == 0 ? "Клиент найден · исходная схема AZMP, SHA не задан" : "Клиент найден · SHA-256 совпадает";
            }
            catch (Exception error) when (error is Win32Exception or InvalidOperationException or IOException or UnauthorizedAccessException or System.Security.SecurityException or ArgumentException)
            { moduleBase = moduleSize = 0; ResetCache(); status = error.Message; }
        }
    }

    private bool ForegroundMatches()
    {
        if (processId == 0 || process is null || process.IsInvalid || process.IsClosed) return false;
        Native.GetWindowThreadProcessId(Native.GetForegroundWindow(), out var foregroundPid);
        return foregroundPid == processId;
    }

    private bool BuildAllowed()
    {
        var expected = Volatile.Read(ref expectedHash);
        if (moduleBase == 0 || process == null) return false;
        if (expected.Length == 0) return true;
        if (expected.Length != 64 || expected.Any(c => !Uri.IsHexDigit(c)))
        { status = "Ожидаемый SHA-256 должен содержать 64 шестнадцатеричных символа"; return false; }
        try
        {
            var info = new FileInfo(modulePath);
            var key = $"{processId}:{moduleBase}:{info.Length}:{info.LastWriteTimeUtc.Ticks}:{expected}";
            if (key != hashKey)
            {
                using var file = new FileStream(modulePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
                hashMatches = Convert.ToHexString(SHA256.HashData(file)).Equals(expected, StringComparison.OrdinalIgnoreCase);
                hashKey = key;
            }
            if (!hashMatches) status = "SHA-256 azmp.dll не совпадает; доступ к памяти остановлен";
            return hashMatches;
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        { status = "Не удалось проверить SHA-256: " + error.Message; return false; }
    }

    private bool ReadPe32()
    {
        var header = Read(moduleBase, 4096);
        if (header == null || U16(header, 0) != 0x5A4D) return false;
        var pe = U32(header, 0x3C);
        if (pe < 64 || pe > header.Length - 120 || U32(header, (int)pe) != 0x4550
            || U16(header, (int)pe + 4) != 0x14C || (U16(header, (int)pe + 22) & 0x2000) == 0
            || U16(header, (int)pe + 24) != 0x10B) return false;
        var optionalSize = U16(header, (int)pe + 20);
        var imageSize = U32(header, (int)pe + 80);
        var headerSize = U32(header, (int)pe + 84);
        return optionalSize >= 96 && pe + 24 + optionalSize <= header.Length
            && imageSize >= 0x26E8F8 && imageSize <= 0x10000000 && imageSize <= moduleSize
            && headerSize >= pe + 24 + optionalSize && headerSize <= imageSize;
    }

    private bool Executable(uint address)
    {
        if (process == null || address < moduleBase || (ulong)address + 16 > (ulong)moduleBase + moduleSize) return false;
        if (Native.VirtualQueryEx(process, Ptr(address), out var info, (nuint)Marshal.SizeOf<Native.MemoryBasicInformation>()) == 0) return false;
        var protect = info.Protect & 0xFF;
        var regionBase = (ulong)(nuint)info.BaseAddress;
        if (info.State != Native.MemCommit || (info.Protect & 0x100) != 0
            || protect is not (0x10 or 0x20 or 0x40 or 0x80)
            || unchecked((uint)(nuint)info.AllocationBase) != moduleBase
            || address < regionBase || (ulong)address + 16 > regionBase + (ulong)info.RegionSize) return false;
        var bytes = Read(address, 16);
        return bytes != null && bytes.Any(b => b != 0 && b != 0xFF);
    }

    public TargetSnapshot? ReadAimTarget()
    {
        lock (sync)
        {
            Refresh();
            if (!ForegroundMatches() || !BuildAllowed()) return null;
            var gtaPool = ReadPedPool();
            if (gtaPool == null) { status = "Пул персонажей GTA недоступен"; return null; }
            var primary = ReadUInt(0xB6F3B8);
            var fallback = ReadUInt(0xB6F5F0);
            var source = primary;
            var target = Pointer(primary) ? ReadUInt(primary + 0x79C) : 0;
            if (!PedInPool(target, gtaPool.Value))
            { source = fallback; target = Pointer(fallback) ? ReadUInt(fallback + 0x79C) : 0; }
            if (!PedInPool(target, gtaPool.Value)) { ResetCache(); return null; }
            var pool = PlayerPool();
            if (!Pointer(pool)) { ResetCache(); status = "Пул игроков AZMP недоступен"; return null; }
            if (cachedPed == target && cachedPool == pool && Environment.TickCount64 - cachedAt < 1000 && cachedId is >= 0 and < MaxPlayers
                && ListedInfo(pool, cachedId) == cachedInfo && Matches(cachedInfo, target))
            {
                if (ReadUInt(source + 0x79C) == target)
                    return new TargetSnapshot(cachedId, Nickname(cachedInfo), target);
                return null;
            }
            var infos = Read(pool + 4, MaxPlayers * 4);
            var flags = Read(pool + 0xFB4, MaxPlayers * 4);
            if (infos == null || flags == null) { ResetCache(); return null; }
            var found = -1; uint foundInfo = 0;
            for (var id = 0; id < MaxPlayers; id++)
            {
                if (U32(flags, id * 4) == 0) continue;
                var info = U32(infos, id * 4);
                if (!Pointer(info) || !Matches(info, target)) continue;
                if (found != -1) { ResetCache(); status = "Один CPed найден у нескольких ID; предложение отклонено"; return null; }
                found = id; foundInfo = info;
            }
            if (found < 0 || ReadUInt(source + 0x79C) != target || ListedInfo(pool, found) != foundInfo
                || !Matches(foundInfo, target) || !PedInPool(target, gtaPool.Value))
            { ResetCache(); return null; }
            cachedId = found; cachedInfo = foundInfo; cachedPed = target; cachedPool = pool; cachedAt = Environment.TickCount64;
            return new TargetSnapshot(found, Nickname(foundInfo), target);
        }
    }

    public bool ValidateTarget(TargetSnapshot target)
    {
        lock(sync)
        {
            Refresh(); if(!ForegroundMatches()||!BuildAllowed()||target.Id is <0 or >=MaxPlayers)return false;
            uint pool=PlayerPool(),info=ListedInfo(pool,target.Id);
            if(!Pointer(info))return false;
            if(target.Ped!=0&&!Matches(info,target.Ped))return false;
            return target.Ped==0||string.IsNullOrEmpty(target.Name)||Nickname(info)==target.Name;
        }
    }

    /// <summary>Only streamed remote players, not NPCs or all connected players. Distances are 3D game units.</summary>
    public IReadOnlyList<NearbyPlayer> ReadNearby(double radius)
    {
        lock (sync)
        {
            Refresh();
            if (!double.IsFinite(radius) || radius is < 1 or > 1000) throw new ArgumentOutOfRangeException(nameof(radius));
            if (!ForegroundMatches() || !BuildAllowed()) return [];
            var gtaPool = ReadPedPool();
            var localPed = ReadUInt(0xB6F5F0);
            if (gtaPool == null || !PedInPool(localPed, gtaPool.Value)) return [];
            var origin = Coordinates(localPed);
            var pool = PlayerPool();
            if (origin == null || !Pointer(pool)) return [];
            var infos = Read(pool + 4, MaxPlayers * 4);
            var flags = Read(pool + 0xFB4, MaxPlayers * 4);
            if (infos == null || flags == null) return [];
            var players = new List<NearbyPlayer>();
            var seenPeds = new HashSet<uint>();
            for (var id = 0; id < MaxPlayers; id++)
            {
                if (U32(flags, id * 4) == 0) continue;
                var info = U32(infos, id * 4);
                var ped = GamePed(info, gtaPool.Value);
                if (ped == 0 || ped == localPed || !seenPeds.Add(ped)) continue;
                var position = Coordinates(ped);
                if (position == null) continue;
                var dx = (double)origin.Value.X - position.Value.X;
                var dy = (double)origin.Value.Y - position.Value.Y;
                var dz = (double)origin.Value.Z - position.Value.Z;
                var distance = Math.Sqrt(dx * dx + dy * dy + dz * dz);
                if (distance > radius || ListedInfo(pool, id) != info || !Matches(info, ped)) continue;
                players.Add(new NearbyPlayer(id, Nickname(info), distance));
            }
            // A respawn during the snapshot invalidates the origin instead of producing a misleading list.
            if (ReadUInt(0xB6F5F0) != localPed || PlayerPool() != pool) return [];
            return players.OrderBy(p => p.Distance).ThenBy(p => p.Id).ToArray();
        }
    }

    public void SendChat(string text, CancellationToken cancellationToken=default)
    {
        lock (sync)
        {
            ObjectDisposedException.ThrowIf(disposed, this);
            cancellationToken.ThrowIfCancellationRequested();
            if (string.IsNullOrWhiteSpace(text) || text.Length > 1023 || text.Any(c => c == '\0' || c == '\r' || c == '\n'))
                throw new ArgumentException("Сообщение должно быть одной строкой длиной до 1023 символов.");
            byte[] encoded;
            try { encoded = Cp1251.GetBytes(text + '\0'); }
            catch (EncoderFallbackException) { throw new ArgumentException("Игровой чат поддерживает CP1251; текст содержит неподдерживаемый символ."); }
            Refresh(); ReapPending();
            var expectedAtStart = ExpectedHash;
            if (pending != null) throw new InvalidOperationException("Результат предыдущей отправки неизвестен. Повтор запрещён до завершения потока.");
            if (!ForegroundMatches()) throw new InvalidOperationException("Игра должна оставаться активной.");
            if (!ReadPe32() || !BuildAllowed()) throw new InvalidOperationException(status);
            // Same callable-page checks as MemoryLegacyLayoutCompatible in common.ahk.
            foreach (var offset in new uint[] { 0x5820, 0x69190, 0x67970, 0x6F8C0 })
                if (!Executable(moduleBase + offset)) throw new InvalidOperationException("Исполняемые страницы AZMP не соответствуют исходной схеме.");
            var writable = Native.OpenProcess(Native.WriteAccess, false, processId);
            if (writable.IsInvalid) { writable.Dispose(); throw new Win32Exception(Marshal.GetLastWin32Error(), "Нет доступа к отправке в память."); }
            // Upgrade once per send, never retain write rights during read-only HUD operation.
            using (writable)
            {
                nint remoteText = 0, remoteCode = 0, thread = 0;
                var launched = false;
                try
                {
                    remoteText = Native.VirtualAllocEx(writable, 0, (nuint)encoded.Length, Native.MemCommit | Native.MemReserve, Native.PageReadWrite);
                    remoteCode = Native.VirtualAllocEx(writable, 0, 4096, Native.MemCommit | Native.MemReserve, Native.PageReadWrite);
                    if (remoteText == 0 || remoteCode == 0) throw new Win32Exception(Marshal.GetLastWin32Error(), "Не удалось выделить память сообщения.");
                    var function = moduleBase + (text.StartsWith('/') ? 0x69190u : 0x5820u);
                    var stub = BuildChatStub(unchecked((uint)(nuint)remoteText), function);
                    Write(writable, remoteText, encoded); Write(writable, remoteCode, stub);
                    if (!Native.VirtualProtectEx(writable, remoteCode, 4096, Native.PageExecuteRead, out _)
                        || !Native.FlushInstructionCache(writable, remoteCode, (nuint)stub.Length))
                        throw new Win32Exception(Marshal.GetLastWin32Error(), "Не удалось подготовить вызов игрового чата.");
                    if (!ForegroundMatches() || ExpectedHash != expectedAtStart || !BuildAllowed() || !Executable(function))
                        throw new InvalidOperationException("Контекст изменился до отправки.");
                    cancellationToken.ThrowIfCancellationRequested();
                    thread = Native.CreateRemoteThread(writable, 0, 0, remoteCode, 0, 0, out _);
                    if (thread == 0) throw new Win32Exception(Marshal.GetLastWin32Error(), "Игровой вызов не запущен.");
                    launched = true;
                    foreach (var handler in ChatCallLaunched?.GetInvocationList() ?? [])
                        try { ((Action)handler)(); } catch { /* Observers cannot relabel an in-flight send. */ }
                    if (Native.WaitForSingleObject(thread, 2000) != Native.WaitObject0)
                    {
                        pending = new PendingCall(thread, remoteCode, remoteText);
                        thread = remoteCode = remoteText = 0;
                        throw new InvalidOperationException("Результат отправки неизвестен: поток ещё не завершён. Автоповтор отключён.");
                    }
                    if (!Native.GetExitCodeThread(thread, out var exit) || exit != 0)
                        throw new InvalidOperationException("Игровой вызов завершился с ошибкой; сообщение могло быть отправлено. Повтор отключён.");
                    status = "Передано клиенту через память · подтверждение сервера не проверялось";
                }
                catch
                {
                    if (launched) status = "Результат игрового вызова не подтверждён; автоматический повтор запрещён";
                    throw;
                }
                finally
                {
                    if (thread != 0) Native.CloseHandle(thread);
                    if (remoteCode != 0) Native.VirtualFreeEx(writable, remoteCode, 0, Native.MemRelease);
                    if (remoteText != 0) Native.VirtualFreeEx(writable, remoteText, 0, Native.MemRelease);
                }
            }
        }
    }

    /// <summary>Original callee-cleanup ABI, with a normal-return marker independent of game's EAX.</summary>
    public static byte[] BuildChatStub(uint textAddress, uint functionAddress)
    {
        byte[] stub = [0x68, 0, 0, 0, 0, 0xB8, 0, 0, 0, 0, 0xFF, 0xD0, 0x31, 0xC0, 0xC2, 4, 0];
        BinaryPrimitives.WriteUInt32LittleEndian(stub.AsSpan(1, 4), textAddress);
        BinaryPrimitives.WriteUInt32LittleEndian(stub.AsSpan(6, 4), functionAddress);
        return stub;
    }

    private void ReapPending()
    {
        if (pending == null || process == null) return;
        var state = Native.WaitForSingleObject(pending.Thread, 0);
        var alive = Native.GetExitCodeProcess(process, out var exit) && exit == Native.StillActive;
        if (state != Native.WaitObject0 && alive) return;
        // Read-only main handle cannot free remote allocations; acquire only for completed cleanup.
        if (alive && state == Native.WaitObject0)
        {
            using var cleanup = Native.OpenProcess(Native.WriteAccess, false, processId);
            if (!cleanup.IsInvalid)
            {
                Native.VirtualFreeEx(cleanup, pending.Code, 0, Native.MemRelease);
                Native.VirtualFreeEx(cleanup, pending.Text, 0, Native.MemRelease);
            }
        }
        Native.CloseHandle(pending.Thread); pending = null;
    }

    private void ReleaseProcess()
    {
        ReapPending();
        if (pending != null)
        {
            // Never free code while a target thread may execute it. Target exit reclaims it.
            Native.CloseHandle(pending.Thread); pending = null;
        }
        process?.Dispose(); process = null; processId = moduleBase = moduleSize = 0;
        hashKey = modulePath = ""; ResetCache();
    }

    private void ResetCache() { cachedId = -1; cachedPed = cachedInfo = cachedPool = 0; cachedAt = 0; }
    private uint PlayerPool()
    {
        var info = ReadUInt(moduleBase + SampInfoOffset);
        var pools = Pointer(info) ? ReadUInt(info + 0x3DE) : 0;
        return Pointer(pools) ? ReadUInt(pools + 8) : 0;
    }
    private uint ListedInfo(uint pool, int id) => id is >= 0 and < MaxPlayers && ReadUInt(pool + 0xFB4 + (uint)id * 4) != 0
        ? ReadUInt(pool + 4 + (uint)id * 4) : 0;
    private (uint First, uint Second) Peds(uint info)
    {
        var remote = Pointer(info) ? ReadUInt(info) : 0;
        var sampPed = Pointer(remote) ? ReadUInt(remote) : 0;
        return Pointer(sampPed) ? (ReadUInt(sampPed + 0x2A4), ReadUInt(sampPed + 0x40)) : (0, 0);
    }
    private bool Matches(uint info, uint target)
    {
        if (!Pointer(target)) return false;
        var peds = Peds(info); return peds.First == target || peds.Second == target;
    }
    private uint GamePed(uint info, PedPool pool)
    {
        var peds = Peds(info);
        return PedInPool(peds.First, pool) ? peds.First : PedInPool(peds.Second, pool) ? peds.Second : 0;
    }
    private PedPool? ReadPedPool()
    {
        var pool = ReadUInt(GtaPedPool);
        if (!Pointer(pool)) return null;
        var data = Read(pool, 12);
        if (data == null) return null;
        var objects = U32(data, 0); var flags = U32(data, 4); var count = U32(data, 8);
        return Pointer(objects) && Pointer(flags) && count is >= 1 and <= 4096
            && (ulong)objects + count * PedSize <= uint.MaxValue ? new PedPool(objects, flags, count) : null;
    }
    private bool PedInPool(uint ped, PedPool pool)
    {
        if (!Pointer(ped) || ped < pool.Objects) return false;
        var delta = ped - pool.Objects;
        if (delta % PedSize != 0 || delta / PedSize >= pool.Count) return false;
        var flags = Read(pool.Flags + delta / PedSize, 1);
        return flags != null && (flags[0] & 0x80) == 0 && Coordinates(ped) != null;
    }
    private Position? Coordinates(uint ped)
    {
        var matrix = Pointer(ped) ? ReadUInt(ped + 0x14) : 0;
        if (!Pointer(matrix)) return null;
        var data = Read(matrix + 0x30, 12);
        if (data == null) return null;
        var x = BitConverter.ToSingle(data, 0); var y = BitConverter.ToSingle(data, 4); var z = BitConverter.ToSingle(data, 8);
        return float.IsFinite(x) && float.IsFinite(y) && float.IsFinite(z) && Math.Abs(x) <= 20000 && Math.Abs(y) <= 20000 && Math.Abs(z) <= 5000
            ? new Position(x, y, z) : null;
    }
    private string Nickname(uint info)
    {
        if (!Pointer(info)) return "";
        var storage = Read(info + 0x0C, 24);
        if (storage == null) return "";
        var length = U32(storage, 16); var capacity = U32(storage, 20);
        if (length is < 1 or > 48 || capacity < length || capacity > 4096) return "";
        var address = capacity >= 16 ? U32(storage, 0) : info + 0x0C;
        var data = Read(address, (int)length);
        if (data == null) return "";
        var name = Cp1251.GetString(data).Trim();
        return name.Any(char.IsControl) ? "" : name;
    }
    private byte[]? Read(uint address, int size)
    {
        if (process == null || process.IsInvalid || process.IsClosed || address < 0x10000
            || size < 1 || size > 1_048_576 || (ulong)address + (uint)size > 0x1_0000_0000UL) return null;
        var buffer = new byte[size];
        return Native.ReadProcessMemory(process, Ptr(address), buffer, (nuint)size, out var read) && read == (nuint)size ? buffer : null;
    }
    private bool TryReadUInt(uint address, out uint value)
    {
        value = 0;
        if (process == null || process.IsInvalid || process.IsClosed || address < 0x10000
            || (ulong)address + 4 > 0x1_0000_0000UL) return false;
        if (!Native.ReadProcessMemory(process, Ptr(address), scalarReadBuffer, 4, out var read) || read != 4) return false;
        value = U32(scalarReadBuffer, 0);
        return true;
    }
    private uint ReadUInt(uint address) => TryReadUInt(address, out var value) ? value : 0;
    private static bool Pointer(uint value) => value is >= 0x10000 and < 0xFFFF0000 && value % 4 == 0;
    private static nint Ptr(uint value) => unchecked((nint)(nuint)value);
    private static uint U32(byte[] bytes, int offset) => BinaryPrimitives.ReadUInt32LittleEndian(bytes.AsSpan(offset, 4));
    private static ushort U16(byte[] bytes, int offset) => BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(offset, 2));
    private static void Write(SafeProcessHandle handle, nint address, byte[] bytes)
    {
        if (!Native.WriteProcessMemory(handle, address, bytes, (nuint)bytes.Length, out var wrote) || wrote != (nuint)bytes.Length)
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Не удалось записать сообщение в память.");
    }
    public void Dispose()
    {
        lock (sync) { if (disposed) return; ReleaseProcess(); disposed = true; }
    }
}
