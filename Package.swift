// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clothesline",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Clothesline", targets: ["Clothesline"])],
    targets: [
        .executableTarget(name: "Clothesline", path: "Sources/Clothesline")
    ]
)
