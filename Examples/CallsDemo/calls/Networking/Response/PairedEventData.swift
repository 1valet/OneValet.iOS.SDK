//
//  PairedEventData.swift
//  calls
//

import Foundation

/// A referenced entity in the "paired" event — id plus a display name.
struct NamedRef: Codable {
    let id: String
    let name: String?
}

/// Data of the "paired" SSE event: the activated pairing token this device uses
/// from now on, and who it now rings for. The names are for the UI; the token
/// carries the binding. No intercom here on purpose — which intercom is calling
/// arrives with every ring event.
struct PairedEventData: Codable {
    let pairingToken: String
    let building: NamedRef
    let occupant: NamedRef
    let expiresAt: String
}
