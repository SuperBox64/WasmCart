// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "WasmCart",
    products: [
        .library(name: "WasmCart", targets: ["WasmCart"]),
    ],
    dependencies: [
        .package(path: "../SuperBox64Kit"),
    ],
    targets: [
        .target(
            name: "WasmCart",
            dependencies: [
                .product(name: "SpriteKit", package: "SuperBox64Kit"),
                .product(name: "CSDL3", package: "SuperBox64Kit"),
                .product(name: "CWamr", package: "SuperBox64Kit"),
                .product(name: "KitABI", package: "SuperBox64Kit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .defaultIsolation(MainActor.self),
            ]
        ),
    ]
)
