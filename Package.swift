// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GDCPluginManager",
    platforms: [.macOS(.v14)],
    targets: [
        // Shared between the client app and the vendor app: license
        // verification, machine ID, and the catalog data model. No
        // signing/generation code lives here - that's vendor-only, kept
        // out of the client binary entirely (see GDCPluginManagerFurnizor).
        .target(
            name: "GDCPluginManagerCore",
            path: "Sources/GDCPluginManagerCore"
        ),
        // The distributed client app - what customers download and run.
        .executableTarget(
            name: "GDCPluginManager",
            dependencies: ["GDCPluginManagerCore"],
            path: "Sources/GDCPluginManager",
            exclude: ["PrivateCatalogAuth.swift.example"]
        ),
        // Cristi-only tool: publishes products and generates license
        // codes. Never distributed, never linked into the client binary.
        .executableTarget(
            name: "GDCPluginManagerFurnizor",
            dependencies: ["GDCPluginManagerCore"],
            path: "Sources/GDCPluginManagerFurnizor"
        )
    ]
)
