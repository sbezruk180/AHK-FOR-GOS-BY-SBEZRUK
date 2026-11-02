using System.Text;
using Gos.Core;
namespace Gos.Windows;
// Reads only newly appended bytes. A partial final line is retained, never replayed.
public sealed class ChatLogWatcher
{
    string path="",partial=""; long position; DateTime creation;
    public IEnumerable<DetectedTarget> Poll(string requestedPath,string ownName)
    {
        if(string.IsNullOrWhiteSpace(requestedPath)) {path="";position=0;partial="";return [];}
        var file=new FileInfo(requestedPath);
        if(!file.Exists) return [];
        if(path!=requestedPath || file.CreationTimeUtc!=creation || file.Length<position)
        { path=requestedPath;creation=file.CreationTimeUtc;position=file.Length;partial="";return []; }
        using var stream=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete);
        // Bound work after a flood. Drop stale partial instead of pairing unrelated bytes.
        if(stream.Length-position>65536) {position=stream.Length;partial="";return [];}
        stream.Position=position;
        byte[] bytes=new byte[(int)(stream.Length-position)]; int count=stream.Read(bytes);position+=count;
        partial+=Encoding.GetEncoding(1251).GetString(bytes,0,count);
        var lines=partial.Split('\n');partial=lines[^1]; if(partial.Length>4096)partial="";
        return lines.SkipLast(1).Select(l=>ChatEventParser.Parse(l.TrimEnd('\r'),ownName)).OfType<DetectedTarget>().ToArray();
    }
}
