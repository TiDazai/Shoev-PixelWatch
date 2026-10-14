// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "PixelWatch", platforms: [.macOS("26.0")], products: [.library(name: "PixelWatchCore", targets: ["PixelWatchCore"])], targets: [
    .target(name: "PixelWatchCore", path: "PixelWatch", exclude: ["App", "Views", "ViewModels", "Capture", "Monitoring", "Notifications", "Permissions", "Utilities", "Resources/Info.plist", "Resources/Localizable.xcstrings", "Resources/PixelWatch.icns", "Resources/BrandMark.png", "Resources/LICENSE.txt", "Resources/en.lproj", "Resources/ru.lproj"], sources: ["Models", "Detection", "Persistence", "Recognition"], resources: [.copy("Resources/Translations.json")], swiftSettings: [.define("PACKAGE_CORE")]),
    .testTarget(name: "PixelWatchCoreTests", dependencies: ["PixelWatchCore"], path: "Tests", swiftSettings: [.define("PACKAGE_CORE")])
])
