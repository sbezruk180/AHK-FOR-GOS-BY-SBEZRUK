using Gos.Core;
namespace Gos.Windows;

// One physical key grants exactly one character. Never accumulate future permits.
public sealed class ChatTransport(GameMemory game) : IMessageTransport, IKeyTransport, IDisposable
{
    readonly AssistedInput input=new();
    public bool IsAssisting=>input.IsActive;
    public event Action<string>? Progress;
    public TargetSnapshot? GuardTarget {get;set;}
    void ValidateTarget() {if(GuardTarget is {} target&&!game.ValidateTarget(target))throw new InvalidOperationException("Выбранный игрок вышел или изменился. Выберите ID заново.");}
    public bool ConsumeKey(KeyStroke stroke)
    {
        if (stroke.Injected || stroke.VirtualKey is 0x10 or 0x11 or 0x12 or 0xA0 or 0xA1 or 0xA2 or 0xA3 or 0xA4 or 0xA5) return false;
        return input.Press(stroke.Down,stroke.Repeat);
    }
    Task WaitForPhysicalKey(CancellationToken ct)=>input.WaitAsync(ct);
    void RequireGame(CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        if (!game.IsActive) throw new InvalidOperationException("Переключение окна: отправка остановлена. Вернитесь в GTA и запустите действие заново.");
    }
    public async Task SendAsync(string text, SendMode mode, AppSettings settings, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(text) || text.Contains('\r') || text.Contains('\n') || text.Contains('\0'))
            throw new InvalidOperationException("Нужна одна непустая строка чата.");
        if (text.Length > 240) throw new InvalidOperationException("Строка длиннее 240 символов. Разделите её на несколько шагов.");
        RequireGame(ct);ValidateTarget();
        if (game.IsChatOpen != false) throw new InvalidOperationException("Закройте игровой чат. Если состояние не читается — проверьте совместимость azmp.dll.");
        if (mode == SendMode.Memory)
        {
            // Never cancel an in-flight remote thread by freeing its memory.
            await Task.Run(() => { RequireGame(ct); game.SendChat(text,ct); }, ct);
            ct.ThrowIfCancellationRequested();
            return;
        }
        bool opened = false, submitted = false;
        nint originalWindow=Native.GetForegroundWindow(), originalLayout=KeyboardHook.CaptureLayout();
        try
        {
            for (int i=0; i<150 && ModifiersDown(); i++) await Task.Delay(10,ct);
            if (ModifiersDown()) throw new InvalidOperationException("Отпустите Alt, Ctrl и Shift перед печатью.");
            RequireGame(ct);
            KeyboardHook.PressKey(0x75); // F6
            opened = true;
            await Task.Delay(100,ct);
            if (game.IsChatOpen != true) throw new InvalidOperationException("Игра не подтвердила открытие чата. Текст не отправлен.");
            if(mode==SendMode.KeyAssisted)input.Begin(text.Length);
            for (int index=0; index<text.Length; index++)
            {
                if (mode == SendMode.KeyAssisted)
                {
                    Progress?.Invoke($"Клавишный ввод: {index}/{text.Length} — нажимайте любые буквенные клавиши; Pause — отмена");
                    await WaitForPhysicalKey(ct);
                }
                long characterStart=System.Diagnostics.Stopwatch.GetTimestamp();
                RequireGame(ct);
                if (game.IsChatOpen != true) throw new InvalidOperationException("Чат закрыт во время печати. Действие остановлено.");
                KeyboardHook.TypeCharacter(text[index]);
                if (mode == SendMode.RandomTyping)
                {
                    int speed = Random.Shared.Next(settings.MinCps, settings.MaxCps + 1);
                    int remaining=(int)Math.Ceiling(1000.0/speed-System.Diagnostics.Stopwatch.GetElapsedTime(characterStart).TotalMilliseconds);
                    if(remaining>0)await Task.Delay(remaining,ct);
                }
            }
            // End assisted capture before injecting Enter; injected keys never earn permits.
            input.End();
            RequireGame(ct);
            if (game.IsChatOpen != true) throw new InvalidOperationException("Чат закрыт перед отправкой.");
            ValidateTarget();
            if(ModifiersDown())throw new InvalidOperationException("Печать прервана: отпустите модификаторы и закройте неотправленный чат.");
            KeyboardHook.PressKey(0x0D);
            submitted = true;
        }
        finally
        {
            input.End();
            // Only cancel the chat this operation opened; never send keys to another app.
            if (opened && !submitted && game.IsActive && !ModifiersDown() && game.IsChatOpen == true) KeyboardHook.PressKey(0x1B);
            if(Native.GetForegroundWindow()==originalWindow)
                try {KeyboardHook.RestoreLayout(originalLayout);} catch(System.ComponentModel.Win32Exception){}
        }
    }
    static bool ModifiersDown() => new[] {0x10,0x11,0x12,0x5B,0x5C}.Any(KeyboardHook.IsKeyDown);
    public Task PressKeyAsync(string key, CancellationToken ct)
    {
        RequireGame(ct);
        int vk = key.ToUpperInvariant() switch { "DOWN"=>0x28,"UP"=>0x26,"ENTER"=>0x0D,"HOME"=>0x24,"END"=>0x23,_=>throw new InvalidOperationException("Клавиша меню не разрешена.") };
        KeyboardHook.PressKey(vk); return Task.CompletedTask;
    }
    public void Dispose()=>input.End();
}
