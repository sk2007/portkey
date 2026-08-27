import SwiftUI

public struct StatusBadge: View {
    public let text: String
    public let systemImage: String?
    public let foregroundColor: Color
    public let backgroundColor: Color
    
    public init(
        text: String,
        systemImage: String? = nil,
        foregroundColor: Color = .primary,
        backgroundColor: Color = Color(nsColor: .quaternaryLabelColor)
    ) {
        self.text = text
        self.systemImage = systemImage
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .foregroundColor(foregroundColor)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(backgroundColor)
        )
    }
}

public struct ProtocolBadge: View {
    public let protocolType: TransportProtocol
    
    public init(protocolType: TransportProtocol) {
        self.protocolType = protocolType
    }
    
    public var body: some View {
        StatusBadge(
            text: protocolType.rawValue,
            foregroundColor: protocolType == .tcp ? .blue : .orange,
            backgroundColor: (protocolType == .tcp ? Color.blue : Color.orange).opacity(0.15)
        )
    }
}

public struct AddressBadge: View {
    public let address: String
    public let isLocalhost: Bool
    public let isWildcard: Bool
    
    public init(address: String, isLocalhost: Bool, isWildcard: Bool) {
        self.address = address
        self.isLocalhost = isLocalhost
        self.isWildcard = isWildcard
    }
    
    public var body: some View {
        if isLocalhost {
            StatusBadge(
                text: "localhost",
                systemImage: "lock.shield",
                foregroundColor: .green,
                backgroundColor: Color.green.opacity(0.12)
            )
        } else if isWildcard {
            StatusBadge(
                text: "0.0.0.0 (All)",
                systemImage: "globe",
                foregroundColor: .amberColor,
                backgroundColor: Color.orange.opacity(0.12)
            )
        } else {
            StatusBadge(
                text: address,
                systemImage: "network",
                foregroundColor: .secondary,
                backgroundColor: Color(nsColor: .quaternaryLabelColor)
            )
        }
    }
}

extension Color {
    static let amberColor = Color(red: 0.95, green: 0.6, blue: 0.0)
}
