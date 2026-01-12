// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clify",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Clify", targets: ["Clify"])
    ],
    dependencies: [
        .package(url: "https://github.com/cocoabits/MASShortcut.git", branch: "master")
    ],
    targets: [
        .executableTarget(
            name: "Clify",
            dependencies: ["MASShortcut"],
            path: "Sources/Clif"
        )
    ]
)
