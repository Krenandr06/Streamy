// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Streamy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Streamy", targets: ["Streamy"])
    ],
    targets: [
        .executableTarget(
            name: "Streamy",
            path: "Sources/Streamy",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
