//
//  ProfileEffects.metal
//  FoodShare
//
//  Advanced Metal Shaders for Profile Feature
//  Optimized for ProMotion 120Hz displays
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct ProfileVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct ProfileUniforms {
    float time;
    float2 resolution;
    float intensity;
    float4 primaryColor;
    float4 secondaryColor;
    float progress;
};

// MARK: - Utility Functions

float2x2 rotate2D(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float2x2(c, -s, s, c);
}

float sdCircle(float2 p, float r) {
    return length(p) - r;
}

float smoothNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = fract(sin(dot(i, float2(12.9898, 78.233))) * 43758.5453);
    float b = fract(sin(dot(i + float2(1.0, 0.0), float2(12.9898, 78.233))) * 43758.5453);
    float c = fract(sin(dot(i + float2(0.0, 1.0), float2(12.9898, 78.233))) * 43758.5453);
    float d = fract(sin(dot(i + float2(1.0, 1.0), float2(12.9898, 78.233))) * 43758.5453);
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * smoothNoise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// MARK: - Avatar Ring Shader

/// Creates an animated glowing ring effect for profile avatars
fragment float4 avatar_ring_fragment(
    ProfileVertexOut in [[stage_in]],
    constant ProfileUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float2 center = float2(0.0);
    
    // Ring parameters
    float innerRadius = 0.7;
    float outerRadius = 0.85;
    float dist = length(uv - center);
    
    // Animated gradient rotation
    float angle = atan2(uv.y, uv.x);
    float rotatedAngle = angle + uniforms.time * 0.5;
    
    // Multi-color gradient
    float3 color1 = uniforms.primaryColor.rgb;   // Brand green
    float3 color2 = uniforms.secondaryColor.rgb; // Brand blue
    float3 color3 = float3(0.0, 0.65, 0.6);      // Teal
    
    float gradientPos = (sin(rotatedAngle * 2.0) + 1.0) * 0.5;
    float3 ringColor = mix(mix(color1, color2, gradientPos), color3, sin(rotatedAngle + uniforms.time) * 0.5 + 0.5);
    
    // Ring mask with soft edges
    float ring = smoothstep(innerRadius - 0.02, innerRadius, dist) * 
                 smoothstep(outerRadius + 0.02, outerRadius, dist);
    
    // Pulsing glow
    float pulse = sin(uniforms.time * 2.0) * 0.15 + 0.85;
    float glow = exp(-abs(dist - (innerRadius + outerRadius) * 0.5) * 8.0) * pulse;
    
    // Sparkle effect
    float sparkle = smoothNoise(uv * 20.0 + uniforms.time * 2.0);
    sparkle = pow(sparkle, 8.0) * ring;
    
    // Combine
    float3 finalColor = ringColor * (ring + glow * 0.5) + float3(1.0) * sparkle * 0.3;
    float alpha = ring * 0.9 + glow * 0.4 + sparkle * 0.2;
    
    return float4(finalColor, alpha * uniforms.intensity);
}

// MARK: - Progress Ring Shader

/// Animated circular progress indicator with liquid glass effect
fragment float4 progress_ring_fragment(
    ProfileVertexOut in [[stage_in]],
    constant ProfileUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    
    float angle = atan2(uv.y, uv.x);
    float normalizedAngle = (angle + M_PI_F) / (2.0 * M_PI_F);
    
    // Progress with smooth animation
    float targetProgress = uniforms.progress;
    float animatedProgress = targetProgress;
    
    // Ring geometry
    float dist = length(uv);
    float ringWidth = 0.08;
    float ringRadius = 0.8;
    
    float ring = smoothstep(ringRadius - ringWidth, ringRadius - ringWidth + 0.01, dist) *
                 smoothstep(ringRadius + ringWidth, ringRadius + ringWidth - 0.01, dist);
    
    // Background track
    float3 trackColor = float3(0.2, 0.2, 0.25);
    
    // Progress fill with gradient
    float progressMask = step(normalizedAngle, animatedProgress);
    float3 progressColor = mix(
        uniforms.primaryColor.rgb,
        uniforms.secondaryColor.rgb,
        normalizedAngle
    );
    
    // Glow at progress tip
    float tipAngle = animatedProgress * 2.0 * M_PI_F - M_PI_F;
    float2 tipPos = float2(cos(tipAngle), sin(tipAngle)) * ringRadius;
    float tipGlow = exp(-length(uv - tipPos) * 15.0);
    
    // Combine
    float3 finalColor = mix(trackColor, progressColor, progressMask) * ring;
    finalColor += uniforms.primaryColor.rgb * tipGlow * 0.5;
    
    float alpha = ring * 0.9 + tipGlow * 0.3;
    
    return float4(finalColor, alpha * uniforms.intensity);
}

// MARK: - Stats Card Background Shader

