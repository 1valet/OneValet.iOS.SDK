//
//  TokenAndParticipantRequest.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-18.
//

/// Body for requesting a video room access token.
struct TokenAndParticipantRequest: Codable {
    /// Occupant joining the room; the room itself comes from the URL path.
    let occupantId: String
}
