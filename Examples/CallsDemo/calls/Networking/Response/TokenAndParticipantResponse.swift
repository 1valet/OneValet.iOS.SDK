//
//  TokenAndParticipant.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

/// Envelope wrapping a video room token response.
struct TokenAndParticipantResponse: Codable {
    /// The token payload.
    let data: TokenAndParticipantData
}

/// Credentials needed to join a video room.
struct TokenAndParticipantData: Codable {
    /// Access token to hand to `CallManager.joinRoom`.
    let token: String
    /// This device's participant identifier, required when reporting status.
    let participantId: String
}
