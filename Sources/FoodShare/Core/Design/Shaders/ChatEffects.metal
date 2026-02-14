//
//  ChatEffects.metal
//  FoodShare
//
//  Metal shaders for Chat/Messaging feature
//  GPU-accelerated message bubbles, typing indicators, and chat effects
//  Optimized for ProMotion 120Hz displays
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Structures

struct ChatUniforms {
    float time;
    float2 resolution;
    float intensity;
    float4 primaryColor;
    float4 secondaryColor;
    float progress;
    float isOutgoing;
    float isRead;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// MARK: - Utility Functions

float chatHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float chatNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = chatHash(i);
    float b = chatHash(i + float2(1.0, 0.0));
    float c = chatHash(i + float2(0.0, 1.0));
    float d = chatHash(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// MARK: - Vertex Shader

vertex VertexOut chat_vertex(uint vertexID [[vertex_id]]) {
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    
    float2 uvs[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };
    
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = uvs[vertexID];
    return out;
}

// MARK: - Message Bubble Glow Shader
// Subtle glow effect for message bubbles with gradient

fragment float4 message_bubble_glow_fragment(
    VertexOut in [[stage_in]],
    constant ChatUniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.uv;
    float2 center = float2(0.5);
    float dist = distance(uv, center);
    
    // Determine color based on outgoing/incoming
    float4 bubbleColor = uniforms.isOutgoing > 0.5 ? uniforms.primaryColor : uniforms.secondaryColor;
    
    // Soft edge glow
    float glow = 1.0 - smoothstep(0.3, 0.5, dist);
    glow *= uniforms.intensity;
    
    // Subtle pulse for unread messages
    if (uniforms.isRead < 0.5) {
        float pulse = sin(uniforms.time * 2.0) * 0.5 + 0.5;
        glow *= 1.0 + pulse * 0.2;
    }
    
    // Inner highlight
    float highlight = 1.0 - smoothstep(0.0, 0.3, dist);
    highlight *= 0.3;
    
    float4 color = bubbleColor;
    color.rgb += highlight;
    color.a = glow * 0.6;
    
    return color;
}

// MARK: - Typing Indicator Shader
// Animated dots with wave effect

fragment float4 typing_indicator_fragment(
    VertexOut in [[stage_in]],
    constant ChatUniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.uv;
    float4 color = float4(0.0);
    
    // Three dots positions
    float dotSpacing = 0.25;
    float dotRadius = 0.08;
    
    for (int i = 0; i < 3; i++) {
        float2 dotCenter = float2(0.25 + float(i) * dotSpacing, 0.5);
        
        // Wave animation with phase offset
        float phase = float(i) * 0.4;
        float bounce = sin(uniforms.time * 4.0 + phase) * 0.15;
        dotCenter.y += bounce;
        
        // Distance to dot
        float dist = distance(uv, dotCenter);
        
        // Soft circle
        float dot = 1.0 - smoothstep(dotRadius - 0.02, dotRadius + 0.02, dist);
        
        // Scale animation
        float scale = 0.8 + sin(uniforms.time * 3.0 + phase) * 0.2;
        dot *= scale;
        
        // Color with gradient
        float4 dotColor = mix(uniforms.primaryColor, uniforms.secondaryColor, float(i) / 2.0);
        color += dotColor * dot * uniforms.intensity;
    }
    
    return color;
}

// MARK: - Message Send Animation Shader
// Ripple effect when sending a message

fragment float4 message_send_fragment(
    VertexOut in [[stage_in]],
    constant ChatUniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.uv;
    float2 center = float2(0.5);
    float dist = distance(uv, center);
    
    // Expanding ring
    float ringRadius = uniforms.progress * 0.8;
    float ringWidth = 0.05;
    float ring = 1.0 - smoothstep(ringWidth, ringWidth + 0.02, abs(dist - ringRadius));
    
    // Fade out as it expands
    ring *= 1.0 - uniforms.progress;
    
    // Inner glow
    float innerGlow = 1.0 - smoothstep(0.0, ringRadius, dist);
    innerGlow *= (1.0 - uniforms.progress) * 0.5;
    
    float4 color = uniforms.primaryColor;
    color.a = (ring + innerGlow) * uniforms.intensity;
    
    return color;
}

// MARK: - Unread Badge Pulse Shader
// Pulsing notification badge

fragment float4 unread_badge_pulse_fragment(
    VertexOut in [[stage_in]],
    constant ChatUniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.uv;
    float2 center = float2(0.5);
    float dist = distance(uv, center);
    
    // Main badge circle
    float badge = 1.0 - smoothstep(0.35, 0.4, dist);
    
    // Pulsing outer ring
    float pulse = sin(uniforms.time * 3.0) * 0.5 + 0.5;
    float ringRadius = 0.4 + pulse * 0.1;
    float ring = 1.0 - smoothstep(0.02, 0.05, abs(dist - ringRadius));
    ring *= 0.5 * (1.0 - pulse * 0.5);
    
    // Glow
    float glow = 1.0 - smoothstep(0.3, 0.6, dist);
    glow *= 0.3;
    
    float4 color = uniforms.primaryColor;
    color.a = (badge + ring + glow) * uniforms.intensity;
    
    return color;
}

// MARK: - Online Status Indicator Shader
// Breathing glow for online status

fragment float4 online_status_fragment(
    VertexOut in [[stage_in]],
    constant ChatUniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.uv;
    float2 center = float2(0.5);
    float dist = distance(uv, center);
    
    // Breathing animation
    float breath = sin(uniforms.time * 2.0) * 0.5 + 0.5;
    
    // Main circle
    float circle = 1.0 - smoothstep(0.3, 0.35, dist);
    
    // Outer glow that breathes
    float glowRadius = 0.35 + breath * 0.15;
    float glow = 1.0 - smoothstep(0.3, glowRadius, dist);
    glow *= 0.4 * breath;
    
    // Inner highlight
    float highlight = 1.0 - smoothstep(0.0, 0.2, dist);
    highlight *= 0.3;
    
    float4 color = uniforms.primaryColor;
    color.rgb += highlight;
    color.a = (circle + glow) * uniforms.intensity;
    
    return color;
}

// MARK: - Message Reaction Burst Shader
// Particle burst for reactions

fragment float4 reaction_burst_fragment(
    VertexOut in [[stage_in]],
    constant ChatUniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.uv;
    float2 center = float2(0.5);
    float4 color = float4(0.0);
    
    // Multiple particles
    for (int i = 0; i < 8; i++) {
        float angle = float(i) * 0.785398; // 45 degrees
        float speed = 0.5 + chatHash(float2(float(i), 0.0)) * 0.3;
        
        // Particle position based on progress
        float2 particlePos = center + float2(cos(angle), sin(angle)) * uniforms.progress * speed;
        
        // Particle size decreases as it moves
        float size = 0.05 * (1.0 - uniforms.progress);
        float dist = distance(uv, particlePos);
        float particle = 1.0 - smoothstep(size - 0.01, size + 0.01, dist);
        
        // Fade out
        particle *= 1.0 - uniforms.progress;
        
        // Alternate colors
        float4 particleColor = (i % 2 == 0) ? uniforms.primaryColor : uniforms.secondaryColor;
        color += particleColor * particle;
    }
    
    return color * uniforms.intensity;
}

// MARK: - Chat Background Ambient Shader
// Subtle animated background for chat view

fragment float4 chat_ambient_background_fragment(
    VertexOut in [[stage_in]],
    constant ChatUniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.uv;
    
    // Slow moving noise
    float noise1 = chatNoise(uv * 3.0 + uniforms.time * 0.1);
    float noise2 = chatNoise(uv * 5.0 - uniforms.time * 0.08);
    
    // Combine noises
    float combined = (noise1 + noise2) * 0.5;
    
    // Gradient from top to bottom
    float gradient = 1.0 - uv.y;
    
    // Mix colors
    float4 color = mix(uniforms.primaryColor, uniforms.secondaryColor, combined);
    color.a = combined * gradient * uniforms.intensity * 0.15;
    
    return color;
}

// MARK: - Voice Message Waveform Shader
// Animated audio waveform visualization

fragment float4 voice_waveform_fragment(
    VertexOut in [[stage_in]],
    constant ChatUniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.uv;
    float4 color = float4(0.0);
    
    // Number of bars
    int numBars = 20;
    float barWidth = 1.0 / float(numBars);
    
    for (int i = 0; i < numBars; i++) {
        float x = float(i) * barWidth + barWidth * 0.5;
        
        // Animated height based on position and time
        float phase = float(i) * 0.3;
        float height = 0.3 + sin(uniforms.time * 4.0 + phase) * 0.2;
        height *= uniforms.progress; // Scale with playback progress
        
        // Bar bounds
        float barLeft = x - barWidth * 0.3;
        float barRight = x + barWidth * 0.3;
        float barBottom = 0.5 - height * 0.5;
        float barTop = 0.5 + height * 0.5;
        
        // Check if UV is inside bar
        if (uv.x >= barLeft && uv.x <= barRight && uv.y >= barBottom && uv.y <= barTop) {
            // Gradient within bar
            float barGradient = (uv.y - barBottom) / (barTop - barBottom);
            float4 barColor = mix(uniforms.primaryColor, uniforms.secondaryColor, barGradient);
            
            // Soft edges
            float edgeSoftness = 0.01;
            float alpha = smoothstep(barLeft, barLeft + edgeSoftness, uv.x);
            alpha *= 1.0 - smoothstep(barRight - edgeSoftness, barRight, uv.x);
            alpha *= smoothstep(barBottom, barBottom + edgeSoftness, uv.y);
            alpha *= 1.0 - smoothstep(barTop - edgeSoftness, barTop, uv.y);
            
            barColor.a = alpha * uniforms.intensity;
            color = max(color, barColor);
        }
    }
    
    return color;
}

// MARK: - Read Receipt Checkmark Shader
// Animated checkmark with glow

fragment float4 read_receipt_fragment(
    VertexOut in [[stage_in]],
    constant ChatUniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.uv;
    float4 color = float4(0.0);
    
    // Double checkmark for "read"
    float checkWidth = 0.03;
    
    // First checkmark
    float2 check1Start = float2(0.2, 0.5);
    float2 check1Mid = float2(0.35, 0.3);
    float2 check1End = float2(0.55, 0.7);
    
    // Second checkmark (offset)
    float2 check2Start = float2(0.35, 0.5);
    float2 check2Mid = float2(0.5, 0.3);
    float2 check2End = float2(0.7, 0.7);
    
    // Draw progress based on animation
    float drawProgress = uniforms.progress;
    
    // Line distance function
    auto lineDist = [](float2 p, float2 a, float2 b) -> float {
        float2 pa = p - a;
        float2 ba = b - a;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        return length(pa - ba * h);
    };
    
    // First check (always visible if read)
    if (uniforms.isRead > 0.5) {
        float d1 = lineDist(uv, check1Start, check1Mid);
        float d2 = lineDist(uv, check1Mid, check1End);
        float check1 = 1.0 - smoothstep(checkWidth - 0.01, checkWidth + 0.01, min(d1, d2));
        
        // Second check
        float d3 = lineDist(uv, check2Start, check2Mid);
        float d4 = lineDist(uv, check2Mid, check2End);
        float check2 = 1.0 - smoothstep(checkWidth - 0.01, checkWidth + 0.01, min(d3, d4));
        
        float checks = max(check1, check2);
        
        // Glow
        float glow = 1.0 - smoothstep(0.0, 0.15, min(min(d1, d2), min(d3, d4)));
        glow *= 0.3;
        
        color = uniforms.primaryColor;
        color.a = (checks + glow) * uniforms.intensity;
    } else {
        // Single check for "delivered"
        float d1 = lineDist(uv, check1Start, check1Mid);
        float d2 = lineDist(uv, check1Mid, check1End);
        float check1 = 1.0 - smoothstep(checkWidth - 0.01, checkWidth + 0.01, min(d1, d2));
        
        color = uniforms.secondaryColor;
        color.a = check1 * uniforms.intensity;
    }
    
    return color;
}
