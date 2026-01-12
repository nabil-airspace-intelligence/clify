// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clif",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Clif", targets: ["Clif"])
    ],
    dependencies: [
        .package(url: "https://github.com/cocoabits/MASShortcut.git", branch: "master")
    ],
    targets: [
        .executableTarget(
            name: "Clif",
            dependencies: ["MASShortcut"],
            path: "Sources/Clif"
        )
    ]
)
