using System.Text.Json;
namespace Clothesline.Core;

public sealed class Settings
{
    public List<string> Folders { get; set; } = [];
    public List<string> Attached { get; set; } = [];
    public List<string> Recent { get; set; } = [];
    public List<string> Pins { get; set; } = [];
    public List<FileRecord> PinSnapshots { get; set; } = [];
    public Dictionary<string, string> Dismissed { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public bool AlwaysVisible { get; set; }
    public bool ClipboardImages { get; set; }
    public bool ClipboardText { get; set; }
    public bool English { get; set; } = !System.Globalization.CultureInfo.CurrentUICulture.Name.StartsWith("zh");
    public int Capacity { get; set; } = 8;
    public static Settings Load(string path)
    {
        if (!File.Exists(path)) return new();
        try
        {
            var value = JsonSerializer.Deserialize<Settings>(File.ReadAllText(path)) ?? throw new JsonException();
            if (value.Folders is null || value.Attached is null || value.Recent is null || value.Pins is null || value.PinSnapshots is null || value.Dismissed is null) throw new JsonException();
            value.Dismissed = new(value.Dismissed, StringComparer.OrdinalIgnoreCase);
            value.Capacity = Math.Clamp(value.Capacity, 3, 50);
            return value;
        }
        catch (JsonException)
        {
            // Preserve damaged preferences before creating a replacement. Never touch source files.
            File.Copy(path, path + ".invalid-" + Guid.NewGuid().ToString("N"));
            return new();
        }
    }
    public void Save(string path)
    {
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path)!);
        var temporary = path + ".new";
        File.WriteAllText(temporary, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        File.Move(temporary, path, true);
    }
}
