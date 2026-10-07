//
//  PairingStore.swift
//  calls
//

import Foundation

/// The saved pairing: the token the portal minted at activation plus the display
/// names it came with. The token is the credential for every demo API call.
struct Pairing {
    let token: String
    let occupantName: String
    let buildingName: String
}

/// Persists the pairing across launches, so the app pairs once and then just
/// reconnects. `UserDefaults` is demo-grade on purpose — a production app would
/// keep a session credential in the Keychain.
struct PairingStore {
    private static let tokenKey = "pairing_token"
    private static let occupantNameKey = "occupant_name"
    private static let buildingNameKey = "building_name"

    static func load() -> Pairing? {
        let defaults = UserDefaults.standard
        guard let token = defaults.string(forKey: tokenKey) else {
            return nil
        }
        return Pairing(
            token: token,
            occupantName: defaults.string(forKey: occupantNameKey) ?? "",
            buildingName: defaults.string(forKey: buildingNameKey) ?? ""
        )
    }

    static func save(_ pairing: Pairing) {
        let defaults = UserDefaults.standard
        defaults.set(pairing.token, forKey: tokenKey)
        defaults.set(pairing.occupantName, forKey: occupantNameKey)
        defaults.set(pairing.buildingName, forKey: buildingNameKey)
    }

    /// Forgets the pairing — after an expired/rejected token, or the Unpair button.
    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: occupantNameKey)
        defaults.removeObject(forKey: buildingNameKey)
    }
}
