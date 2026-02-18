//
//  ChatMetalEffects.swift
//  Foodshare
//
//  Swift wrappers for Chat Metal shader effects
//  GPU-accelerated messaging effects optimized for ProMotion 120Hz
//


#if !SKIP
import MetalKit
import SwiftUI

// MARK: - Conditional Glow Modifier

/// ViewModifier that conditionally applies glow effects
private struct ConditionalGlowModifier: ViewModifier {
    let showGlow: Bool
    let isOutgoing: Bool
    let isRead: Bool

    func body(content: Content) -> some View {
        if showGlow {
            content.messageBubbleGlow(
                isOutgoing: isOutgoing,
                isRead: isRead,
                intensity: 0.3,
            )
        } else {
            content
        }
    }
}

// MARK: - Chat Metal Effect Type

enum ChatMetalEffect: String, CaseIterable {
    case messageBubbleGlow = "message_bubble_glow_fragment"
    case typingIndicator = "typing_indicator_fragment"
    case messageSend = "message_send_fragment"
    case unreadBadgePulse = "unread_badge_pulse_fragment"
    case onlineStatus = "online_status_fragment"
    case reactionBurst = "reaction_burst_fragment"
    case chatAmbient = "chat_ambient_background_fragment"
    case voiceWaveform = "voice_waveform_fragment"
    case readReceipt = "read_receipt_fragment"
}

// MARK: - Chat Uniforms

struct ChatShaderUniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var intensity: Float
    var primaryColor: SIMD4<Float>
    var secondaryColor: SIMD4<Float>
    var progress: Float
    var isOutgoing: Float
    var isRead: Float
}

// MARK: - Chat Metal Effect View

struct ChatMetalEffectView: UIViewRepresentable {
    let effect: ChatMetalEffect
    let intensity: Float
    let primaryColor: Color
    let secondaryColor: Color
    let progress: Float
    let isOutgoing: Bool
    let isRead: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        effect: ChatMetalEffect,
        intensity: Float = 1.0,
        primaryColor: Color = .DesignSystem.brandGreen,
        secondaryColor: Color = .DesignSystem.brandBlue,
        progress: Float = 0.0,
        isOutgoing: Bool = true,
        isRead: Bool = false,
    ) {
        self.effect = effect
        self.intensity = intensity
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.progress = progress
        self.isOutgoing = isOutgoing
        self.isRead = isRead
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.isOpaque = false
        mtkView.backgroundColor = .clear
        mtkView.preferredFramesPerSecond = 120
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.intensity = intensity
        context.coordinator.primaryColor = primaryColor
        context.coordinator.secondaryColor = secondaryColor
        context.coordinator.progress = progress
        context.coordinator.isOutgoing = isOutgoing
        context.coordinator.isRead = isRead
        context.coordinator.reduceMotion = reduceMotion
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            effect: effect,
            intensity: intensity,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            progress: progress,
            isOutgoing: isOutgoing,
            isRead: isRead,
        )
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice?
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        var effect: ChatMetalEffect
        var intensity: Float
        var primaryColor: Color
        var secondaryColor: Color
        var progress: Float
        var isOutgoing: Bool
        var isRead: Bool
        var reduceMotion = false
        private var time: Float = 0

        init(
            effect: ChatMetalEffect,
            intensity: Float,
            primaryColor: Color,
            secondaryColor: Color,
            progress: Float,
            isOutgoing: Bool,
            isRead: Bool,
        ) {
            self.effect = effect
            self.intensity = intensity
            self.primaryColor = primaryColor
            self.secondaryColor = secondaryColor
            self.progress = progress
            self.isOutgoing = isOutgoing
            self.isRead = isRead
            super.init()
            setupMetal()
        }

        func setupMetal() {
            guard let device = MTLCreateSystemDefaultDevice() else { return }
            self.device = device
            commandQueue = device.makeCommandQueue()

            guard let library = device.makeDefaultLibrary() else { return }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "chat_vertex")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: effect.rawValue)
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            let timeIncrement: Float = reduceMotion ? 0.004 : 0.016
            time += timeIncrement

            guard let drawable = view.currentDrawable,
                  let pipelineState,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

            renderEncoder.setRenderPipelineState(pipelineState)

            var uniforms = ChatShaderUniforms(
                time: time,
                resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                intensity: intensity,
                primaryColor: primaryColor.toSIMD4(),
                secondaryColor: secondaryColor.toSIMD4(),
                progress: progress,
                isOutgoing: isOutgoing ? 1.0 : 0.0,
                isRead: isRead ? 1.0 : 0.0,
            )
            renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<ChatShaderUniforms>.stride, index: 0)

            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply glow effect to message bubbles
    func messageBubbleGlow(
        isOutgoing: Bool,
        isRead: Bool = true,
        intensity: CGFloat = 0.5,
    ) -> some View {
        background(
            ChatMetalEffectView(
                effect: .messageBubbleGlow,
                intensity: Float(intensity),
                primaryColor: .DesignSystem.brandGreen,
                secondaryColor: .DesignSystem.glassBackground,
                isOutgoing: isOutgoing,
                isRead: isRead,
            ),
        )
    }

    /// Apply unread badge pulse effect
    func unreadBadgePulse(hasUnread: Bool, intensity: CGFloat = 0.8) -> some View {
        overlay(
            Group {
                if hasUnread {
                    ChatMetalEffectView(
                        effect: .unreadBadgePulse,
                        intensity: Float(intensity),
                        primaryColor: .DesignSystem.brandGreen,
                    )
                    .allowsHitTesting(false)
                }
            },
        )
    }

    /// Apply online status glow
    func onlineStatusGlow(isOnline: Bool, intensity: CGFloat = 0.7) -> some View {
        background(
            Group {
                if isOnline {
                    ChatMetalEffectView(
                        effect: .onlineStatus,
                        intensity: Float(intensity),
                        primaryColor: .DesignSystem.success,
                    )
                }
            },
        )
    }
}

