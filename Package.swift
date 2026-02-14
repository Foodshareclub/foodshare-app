// swift-tools-version: 6.1
// FoodShare - Skip Fuse cross-platform app
import PackageDescription

let package = Package(
    name: "foodshare-skip",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FoodShare", type: .dynamic, targets: ["FoodShare"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.7.2"),
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", from: "1.0.0"),
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.41.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.6.2")
    ],
    targets: [
        .target(name: "FoodShare", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
            .product(name: "Supabase", package: "supabase-swift"),
            .product(name: "Kingfisher", package: "Kingfisher")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "FoodShareTests", dependencies: ["FoodShare"])
    ]
)
