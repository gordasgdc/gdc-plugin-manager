import Foundation
import IOKit
import CryptoKit

/// Swift port of license_check.cpp's `get_machine_id_display()` /
/// `machine_id_hash()` — kept byte-for-byte identical (same IOKit
/// property, same SHA-512-prefix-6-bytes, same Base32, no dashes) so a
/// machine ID shown here matches exactly what `sell.py --machine-id`
/// expects, the same way gdc-resolve-encoder's C++ side already works.
///
/// GDC-SEC-02 (audit securitate 2026-08-24): formula de mai jos rămâne
/// NESCHIMBATĂ pe Mac — doar `IOPlatformUUID`, fără un al doilea factor.
/// Windows a trecut la board UUID + serial disc (vezi
/// `MACHINE_ID_ARCHITECTURE.md` din rădăcina repo-ului) fiindcă sursa lui
/// veche (`MachineGuid` din Registry) se rescrie trivial cu `reg add`; pe
/// Mac nu există un echivalent la fel de trivial pentru `IOPlatformUUID`,
/// deci nu era nevoie de un al doilea factor aici. NU adăuga un al doilea
/// factor pe Mac fără să actualizezi și `MACHINE_ID_ARCHITECTURE.md` — ar
/// sparge toate licențele Mac deja emise.
public enum MachineID {
    /// The raw hardware UUID this Mac reports — the same value across
    /// reboots and reinstalls (tied to the logic board, not the disk).
    /// `available == false` means IOKit couldn't answer just now (in
    /// practice near-impossible on real Mac hardware, unlike WMI on
    /// Windows) — kept for API symmetry with Windows/C++/Python so the
    /// kill-switch's `.hwidUnavailable` case (see LicenseCore.swift) never
    /// mistakes "couldn't ask" for "this really is a different machine".
    private static func rawPlatformUUID() -> (raw: String, available: Bool) {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/")
        guard entry != 0 else { return ("mac-machine-id-unavailable", false) }
        defer { IOObjectRelease(entry) }

        guard let cfValue = IORegistryEntryCreateCFProperty(entry, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0) else {
            return ("mac-machine-id-unavailable", false)
        }
        let uuidRef = cfValue.takeRetainedValue()
        guard let uuid = uuidRef as? String else { return ("mac-machine-id-unavailable", false) }
        return (uuid, true)
    }

    /// The 6-byte SHA-512-prefix hash used both for on-screen display
    /// and for license-code machine-locking — one source of truth so
    /// LicenseCore's validation always matches what's shown on screen.
    public static var hashBytes: [UInt8] {
        Array(SHA512.hash(data: Data(rawPlatformUUID().raw.utf8)).prefix(6))
    }

    /// A short, readable, Base32 string (no dashes) — what the user
    /// copies from Preferences → License and sends before buying, and
    /// what `sell.py --machine-id <this>` expects.
    public static var display: String {
        LicenseCore.base32Encode(Data(hashBytes))
    }

    /// True if IOKit actually answered just now — see kill-switch note above.
    public static var isAvailable: Bool {
        rawPlatformUUID().available
    }
}
