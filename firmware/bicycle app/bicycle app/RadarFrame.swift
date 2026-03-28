//
//  RadarFrame.swift
//  bicycle app
//

import Foundation

struct RadarFrame: Codable, Identifiable, Sendable {
    let targetId: Int
    let angle: Int
    let distance: Int
    let speed: Int
    let direction: String

    let id = UUID()
    let receivedAt = Date()

    enum CodingKeys: String, CodingKey {
        case targetId = "target_id"
        case angle, distance, speed, direction
    }

    var isApproaching: Bool { direction == "近" }

    var sideDescription: String {
        if angle < -2 { return "左侧" }
        if angle > 2 { return "右侧" }
        return "后方"
    }
}
