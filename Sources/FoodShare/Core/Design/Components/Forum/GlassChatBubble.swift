//
//  GlassChatBubble.swift
//  Foodshare
//
//  Liquid Glass v27 - Chat Bubble Component
//  Glass-styled chat bubbles with tail morphing and status indicators
//


#if !SKIP
import SwiftUI

// MARK: - Glass Chat Bubble

/// A glass-styled chat bubble for messaging interfaces
///
/// Features:
/// - Incoming/outgoing bubble styles
/// - Animated tail with morphing effect
/// - Read receipt and delivery status
/// - Timestamp display
/// - Reactions support
/// - Reply preview
///
/// Example usage:
/// ```swift
/// GlassChatBubble(
///     message: "Hello!",
///     isOutgoing: true,
///     status: .read,
///     timestamp: Date()
/// )
///
/// GlassChatBubble(
///     message: "Hi there! How are you?",
///     isOutgoing: false,
///     senderName: "John",
///     senderAvatar: avatarURL
/// )
/// ```
struct GlassChatBubble: View {
    let message: String
    let isOutgoing: Bool
    let status: MessageStatus
    let timestamp: Date?
    let senderName: String?
    let senderAvatar: URL?
    let reactions: [Reaction]
    let replyTo: ReplyPreview?
    let isSequential: Bool

    @State private var isAppearing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    // MARK: - Initialization

    init(
        message: String,
        isOutgoing: Bool,
        status: MessageStatus = .sent,
        timestamp: Date? = nil,
        senderName: String? = nil,
        senderAvatar: URL? = nil,
        reactions: [Reaction] = [],
        replyTo: ReplyPreview? = nil,
        isSequential: Bool = false
    ) {
        self.message = message
        self.isOutgoing = isOutgoing
        self.status = status
        self.timestamp = timestamp
        self.senderName = senderName
        self.senderAvatar = senderAvatar
        self.reactions = reactions
        self.replyTo = replyTo
        self.isSequential = isSequential
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            if isOutgoing {
                Spacer(minLength: 60)
            } else if !isSequential {
                avatarView
            } else {
                Spacer()
                    .frame(width: 32.0)
            }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: Spacing.xxxs) {
                // Sender name (for group chats)
                if let name = senderName, !isOutgoing, !isSequential {
                    Text(name)
                        .font(.DesignSystem.captionMedium)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .padding(.leading, Spacing.sm)
                }

                // Reply preview
                if let reply = replyTo {
                    replyPreviewView(reply)
                }

                // Bubble
                bubbleView
                    .overlay(alignment: isOutgoing ? .bottomTrailing : .bottomLeading) {
                        // Reactions
                        if !reactions.isEmpty {
                            reactionsView
                                .offset(y: 12)
                        }
                    }

                // Status and timestamp
                if isOutgoing || timestamp != nil {
                    statusRow
                }
            }

            if !isOutgoing {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, reactions.isEmpty ? 0 : Spacing.sm)
        .opacity(isAppearing ? 1 : 0)
        .offset(x: isAppearing ? 0 : (isOutgoing ? 20 : -20))
        .onAppear {
            if !reduceMotion {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    isAppearing = true
                }
            } else {
                isAppearing = true
            }
        }
    }

    // MARK: - Subviews

    private var avatarView: some View {
        Group {
            if let url = senderAvatar {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.DesignSystem.glassBorder)
                }
            } else {
                Circle()
                    .fill(Color.DesignSystem.glassBorder)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    )
            }
        }
        .frame(width: 32.0, height: 32)
        .clipShape(Circle())
    }

    private var bubbleView: some View {
        Text(message)
            .font(.DesignSystem.bodyMedium)
            .foregroundStyle(isOutgoing ? .white : Color.DesignSystem.textPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(bubbleBackground)
            .clipShape(ChatBubbleShape(isOutgoing: isOutgoing, showTail: !isSequential))
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isOutgoing {
            LinearGradient(
                colors: [
                    Color.DesignSystem.brandGreen,
                    Color.DesignSystem.brandGreen.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.clear
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func replyPreviewView(_ reply: ReplyPreview) -> some View {
        HStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.DesignSystem.brandGreen)
                .frame(width: 3.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(reply.senderName)
                    .font(.DesignSystem.captionMedium)
                    .foregroundStyle(Color.DesignSystem.brandGreen)

                Text(reply.message)
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(Color.DesignSystem.glassBackground)
        )
        .padding(.horizontal, Spacing.xxs)
    }

    private var reactionsView: some View {
        HStack(spacing: 2) {
            ForEach(reactions.prefix(3), id: \.emoji) { reaction in
                Text(reaction.emoji)
                    .font(.system(size: 12))
            }

            if reactions.count > 3 {
                Text("+\(reactions.count - 3)")
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxxs)
        .background(
            Capsule()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private var statusRow: some View {
        HStack(spacing: Spacing.xxxs) {
            if let time = timestamp {
                Text(formattedTime(time))
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
            }

            if isOutgoing {
                statusIcon
            }
        }
        .padding(.horizontal, Spacing.xxs)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .sending:
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundStyle(Color.DesignSystem.textTertiary)

        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 10))
                .foregroundStyle(Color.DesignSystem.textTertiary)

        case .delivered:
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 10))
            .foregroundStyle(Color.DesignSystem.textTertiary)

        case .read:
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 10))
            .foregroundStyle(Color.DesignSystem.brandGreen)

        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.DesignSystem.error)
        }
    }

    // MARK: - Helpers

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Bubble Shape

