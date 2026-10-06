//
//  UpdateCallStatusRequest.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

/// Body for reporting a change in call status.
struct UpdateCallStatusRequest: Codable {
    /// Participant identifier returned when the token was issued.
    let participantId: String
    /// Occupant on the call.
    let occupantId: String
    /// Entry console that placed the call.
    let entryConsoleId: String
    /// The new status to report.
    let callStatus: CallStatus
}
