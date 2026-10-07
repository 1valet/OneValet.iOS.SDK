//
//  CreatePairingResponse.swift
//  calls
//

import Foundation

/// Response of `POST /api/demo/pairings`: the short code to display and the
/// pending token to listen with until the code is activated.
struct CreatePairingResponse: Codable {
    let code: String
    let pendingToken: String
    let expiresAt: String
}
