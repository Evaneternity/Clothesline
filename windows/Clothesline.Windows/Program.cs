using System;
using System.IO;
using System.Linq;
using System.Threading;
using System.Windows;
using Clothesline.Core;

namespace Clothesline.Windows;
internal static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "--self-test") return WindowsSelfTest.Run(args[1]);
        using var instance = new Mutex(true, "Local\\Clothesline.Windows", out var first);
        if (!first) return 0;
        try
        {
            var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
            var settingsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Clothesline", "settings.json");
            var settings = Settings.Load(settingsPath);
            var downloads = Native.Downloads();
            if (!settings.Folders.Contains(downloads, StringComparer.OrdinalIgnoreCase)) settings.Folders.Insert(0, downloads);
            var window = new RopeWindow(settings, () => settings.Save(settingsPath));
            app.DispatcherUnhandledException += (_, e) => { MessageBox.Show(e.Exception.Message, "Clothesline"); e.Handled = true; };
            app.Run(window);
            return 0;
        }
        catch (Exception e) { MessageBox.Show(e.Message, "Clothesline"); return 1; }
    }
}
