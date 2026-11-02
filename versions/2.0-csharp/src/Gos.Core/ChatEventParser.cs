using System.Text.RegularExpressions;
namespace Gos.Core;
public sealed record DetectedTarget(string Kind, int Id, string Name);
public static partial class ChatEventParser
{
    [GeneratedRegex(@"\[(\d{1,6})\]", RegexOptions.CultureInvariant)] private static partial Regex Ids();
    [GeneratedRegex(@"\bID\s*[:#]?\s*(\d{1,6})", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)] private static partial Regex LabelledIds();
    [GeneratedRegex(@"\b[A-Za-z]{2,}_[A-Za-z_]{2,}\b", RegexOptions.CultureInvariant)] private static partial Regex Names();
    public static DetectedTarget? Parse(string line, string ownNickname)
    {
        string lower=line.ToLowerInvariant();
        line=Regex.Replace(line,@"\{[0-9A-Fa-f]{6,8}\}","").Trim();
        line=Regex.Replace(line,@"^\[\d{1,2}:\d{2}(?::\d{2})?\]\s*","");
        lower=line.ToLowerInvariant();
        bool own=lower.StartsWith("вы ",StringComparison.Ordinal) || (!string.IsNullOrWhiteSpace(ownNickname) && Regex.IsMatch(line,
            "^"+Regex.Escape(ownNickname)+@"\s*\[\d{1,6}\]\s+(?:начал|начала|оглушил|оглушила|спасает|спас|спасла|узнал|узнала)\b",RegexOptions.IgnoreCase));
        if (!own) return null;
        string? kind=lower.Contains("преследован")?"chase":lower.Contains("спасать игрока")||lower.Contains("вы спасли")?"revive":lower.Contains("вы оглушили")?"stun":lower.Contains("местополож")?"lookup":null;
        if(kind==null) return null;
        var ids=Ids().Matches(line).Select(m=>int.Parse(m.Groups[1].Value)).ToArray();
        if(ids.Length==0) ids=LabelledIds().Matches(line).Select(m=>int.Parse(m.Groups[1].Value)).ToArray();
        if(ids.Length==0) return null; // A nickname alone is not proof of an ID.
        int id=ids.Length>1?ids[1]:ids[0];
        if(id is <0 or >1003) return null;
        var names=Names().Matches(line).Select(m=>m.Value).Where(n=>!n.Equals(ownNickname,StringComparison.OrdinalIgnoreCase)).ToArray();
        return new(kind,id,names.LastOrDefault()??"");
    }
}
