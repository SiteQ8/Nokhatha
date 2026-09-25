// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NokhathaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "NokhathaKit", targets: ["NokhathaKit"])],
    targets: [
        .target(name: "NokhathaKit"),
        .testTarget(name: "NokhathaKitTests", dependencies: ["NokhathaKit"]),
    ]
)