/// Animated gradient mesh background for stats cards
fragment float4 stats_background_fragment(
    ProfileVertexOut in [[stage_in]],
    constant ProfileUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Animated noise-based gradient
    float noise1 = fbm(uv * 3.0 + uniforms.time * 0.1, 4);
    float noise2 = fbm(uv * 2.0 - uniforms.time * 0.15, 4);
    
    // Color palette
    float3 color1 = uniforms.primaryColor.rgb * 0.15;
    float3 color2 = uniforms.secondaryColor.rgb * 0.1;
    float3 color3 = float3(0.0, 0.4, 0.4) * 0.12;
    
    // Blend colors based on noise
    float3 gradient = mix(color1, color2, noise1);
    gradient = mix(gradient, color3, noise2 * 0.5);
    
    // Add subtle highlight at top
    float highlight = smoothstep(0.5, 0.0, uv.y) * 0.1;
    gradient += float3(1.0) * highlight;
    
    // Vignette
    float2 vignetteUV = uv * 2.0 - 1.0;
    float vignette = 1.0 - dot(vignetteUV, vignetteUV) * 0.3;
    gradient *= vignette;
    
    return float4(gradient, 0.6 * uniforms.intensity);
}

// MARK: - Badge Glow Shader

/// Creates a premium glow effect for earned badges
fragment float4 badge_glow_fragment(
    ProfileVertexOut in [[stage_in]],
    constant ProfileUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float dist = length(uv);
    
    // Multi-layer glow
    float glow1 = exp(-dist * 3.0);
    float glow2 = exp(-dist * 6.0);
    float glow3 = exp(-dist * 12.0);
    
    // Animated color shift
    float colorShift = sin(uniforms.time * 1.5) * 0.5 + 0.5;
    float3 glowColor = mix(
        uniforms.primaryColor.rgb,
        float3(1.0, 0.84, 0.0), // Gold
        colorShift * 0.3
    );
    
    // Sparkle particles
    float sparkle = 0.0;
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * M_PI_F / 3.0 + uniforms.time;
        float2 sparklePos = float2(cos(angle), sin(angle)) * 0.6;
        sparkle += exp(-length(uv - sparklePos) * 20.0);
    }
    
    // Combine layers
    float3 finalColor = glowColor * (glow1 * 0.3 + glow2 * 0.5 + glow3 * 0.8);
    finalColor += float3(1.0) * sparkle * 0.4;
    
    float alpha = glow1 * 0.4 + glow2 * 0.3 + sparkle * 0.2;
    
    return float4(finalColor, alpha * uniforms.intensity);
}

// MARK: - Impact Visualization Shader

/// Animated visualization for environmental impact stats
fragment float4 impact_viz_fragment(
    ProfileVertexOut in [[stage_in]],
    constant ProfileUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Leaf/eco pattern
    float2 leafUV = uv * 4.0;
    float leafPattern = 0.0;
    
    for (int i = 0; i < 3; i++) {
        float2 offset = float2(
            sin(uniforms.time * 0.5 + float(i) * 2.0),
            cos(uniforms.time * 0.3 + float(i) * 1.5)
        ) * 0.3;
        
        float2 p = fract(leafUV + offset) * 2.0 - 1.0;
        float leaf = 1.0 - smoothstep(0.0, 0.5, abs(p.x) + abs(p.y) * 0.5);
        leafPattern += leaf * 0.3;
    }
    
    // Rising particles (CO2/water droplets)
    float particles = 0.0;
    for (int i = 0; i < 8; i++) {
        float seed = float(i) * 1.618;
        float2 particlePos = float2(
            fract(seed * 0.7),
            fract(uv.y + uniforms.time * 0.2 + seed * 0.3)
        );
        float particle = exp(-length(uv - particlePos) * 30.0);
        particles += particle;
    }
    
    // Color based on impact type
    float3 ecoColor = uniforms.primaryColor.rgb; // Green for positive impact
    float3 finalColor = ecoColor * (leafPattern + particles * 0.5);
    
    // Gradient overlay
    float gradient = smoothstep(1.0, 0.0, uv.y);
    finalColor *= gradient * 0.8 + 0.2;
    
    float alpha = (leafPattern + particles) * 0.5 * uniforms.intensity;
    
    return float4(finalColor, alpha);
}

// MARK: - Liquid Glass Refraction Shader

/// Premium liquid glass effect with light refraction
fragment float4 liquid_glass_refraction_fragment(
    ProfileVertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant ProfileUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    
    // Animated distortion
    float2 distortion = float2(
        sin(uv.y * 10.0 + uniforms.time) * 0.005,
        cos(uv.x * 10.0 + uniforms.time * 1.2) * 0.005
    ) * uniforms.intensity;
    
    // Chromatic aberration for glass effect
    float aberration = 0.002 * uniforms.intensity;
    float r = sourceTexture.sample(textureSampler, uv + distortion + float2(aberration, 0.0)).r;
    float g = sourceTexture.sample(textureSampler, uv + distortion).g;
    float b = sourceTexture.sample(textureSampler, uv + distortion - float2(aberration, 0.0)).b;
    
    float4 color = float4(r, g, b, 1.0);
    
    // Fresnel-like edge highlight
    float2 center = float2(0.5);
    float edgeDist = length(uv - center) * 2.0;
    float fresnel = pow(edgeDist, 2.0) * 0.15;
    
    color.rgb += float3(1.0) * fresnel;
    
    // Subtle tint
    color.rgb = mix(color.rgb, uniforms.primaryColor.rgb, 0.05);
    
    return color;
}

