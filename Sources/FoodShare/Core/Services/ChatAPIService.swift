//
//  ChatAPIService.swift
//  Foodshare
//
//  REST API client for chat/messaging operations via api-v1-chat edge function.
//  Supports both generic chat rooms and food sharing chat (mode=food).
//


#if !SKIP
import Foundation

actor ChatAPIService {
    nonisolated static let shared = ChatAPIService()
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Generic Chat

    /// List user's chat rooms
    func getRooms(limit: Int = 20, cursor: String? = nil) async throws -> [ChatRoomDTO] {
        var params: [String: String] = ["limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await client.get("api-v1-chat", params: params)
    }

    /// Get a single room with messages
    func getRoom(roomId: String, limit: Int = 50, messagesBefore: String? = nil) async throws -> ChatRoomDetailResponse {
        var params: [String: String] = ["roomId": roomId, "limit": "\(limit)"]
        if let messagesBefore { params["messagesBefore"] = messagesBefore }
        return try await client.get("api-v1-chat", params: params)
    }

    /// Create a generic chat room
    func createRoom(_ request: CreateRoomRequest) async throws -> CreateRoomResponse {
        try await client.post("api-v1-chat", body: request)
    }

    /// Send a message in a generic chat room
    func sendMessage(_ request: SendMessageRequest) async throws -> ChatMessageDTO {
        try await client.post("api-v1-chat", body: request, params: ["action": "message"])
    }

    /// Update a generic room (name, mute, pin)
    func updateRoom(roomId: String, body: UpdateRoomRequest) async throws -> SuccessResponse {
        try await client.put("api-v1-chat", body: body, params: ["roomId": roomId])
    }

    /// Leave a generic room
    func leaveRoom(roomId: String) async throws {
        try await client.deleteVoid("api-v1-chat", params: ["roomId": roomId])
    }

    // MARK: - Food Sharing Chat (mode=food)

    /// List food sharing rooms
    func getFoodRooms(limit: Int = 20, cursor: String? = nil) async throws -> [ChatRoomDTO] {
        var params: [String: String] = ["mode": "food", "limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await client.get("api-v1-chat", params: params)
    }

    /// Get a food sharing room with messages
    func getFoodRoom(roomId: String, limit: Int = 50) async throws -> ChatRoomDetailResponse {
        try await client.get("api-v1-chat", params: ["mode": "food", "roomId": roomId, "limit": "\(limit)"])
    }

    /// Create a food sharing room
    func createFoodRoom(_ request: CreateFoodRoomRequest) async throws -> CreateRoomResponse {
        try await client.post("api-v1-chat", body: request, params: ["mode": "food"])
    }

    /// Send a message in a food sharing room
    func sendFoodMessage(_ request: SendFoodMessageRequest) async throws -> ChatMessageDTO {
        try await client.post("api-v1-chat", body: request, params: ["mode": "food", "action": "message"])
    }

    /// Update a food room (accept, complete, archive exchange)
    func updateFoodRoom(roomId: String, action: String) async throws -> SuccessResponse {
        try await client.put("api-v1-chat", body: FoodUpdateRoomRequest(action: action), params: ["mode": "food", "roomId": roomId])
    }

    /// Archive a food sharing room
    func archiveFoodRoom(roomId: String) async throws {
        try await client.deleteVoid("api-v1-chat", params: ["mode": "food", "roomId": roomId])
    }

    // MARK: - Convenience (mode-aware)

    /// List rooms with optional mode parameter
    func getRooms(mode: String? = nil, limit: Int = 20, cursor: String? = nil) async throws -> [ChatRoomDTO] {
        if mode == "food" {
            return try await getFoodRooms(limit: limit, cursor: cursor)
        }
        return try await getRooms(limit: limit, cursor: cursor)
    }

    /// Get room with optional mode parameter
    func getRoom(roomId: String, mode: String? = nil, limit: Int = 50) async throws -> ChatRoomDetailResponse {
        if mode == "food" {
            return try await getFoodRoom(roomId: roomId, limit: limit)
        }
        return try await getRoom(roomId: roomId, limit: limit, messagesBefore: nil)
    }

    /// Update room with optional mode parameter
    func updateRoom(roomId: String, mode: String? = nil, action: String) async throws -> SuccessResponse {
        if mode == "food" {
            return try await updateFoodRoom(roomId: roomId, action: action)
        }
        return try await updateRoom(roomId: roomId, body: UpdateRoomRequest(name: nil, isMuted: nil, isPinned: nil))
    }
}

// MARK: - DTOs

/// Room DTO matching the Edge Function transformer output (both generic and food)
struct ChatRoomDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let postId: Int?
    let post: PostSummary?
    let otherParticipant: ParticipantSummary?
    let lastMessage: String?
    let lastMessageTime: Date?
    let hasUnread: Bool?
    let isArranged: Bool?
    let arrangedAt: Date?
    let isSharer: Bool?
    let createdAt: Date?

    /// Nested post summary from the food room transformer
    struct PostSummary: Codable, Sendable {
        let id: Int?
        let name: String?
        let type: String?
        let image: String?
    }

    /// Nested participant summary
    struct ParticipantSummary: Codable, Sendable {
        let id: UUID?
        let firstName: String?
        let secondName: String?
        let avatarUrl: String?
    }
}

/// Message DTO matching the Edge Function transformer output
struct ChatMessageDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let roomId: UUID?
    let senderId: UUID?
    let text: String?
    let image: String?
    let timestamp: Date?
    let sender: ChatRoomDTO.ParticipantSummary?
}

