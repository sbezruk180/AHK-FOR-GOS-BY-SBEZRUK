using System.Text;
using Gos.Windows;

internal static class ChatLogTests
{
    public static void Run(Action<bool, string> check)
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        var encoding = Encoding.GetEncoding(1251);
        var root = Path.Combine(Path.GetTempPath(), "GosChatLog-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            var path = Path.Combine(root, "chatlog.txt");
            var watcher = new ChatLogWatcher();
            const string first = "Вы начали преследование Test_Player[42]";
            const string second = "Вы начали преследование Next_Player[73]";
            // On Unix filesystems without birth-time, .NET may derive CreationTime from mtime.
            // Pin that fallback in the fixture; production is a Windows application with stable birth-time.
            void StabilizeUnixCreationTime() { if (!OperatingSystem.IsWindows()) File.SetLastWriteTimeUtc(path, DateTime.UnixEpoch); }
            void Append(string text) { File.AppendAllText(path, text, encoding); StabilizeUnixCreationTime(); }
            void Replace(string text) { File.WriteAllText(path, text, encoding); StabilizeUnixCreationTime(); }
            Replace(first + "\r\n");
            check(!watcher.Poll(path, "").Any(), "Chat log starts at tail without replaying historical actions");
            check(!watcher.Poll(path, "").Any(), "Unchanged chat log produces no events");
            Append(first);
            check(!watcher.Poll(path, "").Any(), "Partial chat line waits for newline");
            Append("\r\n" + second + "\n");
            var events = watcher.Poll(path, "").ToArray();
            check(events.Length == 2 && events[0].Id == 42 && events[1].Id == 73,
                "Chat log joins partial CP1251 lines and processes complete events once in order");
            check(!watcher.Poll(path, "").Any(), "Completed chat events are not replayed on idle poll");
            Append("Вы начали преследование Old_");
            watcher.Poll(path, "").ToArray();
            Replace("");
            check(!watcher.Poll(path, "").Any(), "Chat log truncation clears prior partial line");
            Append(second + "\n");
            check(watcher.Poll(path, "").Single().Id == 73, "New log after truncation starts without stale bytes");
            Append(new string('x', 65537));
            check(!watcher.Poll(path, "").Any(), "Chat log flood is bounded and skips stale batch");
            Append("\n" + first + "\n");
            check(watcher.Poll(path, "").Single().Id == 42, "Chat log recovers after bounded flood without replay");
            Append("Вы начали преследование Old_");
            watcher.Poll(path, "").ToArray();
            File.Delete(path);
            check(!watcher.Poll(path, "").Any(), "Deleted chat log clears watch state");
            Replace(second + "\n");
            check(!watcher.Poll(path, "").Any(), "Recreated chat log begins at new tail");
            Append(first + "\n");
            check(watcher.Poll(path, "").Single().Id == 42, "Recreated chat log emits only subsequent complete lines");
            watcher.Poll("", "").ToArray();
            check(!watcher.Poll(path, "").Any(), "Disabling and re-enabling log watch never replays old actions");
        }
        finally { Directory.Delete(root, true); }
    }
}
