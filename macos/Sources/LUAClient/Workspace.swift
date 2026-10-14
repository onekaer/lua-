import AppKit
import SwiftUI
import Carbon

final class FloatingPanel:NSPanel {
 var typing=false
 override var canBecomeKey:Bool{typing}
 override var canBecomeMain:Bool{false}
}
@MainActor final class Workspace:ObservableObject {
 let model:Model
 @Published var editing=false
 @Published var typing=false
 @Published var pinned:Set<Page>=[]
 var panels:[Page:FloatingPanel]=[:],bar:FloatingPanel?,hud:FloatingPanel?
 var priorApp:NSRunningApplication?
 var keys:[EventHotKeyRef]=[]
 var eventHandler:EventHandlerRef?
 init(_ model:Model){self.model=model}
 func panel(size:NSSize)->FloatingPanel{let p=FloatingPanel(contentRect:NSRect(origin:.zero,size:size),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false);p.level = .floating;p.isOpaque=false;p.backgroundColor = .clear;p.hasShadow=true;p.hidesOnDeactivate=false;p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];p.isMovableByWindowBackground=true;p.isReleasedWhenClosed=false;p.title="LUA · Sobreposição";return p}
 func toggle(){editing.toggle();typing=false;if editing{priorApp=NSWorkspace.shared.frontmostApplication;if bar==nil{let p=panel(size:NSSize(width:650,height:60));p.contentView=NSHostingView(rootView:WorkspaceBar(workspace:self).preferredColorScheme(.dark));bar=p};if let screen=NSScreen.main{bar?.setFrameOrigin(NSPoint(x:screen.visibleFrame.midX-325,y:screen.visibleFrame.maxY-78))};bar?.orderFrontRegardless();if panels.isEmpty{open(.home);open(.capture)};for p in panels.values{p.ignoresMouseEvents=false;p.typing=false;p.styleMask.insert(.nonactivatingPanel);p.orderFrontRegardless()}}else{bar?.orderOut(nil);for (page,p) in panels{p.typing=false;p.styleMask.insert(.nonactivatingPanel);p.ignoresMouseEvents=pinned.contains(page);if !pinned.contains(page){p.orderOut(nil)}};priorApp?.activate(options:[])}}
 func open(_ page:Page){if let p=panels[page]{p.orderFrontRegardless();return};let size=page == .capture ? NSSize(width:350,height:205):NSSize(width:390,height:660);let p=panel(size:size);p.contentView=NSHostingView(rootView:WidgetView(workspace:self,model:model,page:page).preferredColorScheme(.dark));if let screen=NSScreen.main{p.setFrameOrigin(NSPoint(x:screen.visibleFrame.minX+20+Double(panels.count%3)*410,y:screen.visibleFrame.maxY-size.height-110))};p.typing=typing;panels[page]=p;p.orderFrontRegardless()}
 func close(_ page:Page){panels[page]?.orderOut(nil);panels.removeValue(forKey:page);pinned.remove(page)}
 func pin(_ page:Page){if pinned.contains(page){pinned.remove(page)}else{pinned.insert(page)}}
 func toggleTyping(){typing.toggle();for p in panels.values{p.typing=typing;if typing{p.styleMask.remove(.nonactivatingPanel)}else{p.styleMask.insert(.nonactivatingPanel);p.resignKey()}};if !typing{priorApp?.activate(options:[])}}
 func recording(_ active:Bool)->CGWindowID? {
  guard active else{hud?.orderOut(nil);return nil}
  if hud==nil{let p=panel(size:NSSize(width:350,height:74));p.title="LUA • Indicador de gravação";p.contentView=NSHostingView(rootView:RecordingHUDView(model:model).preferredColorScheme(.dark));hud=p}
  let screen=NSScreen.screens.first{($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value==model.engine.activeDisplayID} ?? NSScreen.main
  if let screen{hud?.setFrameOrigin(NSPoint(x:screen.visibleFrame.maxX-370,y:screen.visibleFrame.maxY-94))}
  hud?.orderFrontRegardless();hud?.displayIfNeeded()
  guard let number=hud?.windowNumber,number>0 else{return nil}
  return CGWindowID(number)
 }

 func registerKeys(){for key in keys{UnregisterEventHotKey(key)};keys=[]
  if eventHandler==nil{var type=EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed));let context=Unmanaged.passUnretained(self).toOpaque();InstallEventHandler(GetApplicationEventTarget(),{_,event,context in guard let event,let context else{return OSStatus(eventNotHandledErr)};var id=EventHotKeyID();GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&id);let owner=Unmanaged<Workspace>.fromOpaque(context).takeUnretainedValue();DispatchQueue.main.async{switch id.id{case 1:owner.toggle();case 2:owner.model.screenshot();case 3:owner.model.toggleRecording();case 4:owner.model.clip();default:break}};return noErr},1,&type,context,&eventHandler)}
  let mods:UInt32=model.shortcut=="⌃ Espaço" ? UInt32(controlKey):model.shortcut=="⌥⇧ Espaço" ? UInt32(optionKey|shiftKey):UInt32(cmdKey|shiftKey)
  for (id,key,mod) in [(UInt32(1),UInt32(kVK_Space),mods),(2,UInt32(kVK_ANSI_P),UInt32(cmdKey|shiftKey)),(3,UInt32(kVK_ANSI_R),UInt32(cmdKey|shiftKey)),(4,UInt32(kVK_F8),UInt32(cmdKey|shiftKey))]{var ref:EventHotKeyRef?;let status=RegisterEventHotKey(key,mod,EventHotKeyID(signature:0x4C554130,id:id),GetApplicationEventTarget(),0,&ref);if status==noErr,let ref{keys.append(ref)}else{model.notice="Atalho indisponível: revise a combinação nas Configurações."}}
 }
}
struct WorkspaceBar:View {
 @ObservedObject var workspace:Workspace
 var body:some View{HStack(spacing:9){Image(systemName:"moon.stars.fill").font(.title2).foregroundStyle(luaBlue).padding(.horizontal,6);ForEach(Page.allCases){page in Button{workspace.open(page)}label:{Image(systemName:page.icon).frame(width:23,height:28)}.buttonStyle(.plain).help(page.rawValue)};Divider().frame(height:22);Button(workspace.typing ? "Teclado ativo":"Digitar"){workspace.toggleTyping()}.buttonStyle(.bordered).tint(workspace.typing ? .orange:luaBlue)}.padding(10).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(.white.opacity(0.12))).foregroundStyle(.white)}
}
struct WidgetView:View {
 @ObservedObject var workspace:Workspace
 @ObservedObject var model:Model
 let page:Page
 var body:some View{VStack(spacing:12){HStack{if page == .capture{Image(systemName:"moon.fill").foregroundStyle(luaBlue)};Text(page == .home ? "Visão geral":page.rawValue).font(.headline);Spacer();Button{workspace.pin(page)}label:{Image(systemName:workspace.pinned.contains(page) ? "pin.fill":"pin")}.buttonStyle(.plain);Button{workspace.close(page)}label:{Image(systemName:"xmark")}.buttonStyle(.plain)};if page == .capture{CaptureActions(model:model);Button("Ver galeria →"){workspace.open(.gallery)}.buttonStyle(.bordered).frame(maxWidth:.infinity)}else{ScrollView{LuaPage(model:model,page:page)}}}.padding(16).background(Color(red:0.13,green:0.14,blue:0.17),in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(Color.white.opacity(0.12))).foregroundStyle(.white)}
}
