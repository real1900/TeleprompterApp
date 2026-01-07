// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TeleprompterApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TeleprompterApp",
            targets: ["TeleprompterApp"]
        )
    ],
    targets: [
        .target(
            name: "TeleprompterApp",
            dependencies: []
        )
    ]
)
