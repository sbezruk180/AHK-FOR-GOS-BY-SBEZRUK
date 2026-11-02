namespace Gos.Core;

public interface IMessageTransport
{
    Task SendAsync(string text, SendMode mode, AppSettings settings, CancellationToken cancellationToken);
}
public interface IKeyTransport
{
    Task PressKeyAsync(string key, CancellationToken cancellationToken);
}

/// <summary>A single cancellable sequence. No unbounded queue and no automatic retries.</summary>
public sealed class AutomationRunner(IMessageTransport transport) : IDisposable
{
    private readonly object sync = new();
    private CancellationTokenSource? active;
    private bool disposed;
    public bool IsBusy { get { lock(sync) return active is not null; } }
    public event Action<string>? StatusChanged;

    public async Task RunAsync(IEnumerable<ScenarioStep> source, AppSettings settings, TargetSnapshot? target, bool forceMemory = false)
    {
        ArgumentNullException.ThrowIfNull(source);
        ArgumentNullException.ThrowIfNull(settings);
        // Copy both sequence and configuration before the first side effect.
        var steps = source.Select(x => x is null ? throw new InvalidDataException("Пустой шаг.")
            : new ScenarioStep {Kind=x.Kind,Text=x.Text,DelayMs=x.DelayMs}).ToArray();
        if (steps.Length is 0 or >100) throw new InvalidDataException("Последовательность должна содержать от 1 до 100 шагов.");
        foreach (var step in steps) step.Validate();
        if (steps.Sum(s=>(long)s.DelayMs)>600000) throw new InvalidDataException("Суммарная пауза превышает 10 минут.");
        var frozen = ProfileStore.Copy(settings);
        frozen.Normalize();
        // Expand all text first: a bad late placeholder must not send a partial scenario.
        foreach (var step in steps)
            if (step.Kind is "send" or "notice") step.Text = Template.Expand(step.Text,frozen,target);
        if (steps.Any(s=>s.Kind=="key") && transport is not IKeyTransport)
            throw new InvalidOperationException("Транспорт не поддерживает ввод клавиш меню.");
        CancellationTokenSource cts;
        lock(sync)
        {
            ObjectDisposedException.ThrowIf(disposed,this);
            if (active is not null) throw new InvalidOperationException("Действие уже выполняется. Дождитесь завершения или нажмите Pause.");
            active = cts = new();
        }
        try
        {
            var previousWasMessage = false;
            for (var i=0;i<steps.Length;i++)
            {
                var step=steps[i]; cts.Token.ThrowIfCancellationRequested();
                if (step.Kind=="send" && previousWasMessage && frozen.LineDelayMs>0)
                    await Task.Delay(frozen.LineDelayMs,cts.Token).ConfigureAwait(false);
                Publish($"Шаг {i+1}/{steps.Length}: {step.Kind}");
                cts.Token.ThrowIfCancellationRequested();
                switch(step.Kind)
                {
                    case "send": await transport.SendAsync(step.Text,forceMemory ? SendMode.Memory : frozen.SendMode,frozen,cts.Token).ConfigureAwait(false); break;
                    case "key": await ((IKeyTransport)transport).PressKeyAsync(step.Text,cts.Token).ConfigureAwait(false); break;
                    case "notice": Publish(step.Text); break;
                    case "wait": break;
                }
                if (step.DelayMs>0) await Task.Delay(step.DelayMs,cts.Token).ConfigureAwait(false);
                previousWasMessage=step.Kind=="send";
            }
            Publish("Действие завершено.");
        }
        catch(OperationCanceledException) when(cts.IsCancellationRequested)
        {
            Publish("Действие отменено.");
            throw;
        }
        catch(Exception e)
        {
            Publish("Действие остановлено: " + e.Message);
            throw;
        }
        finally
        {
            lock(sync) {if(ReferenceEquals(active,cts))active=null;}
            cts.Dispose();
        }
    }
    public void Cancel() { lock(sync) active?.Cancel(); }
    private void Publish(string value)
    {
        foreach (var handler in StatusChanged?.GetInvocationList() ?? [])
            try { ((Action<string>)handler)(value); } catch { /* A UI observer cannot change delivery semantics. */ }
    }
    public void Dispose() {lock(sync){disposed=true;active?.Cancel();}}
}
