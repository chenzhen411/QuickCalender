// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickCalender",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "QuickCalender", targets: ["QuickCalender"])],
    targets: [
        .target(name: "CalendarCore"),
        .target(name: "AppServices"),
        .executableTarget(name: "QuickCalender", dependencies: ["CalendarCore", "AppServices"]),
        .testTarget(name: "CalendarCoreTests", dependencies: ["CalendarCore"]),
        .testTarget(name: "AppServicesTests", dependencies: ["AppServices"])
    ],
    swiftLanguageModes: [.v5]
)
