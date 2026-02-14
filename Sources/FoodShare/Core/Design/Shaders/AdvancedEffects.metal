//
//  AdvancedEffects.metal
//  FoodShare
//
//  Advanced Metal Shaders for iOS 18+
//  Particle systems, fluid dynamics, and interactive effects
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Advanced Structures

struct Particle {
    float2 position;
    float2 velocity;
    float life;
    float size;
    float4 color;
};

struct FluidCell {
    float2 velocity;
    float density;
    float pressure;
};

// MARK: - Particle System Compute Shader

kernel void update_particles(
    device Particle *particles [[buffer(0)]],
    constant float &deltaTime [[buffer(1)]],
    constant float2 &gravity [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    Particle particle = particles[id];
    
    // Update physics
    particle.velocity += gravity * deltaTime;
    particle.position += particle.velocity * deltaTime;
    particle.life -= deltaTime;
    
    // Bounce off boundaries
    if (particle.position.x < 0.0 || particle.position.x > 1.0) {
        particle.velocity.x *= -0.8;
        particle.position.x = clamp(particle.position.x, 0.0, 1.0);
    }
    if (particle.position.y < 0.0 || particle.position.y > 1.0) {
        particle.velocity.y *= -0.8;
        particle.position.y = clamp(particle.position.y, 0.0, 1.0);
    }
    
    // Fade out
    particle.color.a = particle.life;
    
    particles[id] = particle;
}

// MARK: - Fluid Simulation Compute Shader

kernel void simulate_fluid(
    device FluidCell *cells [[buffer(0)]],
    constant uint2 &gridSize [[buffer(1)]],
    constant float &deltaTime [[buffer(2)]],
    uint2 id [[thread_position_in_grid]]
) {
    if (id.x >= gridSize.x || id.y >= gridSize.y) return;
    
    uint index = id.y * gridSize.x + id.x;
    FluidCell cell = cells[index];
    
    // Advection
    float2 velocity = cell.velocity;
    
    // Diffusion
    float2 avgVelocity = float2(0.0);
    int neighbors = 0;
    
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            int nx = int(id.x) + dx;
            int ny = int(id.y) + dy;
            
            if (nx >= 0 && nx < int(gridSize.x) && ny >= 0 && ny < int(gridSize.y)) {
                uint nIndex = ny * gridSize.x + nx;
                avgVelocity += cells[nIndex].velocity;
                neighbors++;
            }
        }
    }
    
    avgVelocity /= float(neighbors);
    cell.velocity = mix(cell.velocity, avgVelocity, 0.1 * deltaTime);
    
    cells[index] = cell;
}

// MARK: - Morphing Blob Fragment Shader

fragment float4 morphing_blob_fragment(
    float4 position [[position]],
    float2 texCoord [[stage_in]],
    constant float &time [[buffer(0)]],
    constant float2 &resolution [[buffer(1)]]
) {
    float2 uv = texCoord;
    float2 center = float2(0.5, 0.5);
    
    // Multiple blob centers
    float2 blob1 = center + float2(sin(time) * 0.2, cos(time) * 0.2);
    float2 blob2 = center + float2(cos(time * 1.3) * 0.15, sin(time * 1.3) * 0.15);
    float2 blob3 = center + float2(sin(time * 0.7) * 0.18, cos(time * 0.7) * 0.18);
    
    // Metaball distance field
    float d1 = 0.1 / distance(uv, blob1);
    float d2 = 0.08 / distance(uv, blob2);
    float d3 = 0.09 / distance(uv, blob3);
    
    float field = d1 + d2 + d3;
    
    // Color gradient
    float3 color1 = float3(0.18, 0.8, 0.44); // Brand green
    float3 color2 = float3(0.2, 0.6, 0.86);  // Brand blue
    float3 color = mix(color1, color2, sin(time + field) * 0.5 + 0.5);
    
    // Alpha based on field strength
    float alpha = smoothstep(1.0, 2.0, field);
    
    return float4(color, alpha * 0.8);
}

// MARK: - Holographic Fragment Shader

