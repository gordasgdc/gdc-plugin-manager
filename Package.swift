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
            path: "Sources/GDCPluginManagerCore",
            exclude: ["PrivateCatalogAuth.swift.example"]
        ),
        // The distributed client app - what customers download and run.
        .executableTarget(
            name: "GDCPluginManager",
            dependencies: ["GDCPluginManagerCore"],
            path: "Sources/GDCPluginManager",
            resources: [
                .copy("Resources/Ghid-GDCPluginManager-ro.pdf"),
                .copy("Resources/Ghid-GDCPluginManager-en.pdf"),
                .copy("Resources/Ghid-GDCPluginManager-es.pdf"),
            ]
        ),
        // Cristi-only tool: publishes products and generates license
        // codes. Never distributed, never linked into the client binary.
        .executableTarget(
            name: "GDCPluginManagerFurnizor",
            dependencies: ["GDCPluginManagerCore"],
            path: "Sources/GDCPluginManagerFurnizor",
            exclude: ["SupabaseAdminConfig.swift.example"],
            resources: [
                // [2026-08-29] Preseturile sezoniere predefinite au trecut de
                // la SVG inline la PNG randat, bundle-uit - vezi
                // SeasonalBackgroundStore.swift pentru motivul real
                // (decodorul SVG nativ ImageIO NU randează deloc <text>,
                // gasit ca bug real, nu presupunere - toate cele 7 preseturi
                // aveau text complet invizibil).
                .copy("Resources/SeasonalPresets"),
            ]
        )
    ]
)
