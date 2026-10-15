using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;

namespace Clothesline.Windows;
internal static class Native
{
    [DllImport("shell32.dll")] private static extern int SHGetKnownFolderPath(in Guid id, uint flags, IntPtr token, out IntPtr path);
    [DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out PointNative point);
    [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW")] private static extern IntPtr GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll", EntryPoint="SetWindowLongPtrW")] private static extern IntPtr SetWindowLong(IntPtr hwnd, int index, IntPtr value);
    [DllImport("shell32.dll", CharSet=CharSet.Unicode)] private static extern IntPtr SHGetFileInfo(string path, uint attributes, ref ShellInfo info, uint size, uint flags);
    [DllImport("user32.dll")] private static extern bool DestroyIcon(IntPtr icon);
    [StructLayout(LayoutKind.Sequential)] private struct PointNative { public int X, Y; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] private struct ShellInfo
    {
        public IntPtr Icon; public int Index; public uint Attributes;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string DisplayName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=80)] public string TypeName;
    }
    public static string Downloads()
    {
        var id = new Guid("374DE290-123F-4565-9164-39C4925E467B");
        if (SHGetKnownFolderPath(id, 0, IntPtr.Zero, out var ptr) == 0)
        { try { return Marshal.PtrToStringUni(ptr)!; } finally { Marshal.FreeCoTaskMem(ptr); } }
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
    }
    public static Point Cursor { get { GetCursorPos(out var p); return new Point(p.X,p.Y); } }
    public static bool MousePressed => GetAsyncKeyState(1) < 0;
    public static void ClickThrough(Window window, bool enabled)
    {
        var hwnd = new WindowInteropHelper(window).Handle;
        if (hwnd == IntPtr.Zero) return;
        var old = GetWindowLong(hwnd, -20).ToInt64();
        var value = enabled ? old | 0x20 : old & ~0x20;
        if (old != value) SetWindowLong(hwnd, -20, new IntPtr(value));
    }
    public static void Open(string path) => Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
    public static void Reveal(string path) => Process.Start(new ProcessStartInfo("explorer.exe", "/select,\"" + path + "\"") { UseShellExecute = true });
    public static BitmapSource ReadImage(string path)
    {
        using var stream=File.OpenRead(path);
        var image=BitmapFrame.Create(stream,BitmapCreateOptions.PreservePixelFormat,BitmapCacheOption.OnLoad);
        image.Freeze(); return image;
    }
    public static ImageSource? Thumbnail(string path)
    {
        var extension = Path.GetExtension(path).ToLowerInvariant();
        if (extension is ".png" or ".jpg" or ".jpeg" or ".bmp" or ".gif")
        {
            try
            {
                var image = new BitmapImage(); image.BeginInit(); image.CacheOption = BitmapCacheOption.OnLoad;
                image.DecodePixelWidth = 240; image.UriSource = new Uri(path); image.EndInit(); image.Freeze(); return image;
            } catch { }
        }
        var shell = new ShellInfo();
        if (SHGetFileInfo(path, 0, ref shell, (uint)Marshal.SizeOf<ShellInfo>(), 0x100) == IntPtr.Zero) return null;
        try { var bitmap = Imaging.CreateBitmapSourceFromHIcon(shell.Icon, Int32Rect.Empty, BitmapSizeOptions.FromEmptyOptions()); bitmap.Freeze(); return bitmap; }
        finally { if (shell.Icon != IntPtr.Zero) DestroyIcon(shell.Icon); }
    }
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private static string StartupCommand => "\"" + Environment.ProcessPath + "\"";
    public static bool LaunchAtLogin
    {
        get { using var key = Registry.CurrentUser.OpenSubKey(RunKey); return string.Equals(key?.GetValue("Clothesline") as string, StartupCommand, StringComparison.OrdinalIgnoreCase); }
        set
        {
            using var key = Registry.CurrentUser.CreateSubKey(RunKey);
            if (value) key.SetValue("Clothesline", StartupCommand);
            else if (string.Equals(key.GetValue("Clothesline") as string, StartupCommand, StringComparison.OrdinalIgnoreCase)) key.DeleteValue("Clothesline", false);
        }
    }
}
