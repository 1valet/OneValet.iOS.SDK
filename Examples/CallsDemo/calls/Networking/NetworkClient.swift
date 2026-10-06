//
//  NetworkClient.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import Foundation

/// A centralized struct to handle all networking operations.
/// This approach makes the networking layer clean, reusable, and testable.
struct NetworkClient {

    // MARK: - GET Request

    /// Performs a generic GET request to a given URL and decodes the response
    /// into an arbitrary Decodable type.
    ///
    /// - Parameters:
    ///   - url: The URL to fetch data from.
    ///   - responseType: The expected response model type conforming to `Decodable`.
    /// - Returns: An instance of the decoded `ResponseType`.
    func get<Response: Decodable>(
        from url: URL,
        responseType: Response.Type
    ) async throws -> Response {

        // 1. Create the Request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add required header to specify we accept JSON
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // 2. Perform the Request
        let (data, response) = try await URLSession.shared.data(for: request)

        if let responseString = String(data: data, encoding: .utf8) {
            print("✅ URL: \(url.absoluteString) API Response String:")
            print(responseString)
        } else {
            print("❌ Could not convert data to string using UTF-8.")
        }
        
        // 3. Validate the Response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // Check for success status codes (200-299)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        // 4. Decode the Response Data
        do {
            let decodedResponse = try JSONDecoder().decode(Response.self, from: data)
            return decodedResponse
        } catch {
            // Throw a custom error if decoding fails
            throw NetworkError.decodingFailed(error)
        }
    }
    
    // MARK: - POST Request (decoded response)

    /// Performs a generic POST request to a given URL, encoding an arbitrary Encodable payload
    /// and decoding the response into an arbitrary Decodable type.
    ///
    /// - Parameters:
    ///   - url: The URL to post the data to.
    ///   - payload: The data model conforming to `Encodable` to be sent in the request body.
    ///   - responseType: The expected response model type conforming to `Decodable`.
    /// - Returns: An instance of the decoded `ResponseType`.
    func post<Payload: Encodable, Response: Decodable>(
        to url: URL,
        payload: Payload,
        responseType: Response.Type
    ) async throws -> Response {
        
        // 1. Create the Request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add required headers for JSON content
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // 2. Encode the Payload
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            // Throw a custom error if encoding fails
            throw NetworkError.encodingFailed(error)
        }

        // 3. Perform the Request
        let (data, response) = try await URLSession.shared.data(for: request)

        if let responseString = String(data: data, encoding: .utf8) {
            print("✅ URL: \(url.absoluteString) API Response String:")
            print(responseString)
        } else {
            print("❌ Could not convert data to string using UTF-8.")
        }
        
        // 4. Validate the Response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // Check for success status codes (200-299)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        // 5. Decode the Response Data
        do {
            let decodedResponse = try JSONDecoder().decode(Response.self, from: data)
            return decodedResponse
        } catch {
            // Throw a custom error if decoding fails
            throw NetworkError.decodingFailed(error)
        }
    }
    
    // MARK: - POST Request (success only)

    /// Performs a generic POST request to a given URL, encoding an arbitrary Encodable payload
    /// and decoding the response into an arbitrary Decodable type.
    ///
    /// - Parameters:
    ///   - url: The URL to post the data to.
    ///   - payload: The data model conforming to `Encodable` to be sent in the request body.
    /// - Returns: A boolean for success.
    func post<Payload: Encodable>(
        to url: URL,
        payload: Payload
    ) async throws -> Bool {
        
        // 1. Create the Request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add required headers for JSON content
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // 2. Encode the Payload
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            // Throw a custom error if encoding fails
            throw NetworkError.encodingFailed(error)
        }

        // 3. Perform the Request
        let (data, response) = try await URLSession.shared.data(for: request)

        if let responseString = String(data: data, encoding: .utf8) {
            print("✅ URL: \(url.absoluteString) API Response String:")
            print(responseString)
        } else {
            print("❌ Could not convert data to string using UTF-8.")
        }
        
        // 4. Validate the Response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // Check for success status codes (200-299)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        return true
    }
    
}

// MARK: - Helper Structures for Networking

/// Custom error types for better error handling.
enum NetworkError: LocalizedError {
    /// The request payload could not be encoded to JSON.
    case encodingFailed(Error)
    /// The response body did not match the expected model.
    case decodingFailed(Error)
    /// The response was not an `HTTPURLResponse`.
    case invalidResponse
    /// The server replied with a status code outside 200–299.
    case httpError(Int)

    /// Human-readable description, surfaced through `localizedDescription`.
    var errorDescription: String? {
        switch self {
        case .encodingFailed(let error):
            return "Failed to encode request payload: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received an invalid response type (not HTTP)."
        case .httpError(let statusCode):
            return "HTTP error code: \(statusCode)"
        }
    }
}
