//
//  FeedEffects.metal
//  FoodShare
//
//  Advanced Metal Shaders for Feed Feature
//  GPU-accelerated card effects optimized for ProMotion 120Hz
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct FeedVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct FeedUniforms {
    float time;
    float2 resolution;
    float intensity;
    float4 primaryColor;
    float4 secondaryColor;
    float progress;
    float parallaxOffset;
    float isUrgent;
};

// MARK: - Utility Functions

float2x2 feedRotate2D(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float2x2(c, -s, s, c);
}

float feedSmoothNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = fract(sin(dot(i, float2(12.9898, 78.233))) * 43758.5453);
    float b = fract(sin(dot(i + float2(1.0, 0.0), float2(12.9898, 78.233))) * 43758.5453);
    float c = fract(sin(dot(i + float2(0.0, 1.0), float2(12.9898, 78.233))) * 43758.5453);
    float d = fract(sin(dot(i + float2(1.0, 1.0), float2(12.9898, 78.233))) * 43758.5453);
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float feedFbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * feedSmoothNoise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// MARK: - Card Shimmer Shader

/// Creates a premium shimmer loading effect for cards
fragment float4 card_shimmer_fragment(
    FeedVertexOut in [[stage_in]],
    constant FeedUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Animated shimmer wave
    float shimmerPos = fract(uniforms.time * 0.5);
    float shimmerWidth = 0.3;
    
    // Calculate shimmer intensity
    float shimmer = smoothstep(shimmerPos - shimmerWidth, shimmerPos, uv.x) *
                    smoothstep(shimmerPos + shimmerWidth, shimmerPos, uv.x);
    
    // Add diagonal movement
    float diagonal = (uv.x + uv.y) * 0.5;
    shimmer *= smoothstep(shimmerPos - shimmerWidth, shimmerPos, diagonal) *
               smoothstep(shimmerPos + shimmerWidth, shimmerPos, diagonal);
    
    // Base color (subtle gray)
    float3 baseColor = float3(0.15, 0.15, 0.18);
    
    // Shimmer highlight
    float3 shimmerColor = float3(0.25, 0.25, 0.3);
    
    float3 finalColor = mix(baseColor, shimmerColor, shimmer * 0.8);
    
    return float4(finalColor, 0.6 * uniforms.intensity);
}

// MARK: - Card Hover Glow Shader

/// Creates a subtle glow effect when hovering/pressing cards
fragment float4 card_hover_glow_fragment(
    FeedVertexOut in [[stage_in]],
    constant FeedUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    
    // Distance from center
    float dist = length(uv);
    
    // Animated glow
    float pulse = sin(uniforms.time * 2.0) * 0.1 + 0.9;
    
    // Radial glow
    float glow = exp(-dist * 2.0) * pulse;
    
    // Edge highlight
    float edge = smoothstep(0.8, 1.0, dist) * 0.3;
    
    // Color based on primary color
    float3 glowColor = uniforms.primaryColor.rgb;
    
    float3 finalColor = glowColor * (glow + edge);
    float alpha = (glow * 0.4 + edge * 0.2) * uniforms.intensity;
    
    return float4(finalColor, alpha);
}

// MARK: - Trending Badge Shader

/// Animated fire/trending effect for popular items
fragment float4 trending_badge_fragment(
    FeedVertexOut in [[stage_in]],
    constant FeedUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Flame-like noise
    float noise1 = feedFbm(float2(uv.x * 3.0, uv.y * 2.0 - uniforms.time * 0.8), 4);
    float noise2 = feedFbm(float2(uv.x * 4.0 + 10.0, uv.y * 3.0 - uniforms.time * 1.2), 4);
    
    // Combine noises for flame shape
    float flame = noise1 * 0.6 + noise2 * 0.4;
    flame = pow(flame, 1.5);
    
    // Vertical gradient (flames rise)
    float vertGrad = 1.0 - uv.y;
    flame *= vertGrad;
    
    // Color gradient (orange to yellow)
    float3 color1 = float3(1.0, 0.4, 0.1);  // Orange
    float3 color2 = float3(1.0, 0.8, 0.2);  // Yellow
    float3 color3 = float3(1.0, 0.95, 0.8); // White-yellow
    
    float3 flameColor = mix(color1, color2, flame);
    flameColor = mix(flameColor, color3, pow(flame, 3.0));
    
    float alpha = flame * uniforms.intensity;
    
    return float4(flameColor, alpha);
}

