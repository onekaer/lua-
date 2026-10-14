import AppKit
import ImageIO
import LUACore

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
