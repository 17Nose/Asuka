// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MusicApp",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MusicApp",
            targets: ["MusicApp"]
        ),
    ],
    dependencies: [
        // SQLite 数据库（GRDB.swift）
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
        // 图片加载缓存（Kingfisher）
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.12.0"),
    ],
    targets: [
        .target(
            name: "MusicApp",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Kingfisher", package: "Kingfisher"),
            ],
            path: ".",
            exclude: ["Package.swift", "README.md"],
            sources: [
                "App/",
                "Core/",
                "Modules/",
                "UI/",
                "Utilities/",
                "Resources/"
            ]
        ),
    ]
)
