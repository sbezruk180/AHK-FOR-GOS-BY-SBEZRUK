using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Gos.Core;

public sealed class ProfileStore
{
    private readonly string directory;
    public string FilePath => Path.Combine(directory,"settings.json");
    public string? Warning { get; private set; }
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented=true, PropertyNameCaseInsensitive=true, MaxDepth=32,
        Converters={new JsonStringEnumConverter()}
    };
    public ProfileStore(string dataDir) => directory=Path.GetFullPath(dataDir);
    public static AppSettings Copy(AppSettings value) => JsonSerializer.Deserialize<AppSettings>(JsonSerializer.Serialize(value,Options),Options)
        ?? throw new InvalidDataException("Настройки пусты.");
    public AppSettings Load()
    {
        Warning=null;
        if (!File.Exists(FilePath)) return new();
        try { return Read(FilePath); }
        catch (Exception e) when (e is JsonException or InvalidDataException)
        {
            var backup=FilePath+".bak";
            if (File.Exists(backup))
            {
                try {var previous=Read(backup); Warning="Повреждён файл настроек. Загружена предыдущая копия; исходный файл сохранён.";return previous;}
                catch(Exception second) when(second is JsonException or InvalidDataException) { }
            }
            throw new InvalidDataException("Не удалось прочитать настройки. Файл сохранён без изменений: " + FilePath,e);
        }
    }
    private static AppSettings Read(string path)
    {
        if(new FileInfo(path).Length>2*1024*1024)throw new InvalidDataException("Файл настроек превышает 2 МБ.");
        var value=JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(path,Encoding.UTF8),Options)
            ?? throw new InvalidDataException("Настройки пусты.");
        if(value.SchemaVersion>1) throw new NotSupportedException("Настройки созданы более новой версией приложения; исходный файл не будет заменён.");
        value.Normalize();return value;
    }
    public void Save(AppSettings settings)
    {
        var copy=Copy(settings);copy.Normalize();
        Directory.CreateDirectory(directory);
        var stage=FilePath+"."+Guid.NewGuid().ToString("N")+".tmp";
        try
        {
            using(var stream=new FileStream(stage,FileMode.CreateNew,FileAccess.Write,FileShare.None,4096,FileOptions.WriteThrough))
            {
                JsonSerializer.Serialize(stream,copy,Options);stream.Flush(true);
            }
            if (File.Exists(FilePath))
            {
                // Keep the previous VALID file, not an already corrupt primary, as recovery backup.
                try {Read(FilePath);File.Copy(FilePath,FilePath+".bak",true);}
                catch(Exception e) when(e is JsonException or InvalidDataException)
                {File.Copy(FilePath,FilePath+".corrupt-"+DateTime.UtcNow.ToString("yyyyMMddHHmmssfff")+"-"+Guid.NewGuid().ToString("N"),false);}
            }
            File.Move(stage,FilePath,true);
        }
        finally {if(File.Exists(stage))File.Delete(stage);}
    }
    public bool TryImportLegacy(string iniPath,AppSettings settings)
    {
        if(!File.Exists(iniPath))return false;
        if(new FileInfo(iniPath).Length>4*1024*1024)throw new InvalidDataException("INI превышает 4 МБ.");
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        var bytes=File.ReadAllBytes(iniPath);
        var encoding=bytes.Length>=3 && bytes[0]==0xEF && bytes[1]==0xBB && bytes[2]==0xBF ? Encoding.UTF8
            : bytes.Length>=2 && bytes[0]==0xFF && bytes[1]==0xFE ? Encoding.Unicode : Encoding.GetEncoding(1251);
        var ini=new Dictionary<string,Dictionary<string,string>>(StringComparer.OrdinalIgnoreCase);
        string section="";
        foreach(var raw in encoding.GetString(bytes).TrimStart('\uFEFF').Split('\n'))
        {
            var line=raw.Trim();if(line.Length==0||line[0] is ';' or '#')continue;
            if(line.StartsWith('[')&&line.EndsWith(']')){section=line[1..^1];if(!ini.ContainsKey(section))ini[section]=new(StringComparer.OrdinalIgnoreCase);continue;}
            var at=line.IndexOf('=');if(at<0||!ini.TryGetValue(section,out var values))continue;
            values[line[..at].Trim()]=line[(at+1)..].Trim();
        }
        string Get(string part,string key,string fallback="") => ini.TryGetValue(part,out var values)&&values.TryGetValue(key,out var text) ? DecodeLegacy(text) : fallback;
        var profile=Get("Profiles","Last","Основной");
        var selected="Profile_"+profile;
        if(!ini.ContainsKey(selected))selected=ini.Keys.FirstOrDefault(k=>k.StartsWith("Profile_",StringComparison.OrdinalIgnoreCase))??"";
        if(selected.Length==0)return false;
        var next=Copy(settings);
        next.Name=Get(selected,"Surname",next.Name);next.Rank=Get(selected,"Rank",next.Rank);
        if (!next.Rank.Contains("полиции",StringComparison.OrdinalIgnoreCase))next.Rank+=" полиции";
        next.IntroRole=Get(selected,"IntroRole",next.IntroRole);
        next.Department=Get(selected,"ProfileMode",Get("UI","ProfileMode",next.Department));
        next.ChatLogPath=Get("ChatLog","Path",next.ChatLogPath); next.ChatLogNickname=Get("ChatLog","PlayerNickname",next.ChatLogNickname);
        next.ExpectedModuleHash=Get("UI","AzmpExpectedSHA256",next.ExpectedModuleHash);
        next.HideFromCapture=Get("UI","OBSHideWindows",next.HideFromCapture ? "On":"Off").Equals("On",StringComparison.OrdinalIgnoreCase);
        foreach(var (key,iniKey) in new Dictionary<string,string>{{"intro","T_Intro"},{"rights","RP_Rights"},{"stop","RP_StopChase"},{"incar","RP_InCar"}})
        {
            var value=Get(selected,iniKey);
            if(value.Length>0)next.ActionTemplates[key]=value.Replace("{INTRO_ROLE}","{introRole}",StringComparison.OrdinalIgnoreCase)
                .Replace("{SURNAME}","{name}",StringComparison.OrdinalIgnoreCase).Replace("{RANK} полиции","{rank}",StringComparison.OrdinalIgnoreCase)
                .Replace("{RANK}","{rank}",StringComparison.OrdinalIgnoreCase).Replace("`n","\n",StringComparison.Ordinal)
                .Split(['\r','\n'],StringSplitOptions.RemoveEmptyEntries);
        }
        foreach(var (key,iniKey) in new Dictionary<string,string>{{"intro","Bind_Intro"},{"chase","Bind_Chase"},{"chase-id","Bind_ChaseID"},{"stop","Bind_StopChase"},{"cuff","Bind_Cuff"},{"deject","Bind_Deject"},{"incar","Bind_InCar"},{"sos","Bind_SOS"},{"rights","Bind_Rights"}})
        {
            var value=Get(selected,iniKey);if(value.Length>0 && value!="ERROR")next.Hotkeys[key]=ConvertLegacyHotkey(value);
        }
        next.Normalize();
        // Validation finishes before mutating the live settings object.
        settings.Name=next.Name;settings.Rank=next.Rank;settings.IntroRole=next.IntroRole;settings.Department=next.Department;
        settings.ChatLogPath=next.ChatLogPath;settings.ChatLogNickname=next.ChatLogNickname;settings.ExpectedModuleHash=next.ExpectedModuleHash;
        settings.HideFromCapture=next.HideFromCapture;settings.ActionTemplates=next.ActionTemplates;settings.Hotkeys=next.Hotkeys;
        return true;
    }
    private static string DecodeLegacy(string value)
    {
        if(!value.StartsWith("H1:",StringComparison.Ordinal))return value.Replace("{NL}","\n",StringComparison.Ordinal).Replace("{RAW_NL}","{NL}",StringComparison.Ordinal).Replace("{RAW2_NL}","{RAW_NL}",StringComparison.Ordinal);
        var parts=value.Split(':',3);
        if(parts.Length!=3 || !int.TryParse(parts[1],out var count) || count<0 || count>32768 || parts[2].Length!=count*2)
            throw new InvalidDataException("Повреждена длина H1 в старом INI.");
        try {return Encoding.GetEncoding(1251).GetString(Convert.FromHexString(parts[2]));}
        catch(FormatException e){throw new InvalidDataException("Повреждён H1 в старом INI.",e);}
    }
    private static string ConvertLegacyHotkey(string value)
    {
        var parts=new List<string>();
        if(value.Contains('^'))parts.Add("Ctrl");if(value.Contains('!'))parts.Add("Alt");if(value.Contains('+'))parts.Add("Shift");if(value.Contains('#'))parts.Add("Win");
        var key=value.TrimStart('^','!','+','#','~','$','*','<','>');
        const string ru="йцукенгшщзхъфывапролджэячсмитьбю";const string en="qwertyuiop[]asdfghjkl;'zxcvbnm,.";
        if(key.Length==1){var at=ru.IndexOf(char.ToLowerInvariant(key[0]));if(at>=0)key=en[at].ToString();}
        parts.Add(key.ToUpperInvariant());return string.Join('+',parts);
    }
}