fragment float4 holographic_fragment(
    float4 position [[position]],
    float2 texCoord [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant float &time [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = texCoord;
    float4 color = sourceTexture.sample(textureSampler, uv);
    
    // Holographic scan lines
    float scanline = sin(uv.y * 100.0 + time * 5.0) * 0.5 + 0.5;
    
    // RGB shift for holographic effect
    float shift = 0.002;
    float r = sourceTexture.sample(textureSampler, uv + float2(shift, 0.0)).r;
    float g = color.g;
    float b = sourceTexture.sample(textureSampler, uv - float2(shift, 0.0)).b;
    
    // Holographic color
    float3 holoColor = float3(r, g, b);
    holoColor *= scanline * 0.3 + 0.7;
    
    // Add cyan/magenta tint
    holoColor += float3(0.0, 0.3, 0.3) * sin(time + uv.y * 5.0) * 0.2;
    
    return float4(holoColor, color.a * 0.9);
}

// MARK: - Energy Field Fragment Shader

fragment float4 energy_field_fragment(
    float4 position [[position]],
    float2 texCoord [[stage_in]],
    constant float &time [[buffer(0)]],
    constant float2 &touchPoint [[buffer(1)]]
) {
    float2 uv = texCoord;
    
    // Distance from touch point
    float dist = distance(uv, touchPoint);
    
    // Ripple waves
    float wave = sin(dist * 30.0 - time * 5.0) * 0.5 + 0.5;
    wave *= exp(-dist * 3.0); // Fade with distance
    
    // Energy color (green to blue)
    float3 color = mix(
        float3(0.18, 0.8, 0.44),
        float3(0.2, 0.6, 0.86),
        wave
    );
    
    // Pulsing intensity
    float intensity = wave * (sin(time * 2.0) * 0.3 + 0.7);
    
    return float4(color * intensity, intensity * 0.6);
}

// MARK: - Caustics Fragment Shader

fragment float4 caustics_fragment(
    float4 position [[position]],
    float2 texCoord [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    constant float &time [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 uv = texCoord;
    
    // Caustic pattern
    float caustic = 0.0;
    for (int i = 0; i < 3; i++) {
        float t = time * 0.5 + float(i) * 2.0;
        float2 p = uv * 5.0 + float2(sin(t), cos(t));
        caustic += sin(p.x + sin(p.y + t)) * cos(p.y + cos(p.x + t));
    }
    caustic = abs(caustic) * 0.3;
    
    float4 color = sourceTexture.sample(textureSampler, uv);
    
    // Add caustic lighting
    color.rgb += float3(0.3, 0.6, 0.8) * caustic;
    
    return color;
}

// MARK: - Perlin Noise Function

float perlin_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    float a = fract(sin(dot(i, float2(12.9898, 78.233))) * 43758.5453);
    float b = fract(sin(dot(i + float2(1.0, 0.0), float2(12.9898, 78.233))) * 43758.5453);
    float c = fract(sin(dot(i + float2(0.0, 1.0), float2(12.9898, 78.233))) * 43758.5453);
    float d = fract(sin(dot(i + float2(1.0, 1.0), float2(12.9898, 78.233))) * 43758.5453);
    
    float2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// MARK: - Smoke Fragment Shader

fragment float4 smoke_fragment(
    float4 position [[position]],
    float2 texCoord [[stage_in]],
    constant float &time [[buffer(0)]]
) {
    float2 uv = texCoord;

    // Layered noise for smoke
    float smoke = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;

    for (int i = 0; i < 4; i++) {
        smoke += perlin_noise(uv * frequency + float2(0.0, time * 0.2)) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    smoke = smoothstep(0.3, 0.7, smoke);

    // Smoke color (white to gray)
    float3 color = float3(0.9, 0.9, 0.9) * smoke;

    return float4(color, smoke * 0.5);
}

// MARK: - Celebration Confetti Compute Shader

struct ConfettiParticle {
    float2 position;
    float2 velocity;
    float rotation;
    float rotationSpeed;
    float life;
    float4 color;
    float size;
};

kernel void celebration_confetti_compute(
    device ConfettiParticle *particles [[buffer(0)]],
    constant float &deltaTime [[buffer(1)]],
    constant float2 &gravity [[buffer(2)]],
    constant float &wind [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    ConfettiParticle particle = particles[id];

    // Apply gravity
    particle.velocity += gravity * deltaTime;

    // Apply wind with turbulence
    float turbulence = sin(particle.position.y * 10.0 + particle.life * 5.0) * 0.5;
    particle.velocity.x += (wind + turbulence) * deltaTime;

    // Update position
    particle.position += particle.velocity * deltaTime;

    // Update rotation
    particle.rotation += particle.rotationSpeed * deltaTime;

    // Decrease life
    particle.life -= deltaTime * 0.5;

    // Bounce off sides
    if (particle.position.x < 0.0 || particle.position.x > 1.0) {
        particle.velocity.x *= -0.6;
        particle.position.x = clamp(particle.position.x, 0.0, 1.0);
    }

    // Fade out
    particle.color.a = smoothstep(0.0, 0.3, particle.life);

    particles[id] = particle;
}

// MARK: - Achievement Burst Fragment Shader

fragment float4 achievement_burst_fragment(
    float4 position [[position]],
    float2 texCoord [[stage_in]],
    constant float &time [[buffer(0)]],
    constant float &progress [[buffer(1)]]
) {
    float2 uv = texCoord;
    float2 center = float2(0.5, 0.5);

    // Distance from center
    float dist = distance(uv, center);

    // Expanding ring
    float ringRadius = progress * 0.8;
    float ringWidth = 0.1 * (1.0 - progress);
    float ring = smoothstep(ringRadius - ringWidth, ringRadius, dist) -
                 smoothstep(ringRadius, ringRadius + ringWidth, dist);

    // Star burst rays
    float angle = atan2(uv.y - center.y, uv.x - center.x);
    float rays = pow(abs(sin(angle * 6.0 + time * 2.0)), 20.0);
    rays *= smoothstep(0.5, 0.0, dist) * (1.0 - progress);

    // Central glow
    float glow = exp(-dist * 6.0) * (1.0 - progress * 0.5);

    // Combine effects
    float intensity = ring * 0.8 + rays * 0.5 + glow;

    // Gold to white gradient
    float3 goldColor = float3(1.0, 0.85, 0.3);
    float3 whiteColor = float3(1.0, 1.0, 1.0);
    float3 color = mix(goldColor, whiteColor, glow);

    return float4(color * intensity, intensity);
}

// MARK: - Badge Sparkle Fragment Shader

fragment float4 badge_sparkle_fragment(
    float4 position [[position]],
    float2 texCoord [[stage_in]],
    constant float &time [[buffer(0)]],
    constant float &intensity [[buffer(1)]]
) {
    float2 uv = texCoord;

    // Multiple sparkle points
    float sparkle = 0.0;

    // Fixed sparkle positions with animation
    float2 sparklePositions[6] = {
        float2(0.2, 0.3),
        float2(0.8, 0.25),
        float2(0.5, 0.15),
        float2(0.3, 0.75),
        float2(0.7, 0.8),
        float2(0.5, 0.5)
    };

    for (int i = 0; i < 6; i++) {
        float2 pos = sparklePositions[i];

        // Animate sparkle position slightly
        pos += float2(sin(time + float(i)), cos(time * 1.3 + float(i))) * 0.02;

        float dist = distance(uv, pos);

        // Twinkling intensity
        float twinkle = pow(sin(time * 3.0 + float(i) * 1.7) * 0.5 + 0.5, 2.0);

        // Star shape
        float angle = atan2(uv.y - pos.y, uv.x - pos.x);
        float star = pow(abs(sin(angle * 4.0)), 10.0) * 0.5 + 0.5;

        sparkle += exp(-dist * 40.0) * twinkle * star;
    }

    sparkle *= intensity;

    // Golden color
    float3 color = float3(1.0, 0.9, 0.4);

    return float4(color * sparkle, sparkle);
}

// MARK: - Glow Pulse Fragment Shader

fragment float4 glow_pulse_fragment(
    float4 position [[position]],
    float2 texCoord [[stage_in]],
    constant float &time [[buffer(0)]],
    constant float4 &tintColor [[buffer(1)]]
) {
    float2 uv = texCoord;
    float2 center = float2(0.5, 0.5);

    // Distance from center
    float dist = distance(uv, center);

    // Pulsing glow
    float pulse = sin(time * 2.0) * 0.2 + 0.8;
    float glow = exp(-dist * 3.0 * pulse) * pulse;

    // Edge highlight
    float edge = smoothstep(0.4, 0.5, dist) - smoothstep(0.5, 0.6, dist);
    edge *= sin(time * 3.0) * 0.3 + 0.7;

    float intensity = glow * 0.5 + edge * 0.3;

    float3 color = tintColor.rgb;

    return float4(color * intensity, intensity * tintColor.a);
}
