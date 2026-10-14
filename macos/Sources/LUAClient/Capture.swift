import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit
import LUACore

// All media writers and segment ownership live on the single capture queue.
final class MovieSink {
 let writer:AVAssetWriter, video:AVAssetWriterInput
 let audio:AVAssetWriterInput?, mic:AVAssetWriterInput?
 let url:URL
 var start:CMTime?
 init(url:URL,width:Int,height:Int,audio:Bool,mic:Bool) throws {
  self.url=url;let type:AVFileType=url.pathExtension.lowercased()=="mp4" ? .mp4:.mov;let targetWriter=try AVAssetWriter(outputURL:url,fileType:type);writer=targetWriter
  if type == .mp4 {targetWriter.shouldOptimizeForNetworkUse=true}
  video=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:width,AVVideoHeightKey:height,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:8_000_000]])
  video.expectsMediaDataInRealTime=true;guard writer.canAdd(video) else {throw LuaError.message("Codificador de vídeo indisponível.")};writer.add(video)
  func input(_ enabled:Bool)->AVAssetWriterInput? {guard enabled else{return nil};let i=AVAssetWriterInput(mediaType:.audio,outputSettings:[AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:48000,AVNumberOfChannelsKey:2,AVEncoderBitRateKey:128000]);i.expectsMediaDataInRealTime=true;if targetWriter.canAdd(i){targetWriter.add(i);return i};return nil}
  self.audio=input(audio);self.mic=input(mic)
 }
 func append(_ sample:CMSampleBuffer,type:SCStreamOutputType) {
  let t=CMSampleBufferGetPresentationTimeStamp(sample)
  if start == nil {guard type == .screen else{return};guard writer.startWriting() else{return};writer.startSession(atSourceTime:t);start=t}
  guard writer.status == .writing,let start,t>=start else{return}
  let target=type == .screen ? video : type == .audio ? audio : mic
  if target?.isReadyForMoreMediaData == true {target?.append(sample)}
 }
 func finish(_ done:@escaping (Result<URL,Error>)->Void) {
  guard start != nil,writer.status == .writing else {writer.cancelWriting();try? FileManager.default.removeItem(at:url);done(.failure(writer.error ?? LuaError.message("Nenhum quadro recebido.")));return}
  video.markAsFinished();audio?.markAsFinished();mic?.markAsFinished()
  writer.finishWriting {if self.writer.status == .completed {done(.success(self.url))}else{done(.failure(self.writer.error ?? LuaError.message("Não foi possível finalizar o vídeo.")))}}
 }
}

