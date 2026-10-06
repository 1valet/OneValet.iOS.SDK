//
//  OccupantResponse.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-18.
//
import Foundation

/// Envelope wrapping an occupant profile response.
struct OccupantResponse: Codable {
    /// The occupant, or `nil` if none was found.
    let data: Occupant?
}

/// A resident's profile as returned by the 1VALET API.
///
/// Every field is optional because the API omits values the caller is not
/// entitled to see.
struct Occupant: Codable {
    /// Unique identifier for the occupant.
    let occupantId: String?
    /// Display name, typically first and last combined.
    let name: String?
    /// Identifier of the suite the occupant lives in.
    let suiteId: String?
    /// Human-readable suite number, e.g. `"1203"`.
    let suiteNumber: String?
    /// Given name.
    let firstname: String?
    /// Family name.
    let lastname: String?
    /// Date the occupant moved in, as returned by the API.
    let moveInDate: String?
    /// Date the occupant moves out, if scheduled.
    let moveOutDate: String?
    /// Contact email address.
    let email: String?
    /// Contact phone number.
    let phoneNumber: String?
    /// Code visitors dial on the entry console to reach this occupant.
    let directoryCode: String?
}
