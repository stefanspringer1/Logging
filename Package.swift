// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BasicLogging",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BasicLogging",
            targets: ["BasicLogging"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/stefanspringer1/LoggingInterfaces.git", from: "0.0.4")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BasicLogging",
            dependencies: [
                "LoggingInterfaces",
            ]
        ),
        .testTarget(
            name: "BasicLoggingTests",
            dependencies: ["BasicLogging"]
        ),
    ]
)
