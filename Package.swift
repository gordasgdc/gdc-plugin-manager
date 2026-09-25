// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GDCPluginManager",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Raportare de erori și crash-uri (2026-09-14). Produsul „Sentry" e
        // xcframework STATIC — se leagă în binar, deci nu apare niciun
        // framework imbricat de semnat separat în .app. Alegerea contează:
        // varianta dinamică ar fi cerut un pas nou de semnare în
        // build_app.sh, iar o semnătură lipsă pe un framework imbricat pică
        // notarizarea abia la final, după 40 de minute de așteptare.
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", from: "9.28.0"),
    ],
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
            dependencies: [
                "GDCPluginManagerCore",
                .product(name: "Sentry", package: "sentry-cocoa"),
            ],
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
                // Ghiduri PDF dedicate — vezi FurnizorGuidePDF.swift (nou,
                // 2026-09-03). Generate cu installer/generate_furnizor_guides.py.
                .copy("Resources/Ghid-Furnizor-Cursuri.pdf"),
                .copy("Resources/Ghid-Furnizor-Produse.pdf"),
                .copy("Resources/Ghid-Furnizor-Licente.pdf"),
                .copy("Resources/Ghid-Furnizor-Backup.pdf"),
            ]
        ),
        // Contractele Core (licență, catalog, update.json). Citesc
        // docs/catalog.json și docs/update.json reale din repo.
        .testTarget(
            name: "GDCPluginManagerCoreTests",
            dependencies: ["GDCPluginManagerCore"],
            path: "Tests/GDCPluginManagerCoreTests"
        )
    ]
)
