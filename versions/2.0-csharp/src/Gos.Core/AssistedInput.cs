using System.Threading.Channels;
namespace Gos.Core;
// Per-message bounded permits: rapid real presses are retained, repeats and the next message are isolated.
public sealed class AssistedInput
{
    readonly object sync=new();Channel<byte>? channel;
    public bool IsActive {get{lock(sync)return channel!=null;}}
    public void Begin(int characters)
    {
        if(characters is <1 or >240)throw new ArgumentOutOfRangeException(nameof(characters));
        lock(sync){channel?.Writer.TryComplete();channel=Channel.CreateBounded<byte>(new BoundedChannelOptions(characters){SingleReader=true,SingleWriter=false,FullMode=BoundedChannelFullMode.DropWrite});}
    }
    public bool Press(bool down,bool repeat)
    {lock(sync){if(channel==null)return false;if(down&&!repeat)channel.Writer.TryWrite(1);return true;}}
    public async Task WaitAsync(CancellationToken ct)
    {Channel<byte> current;lock(sync)current=channel??throw new InvalidOperationException("Ввод завершён.");await current.Reader.ReadAsync(ct).ConfigureAwait(false);}
    public void End(){lock(sync){channel?.Writer.TryComplete();channel=null;}}
}