final class CaptureEngine:NSObject,SCStreamOutput,SCStreamDelegate {
 let queue=DispatchQueue(label:"lua.media",qos:.userInitiated)
 var stream:SCStream?
 var width=1920,height=1080,systemAudio=true,microphone=false
 var buffer:MovieSink?,recording:MovieSink?,segmentStart=0.0
 var segments:[ReplaySegment]=[],segmentPending=0,exporting=false,generation=0
 let cache:URL
 var lastImage:CVPixelBuffer?
 var running=false
 var activeDisplayID:CGDirectDisplayID?
 var samplesPaused=false,resumeAfter:CMTime?
 var excludedWindowIDs=Set<CGWindowID>()
 var hudFilterReady=false
 var onStatus:((String)->Void)?,onSaved:((URL)->Void)?,onError:((Error)->Void)?
 var onClipFinished:((Result<URL,Error>)->Void)?
 var onRecordingFinished:((Result<URL,Error>)->Void)?
 init(cache:URL){self.cache=cache;super.init()}
 func notify(_ text:String){DispatchQueue.main.async{self.onStatus?(text)}}
 func fail(_ error:Error){DispatchQueue.main.async{self.onError?(error)}}
 func start(audio:Bool,mic:Bool,displayID:CGDirectDisplayID?=nil) async throws {
  guard !running else{return}
  // Permission is requested only after an explicit user action or a previously granted permission.
  let content=try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:true)
  guard let display=content.displays.first(where:{$0.displayID==displayID}) ?? content.displays.first else {throw LuaError.message("Nenhuma tela disponível.")}
  activeDisplayID=display.displayID;hudFilterReady=false
  width=min(display.width,1920);height=Int(Double(display.height)*Double(width)/Double(display.width));height-=height%2;width-=width%2
  systemAudio=audio;microphone=mic
  let config=SCStreamConfiguration();config.width=width;config.height=height;config.minimumFrameInterval=CMTime(value:1,timescale:30);config.queueDepth=3;config.showsCursor=true;config.capturesAudio=audio;config.sampleRate=48000;config.channelCount=2;config.excludesCurrentProcessAudio=true;config.captureMicrophone=mic
  // Keep the workspace in captures, excluding only the recording indicator.
  let filter=SCContentFilter(display:display,excludingWindows:content.windows.filter{excludedWindowIDs.contains($0.windowID)})
  let s=SCStream(filter:filter,configuration:config,delegate:self)
  try s.addStreamOutput(self,type:.screen,sampleHandlerQueue:queue)
  if audio {try s.addStreamOutput(self,type:.audio,sampleHandlerQueue:queue)}
  if mic {try s.addStreamOutput(self,type:.microphone,sampleHandlerQueue:queue)}
  try FileManager.default.createDirectory(at:cache,withIntermediateDirectories:true)
  stream=s;try await s.startCapture();running=true;notify("Histórico ativo · aguarde os primeiros segundos")
 }
 func stream(_ stream:SCStream,didStopWithError error:Error) {guard stream === self.stream else{return};running=false;fail(error);queue.async{self.buffer?.writer.cancelWriting();self.buffer=nil;if let sink=self.recording{self.recording=nil;sink.finish{result in DispatchQueue.main.async{self.onRecordingFinished?(result)}}}};notify("Captura interrompida · reative o histórico")}
 func stream(_ stream:SCStream,didOutputSampleBuffer sample:CMSampleBuffer,of type:SCStreamOutputType) {
  guard stream === self.stream else{return}
  autoreleasepool {process(sample,type:type)}
 }
 func process(_ sample:CMSampleBuffer,type:SCStreamOutputType) {
  let time=CMSampleBufferGetPresentationTimeStamp(sample)
  guard sample.isValid,acceptsSample(at:time) else{return}
  if type == .screen {
   guard let attachments=CMSampleBufferGetSampleAttachmentsArray(sample,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]],let value=attachments.first?[.status] as? Int,value==SCFrameStatus.complete.rawValue,let image=sample.imageBuffer else{return}
   lastImage=image
   let now=CMSampleBufferGetPresentationTimeStamp(sample).seconds
   if buffer==nil,segmentPending<2 {do{buffer=try newSink(cache.appendingPathComponent(UUID().uuidString+".mov"));segmentStart=now}catch{fail(error)}}
   if now-segmentStart>=3,let old=buffer {
    let available=((try? FileManager.default.attributesOfFileSystem(forPath:cache.path))?[.systemFreeSize] as? NSNumber)?.int64Value ?? Int64.max
    if available<500*1024*1024 {
     buffer?.writer.cancelWriting();buffer=nil;running=false
     if let active=recording{recording=nil;active.finish{result in DispatchQueue.main.async{self.onRecordingFinished?(result)}}}
     Task{try? await self.stream?.stopCapture()}
     fail(LuaError.message("Captura interrompida: menos de 500 MB livres. A gravação recebida foi finalizada."));return
    }
    let begin=segmentStart,session=generation;buffer=nil;segmentPending+=1
    old.finish{result in self.queue.async{guard self.generation==session else{if case .success(let url)=result{try? FileManager.default.removeItem(at:url)};return};self.segmentPending-=1;if case .success(let url)=result{self.segments.append(ReplaySegment(url:url,start:begin,end:now));self.prune(now:now)}else if case .failure(let error)=result{self.fail(error)}}}
    if segmentPending<2 {do{buffer=try newSink(cache.appendingPathComponent(UUID().uuidString+".mov"));segmentStart=now}catch{fail(error)}}
   }
  }
  buffer?.append(sample,type:type);recording?.append(sample,type:type)
 }
 func newSink(_ url:URL)throws->MovieSink {try MovieSink(url:url,width:width,height:height,audio:systemAudio,mic:microphone)}
 func prune(now:Double) {guard !exporting else{return};let old=segments.filter{$0.end<now-130};segments.removeAll{$0.end<now-130};old.forEach{try? FileManager.default.removeItem(at:$0.url)};notify("Histórico pronto · até \(Int(segments.reduce(0){$0+$1.end-$1.start})) s disponíveis")}
 func acceptsSample(at time:CMTime)->Bool{!samplesPaused && time.isValid && (resumeAfter==nil || time>=resumeAfter!)}
 func pauseSamples() async {await withCheckedContinuation{(done:CheckedContinuation<Void,Never>) in queue.async{self.samplesPaused=true;done.resume()}}}
 func resumeSamples() async {await withCheckedContinuation{(done:CheckedContinuation<Void,Never>) in queue.async{self.resumeAfter=CMClockGetTime(self.stream?.synchronizationClock ?? CMClockGetHostTimeClock());self.samplesPaused=false;done.resume()}}}
 func excludeRecordingIndicator(_ id:CGWindowID) async throws {
  guard let current=stream,let displayID=activeDisplayID,running,id>0 else{throw LuaError.message("A captura não está pronta para preparar o indicador.")}
  // The new panel must be known to WindowServer before applying the filter.
  // Samples remain paused until the filter is applied and the writer is ready.
  for attempt in 0..<5 {
   let content=try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:false)
   guard let display=content.displays.first(where:{$0.displayID==displayID}) else{throw LuaError.message("O monitor da captura foi desconectado.")}
   if let indicator=content.windows.first(where:{$0.windowID==id}){
    try await current.updateContentFilter(SCContentFilter(display:display,excludingWindows:[indicator]))
    guard stream === current,running else{throw LuaError.message("A captura foi interrompida durante a preparação.")}
    excludedWindowIDs=[id];hudFilterReady=true;return
   }
   if attempt<4{try await Task.sleep(nanoseconds:50_000_000)}
  }
  throw LuaError.message("Não foi possível excluir o indicador do vídeo. Tente iniciar a gravação novamente.")
 }
 func startRecording(to url:URL) async throws {try await withCheckedThrowingContinuation{(done:CheckedContinuation<Void,Error>) in queue.async{do{guard self.running,self.recording==nil else{throw LuaError.message("Ative a captura antes de gravar.")};guard self.hudFilterReady else{throw LuaError.message("O indicador precisa estar excluído antes de gravar.")};self.recording=try self.newSink(url);self.notify("Gravação em andamento");done.resume()}catch{done.resume(throwing:error)}}}}
 func stopRecording(){queue.async{guard let sink=self.recording else{return};self.recording=nil;sink.finish{result in DispatchQueue.main.async{self.onRecordingFinished?(result)}}}}
 func screenshot(to url:URL){queue.async{guard let image=self.lastImage else{self.fail(LuaError.message("Ative a captura e aguarde o primeiro quadro."));return};let ci=CIImage(cvPixelBuffer:image);let ctx=CIContext();guard let cg=ctx.createCGImage(ci,from:ci.extent) else{return};let rep=NSBitmapImageRep(cgImage:cg);do{guard let data=rep.representation(using:.png,properties:[:]) else{throw LuaError.message("PNG indisponível.")};try data.write(to:url,options:.atomic);DispatchQueue.main.async{self.onSaved?(url)}}catch{self.fail(error)}}}
 func clip(seconds:Int,to url:URL){queue.async{
  guard !self.exporting else{self.fail(LuaError.message("Aguarde o clipe atual terminar."));return}
  let now=self.buffer?.start?.seconds ?? ProcessInfo.processInfo.systemUptime
  let selected=ReplayPolicy.selected(self.segments,now:now,seconds:Double(seconds))
  guard !selected.isEmpty else{DispatchQueue.main.async{self.onClipFinished?(.failure(LuaError.message("O histórico ainda está preparando os primeiros segundos.")))};return}
  self.exporting=true
  Task{let result:Result<URL,Error>;do{try await Self.join(selected,seconds:seconds,output:url);result = .success(url)}catch{result = .failure(error)};self.queue.async{self.exporting=false;DispatchQueue.main.async{self.onClipFinished?(result)}}}
 }}
 static func join(_ selected:[ReplaySegment],seconds:Int,output:URL) async throws {
  let composition=AVMutableComposition();guard let video=composition.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid) else{throw LuaError.message("Trilha de vídeo indisponível.")}
  var audioTracks:[Int:AVMutableCompositionTrack]=[:],cursor=CMTime.zero
  for segment in selected {
   let asset=AVURLAsset(url:segment.url);let duration=try await asset.load(.duration)
   let videos=try await asset.loadTracks(withMediaType:.video)
   if let source=videos.first {try video.insertTimeRange(CMTimeRange(start:.zero,duration:duration),of:source,at:cursor)}
   let audios=try await asset.loadTracks(withMediaType:.audio)
   for (index,source) in audios.enumerated(){if audioTracks[index]==nil{audioTracks[index]=composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid)};try audioTracks[index]?.insertTimeRange(CMTimeRange(start:.zero,duration:duration),of:source,at:cursor)}
   cursor=cursor+duration
  }
  guard let export=AVAssetExportSession(asset:composition,presetName:AVAssetExportPresetHighestQuality) else{throw LuaError.message("Exportação indisponível.")}
  export.outputURL=output;export.outputFileType = .mp4
  export.timeRange=CMTimeRange(start:CMTime(seconds:max(0,cursor.seconds-Double(seconds)),preferredTimescale:600),duration:CMTime(seconds:min(cursor.seconds,Double(seconds)),preferredTimescale:600))
  // Multiple independent system/microphone tracks are mixed on clip export.
  let mix=AVMutableAudioMix();mix.inputParameters=audioTracks.values.map{let p=AVMutableAudioMixInputParameters(track:$0);p.setVolume(1,at:.zero);return p};export.audioMix=mix
  try await export.export(to:output,as:.mp4)
 }
 func stop() async {let old=stream;stream=nil;try? await old?.stopCapture();running=false;await withCheckedContinuation{(done:CheckedContinuation<Void,Never>) in queue.async{self.generation+=1;self.segmentPending=0;self.samplesPaused=false;self.resumeAfter=nil;self.hudFilterReady=false;self.buffer?.writer.cancelWriting();self.buffer=nil;self.lastImage=nil;self.segments.forEach{try? FileManager.default.removeItem(at:$0.url)};self.segments=[];done.resume()}}}
}
