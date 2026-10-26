// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ExcaliburForms",
    platforms: [.macOS(.v14)],
    targets: [
        // App SwiftUI: janela, lista de quadros, barra de ferramentas e o editor (WKWebView).
        .executableTarget(
            name: "ExcaliburForms",
            dependencies: ["ExcaliburCore"],
            path: "Sources/ExcaliburForms"
        ),
        // Núcleo puro (Foundation): quadros e persistência em disco. Testável sem UI.
        .target(
            name: "ExcaliburCore",
            path: "Sources/ExcaliburCore"
        ),
        .testTarget(
            name: "ExcaliburCoreTests",
            dependencies: ["ExcaliburCore"],
            path: "Tests/ExcaliburCoreTests"
        ),
    ]
)
