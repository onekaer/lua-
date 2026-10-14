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
  self.url=url;let targetWriter=try AVAssetWriter(outputURL:url,fileType:.mov);writer=targetWriter
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
 var segments:[ReplaySegment]=[],segmentPending=0,exporting=false
 let cache:URL
 var lastImage:CVPixelBuffer?
 var running=false
 var onStatus:((String)->Void)?,onSaved:((URL)->Void)?,onError:((Error)->Void)?
 init(cache:URL){self.cache=cache;super.init()}
 func notify(_ text:String){DispatchQueue.main.async{self.onStatus?(text)}}
 func fail(_ error:Error){DispatchQueue.main.async{self.onError?(error)}}
 func start(audio:Bool,mic:Bool,displayID:CGDirectDisplayID?=nil) async throws {
  guard !running else{return}
  // Permission is requested only after an explicit user action or a previously granted permission.
  let content=try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:true)
  guard let display=content.displays.first(where:{$0.displayID==displayID}) ?? content.displays.first else {throw LuaError.message("Nenhuma tela disponível.")}
  width=min(display.width,1920);height=Int(Double(display.height)*Double(width)/Double(display.width));height-=height%2;width-=width%2
  systemAudio=audio;microphone=mic
  let config=SCStreamConfiguration();config.width=width;config.height=height;config.minimumFrameInterval=CMTime(value:1,timescale:30);config.queueDepth=5;config.showsCursor=true;config.capturesAudio=audio;config.sampleRate=48000;config.channelCount=2;config.excludesCurrentProcessAudio=true;config.captureMicrophone=mic
  // The app's overlay is intentionally included, matching the Windows edition.
  let filter=SCContentFilter(display:display,excludingWindows:[])
  let s=SCStream(filter:filter,configuration:config,delegate:self)
  try s.addStreamOutput(self,type:.screen,sampleHandlerQueue:queue)
  if audio {try s.addStreamOutput(self,type:.audio,sampleHandlerQueue:queue)}
  if mic {try s.addStreamOutput(self,type:.microphone,sampleHandlerQueue:queue)}
  try FileManager.default.createDirectory(at:cache,withIntermediateDirectories:true)
  stream=s;try await s.startCapture();running=true;notify("Histórico ativo · aguarde os primeiros segundos")
 }
 func stream(_ stream:SCStream,didStopWithError error:Error) {running=false;fail(error);queue.async{self.buffer?.writer.cancelWriting();self.buffer=nil;if let sink=self.recording{self.recording=nil;sink.finish{result in if case .success(let url)=result{DispatchQueue.main.async{self.onSaved?(url)}}}}};notify("Captura interrompida · reative o histórico")}
 func stream(_ stream:SCStream,didOutputSampleBuffer sample:CMSampleBuffer,of type:SCStreamOutputType) {
  guard sample.isValid else{return}
  if type == .screen {
   guard let attachments=CMSampleBufferGetSampleAttachmentsArray(sample,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]],let value=attachments.first?[.status] as? Int,value==SCFrameStatus.complete.rawValue,let image=sample.imageBuffer else{return}
   lastImage=image
   let now=CMSampleBufferGetPresentationTimeStamp(sample).seconds
   if buffer==nil {do{buffer=try newSink(cache.appendingPathComponent(UUID().uuidString+".mov"));segmentStart=now}catch{fail(error)}}
   if now-segmentStart>=3,let old=buffer {
    let begin=segmentStart;buffer=nil;segmentPending+=1
    old.finish{result in self.queue.async{self.segmentPending-=1;if case .success(let url)=result{self.segments.append(ReplaySegment(url:url,start:begin,end:now));self.prune(now:now)}else if case .failure(let error)=result{self.fail(error)}}}
    do{buffer=try newSink(cache.appendingPathComponent(UUID().uuidString+".mov"));segmentStart=now}catch{fail(error)}
   }
  }
  buffer?.append(sample,type:type);recording?.append(sample,type:type)
 }
 func newSink(_ url:URL)throws->MovieSink {try MovieSink(url:url,width:width,height:height,audio:systemAudio,mic:microphone)}
 func prune(now:Double) {guard !exporting else{return};let old=segments.filter{$0.end<now-130};segments.removeAll{$0.end<now-130};old.forEach{try? FileManager.default.removeItem(at:$0.url)};notify("Histórico pronto · até \(Int(segments.reduce(0){$0+$1.end-$1.start})) s disponíveis")}
 func startRecording(to url:URL) {queue.async{do{guard self.running,self.recording==nil else{throw LuaError.message("Ative a captura antes de gravar.")};self.recording=try self.newSink(url);self.notify("Gravação em andamento")}catch{self.fail(error)}}}
 func stopRecording(){queue.async{guard let sink=self.recording else{return};self.recording=nil;sink.finish{result in DispatchQueue.main.async{switch result{case .success(let url):self.onSaved?(url);case .failure(let error):self.onError?(error)}}}}}
 func screenshot(to url:URL){queue.async{guard let image=self.lastImage else{self.fail(LuaError.message("Ative a captura e aguarde o primeiro quadro."));return};let ci=CIImage(cvPixelBuffer:image);let ctx=CIContext();guard let cg=ctx.createCGImage(ci,from:ci.extent) else{return};let rep=NSBitmapImageRep(cgImage:cg);do{guard let data=rep.representation(using:.png,properties:[:]) else{throw LuaError.message("PNG indisponível.")};try data.write(to:url,options:.atomic);DispatchQueue.main.async{self.onSaved?(url)}}catch{self.fail(error)}}}
 func clip(seconds:Int,to url:URL){queue.async{
  guard !self.exporting else{self.fail(LuaError.message("Aguarde o clipe atual terminar."));return}
  let now=self.buffer?.start?.seconds ?? ProcessInfo.processInfo.systemUptime
  let selected=ReplayPolicy.selected(self.segments,now:now,seconds:Double(seconds))
  guard !selected.isEmpty else{self.fail(LuaError.message("O histórico ainda está preparando os primeiros segundos."));return}
  self.exporting=true
  Task{do{try await Self.join(selected,seconds:seconds,output:url);DispatchQueue.main.async{self.onSaved?(url)}}catch{self.fail(error)};self.queue.async{self.exporting=false}}
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
 func stop() async {try? await stream?.stopCapture();stream=nil;running=false;queue.async{self.buffer?.writer.cancelWriting();self.buffer=nil;self.lastImage=nil;self.segments.forEach{try? FileManager.default.removeItem(at:$0.url)};self.segments=[]}}
}
