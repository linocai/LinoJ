// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LinoJCore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "LinoJCore",
            targets: ["LinoJCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LinoJCore",
            dependencies: [],
            path: "Sources/LinoJCore",
            exclude: [
                // SwiftPM CLI 不会调用 xcstringstool 把 .xcstrings 编译成 .strings；
                // 把它从 build 中排除，改为：仓库同时维护 Resources/Localizable.xcstrings（编辑源）
                //   + Resources/<lang>.lproj/Localizable.strings（编译产物，纳入 build）。
                // 想新增/改翻译时：编辑 xcstrings 后跑
                //     xcrun xcstringstool compile Resources/Localizable.xcstrings -o Resources/
                // 把 lproj 同步覆盖即可。
                // xcodebuild 真机/模拟器构建走自己的 xcstrings pipeline，因此 LinoJ-macOS /
                // LinoJ-iOS 工程编译时仍然吃 xcstrings；只有 `swift build` / `swift test` 走 lproj。
                "Resources/Localizable.xcstrings"
            ],
            resources: [
                // P5：把两个 lproj 子目录作为 localized resources 处理。SwiftPM 看到 .lproj
                // 会自动按目录名识别语言并写入 bundle 的对应位置。
                .process("Resources/en.lproj"),
                .process("Resources/zh-Hans.lproj")
            ],
            swiftSettings: [
                // Swift 6 默认启用 strict concurrency / Sendable 推断；这里追加
                // ExistentialAny 让所有 `any` protocol 必须显式标注，
                // 防止未来扩展时悄悄引入隐式存在类型。
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "LinoJCoreTests",
            dependencies: ["LinoJCore"],
            path: "Tests/LinoJCoreTests"
        )
    ]
)
