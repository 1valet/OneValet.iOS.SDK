//
//  NetworkClient.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import Foundation

/// A centralized struct to handle all networking operations.
/// This approach makes the networking layer clean, reusable, and testable.
/// Besides request/response calls it can hold a Server-Sent Events stream
/// open (see `readEventStream`).
struct NetworkClient {

    // MARK: - POST Request (decoded response)

    /// Performs a generic POST request to a given URL, encoding an arbitrary Encodable payload
    /// and decoding the response into an arbitrary Decodable type.
    ///
    /// - Parameters:
    ///   - url: The URL to post the data to.
    ///   - payload: The data model conforming to `Encodable` to be sent in the request body.
    ///   - bearerToken: Optional bearer token for the `Authorization` header.
    ///   - responseType: The expected response model type conforming to `Decodable`.
    /// - Returns: An instance of the decoded `ResponseType`.
    func post<Payload: Encodable, Response: Decodable>(
        to url: URL,
        payload: Payload,
        bearerToken: String? = nil,
        responseType: Response.Type
    ) async throws -> Response {
        print("➡️ POST \(url.absoluteString) payload=\(Payload.self) expecting=\(Response.self)")

        var request = makeRequest(url: url, method: "POST", bearerToken: bearerToken)

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            print("📦 Encoded \(Payload.self) (\(request.httpBody?.count ?? 0) bytes)")
        } catch {
            print("❌ Encoding \(Payload.self) failed: \(error.localizedDescription)")
            throw NetworkError.encodingFailed(error)
        }

        let data = try await perform(request)

