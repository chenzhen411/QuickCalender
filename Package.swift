// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickCalender",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "QuickCalender", targets: ["QuickCalender"])],
    targets: [
        .target(name: "CalendarCore"),
        .executableTarget(name: "QuickCalender", dependencies: ["CalendarCore"]),
        .testTarget(name: "CalendarCoreTests", dependencies: ["CalendarCore"])
    ],
    swiftLanguageModes: [.v5]
)