// MARK: - Standalone Effect Components

/// Animated typing indicator with Metal shader
struct MetalTypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            // Fallback for reduced motion
            HStack(spacing: 4) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    Circle()
                        .fill(Color.DesignSystem.textSecondary)
                        .frame(width: 8.0, height: 8)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        } else {
            ChatMetalEffectView(
                effect: .typingIndicator,
                intensity: 1.0,
                primaryColor: .DesignSystem.brandGreen,
                secondaryColor: .DesignSystem.brandBlue,
            )
            .frame(width: 60.0, height: 30)
        }
    }
}

/// Message send animation overlay
struct MetalMessageSendAnimation: View {
    @Binding var isAnimating: Bool
    @State private var progress: Float = 0

    var body: some View {
        ChatMetalEffectView(
            effect: .messageSend,
            intensity: 1.0,
            primaryColor: .DesignSystem.brandGreen,
            progress: progress,
        )
        .opacity(isAnimating ? 1 : 0)
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.5)) {
                    progress = 1.0
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    isAnimating = false
                    progress = 0
                }
            }
        }
    }
}

/// Online status indicator with breathing glow
struct MetalOnlineIndicator: View {
    enum Status {
        case online
        case away
        case offline
    }

    let status: Status
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(status: Status, size: CGFloat = 12) {
        self.status = status
        self.size = size
    }

    var body: some View {
        ZStack {
            if status == .online, !reduceMotion {
                ChatMetalEffectView(
                    effect: .onlineStatus,
                    intensity: 0.7,
                    primaryColor: statusColor,
                )
                .frame(width: size * 2, height: size * 2)
            }

            Circle()
                .fill(statusColor)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.DesignSystem.background, lineWidth: 2),
                )
        }
    }

    private var statusColor: Color {
        switch status {
        case .online: .DesignSystem.success
        case .away: .DesignSystem.warning
        case .offline: .DesignSystem.textTertiary
        }
    }
}

/// Unread message badge with pulse effect
struct MetalUnreadBadge: View {
    let count: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if !reduceMotion {
                ChatMetalEffectView(
                    effect: .unreadBadgePulse,
                    intensity: 0.6,
                    primaryColor: .DesignSystem.brandGreen,
                )
                .frame(width: 32.0, height: 32)
            }

            Text(count > 99 ? "99+" : "\(count)")
                .font(.LiquidGlass.captionSmall)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.DesignSystem.brandGreen),
                )
        }
    }
}

/// Voice message waveform visualization
struct MetalVoiceWaveform: View {
    let isPlaying: Bool
    @Binding var progress: Float

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            // Static waveform fallback
            HStack(spacing: 2) {
                ForEach(0 ..< 20, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            i < Int(progress * 20)
                                ? Color.DesignSystem.brandGreen
                                : Color.DesignSystem.textTertiary,
                        )
                        .frame(width: 3.0, height: CGFloat.random(in: 8 ... 24))
                }
            }
        } else {
            ChatMetalEffectView(
                effect: .voiceWaveform,
                intensity: isPlaying ? 1.0 : 0.5,
                primaryColor: .DesignSystem.brandGreen,
                secondaryColor: .DesignSystem.brandBlue,
                progress: progress,
            )
        }
    }
}

