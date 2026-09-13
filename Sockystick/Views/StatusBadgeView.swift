//
//  StatusBadgeView.swift
//  Sockystick
//

import SwiftUI

public struct StatusBadgeView: View {
    public let isEnabled: Bool

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .shadow(color: isEnabled ? Color.green.opacity(0.6) : Color.clear, radius: 4)
            
            Text(isEnabled ? "SOCKS5 Active" : "Proxy Disabled")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isEnabled ? .green : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isEnabled ? Color.green.opacity(0.15) : Color.gray.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(isEnabled ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
