namespace Clothesline.Core;

public sealed record ReleaseVersion(Version Core, string[] Preview) : IComparable<ReleaseVersion>
{
    public static ReleaseVersion? Parse(string? tag)
    {
        if (tag is null || !tag.StartsWith("windows-v",StringComparison.Ordinal)) return null;
        var value=tag[9..].Split('+')[0].Split('-',2);
        if (!Version.TryParse(value[0],out var core) || value[0].Split('.').Length!=3) return null;
        var preview=value.Length==1 ? Array.Empty<string>() : value[1].Split('.');
        if (preview.Any(p=>p.Length==0 || p.Any(c=>!char.IsAsciiLetterOrDigit(c) && c!='-'))) return null;
        return new(core,preview);
    }
    public int CompareTo(ReleaseVersion? other)
    {
        if (other is null) return 1;
        var core=Core.CompareTo(other.Core); if (core!=0) return core;
        if (Preview.Length==0) return other.Preview.Length==0 ? 0 : 1;
        if (other.Preview.Length==0) return -1;
        for (var i=0;i<Math.Min(Preview.Length,other.Preview.Length);i++)
        {
            var a=Preview[i]; var b=other.Preview[i]; if (a==b) continue;
            var an=a.All(char.IsAsciiDigit); var bn=b.All(char.IsAsciiDigit);
            if (an && bn) { var length=a.TrimStart('0').Length.CompareTo(b.TrimStart('0').Length); return length!=0 ? length : string.CompareOrdinal(a.TrimStart('0'),b.TrimStart('0')); }
            if (an!=bn) return an ? -1 : 1;
            return string.CompareOrdinal(a,b);
        }
        return Preview.Length.CompareTo(other.Preview.Length);
    }
}
