// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MonitorWidget",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MonitorWidget", targets: ["MonitorWidget"]),
        .executable(name: "monitorctl", targets: ["monitorctl"]),
    ],
    targets: [
        // DDC/CI transport + VCP logic for external displays on Apple Silicon.
        .target(name: "DDCKit"),
        // Command-line probe / controller (used to analyze the monitor).
        .executableTarget(name: "monitorctl", dependencies: ["DDCKit"]),
        // Menu bar widget.
        .executableTarget(name: "MonitorWidget", dependencies: ["DDCKit"]),
    ]
)
