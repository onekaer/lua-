// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "LUA", platforms: [.macOS("15.0")], products: [.executable(name: "LUA", targets: ["LUAClient"])], targets: [
 .target(name: "SystemMetricsC", publicHeadersPath: "include"),
 .target(name: "LUACore"),
 .executableTarget(name: "LUAClient", dependencies: ["LUACore", "SystemMetricsC"], linkerSettings: [.linkedFramework("Carbon"), .linkedFramework("ScreenCaptureKit"), .linkedFramework("AVFoundation")]),
 .testTarget(name: "LUACoreTests", dependencies: ["LUACore"])
])
