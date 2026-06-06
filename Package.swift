// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CropAndLock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CropAndLock", targets: ["CropAndLock"])
    ],
    targets: [
        .executableTarget(
            name: "CropAndLock",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "CropAndLockTests",
            dependencies: ["CropAndLock"]
        )
    ]
)
