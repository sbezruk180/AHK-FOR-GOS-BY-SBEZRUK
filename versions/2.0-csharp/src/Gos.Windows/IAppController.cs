using Gos.Core;
namespace Gos.Windows;
public interface IAppController
{
    AppSettings Settings { get; }
    string Status { get; }
    string ConnectionStatus { get; }
    TargetSnapshot? Target { get; }
    TargetSnapshot? Candidate { get; }
    bool IsGameActive { get; }
    IReadOnlyList<NearbyPlayer> Nearby { get; }
    LawLibrary Laws { get; }
    event Action? Changed;
    Task RunAsync(string key);
    Task RunScenarioAsync(Scenario scenario);
    void Cancel();
    void AcceptTarget();
    void RejectTarget();
    void SaveSettings();
    void ApplySettings(AppSettings draft);
    void SetManualTarget(int id);
    void ClearTarget();
    void Notify(string text);
    void ImportLegacy(string path);
    bool IsCapturingHotkey { get; }
    void BeginHotkeyCapture(string actionKey,Action<string?> onCaptured);
    void CancelHotkeyCapture();
}
