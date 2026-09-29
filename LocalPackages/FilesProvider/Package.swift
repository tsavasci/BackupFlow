// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FilesProvider",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "FilesProvider",
            targets: ["FilesProvider"]
        )
    ],
    dependencies: [],
    targets: [
        .target(name: "FilesProvider",
                dependencies: [],
                path: "Sources",
                // Vendored third-party code; its legacy warnings are not actionable here.
                swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        ),
    ]
)
