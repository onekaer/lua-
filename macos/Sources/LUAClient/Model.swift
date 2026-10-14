import AppKit
import SwiftUI
import AVKit
import Metal
import CryptoKit
import SystemMetricsC
import LUACore

enum Page:String,CaseIterable,Identifiable,Hashable {
 case home="Início",hardware="Hardware",network="Rede",storage="Armazenamento",cleanup="Limpeza",games="Jogos",fps="Jogos e FPS",processes="Processos",capture="Capturas",gallery="Galeria",analysis="Analisar Mac",settings="Configurações"
 var id:String{rawValue}
 var icon:String{switch self{case .home:return "house";case .hardware:return "cpu";case .network:return "network";case .storage:return "internaldrive";case .cleanup:return "sparkles";case .games:return "square.grid.2x2";case .fps:return "gamecontroller";case .processes:return "chart.bar";case .capture:return "record.circle";case .gallery:return "photo.on.rectangle";case .analysis:return "waveform.path.ecg";case .settings:return "gearshape"}}
}
struct Game:Identifiable,Codable {var id:String{url.path};let name:String;let url:URL;var cover:String?=nil}
struct Media:Identifiable {var id:String{url.path};let url:URL;let date:Date;let bytes:Int64;var kind:String{url.pathExtension=="png" ? "Prints" : url.lastPathComponent.hasPrefix("Clipe") ? "Clipes":"Vídeos"}}
@MainActor final class Model:ObservableObject {
 static let version="0.1.1"
 @Published var page:Page = .home
 @Published var cpu=0.0
 @Published var ramUsed:Int64=0
 @Published var ramTotal:Int64=0
 @Published var free:Int64=0
 @Published var total:Int64=0
 @Published var down=0.0
 @Published var up=0.0
 @Published var cpuHistory:[Double]=Array(repeating:0,count:40)
 @Published var notice=""
 @Published var captureStatus="Autorize a captura para preparar o histórico"
 @Published var captureStarting=false
 @Published var captureActive=false
 @Published var isRecording=false
 @Published var clipBusy=false
 @Published var scanBusy=false
 @Published var speedBusy=false
 @Published var updateBusy=false
 @Published var scanRoot:URL?
 @Published var entries:[ScanEntry]=[]
 @Published var duplicates:[ScanEntry]=[]
 @Published var selected=Set<String>()
 @Published var media:[Media]=[]
 @Published var games:[Game]=[]
 @Published var apps:[NSRunningApplication]=[]
 @Published var query=""
 @Published var galleryKind="Todos"
 @Published var gameGrid=true
 @Published var audio=true
 @Published var microphone=false
 @Published var autoUpdates=false
 @Published var clipSeconds=30
 @Published var shortcut="⌃ Espaço"
 @Published var update:UpdateFeed?
 @Published var speedResult=""
 @Published var folder:URL
 var timer:Timer?,scanTask:Task<Void,Never>?
 var oldNet:(UInt64,UInt64,Date)?
 var nextUpdate=Date().addingTimeInterval(21600),retryUpdate=Date.distantPast
 let data:URL,engine:CaptureEngine
 let preview:Bool
 var resize:((Bool)->Void)?
 var openOverlay:(()->Void)?,updateShortcuts:(()->Void)?,recordingHUD:((Bool)->Void)?
 init(preview:Bool=false,dataOverride:URL?=nil){
  self.preview=preview
  data=dataOverride ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("LUA")
  folder=FileManager.default.urls(for:.moviesDirectory,in:.userDomainMask)[0].appendingPathComponent("LUA")
  engine=CaptureEngine(cache:data.appendingPathComponent("Replay/"+UUID().uuidString))
  if !preview {
   if let value=UserDefaults.standard.string(forKey:"lua.captureFolder"){folder=URL(fileURLWithPath:value)}
   audio=UserDefaults.standard.object(forKey:"lua.audio") as? Bool ?? true
   microphone=UserDefaults.standard.bool(forKey:"lua.microphone");autoUpdates=UserDefaults.standard.bool(forKey:"lua.autoUpdates");shortcut=UserDefaults.standard.string(forKey:"lua.shortcut") ?? "⌃ Espaço"
   if let saved=UserDefaults.standard.data(forKey:"lua.games"),let values=try? JSONDecoder().decode([Game].self,from:saved){games=values}
   try? FileManager.default.createDirectory(at:data,withIntermediateDirectories:true)
   // Delete only stale temporary segment directories owned by this application.
   let replay=data.appendingPathComponent("Replay");if let list=try? FileManager.default.contentsOfDirectory(at:replay,includingPropertiesForKeys:[.contentModificationDateKey]){for f in list where SafeFiles.contained(f,in:replay){let date=(try? f.resourceValues(forKeys:[.contentModificationDateKey]))?.contentModificationDate ?? Date();if Date().timeIntervalSince(date)>86400{try? FileManager.default.removeItem(at:f)}}}
  }
  engine.onStatus={[weak self] text in self?.captureStatus=text}
  engine.onError={[weak self] error in self?.notice=error.localizedDescription;self?.clipBusy=false;if self?.engine.running == false{self?.captureActive=false};if self?.engine.recording == nil{self?.isRecording=false;self?.recordingHUD?(false)}}
  engine.onSaved={[weak self] url in guard let self else{return};self.clipBusy=false;if url.lastPathComponent.hasPrefix("Gravação"){self.isRecording=false;self.recordingHUD?(false)};self.notice="\(url.lastPathComponent) salvo";self.refreshGallery()}
  if preview{cpu=34;ramUsed=12_400_000_000;ramTotal=32_000_000_000;free=186_000_000_000;total=500_000_000_000;down=5_750_000;up=125_000;cpuHistory=(0..<40).map{30+12*sin(Double($0)/3)};captureStatus="Histórico pronto · 60 s disponíveis";captureActive=true;games=[Game(name:"Jogo Metal · demonstração",url:URL(fileURLWithPath:"/Applications/Exemplo.app"))]}
 }
 func start(){guard !preview else{return};sample();refreshGallery();timer=Timer.scheduledTimer(withTimeInterval:1.5,repeats:true){[weak self] _ in Task{@MainActor in self?.sample()}};Task{await checkUpdates();if CGPreflightScreenCaptureAccess(){await activateCapture(request:false)}}}
 func sample(){if Date()>=nextUpdate{nextUpdate=Date().addingTimeInterval(21600);Task{await checkUpdates()}};if autoUpdates,update != nil,!isRecording,!clipBusy,!updateBusy,Date()>=retryUpdate{retryUpdate=Date().addingTimeInterval(3600);Task{await downloadUpdate()}};let m=lua_metrics();cpu=m.cpu;ramUsed=Int64(m.memoryUsed);ramTotal=Int64(m.memoryTotal);cpuHistory.append(cpu);cpuHistory=Array(cpuHistory.suffix(40));let now=Date();if let old=oldNet,now>old.2{down=m.received>=old.0 ? Double(m.received-old.0)/now.timeIntervalSince(old.2):0;up=m.sent>=old.1 ? Double(m.sent-old.1)/now.timeIntervalSince(old.2):0};oldNet=(m.received,m.sent,now);if let attrs=try? FileManager.default.attributesOfFileSystem(forPath:FileManager.default.homeDirectoryForCurrentUser.path){free=(attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0;total=(attrs[.systemSize] as? NSNumber)?.int64Value ?? 0};apps=NSWorkspace.shared.runningApplications.filter{$0.activationPolicy == .regular && !$0.isTerminated}.sorted{($0.localizedName ?? "")<($1.localizedName ?? "")}}
 func save(){guard !preview else{return};UserDefaults.standard.set(folder.path,forKey:"lua.captureFolder");UserDefaults.standard.set(audio,forKey:"lua.audio");UserDefaults.standard.set(microphone,forKey:"lua.microphone");UserDefaults.standard.set(autoUpdates,forKey:"lua.autoUpdates");UserDefaults.standard.set(shortcut,forKey:"lua.shortcut");UserDefaults.standard.set(try? JSONEncoder().encode(games),forKey:"lua.games")}
 func chooseFolder(scan:Bool=false){let p=NSOpenPanel();p.canChooseDirectories=true;p.canChooseFiles=false;p.canCreateDirectories=true;p.message=scan ? "Escolha uma pasta pessoal para analisar":"Escolha onde salvar capturas";guard p.runModal() == .OK,let url=p.url else{return};if scan{scanRoot=url;entries=[];duplicates=[];selected=[]}else{folder=url;save();refreshGallery()}}
 func output(_ prefix:String,_ ext:String)throws->URL{try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);let df=DateFormatter();df.dateFormat="yyyy-MM-dd HH.mm.ss";return folder.appendingPathComponent("\(prefix) \(df.string(from:Date())) \(UUID().uuidString.prefix(4)).\(ext)")}
 func activateCapture(request:Bool=true) async {
  guard !preview,!captureActive,!captureStarting else{return};captureStarting=true;defer{captureStarting=false}
  if !CGPreflightScreenCaptureAccess(){guard request else{return};_ = CGRequestScreenCaptureAccess();guard CGPreflightScreenCaptureAccess() else{notice="Autorize LUA em Ajustes do Sistema → Privacidade e Segurança → Gravação de Tela e Áudio. Pode ser necessário reabrir.";return}}
  if microphone {let allowed=await AVCaptureDevice.requestAccess(for:.audio);guard allowed else{notice="Microfone não autorizado. Desative-o ou permita em Privacidade e Segurança.";return}}
  do{try await engine.start(audio:audio,mic:microphone);captureActive=true}catch{notice=error.localizedDescription}
 }
 func changeCaptureOptions(){save();guard captureActive,!isRecording,!clipBusy else{return};Task{await engine.stop();captureActive=false;await activateCapture(request:false)}}
 func screenshot(){Task{await activateCapture();guard captureActive else{return};do{engine.screenshot(to:try output("Print","png"))}catch{notice=error.localizedDescription}}}
 func toggleRecording(){if isRecording{engine.stopRecording();return};Task{await activateCapture();guard captureActive else{return};do{let target=try output("Gravação","mov");engine.startRecording(to:target);isRecording=true;recordingHUD?(true)}catch{notice=error.localizedDescription}}}
 func clip(){guard !clipBusy else{return};guard captureActive else{notice="Ative o histórico antes do momento que deseja salvar.";return};do{let target=try output("Clipe","mp4");clipBusy=true;engine.clip(seconds:clipSeconds,to:target);Task{try? await Task.sleep(nanoseconds:60_000_000_000);if clipBusy{clipBusy=false}}}catch{notice=error.localizedDescription}}
 func refreshGallery(){guard !preview else{return};let keys:Set<URLResourceKey>=[.fileSizeKey,.contentModificationDateKey];media=((try? FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:Array(keys))) ?? []).filter{["mov","mp4","png"].contains($0.pathExtension.lowercased())}.compactMap{u in guard let v=try? u.resourceValues(forKeys:keys) else{return nil};return Media(url:u,date:v.contentModificationDate ?? .distantPast,bytes:Int64(v.fileSize ?? 0))}.sorted{$0.date>$1.date}}
 func trashMedia(_ item:Media){guard confirm("Excluir esta captura?",detail:"\(item.url.lastPathComponent) será enviado à Lixeira.") else{return};do{guard SafeFiles.contained(item.url,in:folder) else{throw LuaError.message("Captura fora da pasta configurada.")};try FileManager.default.trashItem(at:item.url,resultingItemURL:nil);refreshGallery()}catch{notice=error.localizedDescription}}
 func confirm(_ title:String,detail:String)->Bool {let a=NSAlert();a.messageText=title;a.informativeText=detail;a.alertStyle = .warning;a.addButton(withTitle:"Confirmar");a.addButton(withTitle:"Cancelar");return a.runModal() == .alertFirstButtonReturn}
 func scan(duplicate:Bool=false){guard !scanBusy,let root=scanRoot else{if scanRoot==nil{chooseFolder(scan:true)};return};scanBusy=true;entries=[];duplicates=[];selected=[]
  scanTask=Task{do{let results=try await Task.detached{try SafeFiles.scan(root,cancelled:{Task.isCancelled})}.value;let extra=duplicate ? try await Task.detached{try SafeFiles.duplicates(results,cancelled:{Task.isCancelled})}.value:[];entries=results;duplicates=extra;notice="Análise concluída · \(results.count) arquivos"}catch{notice=error.localizedDescription};scanBusy=false}
 }
 func trashSelected(){let chosen=(page == .cleanup ? duplicates:entries).filter{selected.contains($0.id)};guard let root=scanRoot,!chosen.isEmpty,confirm("Enviar \(chosen.count) arquivos à Lixeira?",detail:"Revise a seleção. O LUA preserva uma cópia de cada grupo de duplicados.") else{return};do{if page == .cleanup{try SafeFiles.validateDuplicateBatch(chosen,all:entries,root:root)};for f in chosen{try SafeFiles.validateForTrash(f,root:root)};for f in chosen{try FileManager.default.trashItem(at:f.url,resultingItemURL:nil)};selected=[];scan(duplicate:page == .cleanup)}catch{notice=error.localizedDescription}}
 func addGame(){let p=NSOpenPanel();p.allowedContentTypes=[.application];p.message="Escolha o aplicativo de um jogo para adicionar à biblioteca";guard p.runModal() == .OK,let url=p.url else{return};guard url.pathExtension=="app",!games.contains(where:{$0.url==url}) else{return};games.append(Game(name:url.deletingPathExtension().lastPathComponent,url:url));save()}
 func discoverSteam(){let roots=[FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Steam/steamapps/common")];var count=0;for root in roots{if let en=FileManager.default.enumerator(at:root,includingPropertiesForKeys:[.isDirectoryKey],options:[.skipsHiddenFiles]){for case let url as URL in en where url.pathExtension=="app"{en.skipDescendants();if !games.contains(where:{$0.url==url}){games.append(Game(name:url.deletingPathExtension().lastPathComponent,url:url));count+=1}}}};save();notice="\(count) jogos adicionados. Bibliotecas em outros discos podem ser adicionadas manualmente."}
 func launch(_ game:Game,hud:Bool=false){let c=NSWorkspace.OpenConfiguration();if hud{c.environment=["MTL_HUD_ENABLED":"1","MTL_HUD_LOGGING_ENABLED":"1"]};NSWorkspace.shared.openApplication(at:game.url,configuration:c){_,error in if let error{Task{@MainActor in self.notice=error.localizedDescription}}}}
 func removeGame(_ game:Game){guard confirm("Remover jogo da biblioteca?",detail:"O aplicativo e os arquivos do jogo serão preservados.") else{return};games.removeAll{$0.id==game.id};save()}
 func report()->String{"LUA macOS \(Self.version) Beta\n\(ProcessInfo.processInfo.operatingSystemVersionString)\nCPU: \(LuaFormat.percent(cpu))\nMemória ativa/cabeada/comprimida: \(LuaFormat.bytes(ramUsed)) / \(LuaFormat.bytes(ramTotal))\nEspaço livre: \(LuaFormat.bytes(free))\nEstado térmico: \(thermalText)\nGPU: \(MTLCreateSystemDefaultDevice()?.name ?? "indisponível")\nTemperaturas/GPU %: sem leitura pública garantida.\nFPS: HUD Metal em jogos compatíveis; LUA não mede FPS do jogo via captura de tela.\n"}
 var thermalText:String{switch ProcessInfo.processInfo.thermalState{case .nominal:return "Normal";case .fair:return "Elevado";case .serious:return "Alto";case .critical:return "Crítico";@unknown default:return "Indisponível"}}
 func exportReport(){let p=NSSavePanel();p.nameFieldStringValue="Diagnóstico LUA.txt";guard p.runModal() == .OK,let u=p.url else{return};do{try report().write(to:u,atomically:true,encoding:.utf8);notice="Relatório salvo"}catch{notice=error.localizedDescription}}
 func speed(){guard !speedBusy else{return};speedBusy=true;speedResult="Medindo…";Task{do{let session=URLSession(configuration:.ephemeral);let start=Date();let(_,r)=try await session.data(from:URL(string:"https://speed.cloudflare.com/__down?bytes=1000")!);guard (r as? HTTPURLResponse)?.statusCode==200 else{throw LuaError.message("Teste indisponível.")};let latency=Date().timeIntervalSince(start)*1000;let t=Date();let(data,response)=try await session.data(from:URL(string:"https://speed.cloudflare.com/__down?bytes=10000000")!);guard data.count==10_000_000,(response as? HTTPURLResponse)?.statusCode==200 else{throw LuaError.message("Download incompleto.")};let download=Double(data.count)/Date().timeIntervalSince(t);var request=URLRequest(url:URL(string:"https://speed.cloudflare.com/__up")!);request.httpMethod="POST";request.timeoutInterval=30;let payload=Data(count:2_000_000);let begin=Date();let(_,res)=try await session.upload(for:request,from:payload);guard (200..<300).contains((res as? HTTPURLResponse)?.statusCode ?? 0) else{throw LuaError.message("Upload indisponível.")};speedResult="↓ \(LuaFormat.rate(download))  ↑ \(LuaFormat.rate(Double(payload.count)/Date().timeIntervalSince(begin)))  · \(Int(latency)) ms (HTTPS)"}catch{speedResult=error.localizedDescription};speedBusy=false}}
 func checkUpdates() async {guard !preview else{return};do{let(data,response)=try await URLSession.shared.data(from:URL(string:"https://onekaer.github.io/lua-/mac-update.json")!);guard (response as? HTTPURLResponse)?.statusCode==200 else{return};let feed=try JSONDecoder().decode(UpdateFeed.self,from:data);try feed.validate();if feed.isNewer(than:Self.version){update=feed;notice="LUA \(feed.version) disponível para Mac";if autoUpdates{await downloadUpdate()}}}catch{notice="Não foi possível conferir atualizações: \(error.localizedDescription)"}}
 func downloadUpdate() async {guard !updateBusy,!isRecording,!clipBusy,let feed=update else{return};updateBusy=true;retryUpdate=Date().addingTimeInterval(3600);defer{updateBusy=false};do{try feed.validate();let(temp,response)=try await URLSession.shared.download(from:feed.url);guard (response as? HTTPURLResponse)?.statusCode==200 else{throw LuaError.message("Download indisponível.")};let size=(try temp.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0;guard Int64(size)==feed.bytes,try SafeFiles.hash(temp)==feed.sha256 else{throw LuaError.message("A atualização falhou na verificação de integridade.")};guard !isRecording,!clipBusy else{retryUpdate=Date().addingTimeInterval(10);notice="Atualização aguardando a captura terminar.";return};let target=FileManager.default.urls(for:.downloadsDirectory,in:.userDomainMask)[0].appendingPathComponent(feed.url.lastPathComponent);if FileManager.default.fileExists(atPath:target.path){guard try SafeFiles.hash(target)==feed.sha256 else{throw LuaError.message("Há outro arquivo com esse nome em Downloads. Revise-o antes de atualizar.")}}else{try FileManager.default.moveItem(at:temp,to:target)};let prepared=try NativeUpdate.prepare(zip:target,version:feed.version,data:data,current:Bundle.main.bundleURL);try NativeUpdate.install(prepared,data:data);NSApp.terminate(nil)}catch{notice=error.localizedDescription}}
}
