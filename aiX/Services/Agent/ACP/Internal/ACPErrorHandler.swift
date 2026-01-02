//
//  ACPErrorHandler.swift
//  aizen
//
//  Error handling and error type definitions for ACP client
//

import Foundation

enum ACPClientError: Error, LocalizedError {
    case processNotRunning
    case processFailed(Int32)
    case invalidResponse
    case requestTimeout
    case encodingError
    case decodingError(Error)
    case agentError(JSONRPCError)
    case delegateNotSet
    case fileNotFound(String)
    case fileOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .processNotRunning:
            return "Agent process is not running"
        case .processFailed(let code):
            return "Agent process failed with exit code \(code)"
        case .invalidResponse:
            return "Invalid response from agent"
        case .requestTimeout:
            return "Request timed out"
        case .encodingError:
            return "Failed to encode request"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .agentError(let jsonError):
            // Extract the actual error message from the JSON-RPC error

            // Case 1: data is a plain string (Codex)
            if let dataString = jsonError.data?.value as? String {
                return dataString
            }

            // Case 2: data is an object with details
            if let data = jsonError.data?.value as? [String: Any],
               let details = data["details"] as? String {
                // Try to parse nested error details (Gemini)
                if let detailsData = details.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: detailsData) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    return message
                }
                return details
            }

            // Case 3: Fallback to generic message
            return jsonError.message
        case .delegateNotSet:
            return "Internal error: Delegate not set"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileOperationFailed(let message):
            return "File operation failed: \(message)"
        }
    }
}

actor ACPErrorHandler {
    // MARK: - Properties

    private let encoder: JSONEncoder

    // MARK: - Initialization

    init(encoder: JSONEncoder) {
        self.encoder = encoder
    }

    // MARK: - Error Response Creation

    func createErrorResponse(
        requestId: RequestId,
        code: Int,
        message: String
    ) throws -> JSONRPCResponse {
        let error = JSONRPCError(code: code, message: message, data: nil)
        return JSONRPCResponse(id: requestId, result: nil, error: error)
    }

    // MARK: - Error Handling

    func handleError(_ error: Error) -> String {
        if let acpError = error as? ACPClientError {
            return acpError.errorDescription ?? error.localizedDescription
        }
        return error.localizedDescription
    }

    func extractAgentError(from response: JSONRPCResponse) -> Error? {
        if let error = response.error {
            return ACPClientError.agentError(error)
        }
        return nil
    }
}
