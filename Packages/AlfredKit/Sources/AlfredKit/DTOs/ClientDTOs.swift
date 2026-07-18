// Packages/AlfredKit/Sources/AlfredKit/DTOs/ClientDTOs.swift
import Foundation

/// Text message sent from client to server.
public struct TextMessageDTO: Codable, Sendable {
    public let type: String
    public let content: String
    public let identity: String
    public let channel: String
    public let sessionId: String?
    public let timezone: String?

    public init(type: String = "text", content: String, identity: String, channel: String = "ios", sessionId: String? = nil, timezone: String? = TimeZone.current.identifier) {
        self.type = type
        self.content = content
        self.identity = identity
        self.channel = channel
        self.sessionId = sessionId
        self.timezone = timezone
    }

    enum CodingKeys: String, CodingKey {
        case type, content, identity, channel, timezone
        case sessionId = "session_id"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(identity, forKey: .identity)
        try container.encode(channel, forKey: .channel)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(timezone, forKey: .timezone)
    }
}

/// Audio message sent from client to server (base64 data URL).
public struct AudioMessageDTO: Codable, Sendable {
    public let type: String
    public let content: String
    public let identity: String
    public let channel: String
    public let timezone: String?

    public init(type: String = "audio", content: String, identity: String, channel: String = "ios", timezone: String? = TimeZone.current.identifier) {
        self.type = type
        self.content = content
        self.identity = identity
        self.channel = channel
        self.timezone = timezone
    }
}

/// Device token registration for APNs push notifications.
public struct DeviceRegistrationDTO: Codable, Sendable {
    public let deviceToken: String
    public let platform: String
    public let identity: String

    public init(deviceToken: String, platform: String = "ios", identity: String = "sir") {
        self.deviceToken = deviceToken
        self.platform = platform
        self.identity = identity
    }

    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
        case platform, identity
    }
}

/// Device token removal.
public struct DeviceUnregistrationDTO: Codable, Sendable {
    public let deviceToken: String

    public init(deviceToken: String) {
        self.deviceToken = deviceToken
    }

    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
    }
}

/// Onboarding preferences submission.
public struct OnboardingDTO: Codable, Sendable {
    public let wakeTime: String?
    public let workAddress: String?
    public let dietaryRestrictions: String?
    public let proactivityLevel: String?
    public let guestControls: [String]?

    public init(
        wakeTime: String? = nil,
        workAddress: String? = nil,
        dietaryRestrictions: String? = nil,
        proactivityLevel: String? = nil,
        guestControls: [String]? = nil
    ) {
        self.wakeTime = wakeTime
        self.workAddress = workAddress
        self.dietaryRestrictions = dietaryRestrictions
        self.proactivityLevel = proactivityLevel
        self.guestControls = guestControls
    }

    enum CodingKeys: String, CodingKey {
        case wakeTime = "wake_time"
        case workAddress = "work_address"
        case dietaryRestrictions = "dietary_restrictions"
        case proactivityLevel = "proactivity_level"
        case guestControls = "guest_controls"
    }
}