/// Response for getting a room with messages
struct ChatRoomDetailResponse: Codable, Sendable {
    let room: ChatRoomDetailDTO
    let messages: [ChatMessageDTO]
    let hasMoreMessages: Bool?
    let oldestMessageDate: Date?
}

/// Detailed room DTO (from getRoom response)
struct ChatRoomDetailDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let postId: Int?
    let post: FoodPostDetail?
    let otherParticipant: ChatRoomDTO.ParticipantSummary?
    let lastMessage: String?
    let lastMessageTime: Date?
    let hasUnread: Bool?
    let isArranged: Bool?
    let arrangedAt: Date?
    let isSharer: Bool?
    let createdAt: Date?

    /// Detailed post info for room detail view
    struct FoodPostDetail: Codable, Sendable {
        let id: Int?
        let name: String?
        let type: String?
        let address: String?
        let images: [String]?
        let ownerId: UUID?
    }
}

// MARK: - Request Types

/// Request body for creating a generic chat room
struct CreateRoomRequest: Encodable, Sendable {
    let participantIds: [String]
    let name: String?
    let roomType: String?
}

/// Request body for creating a food sharing room
struct CreateFoodRoomRequest: Encodable, Sendable {
    let postId: Int
    let sharerId: String
    let initialMessage: String?
}

/// Request body for sending a message in a generic chat room
struct SendMessageRequest: Encodable, Sendable {
    let roomId: String
    let content: String
    let replyToId: String?
}

/// Request body for sending a message in a food chat room
struct SendFoodMessageRequest: Encodable, Sendable {
    let roomId: String
    let text: String
    let image: String?
}

/// Request body for updating a generic room
struct UpdateRoomRequest: Encodable, Sendable {
    let name: String?
    let isMuted: Bool?
    let isPinned: Bool?
}

/// Request body for updating a food room (accept/complete/archive)
struct FoodUpdateRoomRequest: Encodable, Sendable {
    let action: String
}

// MARK: - Response Types

/// Response for room creation
struct CreateRoomResponse: Codable, Sendable {
    let roomId: UUID
    let created: Bool
}

/// Generic success response
struct SuccessResponse: Codable, Sendable {
    let success: Bool
    let address: String?
}

#endif
