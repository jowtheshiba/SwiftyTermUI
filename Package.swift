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
        .library(
            name: "RetroVision",
            targets: ["RetroVision"]
        ),
        .executable(
            name: "HelloTermUI",
            targets: ["HelloTermUI"]
        ),
        .executable(
            name: "WindowExample",
            targets: ["WindowExample"]
        ),
        .executable(
            name: "InputExample",
            targets: ["InputExample"]
        ),
        .executable(
            name: "DrawingExample",
            targets: ["DrawingExample"]
        ),
        .executable(
            name: "ComponentsExample",
            targets: ["ComponentsExample"]
        ),
        .executable(
            name: "RetroDemo",
            targets: ["RetroDemo"]
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
        .executableTarget(
            name: "InputExample",
            dependencies: ["SwiftyTermUI"],
            path: "Examples",
            sources: ["InputExample.swift"]
        ),
        .executableTarget(
            name: "DrawingExample",
            dependencies: ["SwiftyTermUI"],
            path: "Examples",
            sources: ["DrawingExample.swift"]
        ),
        .executableTarget(
            name: "ComponentsExample",
            dependencies: ["SwiftyTermUI"],
            path: "Examples",
            sources: ["ComponentsExample.swift"]
        ),
        .target(
            name: "RetroVision",
            dependencies: ["SwiftyTermUI"]
        ),
        .executableTarget(
            name: "RetroDemo",
            dependencies: ["RetroVision", "SwiftyTermUI"],
            path: "Examples",
            sources: ["RetroDemo.swift"]
        ),
    ]
)
