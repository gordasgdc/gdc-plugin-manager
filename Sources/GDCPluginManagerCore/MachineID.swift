import Foundation
import IOKit
import CryptoKit

/// Swift port of license_check.cpp's `get_machine_id_display()` /
/// `machine_id_hash()` — kept byte-for-byte identical (same IOKit
/// property, same SHA-512-prefix-6-bytes, same Base32, no dashes) so a
/// machine ID shown here matches exactly what `sell.py --machine-id`
/// expects, the same way gdc-resolve-encoder's C++ side already works.
public enum MachineID {
    /// The raw hardware UUID this Mac reports — the same value across
    /// reboots and reinstalls (tied to the logic board, not the disk).
    private static func rawPlatformUUID() -> String {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/")
        guard entry != 0 else { return "mac-machine-id-unavailable" }
        defer { IOObjectRelease(entry) }

        guard let cfValue = IORegistryEntryCreateCFProperty(entry, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0) else {
            return "mac-machine-id-unavailable"
        }
        let uuidRef = cfValue.takeRetainedValue()
        return (uuidRef as? String) ?? "mac-machine-id-unavailable"
    }

    /// The 6-byte SHA-512-prefix hash used both for on-screen display
    /// and for license-code machine-locking — one source of truth so
    /// LicenseCore's validation always matches what's shown on screen.
    public static var hashBytes: [UInt8] {
        Array(SHA512.hash(data: Data(rawPlatformUUID().utf8)).prefix(6))
    }

    /// A short, readable, Base32 string (no dashes) — what the user
    /// copies from Preferences → License and sends before buying, and
    /// what `sell.py --machine-id <this>` expects.
    public static var display: String {
        LicenseCore.base32Encode(Data(hashBytes))
    }
}
