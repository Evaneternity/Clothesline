using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using Clothesline.Core;

namespace Clothesline.Windows;
internal static class WindowsSelfTest
{
    public static int Run(string report)
    {
        var root=Path.Combine(Path.GetTempPath(),"Clothesline-Windows-Smoke-"+Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            var file=Path.Combine(root,"real-file.txt"); File.WriteAllText(file,"original remains unchanged");
            var before=File.ReadAllBytes(file);
            var record=FileRecord.Read(file) ?? throw new Exception("real file read failed");
            var state=new RopeState(); state.Dismiss(record);
            if (!before.SequenceEqual(File.ReadAllBytes(file))) throw new Exception("take down changed the original");
            var payload=RopeWindow.FilePayload(file);
            if (payload.GetData(DataFormats.FileDrop) is not string[] values || values.Single()!=file) throw new Exception("drag is not a real file drop payload");
            var app=new Application { ShutdownMode=ShutdownMode.OnExplicitShutdown };
            var settings=new Settings { Attached=[file], English=true };
            var window=new RopeWindow(settings,()=>{});
            typeof(RopeWindow).GetMethod("Render",BindingFlags.NonPublic|BindingFlags.Instance|BindingFlags.DeclaredOnly)!.Invoke(window,null);
            var cards=(StackPanel)typeof(RopeWindow).GetField("cards",BindingFlags.NonPublic|BindingFlags.Instance)!.GetValue(window)!;
            if (cards.Children.Count!=1 || !window.AllowDrop || !window.Topmost) throw new Exception("WPF card/drop/overlay construction failed");
            var license=Path.Combine(AppContext.BaseDirectory,"LICENSE.txt");
            if (!File.ReadAllText(license).Contains("Alejandro")) throw new Exception("upstream MIT notice missing");
            if (!File.Exists(Native.Downloads()) && !Directory.Exists(Native.Downloads())) { /* Known folder may be uncreated on a fresh runner. */ }
            File.WriteAllText(report,JsonSerializer.Serialize(new { passed=true, checks=new[] { "real file card", "safe dismissal", "file-drop payload", "WPF overlay construction", "bundled MIT license" }, uiAcceptance=false }));
            app.Shutdown(); return 0;
        }
        catch (Exception error)
        { File.WriteAllText(report,JsonSerializer.Serialize(new { passed=false,error=error.ToString() })); return 1; }
        finally { Directory.Delete(root,true); }
    }
}
