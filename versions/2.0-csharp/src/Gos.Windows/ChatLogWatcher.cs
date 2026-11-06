using System.Buffers;
using System.Text;
using Gos.Core;
namespace Gos.Windows;
// Reads only newly appended bytes. A partial final line is retained, never replayed.
public sealed class ChatLogWatcher
{
    private const int MaxBatchBytes = 65536;
    private static readonly Encoding Cp1251 = CreateEncoding();
    private string path = "", partial = "";
    private long position;
    private DateTime creation;

    private static Encoding CreateEncoding()
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        return Encoding.GetEncoding(1251);
    }

    public IEnumerable<DetectedTarget> Poll(string requestedPath, string ownName)
    {
        if (string.IsNullOrWhiteSpace(requestedPath)) { Reset(); return []; }
        var file = new FileInfo(requestedPath);
        if (!file.Exists) { Reset(); return []; }
        if (path != requestedPath || file.CreationTimeUtc != creation || file.Length < position)
        {
            path = requestedPath; creation = file.CreationTimeUtc;
            position = file.Length; partial = ""; return [];
        }
        // Idle polls only inspect metadata: no open stream, read buffer or line parser.
        if (file.Length == position) return [];
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        var available = stream.Length - position;
        // Recheck after opening: the game can truncate the log between metadata and open.
        // Drop stale partial rather than pairing bytes from unrelated log generations.
        if (available < 0 || available > MaxBatchBytes)
        { position = stream.Length; partial = ""; return []; }
        if (available == 0) return [];
        stream.Position = position;
        var bytes = ArrayPool<byte>.Shared.Rent((int)available);
        try
        {
            int count = stream.Read(bytes, 0, (int)available);
            position += count;
            if (count == 0) return [];
            partial += Cp1251.GetString(bytes, 0, count);
        }
        finally { ArrayPool<byte>.Shared.Return(bytes, clearArray: true); }
        var lines = partial.Split('\n');
        partial = lines[^1];
        if (partial.Length > 4096) partial = "";
        return lines.SkipLast(1).Select(line => ChatEventParser.Parse(line.TrimEnd('\r'), ownName))
            .OfType<DetectedTarget>().ToArray();
    }

    private void Reset() { path = ""; position = 0; partial = ""; creation = default; }
}
