//
//  UnlockRequest.swift
//  calls
//

import Foundation

/// Body of the unlock call. `room` ties the unlock to the video call it
/// happened during; `entrySystemId` is the calling intercom from the ring
/// event — the visitor is standing at that door.
struct UnlockRequest: Codable {
    let room: String
    let entrySystemId: String
}
