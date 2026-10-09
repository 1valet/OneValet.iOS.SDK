//
//  CallStatus.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import Foundation

/// Call lifecycle status reported to the backend, sent by name on the wire
/// ("Answered", "Hold", ...) — the format the 1VALET Public API documents.
enum CallStatus: String, Codable {
    /// The resident accepted the call.
    case answered = "Answered"
    /// The call is on hold.
    case hold = "Hold"
    /// The call is in progress.
    case talking = "Talking"
    /// Declining a ringing call, or leaving one that never connected — this
    /// device did not answer. The resident's other devices stop ringing.
    case busy = "Busy"
    /// Ending a call this device answered.
    case hangup = "Hangup"
}
