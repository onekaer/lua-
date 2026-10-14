import SwiftUI

struct RecordingHUDView:View {
 @ObservedObject var model:Model
 static func elapsed(_ date:Date,from start:Date?)->String {
  let seconds=Int(max(0,date.timeIntervalSince(start ?? date)))
  return String(format:"%02d:%02d:%02d",seconds/3600,(seconds/60)%60,seconds%60)
 }
 var body:some View {
  TimelineView(.animation(minimumInterval:1,paused:!model.isRecording)){context in
   HStack(spacing:10){
    Circle().fill(Color(red:0.96,green:0.44,blue:0.50)).frame(width:8,height:8)
    VStack(alignment:.leading,spacing:3){
     Text(model.recordStarting ? "Preparando…":"REC  "+Self.elapsed(context.date,from:model.recordStartedAt)).font(.system(size:14,weight:.semibold)).monospacedDigit()
     Text(model.recordStopping ? "LUA • finalizando MP4":model.captureActive ? "LUA • buffer de clipes ativo":"LUA • gravação em andamento").font(.system(size:11)).foregroundStyle(Color(red:0.67,green:0.67,blue:0.74))
    }
    Spacer(minLength:4)
    Button{model.toggleRecording()}label:{Text(model.recordStopping ? "Salvando…":"Parar").font(.system(size:12)).foregroundStyle(Color(red:1,green:0.70,blue:0.73)).frame(minWidth:52,minHeight:34).padding(.horizontal,9).background(Color(red:0.33,green:0.17,blue:0.20),in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(Color(red:0.55,green:0.27,blue:0.33)))}.buttonStyle(.plain).disabled(model.recordStarting||model.recordStopping).accessibilityLabel("Parar e salvar gravação")
   }.padding(12).frame(width:350,height:74).background(Color(red:0.14,green:0.14,blue:0.16),in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(Color.white.opacity(0.12))).foregroundStyle(Color(red:0.95,green:0.95,blue:0.97))
  }
 }
}
