//
//  GlassEffects.metal
//  FoodShare
//
//  Metal Shaders for Liquid Glass v26
//  Advanced visual effects using Metal API
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Shader Structures

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct FragmentUniforms {
    float time;
    float2 resolution;
    float intensity;
    float4 tintColor;
};

// MARK: - Vertex Shader

vertex VertexOut glass_vertex(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// MARK: - Glass Blur Fragment Shader

fragment float4 glass_blur_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant FragmentUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    float4 color = float4(0.0);
    
    // Multi-pass gaussian blur
    float blurSize = 0.005 * uniforms.intensity;
    int samples = 9;
    
    for (int x = -samples/2; x <= samples/2; x++) {
        for (int y = -samples/2; y <= samples/2; y++) {
            float2 offset = float2(x, y) * blurSize;
            color += sourceTexture.sample(textureSampler, uv + offset);
        }
    }
    
    color /= float(samples * samples);
    
    // Apply glass tint
    color = mix(color, uniforms.tintColor, 0.1);
    
    return color;
}

// MARK: - Frosted Glass Fragment Shader

fragment float4 frosted_glass_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant FragmentUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    
    // Noise-based distortion for frosted effect
    float noise = fract(sin(dot(uv * 100.0, float2(12.9898, 78.233))) * 43758.5453);
    float2 distortion = float2(noise, fract(noise * 2.0)) * 0.01 * uniforms.intensity;
    
    float4 color = sourceTexture.sample(textureSampler, uv + distortion);
    
    // Add frosted overlay
    float frost = 0.3 + 0.2 * noise;
    color.rgb = mix(color.rgb, float3(1.0), frost * 0.2);
    
    return color;
}

// MARK: - Shimmer Effect Fragment Shader

fragment float4 shimmer_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant FragmentUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    float4 color = sourceTexture.sample(textureSampler, uv);
    
    // Animated shimmer wave
    float shimmer = sin(uv.x * 10.0 + uniforms.time * 2.0) * 
                    cos(uv.y * 10.0 + uniforms.time * 1.5);
    shimmer = (shimmer + 1.0) * 0.5; // Normalize to 0-1
    
    // Add shimmer highlight
    float3 highlight = float3(1.0) * shimmer * uniforms.intensity * 0.3;
    color.rgb += highlight;
    
    return color;
}

// MARK: - Liquid Ripple Fragment Shader

fragment float4 liquid_ripple_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant FragmentUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    
    // Ripple effect
    float dist = distance(uv, center);
    float ripple = sin(dist * 20.0 - uniforms.time * 3.0) * 0.02 * uniforms.intensity;
    
    float2 direction = normalize(uv - center);
    float2 offset = direction * ripple;
    
    float4 color = sourceTexture.sample(textureSampler, uv + offset);
    
    return color;
}

// MARK: - Gradient Mesh Fragment Shader

fragment float4 gradient_mesh_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant FragmentUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    float4 color = sourceTexture.sample(textureSampler, uv);
    
    // Animated gradient mesh
    float wave1 = sin(uv.x * 5.0 + uniforms.time) * 0.5 + 0.5;
    float wave2 = cos(uv.y * 5.0 + uniforms.time * 1.3) * 0.5 + 0.5;
    
    float3 gradient = mix(
        uniforms.tintColor.rgb,
        float3(0.2, 0.8, 1.0),
        wave1 * wave2
    );
    
    color.rgb = mix(color.rgb, gradient, uniforms.intensity * 0.3);
    
    return color;
}

// MARK: - Depth Blur Fragment Shader

fragment float4 depth_blur_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant FragmentUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    
    // Depth-based blur (stronger at edges)
    float2 center = float2(0.5, 0.5);
    float depth = distance(uv, center) * 2.0;
    float blurAmount = depth * uniforms.intensity * 0.01;
    
    float4 color = float4(0.0);
    int samples = 5;
    
    for (int i = 0; i < samples; i++) {
        float angle = float(i) * 2.0 * M_PI_F / float(samples);
        float2 offset = float2(cos(angle), sin(angle)) * blurAmount;
        color += sourceTexture.sample(textureSampler, uv + offset);
    }
    
    color /= float(samples);
    
    return color;
}

// MARK: - Chromatic Aberration Fragment Shader

fragment float4 chromatic_aberration_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant FragmentUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    float2 direction = uv - center;
    
    float aberration = uniforms.intensity * 0.005;
    
    // Sample RGB channels separately
    float r = sourceTexture.sample(textureSampler, uv + direction * aberration).r;
    float g = sourceTexture.sample(textureSampler, uv).g;
    float b = sourceTexture.sample(textureSampler, uv - direction * aberration).b;
    
    return float4(r, g, b, 1.0);
}

// MARK: - Glow Fragment Shader

fragment float4 glow_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant FragmentUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    float4 color = sourceTexture.sample(textureSampler, uv);
    
    // Multi-pass glow
    float4 glow = float4(0.0);
    int samples = 8;
    float glowSize = 0.01 * uniforms.intensity;
    
    for (int i = 0; i < samples; i++) {
        float angle = float(i) * 2.0 * M_PI_F / float(samples);
        float2 offset = float2(cos(angle), sin(angle)) * glowSize;
        glow += sourceTexture.sample(textureSampler, uv + offset);
    }
    
    glow /= float(samples);
    glow *= uniforms.tintColor;
    
    return color + glow * 0.5;
}
