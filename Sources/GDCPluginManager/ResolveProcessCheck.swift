import AppKit

/// Matches Dec18 Plugin Manager's "host process detection": DaVinci
/// Resolve only reads DCTL/LUT/Fuse folders at launch, so installing or
/// removing files while it's running would silently do nothing until the
/// next restart - better to say so up front than let it look broken.
enum ResolveProcessCheck {
    static let bundleID = "com.blackmagic-design.DaVinciResolve"

    static var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }
}