// MARK: - Urgent Item Pulse Shader

/// Pulsing alert effect for items expiring soon
fragment float4 urgent_pulse_fragment(
    FeedVertexOut in [[stage_in]],
    constant FeedUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    
    // Pulsing ring
    float dist = length(uv);
    float pulse = sin(uniforms.time * 3.0) * 0.5 + 0.5;
    
    // Multiple rings expanding outward
    float ring1 = smoothstep(0.3, 0.35, dist) * smoothstep(0.45, 0.4, dist);
    float ring2 = smoothstep(0.5, 0.55, dist) * smoothstep(0.65, 0.6, dist);
    float ring3 = smoothstep(0.7, 0.75, dist) * smoothstep(0.85, 0.8, dist);
    
    // Animate rings
    float animRing1 = ring1 * (1.0 - fract(uniforms.time * 0.5));
    float animRing2 = ring2 * (1.0 - fract(uniforms.time * 0.5 + 0.33));
    float animRing3 = ring3 * (1.0 - fract(uniforms.time * 0.5 + 0.66));
    
    float rings = animRing1 + animRing2 + animRing3;
    
    // Warning color (orange/red)
    float3 warningColor = float3(1.0, 0.5, 0.2);
    
    // Center glow
    float centerGlow = exp(-dist * 3.0) * pulse * 0.5;
    
    float3 finalColor = warningColor * (rings + centerGlow);
    float alpha = (rings * 0.6 + centerGlow * 0.4) * uniforms.intensity;
    
    return float4(finalColor, alpha);
}

// MARK: - Category Chip Glow Shader

/// Subtle glow for selected category chips
fragment float4 category_chip_glow_fragment(
    FeedVertexOut in [[stage_in]],
    constant FeedUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    
    // Pill shape distance
    float2 pillUV = uv;
    pillUV.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float pillDist = length(max(abs(pillUV) - float2(0.5, 0.3), 0.0));
    
    // Animated glow
    float time = uniforms.time * 0.5;
    float glow = exp(-pillDist * 8.0);
    
    // Subtle pulse
    float pulse = sin(time * 2.0) * 0.1 + 0.9;
    glow *= pulse;
    
    // Color from uniforms
    float3 glowColor = uniforms.primaryColor.rgb;
    
    float alpha = glow * 0.5 * uniforms.intensity;
    
    return float4(glowColor, alpha);
}

// MARK: - Card Parallax Background Shader

/// Subtle parallax background effect for premium cards
fragment float4 card_parallax_background_fragment(
    FeedVertexOut in [[stage_in]],
    constant FeedUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Apply parallax offset
    float2 parallaxUV = uv + float2(uniforms.parallaxOffset * 0.02, 0.0);
    
    // Subtle gradient mesh
    float noise = feedFbm(parallaxUV * 2.0 + uniforms.time * 0.05, 3);
    
    // Color palette
    float3 color1 = uniforms.primaryColor.rgb * 0.1;
    float3 color2 = uniforms.secondaryColor.rgb * 0.08;
    
    float3 gradient = mix(color1, color2, noise);
    
    // Top highlight
    float highlight = smoothstep(0.5, 0.0, uv.y) * 0.08;
    gradient += float3(1.0) * highlight;
    
    // Vignette
    float2 vignetteUV = uv * 2.0 - 1.0;
    float vignette = 1.0 - dot(vignetteUV, vignetteUV) * 0.2;
    gradient *= vignette;
    
    return float4(gradient, 0.4 * uniforms.intensity);
}

// MARK: - Fresh Item Sparkle Shader

