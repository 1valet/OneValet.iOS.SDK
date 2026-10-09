//
//  TokenAndParticipantResponse.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import Foundation

/// Response of the room-token call: the access token to hand to
/// `CallManager.joinRoom` and the participant identity to report status with.
struct TokenAndParticipantResponse: Codable {
    let token: String
    let participantId: String
}
