import AppKit
import ImageIO
import LUACore
import CoreMedia

@MainActor extension Delegate {
 func verifyStartup(_ root:URL) async throws {
  try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
  guard window.isVisible,status.button != nil,model.ramTotal>0,model.cpu.isFinite else{throw LuaError.message("Inicialização ou coleta inválida")}
  model.clipBusy=true
  model.engine.onSaved?(root.appendingPathComponent("Print teste.png"))
  guard model.clipBusy else{throw LuaError.message("Salvar print liberou o clipe ainda em exportação")}
  model.engine.onError?(LuaError.message("Erro de outra ação, simulado"))
  guard model.clipBusy else{throw LuaError.message("Erro de outra ação liberou o clipe")}
  model.engine.onClipFinished?(.failure(LuaError.message("Exportação de teste concluída")))
  guard !model.clipBusy else{throw LuaError.message("Conclusão do clipe não liberou a interface")}
  model.isRecording=true;model.recordStartedAt=Date().addingTimeInterval(-7)
  let firstHUD=workspace.recording(true)
  guard firstHUD != nil,workspace.hud?.isVisible==true,workspace.hud?.canBecomeKey==false,RecordingHUDView.elapsed(Date(timeIntervalSince1970:3661),from:Date(timeIntervalSince1970:0))=="01:01:01" else{throw LuaError.message("Indicador REC/tempo sem janela não ativante")}
  guard workspace.recording(true)==firstHUD else{throw LuaError.message("Indicador trocou a identidade da janela")}
  model.toggleRecording();guard model.recordStopping else{throw LuaError.message("Parar não bloqueou a finalização")}
  model.engine.onSaved?(root.appendingPathComponent("Print durante gravação.png"))
  model.engine.onError?(LuaError.message("Falha de outra ação, simulada"))
  guard model.isRecording,model.recordStopping,workspace.hud?.isVisible==true else{throw LuaError.message("Outra ação ocultou o indicador antes de finalizar")}
  model.engine.onRecordingFinished?(.failure(LuaError.message("Finalização de teste")))
  guard !model.isRecording,!model.recordStopping,workspace.hud?.isVisible==false else{throw LuaError.message("Finalização não recolheu o indicador")}
  await model.engine.pauseSamples()
  let gateEngine=model.engine
  let gatePassed=await withCheckedContinuation{(done:CheckedContinuation<Bool,Never>) in gateEngine.queue.async{
   let engine=gateEngine
   let paused = !engine.acceptsSample(at:CMTime(seconds:3,preferredTimescale:600))
   engine.resumeAfter=CMTime(seconds:2,preferredTimescale:600);engine.samplesPaused=false
   let passed=paused && !engine.acceptsSample(at:CMTime(seconds:1,preferredTimescale:600)) && engine.acceptsSample(at:CMTime(seconds:3,preferredTimescale:600)) && !engine.acceptsSample(at:.invalid)
   engine.resumeAfter=nil;done.resume(returning:passed)
  }}
  guard gatePassed else{throw LuaError.message("Transição aceitou quadros antigos ou amostras durante a pausa")}
  model.engine.running=true
  var blocked=false
  do{try await model.engine.startRecording(to:root.appendingPathComponent("nao-deve-existir.mp4"))}catch{blocked=true}
  model.engine.running=false
  guard blocked,model.engine.recording==nil,!FileManager.default.fileExists(atPath:root.appendingPathComponent("nao-deve-existir.mp4").path) else{throw LuaError.message("Gravação iniciou sem filtro do indicador")}
  for page in Page.allCases{model.page=page;try await Task.sleep(nanoseconds:200_000_000)}
  for _ in 0..<3 {
   workspace.toggle()
   for page in [Page.home,.capture,.gallery,.settings]{workspace.open(page);try await Task.sleep(nanoseconds:150_000_000);workspace.close(page)}
   workspace.toggle()
  }
  for page in Array(workspace.panels.keys){workspace.close(page)}
  _ = windowShouldClose(window);guard !window.isVisible else{throw LuaError.message("Fechar não ocultou a janela")};show()
  try await Task.sleep(nanoseconds:2_000_000_000)
  guard window.isVisible,model.cpu.isFinite,model.cpuHistory.count==40 else{throw LuaError.message("Reabertura ou amostragem inválida")}
  let picture=root.appendingPathComponent("print-sintetico.png")
  try autoreleasepool {
   guard let context=CGContext(data:nil,width:4000,height:3000,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue),let image=context.makeImage(),let dest=CGImageDestinationCreateWithURL(picture as CFURL,"public.png" as CFString,1,nil) else{throw LuaError.message("Imagem de teste indisponível")}
   CGImageDestinationAddImage(dest,image,nil);guard CGImageDestinationFinalize(dest) else{throw LuaError.message("PNG de teste inválido")}
  }
  guard let thumbnail=MediaThumbnail.image(picture),thumbnail.width<=440,thumbnail.height<=440 else{throw LuaError.message("Miniatura decodificou a imagem inteira")}
  for _ in 0..<3{await model.engine.stop()}
  guard !model.engine.running,model.engine.segmentPending==0 else{throw LuaError.message("Encerramento da captura deixou trabalho pendente")}
  let rss=try NativeUpdate.run("/bin/ps",["-o","rss=","-p",String(ProcessInfo.processInfo.processIdentifier)]).trimmingCharacters(in:.whitespacesAndNewlines)
  try "PASSOU: abertura normal, 12 páginas, 3 ciclos da sobreposição, ocultar/reabrir, coleta ativa, miniatura de 4000×3000 limitada a 440 px e parada serializada.\nMemória residente ao final (KiB, runner): \(rss)\nNão é benchmark de jogo ou captura física.\n".write(to:root.appendingPathComponent("startup-check.txt"),atomically:true,encoding:.utf8)
 }
}