/// Read receipt checkmarks with animation
struct MetalReadReceipt: View {
    enum Status {
        case sent
        case delivered
        case read
    }

    let status: Status

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            // Static checkmarks
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(checkColor)

                if status == .read {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(checkColor)
                }
            }
        } else {
            ChatMetalEffectView(
                effect: .readReceipt,
                intensity: 1.0,
                primaryColor: .DesignSystem.brandBlue,
                secondaryColor: .DesignSystem.textTertiary,
                isRead: status == .read,
            )
            .frame(width: 24.0, height: 16)
        }
    }

    private var checkColor: Color {
        switch status {
        case .sent: .DesignSystem.textTertiary
        case .delivered: .DesignSystem.textSecondary
        case .read: .DesignSystem.brandBlue
        }
    }
}

/// Reaction burst animation
struct MetalReactionBurst: View {
    @Binding var isAnimating: Bool
    let emoji: String

    @State private var progress: Float = 0

    var body: some View {
        ZStack {
            ChatMetalEffectView(
                effect: .reactionBurst,
                intensity: 1.0,
                primaryColor: .DesignSystem.brandPink,
                secondaryColor: .DesignSystem.accentYellow,
                progress: progress,
            )
            .frame(width: 60.0, height: 60)
            .opacity(isAnimating ? 1 : 0)

            Text(emoji)
                .font(.system(size: 24))
                .scaleEffect(isAnimating ? 1.2 : 1.0)
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.6)) {
                    progress = 1.0
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    isAnimating = false
                    progress = 0
                }
            }
        }
    }
}

// MARK: - Glass Message Bubble

struct GlassMessageBubble: View {
    let message: String
    let isOutgoing: Bool
    let timestamp: Date
    let readStatus: MetalReadReceipt.Status
    let showMetalEffects: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        message: String,
        isOutgoing: Bool,
        timestamp: Date,
        readStatus: MetalReadReceipt.Status = .sent,
        showMetalEffects: Bool = true,
    ) {
        self.message = message
        self.isOutgoing = isOutgoing
        self.timestamp = timestamp
        self.readStatus = readStatus
        self.showMetalEffects = showMetalEffects
    }

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 60) }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: Spacing.xxs) {
                Text(message)
                    .font(.LiquidGlass.bodyMedium)
                    .foregroundStyle(isOutgoing ? .white : Color.DesignSystem.text)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(bubbleBackground)
                    .clipShape(bubbleShape)
                    .modifier(ConditionalGlowModifier(
                        showGlow: showMetalEffects && !reduceMotion,
                        isOutgoing: isOutgoing,
                        isRead: readStatus == .read,
                    ))

                // Timestamp and read status
                HStack(spacing: Spacing.xs) {
                    Text(timestamp, style: .time)
                        .font(.LiquidGlass.captionSmall)
                        .foregroundStyle(Color.DesignSystem.textTertiary)

                    if isOutgoing {
                        MetalReadReceipt(status: readStatus)
                    }
                }
            }

            if !isOutgoing { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isOutgoing {
            LinearGradient(
                colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        } else {
            Color.DesignSystem.glassBackground
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                )
        }
    }

    private var bubbleShape: some Shape {
        RoundedRectangle(cornerRadius: CornerRadius.large)
    }
}

// MARK: - Glass Conversation Row

struct GlassConversationRow: View {
    let avatarUrl: String?
    let name: String
    let lastMessage: String
    let timestamp: Date
    let unreadCount: Int
    let isOnline: Bool
    let isTyping: Bool

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar with online status
            ZStack(alignment: .bottomTrailing) {
                // Avatar
                if let url = avatarUrl, let imageUrl = URL(string: url) {
                    AsyncImage(url: imageUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        avatarPlaceholder
                    }
                    .frame(width: 54.0, height: 54)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }

                // Online indicator
                MetalOnlineIndicator(
                    status: isOnline ? .online : .offline,
                    size: 14,
                )
                .offset(x: 2, y: 2)
            }

            // Content
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text(name)
                        .font(.LiquidGlass.labelLarge)
                        .fontWeight(unreadCount > 0 ? .semibold : .medium)
                        .foregroundStyle(Color.DesignSystem.text)

                    Spacer()

