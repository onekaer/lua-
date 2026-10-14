import Foundation
import AppKit
import AVFoundation
import LUACore

enum NativeUpdate {
 static func verifyFixture(_ root:URL)throws {
  let fixture=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/LUA-verify-"+UUID().uuidString)
  try FileManager.default.createDirectory(at:fixture,withIntermediateDirectories:true)
  defer{try? FileManager.default.removeItem(at:fixture)}
  let incoming=root.appendingPathComponent("mac-package/LUA.app")
  let contents=incoming.appendingPathComponent("Contents")
  try FileManager.default.createDirectory(at:contents.appendingPathComponent("MacOS"),withIntermediateDirectories:true)
  try FileManager.default.copyItem(at:URL(fileURLWithPath:CommandLine.arguments[0]),to:contents.appendingPathComponent("MacOS/LUA"))
  let info:[String:Any] = ["CFBundleIdentifier":"app.lua.monitor","CFBundleExecutable":"LUA","CFBundlePackageType":"APPL","CFBundleShortVersionString":"7.0.0"]
  try PropertyListSerialization.data(fromPropertyList:info,format:.xml,options:0).write(to:contents.appendingPathComponent("Info.plist"))
  try run("/usr/bin/codesign",["--force","--deep","--sign","-",incoming.path])
  let current=fixture.appendingPathComponent("LUA.app");try FileManager.default.copyItem(at:incoming,to:current)
  let zip=root.appendingPathComponent("update-fixture.zip");try run("/usr/bin/ditto",["-c","-k","--keepParent",root.appendingPathComponent("mac-package").path,zip.path])
  let prepared=try prepare(zip:zip,version:"7.0.0",data:root,current:current)
  guard FileManager.default.fileExists(atPath:prepared.1.path),FileManager.default.fileExists(atPath:current.path),!FileManager.default.fileExists(atPath:prepared.2.path) else{throw LuaError.message("Preparação da atualização modificou o app original.")}
  do{_ = try prepare(zip:zip,version:"8.0.0",data:root,current:current);throw LuaError.message("Versão divergente foi aceita.")}catch LuaError.message(let text){if text=="Versão divergente foi aceita."{throw LuaError.message(text)}}
 }
 static func run(_ path:String,_ args:[String])throws->String{let p=Process();p.executableURL=URL(fileURLWithPath:path);p.arguments=args;let pipe=Pipe();p.standardOutput=pipe;p.standardError=pipe;try p.run();let data=pipe.fileHandleForReading.readDataToEndOfFile();p.waitUntilExit();guard p.terminationStatus==0 else{throw LuaError.message(String(data:data,encoding:.utf8) ?? "Operação indisponível.")};return String(data:data,encoding:.utf8) ?? ""}
 static func prepare(zip:URL,version:String,data:URL,current:URL)throws->(URL,URL,URL){
  let current=current.resolvingSymlinksInPath().standardizedFileURL
  let allowed=[URL(fileURLWithPath:"/Applications"),FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
  guard current.pathExtension=="app",allowed.contains(where:{SafeFiles.contained(current,in:$0)}),FileManager.default.isWritableFile(atPath:current.deletingLastPathComponent().path) else{throw LuaError.message("Atualização verificada em Downloads. Mova LUA.app para Aplicativos ou substitua-o manualmente.")}
  let names=try run("/usr/bin/unzip",["-Z1",zip.path]).split(separator:"\n").map(String.init)
  guard !names.isEmpty,names.allSatisfy({!$0.hasPrefix("/") && !$0.split(separator:"/").contains("..") && ($0.hasPrefix("mac-package/")||$0.hasPrefix("__MACOSX/"))}) else{throw LuaError.message("Caminhos inválidos no pacote.")}
  let stage=data.appendingPathComponent("Updates/"+UUID().uuidString);try FileManager.default.createDirectory(at:stage,withIntermediateDirectories:true)
  try run("/usr/bin/ditto",["-x","-k",zip.path,stage.path])
  let app=stage.appendingPathComponent("mac-package/LUA.app")
  guard let bundle=Bundle(url:app),bundle.bundleIdentifier=="app.lua.monitor",bundle.infoDictionary?["CFBundleShortVersionString"] as? String==version else{throw LuaError.message("A versão do app difere do canal.")}
  try run("/usr/bin/codesign",["--verify","--deep","--strict",app.path])
  let sibling=current.deletingLastPathComponent().appendingPathComponent(".LUA-update-"+UUID().uuidString+".app")
  try FileManager.default.copyItem(at:app,to:sibling)
  let backup=current.deletingLastPathComponent().appendingPathComponent("LUA-backup-"+UUID().uuidString+".app")
  return(current,sibling,backup)
 }
 static func install(_ prepared:(URL,URL,URL),data:URL)throws {
  let script=data.appendingPathComponent("update-"+UUID().uuidString+".sh")
  let text="""
  #!/bin/sh
  set -eu
  pid="$1"; target="$2"; staged="$3"; backup="$4"
  count=0
  while kill -0 "$pid" 2>/dev/null; do
    count=$((count+1)); [ "$count" -lt 150 ] || exit 1
    sleep 0.2
  done
  /bin/mv "$target" "$backup"
  if /bin/mv "$staged" "$target"; then
    if /usr/bin/open "$target"; then exit 0; fi
    /bin/mv "$target" "$staged"
  fi
  /bin/mv "$backup" "$target"
  /usr/bin/open "$target"
  exit 1
  """
  try text.write(to:script,atomically:true,encoding:.utf8)
  let p=Process();p.executableURL=URL(fileURLWithPath:"/bin/sh");p.arguments=[script.path,String(ProcessInfo.processInfo.processIdentifier),prepared.0.path,prepared.1.path,prepared.2.path];try p.run()
 }
}
@MainActor extension Model {
 func trim(_ item:Media,start:Double,end:Double) async {
  guard !clipBusy,!isRecording,start.isFinite,end.isFinite,start>=0,end>start else{notice="Defina um intervalo válido em segundos.";return}
  clipBusy=true;defer{clipBusy=false}
  do{let asset=AVURLAsset(url:item.url);let duration=try await asset.load(.duration);guard end<=duration.seconds+0.01 else{throw LuaError.message("O fim ultrapassa a duração do vídeo (\(Int(duration.seconds)) s).")};guard let export=AVAssetExportSession(asset:asset,presetName:AVAssetExportPresetHighestQuality) else{throw LuaError.message("Exportação indisponível.")};export.timeRange=CMTimeRange(start:CMTime(seconds:start,preferredTimescale:600),duration:CMTime(seconds:end-start,preferredTimescale:600));let url=try output("Clipe recortado","mp4");try await export.export(to:url,as:.mp4);refreshGallery();notice="Trecho salvo. O original foi preservado."}catch{notice=error.localizedDescription}
 }
 func changeCover(_ game:Game){let p=NSOpenPanel();p.allowedContentTypes=[.image];guard p.runModal() == .OK,let source=p.url,let image=NSImage(contentsOf:source),let tiff=image.tiffRepresentation,let rep=NSBitmapImageRep(data:tiff),let png=rep.representation(using:.png,properties:[:]) else{return};do{let root=data.appendingPathComponent("Covers");try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);let dest=root.appendingPathComponent(UUID().uuidString+".png");try png.write(to:dest,options:.atomic);if let i=games.firstIndex(where:{$0.id==game.id}){games[i].cover=dest.path};save()}catch{notice=error.localizedDescription}}
}
