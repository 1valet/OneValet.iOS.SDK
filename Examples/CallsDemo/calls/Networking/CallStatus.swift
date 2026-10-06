//
//  CallStatus.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

/// Call states reported to the 1VALET backend so the entry console can reflect
/// what the resident is doing.
///
/// Backed by `Int` because the API expects the numeric form; the raw values are
/// part of the API contract and must not be reordered.
enum CallStatus: Int, Codable {
    /// The resident picked up.
    case answered = 0
    /// The call is muted or otherwise parked.
    case hold
    /// Media is flowing in both directions.
    case talking
    /// Declining a ringing call, or leaving one that never connected — this
    /// device did not answer. The resident's other devices stop ringing.
    case busy

    /// Ending a call this device answered.
    case hangup
}
