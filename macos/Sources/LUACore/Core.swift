import Foundation
import CryptoKit

public enum LuaError: LocalizedError {
 case message(String)
 public var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
public enum LuaFormat {
 public static func bytes(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
 public static func percent(_ value: Double) -> String { String(format: "%.0f%%", max(0,min(100,value))) }
 public static func rate(_ value: Double) -> String { String(format: "%.2f Mbps",max(0,value)*8/1_000_000).replacingOccurrences(of: ".", with: ",") }
}
public struct ScanEntry: Identifiable, Hashable, Codable {
 public var id: String { url.path }
 public let url: URL
 public let bytes: Int64
 public let modified: Date
 public init(url: URL, bytes: Int64, modified: Date) { self.url=url;self.bytes=bytes;self.modified=modified }
}
public enum SafeFiles {
 public static func contained(_ url: URL, in root: URL) -> Bool {
  let a=url.resolvingSymlinksInPath().standardizedFileURL.path
  let b=root.resolvingSymlinksInPath().standardizedFileURL.path
  return a != b && a.hasPrefix(b.hasSuffix("/") ? b : b+"/")
 }
 public static func allowedRoot(_ root: URL) -> Bool {
  let p=root.resolvingSymlinksInPath().standardizedFileURL.path
  let home=FileManager.default.homeDirectoryForCurrentUser.path
  return p.hasPrefix(home+"/") && !p.hasPrefix(home+"/Library") && !p.hasPrefix(home+"/.Trash") && !p.hasPrefix(home+"/.ssh") && !p.hasPrefix(home+"/.codex") && root.pathExtension != "app"
 }
 public static func scan(_ root: URL, cancelled: ()->Bool = { false }) throws -> [ScanEntry] {
  if cancelled(){throw CancellationError()}
  guard allowedRoot(root) else { throw LuaError.message("Escolha uma pasta pessoal, fora de Library e das pastas de sistema.") }
  let keys:Set<URLResourceKey>=[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey,.contentModificationDateKey,.isPackageKey]
  guard let files=FileManager.default.enumerator(at:root,includingPropertiesForKeys:Array(keys),options:[.skipsHiddenFiles,.skipsPackageDescendants]) else { return [] }
  var result:[ScanEntry]=[]
  for case let url as URL in files {
   if cancelled() { throw CancellationError() }
   guard contained(url,in:root), let v=try? url.resourceValues(forKeys:keys), v.isRegularFile == true, v.isSymbolicLink != true else { continue }
   result.append(ScanEntry(url:url,bytes:Int64(v.fileSize ?? 0),modified:v.contentModificationDate ?? .distantPast))
  }
  return result.sorted{$0.bytes > $1.bytes}
 }
 public static func hash(_ url: URL) throws -> String {
  let f=try FileHandle(forReadingFrom:url);defer{try? f.close()};var hash=SHA256()
  while let data=try f.read(upToCount:1024*1024),!data.isEmpty { hash.update(data:data) }
  return hash.finalize().map{String(format:"%02x",$0)}.joined()
 }
 public static func duplicates(_ entries:[ScanEntry],cancelled:()->Bool = {false}) throws -> [ScanEntry] {
  let sizes=Dictionary(grouping:entries.filter{$0.bytes>0},by:{$0.bytes});var result:[ScanEntry]=[]
  for group in sizes.values where group.count>1 {
   var seen=Set<String>()
   for entry in group.sorted(by:{$0.url.path<$1.url.path}) {
    if cancelled(){throw CancellationError()}
    let digest=try hash(entry.url);if !seen.insert(digest).inserted{result.append(entry)}
   }
  }
  return result
 }
 public static func validateForTrash(_ entry:ScanEntry,root:URL) throws {
  guard allowedRoot(root), contained(entry.url,in:root) else {throw LuaError.message("Arquivo fora da pasta revisada.")}
  var fresh=entry.url;fresh.removeAllCachedResourceValues()
  let now=try fresh.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey,.isSymbolicLinkKey,.contentModificationDateKey])
  guard now.isRegularFile == true,now.isSymbolicLink != true,Int64(now.fileSize ?? -1)==entry.bytes,now.contentModificationDate==entry.modified else {throw LuaError.message("O arquivo mudou desde a análise. Analise novamente.")}
 }
 public static func validateDuplicateBatch(_ selected:[ScanEntry],all:[ScanEntry],root:URL)throws {
  let paths=Set(selected.map{$0.id})
  for entry in selected {
   try validateForTrash(entry,root:root);let digest=try hash(entry.url)
   let candidates=all.filter{!paths.contains($0.id) && $0.bytes==entry.bytes}
   var preserved=false
   for candidate in candidates {
    guard (try? validateForTrash(candidate,root:root)) != nil else{continue}
    if try hash(candidate.url)==digest{preserved=true;break}
   }
   guard preserved else{throw LuaError.message("Uma cópia que seria preservada mudou ou foi removida. Analise os duplicados novamente.")}
  }
 }
}
public struct ReplaySegment: Equatable {
 public let url:URL;public let start:Double;public let end:Double
 public init(url:URL,start:Double,end:Double){self.url=url;self.start=start;self.end=end}
}
public enum ReplayPolicy {
 public static func selected(_ segments:[ReplaySegment],now:Double,seconds:Double)->[ReplaySegment] {
  segments.filter{$0.end <= now && $0.end > now-seconds && $0.end > $0.start}.sorted{$0.start<$1.start}
 }
}
public struct UpdateFeed: Codable {
 public let version:String;public let url:URL;public let sha256:String;public let bytes:Int64
 public init(version:String,url:URL,sha256:String,bytes:Int64){self.version=version;self.url=url;self.sha256=sha256;self.bytes=bytes}
 public func validate() throws {
  guard version.range(of:#"^\d+\.\d+\.\d+$"#,options:.regularExpression) != nil,
   url.scheme=="https",url.host=="github.com",url.path.hasPrefix("/onekaer/lua-/releases/download/mac-v"),
   url.lastPathComponent=="LUA-\(version)-macOS-universal.zip",bytes>0,bytes<500_000_000,
   sha256.range(of:#"^[a-f0-9]{64}$"#,options:.regularExpression) != nil else {throw LuaError.message("Canal de atualização inválido.")}
 }
 public func isNewer(than value:String)->Bool {version.compare(value,options:.numeric) == .orderedDescending}
}