                    Text(timestamp, style: .relative)
                        .font(.LiquidGlass.captionSmall)
                        .foregroundStyle(
                            unreadCount > 0
                                ? Color.DesignSystem.brandGreen
                                : Color.DesignSystem.textTertiary,
                        )
                }

                HStack {
                    if isTyping {
                        HStack(spacing: Spacing.xxs) {
                            MetalTypingIndicator()
                                .frame(width: 40.0, height: 20)

                            Text("typing...")
                                .font(.LiquidGlass.bodySmall)
                                .foregroundStyle(Color.DesignSystem.brandGreen)
                                .italic()
                        }
                    } else {
                        Text(lastMessage)
                            .font(.LiquidGlass.bodySmall)
                            .foregroundStyle(
                                unreadCount > 0
                                    ? Color.DesignSystem.text
                                    : Color.DesignSystem.textSecondary,
                            )
                            .fontWeight(unreadCount > 0 ? .medium : .regular)
                            .lineLimit(2)
                    }

                    Spacer()

                    if unreadCount > 0 {
                        MetalUnreadBadge(count: unreadCount)
                    }
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.DesignSystem.textTertiary)
        }
        .padding(Spacing.md)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(rowBorder)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.interpolatingSpring(stiffness: 400, damping: 25), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false },
        )
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.DesignSystem.brandGreen.opacity(0.2),
                        Color.DesignSystem.brandBlue.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
            .frame(width: 54.0, height: 54)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    ),
            )
    }

    @ViewBuilder
    private var rowBackground: some View {
        if unreadCount > 0 {
            Color.DesignSystem.brandGreen.opacity(0.05)
        } else {
            Color.DesignSystem.glassBackground
        }
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: CornerRadius.large)
            .stroke(
                unreadCount > 0
                    ? LinearGradient(
                        colors: [
                            Color.DesignSystem.brandGreen.opacity(0.4),
                            Color.DesignSystem.brandBlue.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    )
                    : LinearGradient(
                        colors: [Color.DesignSystem.glassBorder],
                        startPoint: .top,
                        endPoint: .bottom,
                    ),
                lineWidth: unreadCount > 0 ? 1.5 : 1,
            )
    }
}

// MARK: - Preview

#Preview("Chat Metal Effects") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            Text("Typing Indicator")
                .font(.DesignSystem.headlineSmall)

            MetalTypingIndicator()
                .frame(height: 40.0)
                .background(Color.DesignSystem.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

            Text("Online Status")
                .font(.DesignSystem.headlineSmall)

            HStack(spacing: Spacing.lg) {
                VStack {
                    MetalOnlineIndicator(status: .online, size: 16)
                    Text("Online").font(.caption)
                }
                VStack {
                    MetalOnlineIndicator(status: .away, size: 16)
                    Text("Away").font(.caption)
                }
                VStack {
                    MetalOnlineIndicator(status: .offline, size: 16)
                    Text("Offline").font(.caption)
                }
            }

            Text("Unread Badge")
                .font(.DesignSystem.headlineSmall)

            HStack(spacing: Spacing.lg) {
                MetalUnreadBadge(count: 3)
                MetalUnreadBadge(count: 42)
                MetalUnreadBadge(count: 100)
            }

            Text("Read Receipts")
                .font(.DesignSystem.headlineSmall)

            HStack(spacing: Spacing.lg) {
                VStack {
                    MetalReadReceipt(status: .sent)
                    Text("Sent").font(.caption)
                }
                VStack {
                    MetalReadReceipt(status: .delivered)
                    Text("Delivered").font(.caption)
                }
                VStack {
                    MetalReadReceipt(status: .read)
                    Text("Read").font(.caption)
                }
            }

            Text("Message Bubbles")
                .font(.DesignSystem.headlineSmall)

            VStack(spacing: Spacing.sm) {
                GlassMessageBubble(
                    message: "Hey! Is this still available?",
                    isOutgoing: false,
                    timestamp: Date(),
                    readStatus: .read,
                )

                GlassMessageBubble(
                    message: "Yes! You can pick it up anytime today 😊",
                    isOutgoing: true,
                    timestamp: Date(),
                    readStatus: .read,
                )
            }

            Text("Conversation Row")
                .font(.DesignSystem.headlineSmall)

            GlassConversationRow(
                avatarUrl: nil,
                name: "Sarah",
                lastMessage: "Thanks for the apples! They were delicious 🍎",
                timestamp: Date().addingTimeInterval(-3600),
                unreadCount: 2,
                isOnline: true,
                isTyping: false,
            )

            GlassConversationRow(
                avatarUrl: nil,
                name: "Mike",
                lastMessage: "I'll be there in 10 minutes",
                timestamp: Date().addingTimeInterval(-7200),
                unreadCount: 0,
                isOnline: false,
                isTyping: true,
            )
        }
        .padding()
    }
    .background(Color.DesignSystem.background)
    .preferredColorScheme(.dark)
}

#endif
