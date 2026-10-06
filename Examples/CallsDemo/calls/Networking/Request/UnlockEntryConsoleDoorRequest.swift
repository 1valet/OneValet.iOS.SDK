//
//  UnlockEntryConsoleDoorRequest.swift
//  calls
//
//  Created by Justin Ngo on 2026-01-06.
//

/// Body for unlocking the door controlled by an entry console.
struct UnlockEntryConsoleDoorRequest: Codable {
    /// Occupant authorizing the unlock; the console comes from the URL path.
    let occupantId: String
}