struct ChatBubbleShape: Shape {
    let isOutgoing: Bool
    let showTail: Bool
    let cornerRadius: CGFloat

    init(isOutgoing: Bool, showTail: Bool = true, cornerRadius: CGFloat = 16) {
        self.isOutgoing = isOutgoing
        self.showTail = showTail
        self.cornerRadius = cornerRadius
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tailSize: CGFloat = showTail ? 8 : 0
        let tailInset: CGFloat = 4

        if isOutgoing {
            // Outgoing bubble (right side)
            path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )

            if showTail {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tailInset - tailSize))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX + tailSize, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY - tailInset)
                )
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            } else {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
                path.addArc(
                    center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false
                )
            }

            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        } else {
            // Incoming bubble (left side)
            path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))

            if showTail {
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX - tailSize, y: rect.maxY),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.maxY - tailInset - tailSize),
                    control: CGPoint(x: rect.minX, y: rect.maxY - tailInset)
                )
            } else {
                path.addArc(
                    center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false
                )
            }

            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Supporting Types

extension GlassChatBubble {
    enum MessageStatus {
        case sending
        case sent
        case delivered
        case read
        case failed
    }

    struct Reaction: Identifiable {
        let id = UUID()
        let emoji: String
        let count: Int
        let userReacted: Bool
    }

    struct ReplyPreview {
        let senderName: String
        let message: String
    }
}

// MARK: - Typing Indicator Bubble

struct GlassTypingIndicator: View {
    let senderName: String?

    @State private var animationPhase: Int = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            Circle()
                .fill(Color.DesignSystem.glassBorder)
                .frame(width: 32.0, height: 32)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                if let name = senderName {
                    Text(name)
                        .font(.DesignSystem.captionMedium)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .padding(.leading, Spacing.sm)
                }

                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.DesignSystem.textSecondary)
                            .frame(width: 8.0, height: 8)
                            .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                            .opacity(animationPhase == index ? 1 : 0.5)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Color.clear
                        #if !SKIP
                        .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .background(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                        .clipShape(ChatBubbleShape(isOutgoing: false))
                        .overlay(
                            ChatBubbleShape(isOutgoing: false)
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                        )
                )
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).repeatForever()) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Preview

#Preview("Glass Chat Bubble") {
    ScrollView {
        VStack(spacing: Spacing.sm) {
            Text("Glass Chat Bubbles")
                .font(.DesignSystem.displayMedium)
                .foregroundStyle(Color.DesignSystem.textPrimary)
                .padding(.bottom, Spacing.lg)

            // Incoming message
            GlassChatBubble(
                message: "Hey! Is the produce still available?",
                isOutgoing: false,
                status: .read,
                timestamp: Date(),
                senderName: "Sarah"
            )

            // Outgoing message
            GlassChatBubble(
                message: "Yes! I have fresh tomatoes and lettuce.",
                isOutgoing: true,
                status: .read,
                timestamp: Date()
            )

            // Sequential messages
            GlassChatBubble(
                message: "I can bring them to you today",
                isOutgoing: true,
                status: .delivered,
                timestamp: Date(),
                isSequential: true
            )

            // With reactions
            GlassChatBubble(
                message: "That would be amazing! Thank you so much!",
                isOutgoing: false,
                status: .read,
                timestamp: Date(),
                reactions: [
                    .init(emoji: "❤️", count: 1, userReacted: true),
                    .init(emoji: "👍", count: 1, userReacted: false)
                ]
            )

            // With reply
            GlassChatBubble(
                message: "I'll be there at 3pm",
                isOutgoing: true,
                status: .sent,
                timestamp: Date(),
                replyTo: .init(senderName: "Sarah", message: "When can you come?")
            )

            // Sending state
            GlassChatBubble(
                message: "See you then!",
                isOutgoing: true,
                status: .sending,
                timestamp: Date()
            )

            // Typing indicator
            GlassTypingIndicator(senderName: "Sarah")
        }
        .padding(.vertical, Spacing.lg)
    }
    .background(Color.DesignSystem.background)
}

#endif
