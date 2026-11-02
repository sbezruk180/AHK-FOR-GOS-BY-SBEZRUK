using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;

namespace Gos.Core;
public sealed record LawDocument(string Key,string Name,string Text);
public sealed record LawHit(string Document,string Text);
public sealed class LawLibrary
{
    private static readonly Dictionary<string,string> Names=new(StringComparer.OrdinalIgnoreCase)
    {
        ["ARG"]="Административный регламент",["FP"]="Федеральное постановление",["FSB"]="Закон о ФСБ",["FSIN"]="Закон о ФСИН",
        ["FZOP"]="Закон о полиции",["GT"]="Государственная тайна",["KAS"]="Кодекс административного судопроизводства",
        ["KOAP"]="Кодекс об административных правонарушениях",["KON"]="Конституция",["ORD"]="Оперативно-розыскная деятельность",
        ["ORUZH"]="Закон об оружии",["PDD"]="Правила дорожного движения",["SUD"]="Судоустройство",["TER"]="Территории",
        ["TK"]="Трудовой кодекс",["UK"]="Уголовный кодекс",["UPK"]="Уголовно-процессуальный кодекс",["VS"]="Закон о военной службе",
        ["VU"]="Воинский устав",["VV"]="Внутренние войска"
    };
    private static readonly Dictionary<string,string> Aliases=new(StringComparer.OrdinalIgnoreCase)
    { ["ук"]="UK",["коап"]="KOAP",["пдд"]="PDD",["упк"]="UPK",["тк"]="TK",["фзоп"]="FZOP",["конституция"]="KON",["фсб"]="FSB",["фсин"]="FSIN",["кас"]="KAS" };
    public IReadOnlyList<LawDocument> Documents {get;}
    public LawLibrary()
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        var documents=new List<LawDocument>();var assembly=typeof(LawLibrary).Assembly;
        foreach(var (key,name) in Names)
        {
            using var stream=assembly.GetManifestResourceStream("Gos.Laws."+key+".txt")??throw new InvalidDataException("Не встроен документ: "+key);
            using var reader=new StreamReader(stream,Encoding.GetEncoding(1251),true);
            var text=reader.ReadToEnd();if(string.IsNullOrWhiteSpace(text))throw new InvalidDataException("Пустой документ: "+key);
            documents.Add(new(key,name,text));
        }
        Documents=documents.AsReadOnly();
    }
    public IReadOnlyList<LawHit> Search(string query)
    {
        query=(query??"").Trim();if(query.Length==0)return [];
        if(query.Length>200)throw new ArgumentException("Поисковый запрос не длиннее 200 символов.",nameof(query));
        var terms=Normalize(query).Split(' ',StringSplitOptions.RemoveEmptyEntries);string? documentKey=null;
        if(terms.Length>0)
        {
            if(Aliases.TryGetValue(terms[0],out var alias))documentKey=alias;
            else if(Names.ContainsKey(terms[0]))documentKey=terms[0];
            if(documentKey is not null)terms=terms.Skip(1).ToArray();
        }
        var hits=new List<LawHit>();
        foreach(var doc in Documents.Where(x=>documentKey is null||x.Key.Equals(documentKey,StringComparison.OrdinalIgnoreCase)))
        {
            var lines=doc.Text.Split('\n');
            for(var i=0;i<lines.Length;i++)
            {
                var line=lines[i].Trim();if(line.Length==0)continue;
                if(!terms.All(t=>Normalize(line).Contains(t,StringComparison.Ordinal)))continue;
                var excerpt=line.Length<=1200?line:line[..1200]+"…";
                hits.Add(new(doc.Name+" ("+doc.Key+")",excerpt));
                if(hits.Count>=100)return hits;
            }
        }
        return hits;
    }
    private static string Normalize(string value)=>Regex.Replace(value.ToLowerInvariant().Replace('ё','е'),"\\s+"," ");
}
