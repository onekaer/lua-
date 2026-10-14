import AppKit
import SwiftUI
import AVFoundation
import CoreVideo
import ScreenCaptureKit
import LUACore

@MainActor final class Delegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
 var window:NSWindow!,model:Model!,workspace:Workspace!,status:NSStatusItem!
 func applicationDidFinishLaunching(_ notification:Notification){
  let args=CommandLine.arguments
  if let at=args.firstIndex(of:"--render"),args.count>at+1{do{try render(to:URL(fileURLWithPath:args[at+1]));print("PASSOU: 12 páginas e sobreposição renderizadas pelo app nativo em dados demonstrativos.");NSApp.terminate(nil)}catch{fputs("Falha: \(error)\n",stderr);exit(1)};return}
  if let at=args.firstIndex(of:"--verify-media"),args.count>at+1{Task{do{try await verifyMedia(URL(fileURLWithPath:args[at+1]));print("PASSOU: vídeo real sintético H.264, finalização e clipe retroativo com AVFoundation.");exit(0)}catch{fputs("Falha: \(error)\n",stderr);exit(1)}};return}
  model=Model();workspace=Workspace(model);model.openOverlay={[weak self] in self?.workspace.toggle()};model.updateShortcuts={[weak self] in self?.workspace.registerKeys()};model.recordingHUD={[weak self] active in self?.workspace.recording(active)}
  window=NSWindow(contentRect:NSRect(x:0,y:0,width:1010,height:790),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false);window.title="LUA";window.titlebarAppearsTransparent=true;window.minSize=NSSize(width:620,height:650);window.contentView=NSHostingView(rootView:LuaRoot(model:model));window.center();window.delegate=self;window.isReleasedWhenClosed=false;window.makeKeyAndOrderFront(nil)
  let menu=NSMenu();let item=NSMenuItem();menu.addItem(item);let sub=NSMenu();sub.addItem(withTitle:"Sobre LUA",action:#selector(about),keyEquivalent:"");sub.addItem(NSMenuItem.separator());sub.addItem(withTitle:"Sair do LUA",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");item.submenu=sub;NSApp.mainMenu=menu
  status=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength);status.button?.image=NSImage(systemSymbolName:"moon.stars.fill",accessibilityDescription:"LUA");let tray=NSMenu();tray.addItem(withTitle:"Abrir LUA",action:#selector(show),keyEquivalent:"");tray.addItem(withTitle:"Sobreposição",action:#selector(overlay),keyEquivalent:"");tray.addItem(withTitle:"Parar / iniciar gravação",action:#selector(record),keyEquivalent:"");tray.addItem(NSMenuItem.separator());tray.addItem(withTitle:"Sair",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"");status.menu=tray
  model.resize={[weak self] small in guard let window=self?.window else{return};window.minSize=NSSize(width:small ? 400:620,height:650);window.setContentSize(NSSize(width:small ? 420:1010,height:small ? 760:790))};workspace.registerKeys();model.start();NSApp.activate(ignoringOtherApps:true)
  if let at=args.firstIndex(of:"--verify-startup"),args.count>at+1{Task{do{try await verifyStartup(URL(fileURLWithPath:args[at+1]));print("PASSOU: abertura normal, coleta, navegação, sobreposição, fechar/reabrir e miniatura limitada.");NSApp.terminate(nil)}catch{fputs("Falha na abertura normal: \(error)\n",stderr);exit(1)}}}
 }
 @objc func show(){window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
 @objc func about(){model.page = .settings;show()}
 @objc func overlay(){workspace.toggle()}
 @objc func record(){model.toggleRecording()}
 func windowShouldClose(_ sender:NSWindow)->Bool{sender.orderOut(nil);return false}
 func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {guard let model else{return .terminateNow};if model.isRecording || model.recordStarting || model.recordStopping || model.clipBusy {model.notice="Pare a gravação e aguarde o clipe antes de sair.";show();return .terminateCancel};return .terminateNow}
 func render(to root:URL)throws{
  try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
  let fixture=Model(preview:true);let work=Workspace(fixture)
  func image<V:View>(_ view:V,_ size:NSSize,_ name:String)throws{let host=NSHostingView(rootView:view);host.frame=NSRect(origin:.zero,size:size);let win=NSWindow(contentRect:host.frame,styleMask:.borderless,backing:.buffered,defer:false);win.contentView=host;win.orderFrontRegardless();host.layoutSubtreeIfNeeded();RunLoop.current.run(until:Date().addingTimeInterval(0.4));guard let bitmap=host.bitmapImageRepForCachingDisplay(in:host.bounds) else{throw LuaError.message("Renderização indisponível")};host.cacheDisplay(in:host.bounds,to:bitmap);guard let png=bitmap.representation(using:.png,properties:[:]) else{throw LuaError.message("PNG indisponível")};try png.write(to:root.appendingPathComponent(name+".png"));win.orderOut(nil)}
  for (index,page) in Page.allCases.enumerated(){fixture.page=page;try image(LuaRoot(model:fixture),NSSize(width:1010,height:790),String(format:"%02d",index)+"-"+String(describing:page).replacingOccurrences(of:" ",with:"-"))}
  try image(WorkspaceBar(workspace:work).preferredColorScheme(.dark),NSSize(width:650,height:60),"barra")
  try image(WidgetView(workspace:work,model:fixture,page:.capture).preferredColorScheme(.dark),NSSize(width:350,height:205),"captura")
  try image(WidgetView(workspace:work,model:fixture,page:.home).preferredColorScheme(.dark),NSSize(width:390,height:660),"widget-inicio")
  fixture.isRecording=true;fixture.recordStartedAt=Date().addingTimeInterval(-7)
  try image(RecordingHUDView(model:fixture).preferredColorScheme(.dark),NSSize(width:350,height:74),"gravacao")
  fixture.isRecording=false;fixture.recordStartedAt=nil
  try "Imagens do app nativo macOS. Métricas demonstrativas; não é benchmark.\n".write(to:root.appendingPathComponent("LEIA-ME.txt"),atomically:true,encoding:.utf8)
 }
 func verifyMedia(_ root:URL) async throws{
  try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
  let url=root.appendingPathComponent("gravacao.mp4");let sink=try MovieSink(url:url,width:320,height:180,audio:true,mic:true)
  let bufferSink=try MovieSink(url:root.appendingPathComponent("segmento.mov"),width:320,height:180,audio:false,mic:false)
  var pcm=AudioStreamBasicDescription(mSampleRate:48000,mFormatID:kAudioFormatLinearPCM,mFormatFlags:kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked,mBytesPerPacket:8,mFramesPerPacket:1,mBytesPerFrame:8,mChannelsPerFrame:2,mBitsPerChannel:32,mReserved:0)
  var audioFormat:CMAudioFormatDescription?
  guard CMAudioFormatDescriptionCreate(allocator:nil,asbd:&pcm,layoutSize:0,layout:nil,magicCookieSize:0,magicCookie:nil,extensions:nil,formatDescriptionOut:&audioFormat)==noErr else{throw LuaError.message("Formato de áudio sintético indisponível")}
  for n in 0..<90 {
   var buffer:CVPixelBuffer?;let code=CVPixelBufferCreate(nil,320,180,kCVPixelFormatType_32BGRA,[kCVPixelBufferCGImageCompatibilityKey:true,kCVPixelBufferCGBitmapContextCompatibilityKey:true] as CFDictionary,&buffer);guard code==kCVReturnSuccess,let buffer else{throw LuaError.message("Pixel buffer indisponível")};CVPixelBufferLockBaseAddress(buffer,[]);memset(CVPixelBufferGetBaseAddress(buffer),Int32(30+n),CVPixelBufferGetBytesPerRow(buffer)*180);CVPixelBufferUnlockBaseAddress(buffer,[]);var format:CMVideoFormatDescription?;CMVideoFormatDescriptionCreateForImageBuffer(allocator:nil,imageBuffer:buffer,formatDescriptionOut:&format);var timing=CMSampleTimingInfo(duration:CMTime(value:1,timescale:30),presentationTimeStamp:CMTime(value:Int64(n),timescale:30),decodeTimeStamp:.invalid);var sample:CMSampleBuffer?;CMSampleBufferCreateReadyWithImageBuffer(allocator:nil,imageBuffer:buffer,formatDescription:format!,sampleTiming:&timing,sampleBufferOut:&sample)
   while !sink.video.isReadyForMoreMediaData && sink.writer.status == .writing{try await Task.sleep(nanoseconds:5_000_000)}
   while !bufferSink.video.isReadyForMoreMediaData && bufferSink.writer.status == .writing{try await Task.sleep(nanoseconds:5_000_000)}
   sink.append(sample!,type:.screen);bufferSink.append(sample!,type:.screen)
   var block:CMBlockBuffer?
   guard CMBlockBufferCreateWithMemoryBlock(allocator:nil,memoryBlock:nil,blockLength:1600*8,blockAllocator:kCFAllocatorDefault,customBlockSource:nil,offsetToData:0,dataLength:1600*8,flags:0,blockBufferOut:&block)==noErr,let block else{throw LuaError.message("Buffer de áudio indisponível")}
   CMBlockBufferFillDataBytes(with:0,blockBuffer:block,offsetIntoDestination:0,dataLength:1600*8)
   var audioTiming=CMSampleTimingInfo(duration:CMTime(value:1,timescale:48000),presentationTimeStamp:CMTime(value:Int64(n*1600),timescale:48000),decodeTimeStamp:.invalid)
   var audioSample:CMSampleBuffer?,audioSize=8
   guard CMSampleBufferCreateReady(allocator:nil,dataBuffer:block,formatDescription:audioFormat,sampleCount:1600,sampleTimingEntryCount:1,sampleTimingArray:&audioTiming,sampleSizeEntryCount:1,sampleSizeArray:&audioSize,sampleBufferOut:&audioSample)==noErr,let audioSample else{throw LuaError.message("Amostra de áudio indisponível")}
   for (type,input) in [(SCStreamOutputType.audio,sink.audio),(SCStreamOutputType.microphone,sink.mic)]{guard let input else{throw LuaError.message("Trilha AAC ausente")};while !input.isReadyForMoreMediaData && sink.writer.status == .writing{try await Task.sleep(nanoseconds:5_000_000)};sink.append(audioSample,type:type)}
  }
  let result:URL=try await withCheckedThrowingContinuation{c in sink.finish{c.resume(with:$0)}}
  let segment:URL=try await withCheckedThrowingContinuation{c in bufferSink.finish{c.resume(with:$0)}}
  let recorded=AVURLAsset(url:result);let recordedAudio=try await recorded.loadTracks(withMediaType:.audio)
  let recordedDuration=try await recorded.load(.duration)
  guard recordedAudio.count==2,recordedDuration.seconds>2.8 else{throw LuaError.message("MP4 gravado sem duração ou sem as duas trilhas AAC")}
  let clip=root.appendingPathComponent("clipe.mp4");try await CaptureEngine.join([ReplaySegment(url:result,start:0,end:3)],seconds:2,output:clip)
  let asset=AVURLAsset(url:clip);let duration=try await asset.load(.duration);let tracks=try await asset.loadTracks(withMediaType:.video);guard tracks.count==1,duration.seconds>1.8,duration.seconds<=2.1 else{throw LuaError.message("Clipe com duração inválida")}
  let clipAudio=try await asset.loadTracks(withMediaType:.audio);guard clipAudio.count==1 else{throw LuaError.message("Clipe MP4 não mixou as trilhas de áudio")}
  let historyClip=root.appendingPathComponent("historico.mp4");try await CaptureEngine.join([ReplaySegment(url:segment,start:0,end:3)],seconds:2,output:historyClip)
  for output in [result,clip,historyClip]{let data=try Data(contentsOf:output);guard data.count>1024,String(data:data[4..<8],encoding:.ascii)=="ftyp",String(data:data[8..<12],encoding:.ascii) != "qt  " else{throw LuaError.message("Arquivo final não é um contêiner MP4")}}
  try NativeUpdate.verifyFixture(root.appendingPathComponent("update-check"))
 }
}
let application=NSApplication.shared
application.setActivationPolicy(.regular)
let delegate=MainActor.assumeIsolated { Delegate() };application.delegate=delegate
application.run()
