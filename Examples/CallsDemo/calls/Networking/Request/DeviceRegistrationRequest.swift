//
//  DeviceRegistrationRequest.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

/// Body for registering a device's push tokens with the backend.
struct DeviceRegistrationRequest: Codable {
    /// Occupant this device belongs to.
     let occupantId: String
    /// Building the occupant belongs to.
     let buildingId: String
    /// VoIP push token from PushKit — the only token this app registers.
     let apnsDeviceToken: String
    /// Platform discriminator expected by the API; `1` identifies iOS.
    var platform = 1
//     let DeviceModel: String?
//     let OsVersion: String?
//     let AppVersion: String?
}
