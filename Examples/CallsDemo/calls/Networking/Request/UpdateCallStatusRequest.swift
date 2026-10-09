//
//  UpdateCallStatusRequest.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import Foundation

/// Body of the call-status report. The occupant is pinned server-side by the
/// pairing token; `entrySystemId` is the calling intercom, from the ring
/// event's payload.
struct UpdateCallStatusRequest: Codable {
    let participantId: String
    let callStatus: CallStatus
    let entrySystemId: String
}
