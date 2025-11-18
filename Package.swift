// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyTermUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftyTermUI",
            targets: ["SwiftyTermUI"]
        ),
        .executable(
            name: "HelloTermUI",
            targets: ["HelloTermUI"]
        ),
        .executable(
            name: "WindowExample",
            targets: ["WindowExample"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftyTermUI"
        ),
        .executableTarget(
            name: "HelloTermUI",
            dependencies: ["SwiftyTermUI"],
            path: "Examples",
            sources: ["HelloTermUI.swift"]
        ),
        .executableTarget(
            name: "WindowExample",
            dependencies: ["SwiftyTermUI"],
            path: "Examples",
            sources: ["WindowExample.swift"]
        ),
    ]
)