/// Sparkle effect for newly added items
fragment float4 fresh_item_sparkle_fragment(
    FeedVertexOut in [[stage_in]],
    constant FeedUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Multiple sparkle points
    float sparkles = 0.0;
    
    for (int i = 0; i < 8; i++) {
        float seed = float(i) * 1.618;
        float2 sparklePos = float2(
            fract(seed * 0.7),
            fract(seed * 0.3)
        );
        
        // Animated position
        sparklePos.x += sin(uniforms.time * 2.0 + seed) * 0.1;
        sparklePos.y += cos(uniforms.time * 1.5 + seed * 2.0) * 0.1;
        
        // Sparkle intensity
        float dist = length(uv - sparklePos);
        float sparkle = exp(-dist * 30.0);
        
        // Twinkle animation
        float twinkle = sin(uniforms.time * 5.0 + seed * 10.0) * 0.5 + 0.5;
        sparkle *= twinkle;
        
        sparkles += sparkle;
    }
    
    // Star burst at center
    float2 centerUV = uv * 2.0 - 1.0;
    float angle = atan2(centerUV.y, centerUV.x);
    float rays = abs(sin(angle * 4.0 + uniforms.time));
    float centerDist = length(centerUV);
    float starBurst = rays * exp(-centerDist * 5.0) * 0.3;
    
    // Combine
    float3 sparkleColor = float3(1.0, 0.95, 0.8); // Warm white
    float3 finalColor = sparkleColor * (sparkles + starBurst);
    
    float alpha = (sparkles * 0.6 + starBurst * 0.4) * uniforms.intensity;
    
    return float4(finalColor, alpha);
}

// MARK: - Save Heart Animation Shader

/// Animated heart effect when saving items
fragment float4 save_heart_fragment(
    FeedVertexOut in [[stage_in]],
    constant FeedUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.y -= 0.1; // Offset for heart shape
    
    // Heart shape using SDF
    float2 p = uv;
    p.y -= sqrt(abs(p.x)) * 0.5;
    float heart = length(p) - 0.5;
    
    // Smooth heart mask
    float heartMask = smoothstep(0.02, -0.02, heart);
    
    // Pulsing animation
    float pulse = sin(uniforms.time * 4.0) * 0.1 + 1.0;
    heartMask *= pulse;
    
    // Particle burst when saving
    float particles = 0.0;
    if (uniforms.progress > 0.0) {
        for (int i = 0; i < 12; i++) {
            float angle = float(i) * M_PI_F * 2.0 / 12.0;
            float2 dir = float2(cos(angle), sin(angle));
            float2 particlePos = dir * uniforms.progress * 0.8;
            float dist = length(uv - particlePos);
            particles += exp(-dist * 20.0) * (1.0 - uniforms.progress);
        }
    }
    
    // Heart color (FoodShare pink)
    float3 heartColor = uniforms.primaryColor.rgb;
    
    float3 finalColor = heartColor * (heartMask + particles);
    float alpha = (heartMask * 0.9 + particles * 0.6) * uniforms.intensity;
    
    return float4(finalColor, alpha);
}

// MARK: - Distance Indicator Shader

/// Visual indicator showing distance to item
fragment float4 distance_indicator_fragment(
    FeedVertexOut in [[stage_in]],
    constant FeedUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Progress bar style
    float progress = uniforms.progress; // 0-1 representing distance
    
    // Bar shape
    float barHeight = 0.3;
    float barY = abs(uv.y - 0.5);
    float barMask = smoothstep(barHeight, barHeight - 0.05, barY);
    
    // Progress fill
    float fillMask = step(uv.x, progress) * barMask;
    
    // Gradient color based on distance
    float3 nearColor = float3(0.2, 0.8, 0.4);  // Green (close)
    float3 farColor = float3(0.8, 0.4, 0.2);   // Orange (far)
    float3 barColor = mix(nearColor, farColor, progress);
    
    // Animated tip glow
    float tipGlow = exp(-abs(uv.x - progress) * 20.0) * barMask;
    
    // Background track
    float3 trackColor = float3(0.2, 0.2, 0.25);
    
    float3 finalColor = mix(trackColor, barColor, fillMask);
    finalColor += float3(1.0) * tipGlow * 0.3;
    
    float alpha = barMask * uniforms.intensity;
    
    return float4(finalColor, alpha);
}

