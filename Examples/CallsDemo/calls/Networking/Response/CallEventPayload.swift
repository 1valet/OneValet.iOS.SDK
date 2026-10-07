//
//  CallEventPayload.swift
//  calls
//

import Foundation

/// A "video-call" SSE event: the 1VALET `VideoCall` webhook payload, relayed
/// verbatim by the portal — PascalCase property names, exactly as a production
/// backend receives it. Explicit `CodingKeys` rather than a decoder-wide key
/// strategy, because the demo's other DTOs are camelCase.
struct CallEventPayload: Decodable {
    let eventType: String?
    let entrySystemId: String?
    let buildingId: String?
    let occupantId: String?
    let room: String
    let videoCallState: String
    let participantId: String?
    let capabilities: CallCapabilities?

    enum CodingKeys: String, CodingKey {
        case eventType = "EventType"
        case entrySystemId = "EntrySystemId"
        case buildingId = "BuildingId"
        case occupantId = "OccupantId"
        case room = "Room"
        case videoCallState = "VideoCallState"
        case participantId = "ParticipantId"
        case capabilities = "Capabilities"
    }
}

/// What the call offers — `video == false` means present the call as audio-only.
struct CallCapabilities: Decodable {
    let video: Bool?
    let audio: Bool?

    enum CodingKeys: String, CodingKey {
        case video = "Video"
        case audio = "Audio"
    }
}
