using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Windows.Threading;
using Clothesline.Core;
using Microsoft.Win32;
using Forms = System.Windows.Forms;

namespace Clothesline.Windows;
internal sealed partial class RopeWindow : Window
{
    private readonly Settings settings;
    private readonly Action save;
    private readonly FileIndex index = new();
    private readonly RopeState state = new();
    private readonly Dictionary<string, FileRecord> monitored = new(StringComparer.OrdinalIgnoreCase);
    private readonly Dictionary<string, string?> clipboardItems = new(StringComparer.OrdinalIgnoreCase);
    private readonly HashSet<string> clipboardHashes = new();
    private readonly List<FileSystemWatcher> watchers = [];
    private readonly Canvas surface = new();
    private readonly StackPanel cards = new() { Orientation = Orientation.Horizontal };
    private readonly List<Border> cardViews = [];
    private readonly DispatcherTimer scanTimer = new() { Interval = TimeSpan.FromSeconds(1) };
    private readonly DispatcherTimer pointerTimer = new() { Interval = TimeSpan.FromMilliseconds(100) };
    private Forms.NotifyIcon? tray;
    private bool busy, scanning, closing;
    private string signature = "", failure = "";
    private double scrollOffset;
    private uint clipboardSequence;
    private DateTime lastInside = DateTime.MinValue;
    private string? clipboardFolder;
    private const string OwnCopy = "Clothesline.OwnCopy";
    internal string T(string zh, string en) => settings.English ? en : zh;
    internal RopeWindow(Settings settings, Action save)
    {
        this.settings = settings; this.save = save;
        foreach (var pair in settings.Dismissed) state.Dismissed[pair.Key] = pair.Value;
        foreach (var path in settings.Pins) state.Pinned.Add(path);
        Title = "Clothesline"; Width = SystemParameters.WorkArea.Width; Height = 178;
        Left = SystemParameters.WorkArea.Left; Top = SystemParameters.WorkArea.Top;
        WindowStyle = WindowStyle.None; ResizeMode = ResizeMode.NoResize; AllowsTransparency = true;
        Background = Brushes.Transparent; Topmost = true; ShowInTaskbar = false; ShowActivated = false;
        Icon = BitmapFrame.Create(new Uri("pack://application:,,,/icon.png"));
        surface.ClipToBounds=true;
        surface.PreviewMouseWheel+=(_,e)=> { scrollOffset=Math.Clamp(scrollOffset-e.Delta,0,Math.Max(0,cards.Children.Count*140-Width+20)); Canvas.SetLeft(cards,10-scrollOffset); e.Handled=true; };
        Content = surface; surface.Children.Add(cards); Canvas.SetTop(cards, 18);
        AllowDrop = true;
        PreviewDragOver += (_, e) => { e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None; e.Handled = true; };
        Drop += (_, e) => { if (e.Data.GetData(DataFormats.FileDrop) is string[] paths) Guard(() => Attach(paths)); e.Handled = true; };
        Loaded += (_, _) => Start();
        Closed += (_, _) => { closing = true; scanTimer.Stop(); pointerTimer.Stop(); foreach (var watcher in watchers) watcher.Dispose(); tray?.Dispose(); ClearClipboard(false); Application.Current.Shutdown(); };
    }
    private void Start()
    {
        clipboardSequence = Native.GetClipboardSequenceNumber();
        tray = new Forms.NotifyIcon { Text = "Clothesline", Icon = System.Drawing.Icon.ExtractAssociatedIcon(Environment.ProcessPath!), Visible = true };
        var menu = new Forms.ContextMenuStrip(); menu.Opening += (_, _) => BuildTray(menu); tray.ContextMenuStrip = menu;
        tray.DoubleClick += (_, _) => { settings.AlwaysVisible = !settings.AlwaysVisible; Persist(); };
        RebuildWatchers();
        scanTimer.Tick += async (_, _) => { await Scan(); PollClipboard(); };
        pointerTimer.Tick += (_, _) => PollPointer();
        scanTimer.Start(); pointerTimer.Start(); _ = Scan();
    }
    private void RebuildWatchers()
    {
        foreach (var watcher in watchers) watcher.Dispose(); watchers.Clear();
        foreach (var folder in settings.Folders)
        {
            try
            {
                var watcher = new FileSystemWatcher(folder) { IncludeSubdirectories = false, NotifyFilter = NotifyFilters.FileName | NotifyFilters.DirectoryName | NotifyFilters.LastWrite | NotifyFilters.Size };
                FileSystemEventHandler changed = (_, _) => Dispatcher.BeginInvoke(new Action(() => { if (!closing) _ = Scan(); }));
                watcher.Changed += changed; watcher.Created += changed; watcher.Deleted += changed;
                watcher.Renamed += (_, _) => Dispatcher.BeginInvoke(new Action(() => { if (!closing) _ = Scan(); }));
                watcher.Error += (_, _) => Dispatcher.BeginInvoke(new Action(() => { if (!closing) _ = Scan(); }));
                watcher.EnableRaisingEvents = true; watchers.Add(watcher);
            }
            catch (Exception e) { failure = folder + ": " + e.Message; }
        }
    }
    private async Task Scan()
    {
        if (scanning || closing) return;
        scanning = true;
        try
        {
            var folders = settings.Folders.ToArray();
            var result = await Task.Run(() => { var files = index.Scan(folders, DateTime.UtcNow, out var errors); return (files, errors); });
            if (closing) return;
            if (busy) return; // Never replace a drag source or a card with an open menu.
            failure = string.Join("\n", result.errors);
            // Preserve last records when a watched folder is inaccessible, rather than treating it as empty.
            if (result.errors.Count == 0) monitored.Clear();
            foreach (var file in result.files) monitored[file.Path] = file;
            foreach (var key in monitored.Keys.Where(p => FileRecord.Read(p) is null).ToArray())
                if (!state.Pinned.Contains(key)) monitored.Remove(key);
            var recent = result.files.Select(f => f.Path).Concat(settings.Recent).Distinct(StringComparer.OrdinalIgnoreCase).Take(200).ToList();
            if (!recent.SequenceEqual(settings.Recent)) { settings.Recent = recent; Persist(); }
            Render();
        }
        catch (Exception e) { failure = e.Message; }
        finally { scanning = false; }
    }
    private List<FileRecord> Records()
    {
        var records = new Dictionary<string, FileRecord>(monitored, StringComparer.OrdinalIgnoreCase);
        foreach (var path in settings.Attached.Concat(state.Pinned).Concat(clipboardItems.Keys))
        {
            var fresh = FileRecord.Read(path);
            if (fresh is not null) records[path] = fresh;
            else if (state.Pinned.Contains(path) && settings.PinSnapshots.FirstOrDefault(f => string.Equals(f.Path, path, StringComparison.OrdinalIgnoreCase)) is {} old) records[path] = old;
        }
        return records.Values.ToList();
    }
    private void Persist()
    {
        settings.Dismissed = state.Dismissed.Where(p=>!clipboardItems.ContainsKey(p.Key)).ToDictionary(p=>p.Key,p=>p.Value,StringComparer.OrdinalIgnoreCase); settings.Pins = state.Pinned.ToList();
        settings.PinSnapshots = state.Pinned.Select(p => FileRecord.Read(p) ?? settings.PinSnapshots.FirstOrDefault(f => string.Equals(f.Path,p,StringComparison.OrdinalIgnoreCase))).OfType<FileRecord>().ToList();
        try { save(); } catch (Exception e) { failure = e.Message; }
    }
    private void Attach(IEnumerable<string> paths)
    {
        foreach (var path in paths)
        {
            var file = FileRecord.Read(path); if (file is null) continue;
            if (!settings.Attached.Contains(file.Path, StringComparer.OrdinalIgnoreCase)) settings.Attached.Insert(0, file.Path);
            state.Dismissed.Remove(file.Path);
            settings.Recent.RemoveAll(p=>string.Equals(p,file.Path,StringComparison.OrdinalIgnoreCase)); settings.Recent.Insert(0,file.Path);
            settings.Recent=settings.Recent.Take(200).ToList();
        }
        Persist(); signature = ""; Render();
    }
    private void Render()
    {
        if (busy) return;
        var files = state.Select(Records(), settings.Capacity);
        var key = settings.English + ":" + Width + string.Join("|", files.Select(f => f.Path + f.Fingerprint + state.Pinned.Contains(f.Path) + (FileRecord.Read(f.Path) is null))) + clipboardItems.Count;
        if (signature == key) return; signature = key;
        cards.Children.Clear(); cardViews.Clear();
        foreach (var file in files) cards.Children.Add(CreateCard(file, cards.Children.Count));
        for (var i = surface.Children.Count - 1; i >= 0; i--) if (surface.Children[i] != cards) surface.Children.RemoveAt(i);
        var rope = new System.Windows.Shapes.Path { Stroke = new SolidColorBrush(Color.FromRgb(165,182,195)), StrokeThickness = 2,
            Data = new PathGeometry([new PathFigure(new Point(0,10), [new QuadraticBezierSegment(new Point(Width/2,32),new Point(Width,10),true)],false)]) };
        surface.Children.Insert(0, rope);
        // Wheel scrolling keeps overflow and pinned cards reachable.
        cards.Width = double.NaN;
        Canvas.SetLeft(cards, 10-scrollOffset);
    }
    private UIElement CreateCard(FileRecord file, int position)
    {
        var stack = new StackPanel { Width = 130, Margin = new Thickness(5,0,5,12) };
        var colors = new[] { "#EF5B66", "#F5A623", "#52B77A", "#469EE0", "#9D75D5", "#E77AB0" };
        stack.Children.Add(new Border { Width=8, Height=23, CornerRadius=new CornerRadius(3), Background=(Brush)new BrushConverter().ConvertFromString(colors[position%colors.Length])!, Margin=new Thickness(0,0,0,-7) });
        var body = new StackPanel();
        var missing = FileRecord.Read(file.Path) is null;
        if (clipboardItems.TryGetValue(file.Path,out var note) && note is not null)
            body.Children.Add(new TextBlock { Text=note, TextWrapping=TextWrapping.Wrap, Height=80, Margin=new Thickness(5), Background=new SolidColorBrush(Color.FromRgb(255,248,215)) });
        else body.Children.Add(new Image { Source=Native.Thumbnail(file.Path), Width=106, Height=85, Stretch=Stretch.Uniform });
        body.Children.Add(new TextBlock { Text=note is not null ? T("文字便签","Text Note") : file.Name, TextTrimming=TextTrimming.CharacterEllipsis, FontSize=10, TextAlignment=TextAlignment.Center, Margin=new Thickness(3) });
        if (missing || state.Pinned.Contains(file.Path)) body.Children.Add(new TextBlock { Text=missing ? T("文件失效","Unavailable") : T("已固定","Pinned"), FontSize=10, Foreground=missing ? Brushes.Firebrick : Brushes.SlateGray, TextAlignment=TextAlignment.Center });
        var card = new Border { Child=body, Background=new SolidColorBrush(Color.FromArgb(245,248,249,250)), CornerRadius=new CornerRadius(12), Padding=new Thickness(7),
            Effect=new DropShadowEffect { BlurRadius=12, ShadowDepth=4, Opacity=.2 } };
        var name = note is not null ? T("文字便签","Text Note") : file.Name;
        card.ToolTip = name + "\n" + (clipboardItems.ContainsKey(file.Path) ? T("剪贴板（本次会话）","Clipboard (this session)") : System.IO.Path.GetDirectoryName(file.Path)) +
            "\n" + (file.IsDirectory ? T("文件夹（不递归计算大小）","Folder (contents not counted)") : $"{file.Size:N0} bytes") + "\n" + T("创建：","Created: ") + file.Created.ToLocalTime() + "\n" + T("修改：","Modified: ") + file.Modified.ToLocalTime() + (missing ? "\n" + T("源文件不存在或无法访问","Original is missing or inaccessible") : "");
        ToolTipService.SetInitialShowDelay(card,400); ToolTipService.SetShowDuration(card,30000);
        Point down = new(); bool pressed = false;
        card.MouseLeftButtonDown += (_,e) => { down=e.GetPosition(card); pressed=true; if (e.ClickCount==2) { pressed=false; Guard(()=>Open(file)); } };
        card.MouseLeftButtonUp += (_,_) => pressed=false;
        card.MouseMove += (_,e) => {
            if (!pressed || e.LeftButton!=MouseButtonState.Pressed) return;
            var here=e.GetPosition(card); if ((here-down).Length<6) return;
            pressed=false;
            Guard(()=> { Validate(file); busy=true; Native.ClickThrough(this,false); try { DragDrop.DoDragDrop(card,FilePayload(file.Path),DragDropEffects.Copy); } finally { busy=false; } });
        };
        card.ContextMenu = CardMenu(file);
        card.ContextMenuOpening += (_,_) => busy=true;
        card.ContextMenuClosing += (_,_) => { busy=false; signature=""; Dispatcher.BeginInvoke(new Action(Render)); };
        cardViews.Add(card); stack.Children.Add(card); return stack;
    }
    internal static DataObject FilePayload(string path) => new(DataFormats.FileDrop, new[] { path });
    private void Validate(FileRecord file)
    { if (FileRecord.Read(file.Path) is null) throw new IOException(T("源文件不存在或无法访问。","The original file is missing or inaccessible.")); }
    private void Open(FileRecord file)
    { Validate(file); if (clipboardItems.TryGetValue(file.Path,out var note) && note is not null) EditNote(file.Path,note); else Native.Open(file.Path); }
    private void Guard(Action action) { try { action(); } catch (Exception e) { MessageBox.Show(e.Message,"Clothesline"); } }
    private void PollPointer()
    {
        if (busy) return;
        var local = PointFromScreen(Native.Cursor);
        var overCard = Height>8 && local.X>=0 && local.X<=Width && local.Y>=0 && local.Y<=Height && cardViews.Any(v => { var p=v.TranslatePoint(new Point(),this); return new Rect(p,v.RenderSize).Contains(local); });
        var nearTop = local.X>=0 && local.X<=Width && local.Y>=0 && local.Y<=8;
        if (nearTop || overCard) lastInside=DateTime.UtcNow;
        var reveal=settings.AlwaysVisible || DateTime.UtcNow-lastInside<TimeSpan.FromMilliseconds(800);
        Height=reveal ? 178 : 8;
        Native.ClickThrough(this, !reveal || (!overCard && !Native.MousePressed));
    }
    private void ClearClipboard(bool refresh=true)
    {
        foreach (var path in clipboardItems.Keys) { state.Dismissed.Remove(path); state.Pinned.Remove(path); }
        clipboardItems.Clear(); clipboardHashes.Clear();
        if (clipboardFolder is not null) { try { Directory.Delete(clipboardFolder,true); } catch { } clipboardFolder=null; }
        if (refresh) { signature=""; Persist(); Render(); }
    }
    private void PollClipboard()
    {
        if (!settings.ClipboardImages && !settings.ClipboardText) { clipboardSequence=Native.GetClipboardSequenceNumber(); return; }
        var sequence=Native.GetClipboardSequenceNumber(); if (sequence==clipboardSequence) return;
        try
        {
            if (Clipboard.ContainsData(OwnCopy) || Clipboard.ContainsFileDropList()) { clipboardSequence=sequence; return; }
            byte[]? bytes=null; string? note=null; string extension=".png";
            if (settings.ClipboardImages && Clipboard.ContainsImage())
            {
                var bitmap=Clipboard.GetImage(); if (bitmap is null || (long)bitmap.PixelWidth*bitmap.PixelHeight>32000000) { clipboardSequence=sequence; return; }
                var encoder=new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap));
                using var stream=new MemoryStream(); encoder.Save(stream); bytes=stream.ToArray();
                if (bytes.Length>32000000) { clipboardSequence=sequence; return; }
            }
            else if (settings.ClipboardText && !Clipboard.ContainsImage() && Clipboard.ContainsText())
            { note=Clipboard.GetText(); bytes=Encoding.UTF8.GetBytes(note); extension=".txt"; if (string.IsNullOrWhiteSpace(note) || bytes.Length>200000) { clipboardSequence=sequence; return; } }
            if (bytes is null) { clipboardSequence=sequence; return; }
            var hash=extension+Convert.ToHexString(SHA256.HashData(bytes));
            if (clipboardHashes.Contains(hash) || clipboardItems.Count>=100) { clipboardSequence=sequence; return; }
            clipboardFolder ??= System.IO.Path.Combine(System.IO.Path.GetTempPath(),"Clothesline-Clipboard-"+Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(clipboardFolder);
            var path=System.IO.Path.Combine(clipboardFolder,Guid.NewGuid()+extension); File.WriteAllBytes(path,bytes);
            clipboardItems[path]=note; clipboardHashes.Add(hash); clipboardSequence=sequence; signature=""; Render();
        }
        catch (ExternalException) { } // Retry the same sequence if another app temporarily owns the clipboard.
        catch (Exception e) { clipboardSequence=sequence; failure=e.Message; }
    }
}
