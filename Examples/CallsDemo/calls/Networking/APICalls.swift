//
//  APICalls.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import Foundation

/// The demo's backend calls against the 1VALET Public API.
///
/// Everything here is *your* responsibility in a real integration — the SDK
/// handles media only and never contacts a backend itself. Static because the
/// demo has a single hard-coded occupant; a real app would inject this.
struct APICalls {
    // Placeholders — fill in with your own 1VALET API base URL and IDs.
    /// Base URL of your 1VALET API environment.
    static let baseUrl = "http://192.168.86.85:5266"

    /// Building the demo occupant belongs to.
    static let buildingId = "5f325d2b-8be1-4233-a3d3-2bdbf08afbb2"
    /// Occupant this demo acts as, i.e. the resident receiving calls.
    static let occupantId = "9ee885a2-95e8-4aa3-90ab-08ded6aa7be5"

    /// Requests an access token for a video room.
    ///
    /// Call this before `CallManager.joinRoom` — the SDK expects a token it did
    /// not fetch, so this hop through your backend is required.
    ///
    /// - Parameters:
    ///   - roomId: The video room to get a token for.
    ///   - occupantId: The occupant joining the room.
    /// - Returns: The token and participant identifier, or `nil` if the URL was
    ///   malformed.
    /// - Throws: A `NetworkError` if the request or decoding fails.
    static func getTokenAndParticipant(roomId: String, occupantId: String) async throws -> TokenAndParticipantResponse? {
        guard let url = URL(string: baseUrl + "/api/v1/video-calls/rooms/\(roomId)/tokens") else {
            print("Invalid GET URL")
            return nil
        }

        let client = NetworkClient()
        let request = TokenAndParticipantRequest(occupantId: occupantId)
        let fetchedPost = try await client.post(
            to: url,
            payload: request,
            responseType: TokenAndParticipantResponse.self
        )

        print("✅ Token request succeeded:")
        print("Token: \(fetchedPost.data.token), Participant: \(fetchedPost.data.participantId)")
        return fetchedPost
    }

    /// Reports a call status change so the entry console can update its display.
    ///
    /// - Parameters:
    ///   - occupantId: The occupant on the call.
    ///   - roomId: The video room the call is using.
    ///   - participantId: Participant identifier from `getTokenAndParticipant`.
    ///   - entryConsoleId: The console that placed the call.
    ///   - status: The new call status.
    /// - Returns: `true` on success, `false` if the URL was malformed.
    /// - Throws: A `NetworkError` if the request fails.
    static func updateStatus(occupantId: String, roomId: String, participantId: String, entryConsoleId: String, status: CallStatus) async throws -> Bool {
        guard let url = URL(string: baseUrl + "/api/v1/video-calls/rooms/\(roomId)/update-status") else {
            print("Invalid POST URL")
            return false
        }
                
        let client = NetworkClient()
        let request = UpdateCallStatusRequest(
            participantId: participantId,
            occupantId: occupantId,
            entryConsoleId: entryConsoleId,
            callStatus: status
        )
        
        return try await client.post(
            to: url,
            payload: request
        )
    }

    /// Registers this device's VoIP push token so the backend can reach it for
    /// calls.
    ///
    /// - Parameters:
    ///   - buildingId: Building the occupant belongs to.
    ///   - occupantId: Occupant this device belongs to.
    ///   - apnsDeviceToken: VoIP push token from PushKit.
    /// - Returns: `true` on success, `false` if the URL was malformed.
    /// - Throws: A `NetworkError` if the request fails.
    static func registerDevice(buildingId: String, occupantId: String, apnsDeviceToken: String) async throws -> Bool {
        guard let url = URL(string: baseUrl + "/api/v1/devices/register") else {
            print("Invalid POST URL")
            return false
        }
        
        let client = NetworkClient()
        let request = DeviceRegistrationRequest(
            occupantId: occupantId,
            buildingId: buildingId,
            apnsDeviceToken: apnsDeviceToken
        )
        return try await client.post(
            to: url,
            payload: request
        )
    }

    /// Fetches the occupant's profile. Used at launch as a cheap check that the
    /// configured base URL and IDs are valid.
    ///
    /// - Parameters:
    ///   - buildingId: Building the occupant belongs to.
    ///   - occupantId: Occupant to look up.
    /// - Returns: The occupant profile, or `nil` if the URL was malformed.
    /// - Throws: A `NetworkError` if the request or decoding fails.
    static func getProfile(buildingId: String, occupantId: String) async throws -> OccupantResponse? {
        
        guard let url = URL(string: baseUrl + "/api/v1/occupants/\(occupantId)?buildingId=\(buildingId)") else {
            print("Invalid POST URL")
            return nil
        }
        
        let client = NetworkClient()

        return try await client.get(from: url, responseType: OccupantResponse.self)
    }

    /// Unlocks the door on the entry console that placed the call.
    ///
    /// - Parameters:
    ///   - buildingId: Building containing the entry console.
    ///   - occupantId: Occupant authorizing the unlock.
    ///   - entryConsoleId: Entry console whose door to unlock.
    /// - Returns: `true` if the door was unlocked, `false` if the URL was malformed.
    /// - Throws: A `NetworkError` if the request fails.
    static func unlock(buildingId: String, occupantId: String, entryConsoleId: String) async throws -> Bool {
        guard let url = URL(string: baseUrl + "/api/buildings/\(buildingId)/entry-systems/\(entryConsoleId)/unlock") else {
            print("Invalid POST URL")
            return false
        }
        let request = UnlockEntryConsoleDoorRequest(occupantId: occupantId)
        let client = NetworkClient()
        return try await client.post(to: url, payload: request)
    }
}
