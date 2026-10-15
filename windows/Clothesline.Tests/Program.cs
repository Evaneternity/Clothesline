using Clothesline.Core;

var root=Path.Combine(Path.GetTempPath(),"Clothesline-Core-Tests-"+Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(root);
void Check(bool ok,string message) { if (!ok) throw new Exception(message); }
try
{
    var now=DateTime.UtcNow;
    var file=Path.Combine(root,"download.txt"); var partial=file+".crdownload";
    File.WriteAllText(partial,"fixture bytes"); File.SetLastWriteTimeUtc(partial,now.AddSeconds(-5));
    var index=new FileIndex();
    Check(index.Scan([root],now,out _).Count==0,"partial must not be displayed");
    File.Move(partial,file);
    Check(index.Scan([root],now,out _).Count==0,"first sample is not completion");
    var stable=index.Scan([root],now.AddSeconds(3),out _);
    Check(stable.Count==1,"stable real file must be displayed");
    File.AppendAllText(file,"updated");
    Check(index.Scan([root],now.AddSeconds(4),out _).Count==0,"size change resets completion");
    var record=FileRecord.Read(file)!; var bytes=File.ReadAllBytes(file);
    var state=new RopeState(); state.Dismiss(record);
    Check(state.Select([record],8).Count==0,"dismissal must hide a matching fingerprint");
    Check(bytes.SequenceEqual(File.ReadAllBytes(file)),"dismissal must preserve original bytes");
    state.Pinned.Add(record.Path); state.Dismissed.Clear();
    var other=Path.Combine(root,"newer.txt"); File.WriteAllText(other,"other");
    var second=FileRecord.Read(other)!;
    Check(state.Select([second,record],1).Single().Path==record.Path,"pin survives capacity pressure");
    var renamed=RopeState.Rename(record,"renamed");
    Check(Path.GetExtension(renamed)==".txt" && bytes.SequenceEqual(File.ReadAllBytes(renamed)),"rename preserves extension and bytes");
    try { RopeState.Rename(FileRecord.Read(renamed)!,"newer"); throw new Exception("collision should fail"); } catch (IOException) {}
    var stale=FileRecord.Read(renamed)!; File.AppendAllText(renamed,"changed");
    try { RopeState.Rename(stale,"bad"); throw new Exception("stale rename should fail"); } catch (IOException) {}
    var folder=Path.Combine(root,"folder"); Directory.CreateDirectory(folder); File.WriteAllText(Path.Combine(folder,"child.txt"),"child");
    var dir=FileRecord.Read(folder)!; state.Dismiss(dir);
    Check(File.ReadAllText(Path.Combine(folder,"child.txt"))=="child","directory dismissal preserves contents");
    foreach (var temporary in new[] { ".hidden","a.PART","a.download","~$lock.docx","a.tmp" }) Check(!FileIndex.IsCandidate(temporary),"temporary filter "+temporary);
    var settingsPath=Path.Combine(root,"preferences.json");
    var settings=new Settings { Folders=[root], Pins=[record.Path], English=true, Capacity=12 }; settings.Save(settingsPath);
    var restored=Settings.Load(settingsPath); Check(restored.English && restored.Capacity==12 && restored.Pins.Single()==record.Path,"preferences survive restart");
    File.WriteAllText(settingsPath,"not json"); Settings.Load(settingsPath);
    Check(Directory.GetFiles(root,"preferences.json.invalid-*").Length==1,"corrupt preferences are backed up");
    Check(ReleaseVersion.Parse("v0.1.0-rc.3")==null,"macOS releases must not be offered to Windows");
    Check(ReleaseVersion.Parse("windows-v0.1.0-rc.10")!.CompareTo(ReleaseVersion.Parse("windows-v0.1.0-rc.2"))>0,"numeric rc ordering");
    Check(ReleaseVersion.Parse("windows-v0.1.0")!.CompareTo(ReleaseVersion.Parse("windows-v0.1.0-rc.10"))>0,"stable follows candidates");
    using var seen=new ManualResetEventSlim();
    using var watcher=new FileSystemWatcher(root) { EnableRaisingEvents=true };
    watcher.Created+=(_,e)=> { if (e.Name=="event.txt") seen.Set(); };
    File.WriteAllText(Path.Combine(root,"event.txt"),"event"); Check(seen.Wait(TimeSpan.FromSeconds(8)),"real filesystem event observed");
    Console.WriteLine("PASS: completion gate, temporary filtering, actual file URLs, pin capacity, rename conflicts/staleness, safe file/folder dismissal, preference recovery and live watcher");
}
finally { Directory.Delete(root,true); }