        do {
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            print("✅ Decoded \(Response.self) from \(url.absoluteString)")
            return decoded
        } catch {
            print("❌ Decoding \(Response.self) failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }

    // MARK: - POST Request (no body, decoded response)

    /// Performs a POST request with an empty body and decodes the response.
    ///
    /// - Parameters:
    ///   - url: The URL to post to.
    ///   - bearerToken: Optional bearer token for the `Authorization` header.
    ///   - responseType: The expected response model type conforming to `Decodable`.
    /// - Returns: An instance of the decoded `ResponseType`.
    func post<Response: Decodable>(
        to url: URL,
        bearerToken: String? = nil,
        responseType: Response.Type
    ) async throws -> Response {
        print("➡️ POST \(url.absoluteString) (no body) expecting=\(Response.self)")

        let request = makeRequest(url: url, method: "POST", bearerToken: bearerToken)

        let data = try await perform(request)

        do {
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            print("✅ Decoded \(Response.self) from \(url.absoluteString)")
            return decoded
        } catch {
            print("❌ Decoding \(Response.self) failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }

    // MARK: - POST Request (success only)

    /// Performs a generic POST request to a given URL, encoding an arbitrary Encodable payload.
    ///
    /// - Parameters:
    ///   - url: The URL to post the data to.
    ///   - payload: The data model conforming to `Encodable` to be sent in the request body.
    ///   - bearerToken: Optional bearer token for the `Authorization` header.
    /// - Returns: A boolean for success.
    func post<Payload: Encodable>(
        to url: URL,
        payload: Payload,
        bearerToken: String? = nil
    ) async throws -> Bool {
        print("➡️ POST \(url.absoluteString) payload=\(Payload.self) (success only)")

        var request = makeRequest(url: url, method: "POST", bearerToken: bearerToken)

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            print("📦 Encoded \(Payload.self) (\(request.httpBody?.count ?? 0) bytes)")
        } catch {
            print("❌ Encoding \(Payload.self) failed: \(error.localizedDescription)")
            throw NetworkError.encodingFailed(error)
        }

        _ = try await perform(request)
        print("✅ POST \(url.absoluteString) succeeded")
        return true
    }

    // MARK: - Server-Sent Events

    /// Opens `url` as a Server-Sent Events stream and invokes `onEvent` for every
    /// event until `onEvent` returns `false` (stop listening), the server closes
    /// the connection, the surrounding task is cancelled, or the connection drops
    /// (an error — callers reconnect with backoff). Heartbeat comments
    /// (`: keep-alive`) are consumed silently.
    ///
    /// - Parameters:
    ///   - url: The stream URL.
    ///   - bearerToken: Bearer token for the `Authorization` header.
    ///   - onEvent: Receives `(event, data)` per event; return `false` to stop.
    func readEventStream(
        from url: URL,
        bearerToken: String,
        onEvent: (String, String) async -> Bool
    ) async throws {
        print("📡 Opening event stream \(url.absoluteString)")

        var request = makeRequest(url: url, method: "GET", bearerToken: bearerToken)
        // The shared builder advertises JSON; this endpoint speaks SSE.
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        // URLSession offers gzip by default, and a compressing server (or proxy)
        // then buffers the response — holding events back indefinitely on a
        // stream that never ends. Ask for no encoding at all.
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        // A dedicated session: the shared session's 60 s request timeout would
        // kill an idle stream. The server's heartbeats prove liveness instead.
        // Set on the request too — URLRequest carries its own 60 s default,
        // which otherwise wins over the session configuration.
        let streamTimeout: TimeInterval = 24 * 60 * 60
        request.timeoutInterval = streamTimeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = streamTimeout
        let session = URLSession(configuration: configuration)
        defer {
            print("📡 Event stream session finished \(url.absoluteString)")
            session.finishTasksAndInvalidate()
        }

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Event stream \(url.absoluteString) returned a non-HTTP response")
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Event stream \(url.absoluteString) rejected with status \(httpResponse.statusCode)")
            throw httpResponse.statusCode == 401
                ? NetworkError.unauthorized
                : NetworkError.httpError(httpResponse.statusCode)
        }

        print("📡 Event stream connected (\(httpResponse.statusCode)) \(url.absoluteString)")

        var eventName = "message"
        var data = ""

        // Deliberately not `bytes.lines`: Foundation's AsyncLineSequence drops
        // empty lines, and an empty line is exactly what terminates an SSE
        // event — with it swallowed, no event ever dispatches. Split by hand.
        var lineBytes: [UInt8] = []

        for try await byte in bytes {
            guard byte == UInt8(ascii: "\n") else {
                lineBytes.append(byte)
                continue
            }

            var line = String(decoding: lineBytes, as: UTF8.self)
            lineBytes.removeAll(keepingCapacity: true)
            if line.hasSuffix("\r") {
                line.removeLast()
            }

            print("\u{1F4C4} raw line: \(line.isEmpty ? "<blank>" : line)")
            if line.isEmpty {
                if !data.isEmpty {
                    print("📨 Event '\(eventName)' (\(data.count) bytes)")
                    let keepListening = await onEvent(eventName, data)
                    if !keepListening {
                        print("📡 Handler asked to stop listening — closing stream")
                        return
                    }
                }
                eventName = "message"
                data = ""
            } else if line.hasPrefix(":") {
                // Heartbeat comment.
            } else if line.hasPrefix("event:") {
                eventName = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                if !data.isEmpty {
                    data += "\n"
                }
                data += String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces)
            }
        }

        print("📡 Event stream closed by server \(url.absoluteString)")
    }

    // MARK: - Internals

    private func makeRequest(url: URL, method: String, bearerToken: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        print("🛠️ Built \(method) \(url.absoluteString) (authorized: \(bearerToken != nil))")
        return request
    }

    /// Performs the request, logs the response, and validates the status code.
    private func perform(_ request: URLRequest) async throws -> Data {
        let method = request.httpMethod ?? "GET"
        let urlString = request.url?.absoluteString ?? "<no url>"
        print("🚀 Sending \(method) \(urlString)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("❌ Transport failure for \(method) \(urlString): \(error.localizedDescription)")
            throw error
        }

        if let url = request.url, let responseString = String(data: data, encoding: .utf8) {
            print("✅ URL: \(url.absoluteString) API Response String:")
            print(responseString)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ \(method) \(urlString) returned a non-HTTP response")
            throw NetworkError.invalidResponse
        }

        print("📥 \(httpResponse.statusCode) \(method) \(urlString) (\(data.count) bytes)")

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ \(method) \(urlString) failed with status \(httpResponse.statusCode)")
            throw httpResponse.statusCode == 401
                ? NetworkError.unauthorized
                : NetworkError.httpError(httpResponse.statusCode)
        }

        return data
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
    /// The server rejected the bearer token — the pairing expired or was revoked.
    case unauthorized
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
        case .unauthorized:
            return "The pairing token was rejected (401)."
        case .httpError(let statusCode):
            return "HTTP error code: \(statusCode)"
        }
    }
}
