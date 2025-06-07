//
//  FluidShaders.metal
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct MetalFluidUniforms {
    float dt;
    float viscosity;
    float diffusion;
    float fadeRate;
    float forceMultiplier;
    uint width;
    uint height;
    uint iterations;
};

struct ForceData {
    float2 position;
    float2 velocity;
    float radius;
    float3 color;
};

// OPTIMIZED: Advection kernel with bilinear interpolation
kernel void advection_kernel(
    texture2d<float, access::read> velocity [[texture(0)]],
    texture2d<float, access::read> source [[texture(1)]],
    texture2d<float, access::write> destination [[texture(2)]],
    constant MetalFluidUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) return;
    
    float2 pos = float2(gid);
    float2 vel = velocity.read(gid).xy;
    
    // Backward advection
    float2 prevPos = pos - uniforms.dt * vel * float2(uniforms.width, uniforms.height);
    
    // Clamp to texture bounds
    prevPos = clamp(prevPos, float2(0.5), float2(uniforms.width - 0.5, uniforms.height - 0.5));
    
    // Bilinear interpolation
    uint2 coord0 = uint2(floor(prevPos));
    uint2 coord1 = coord0 + uint2(1, 0);
    uint2 coord2 = coord0 + uint2(0, 1);
    uint2 coord3 = coord0 + uint2(1, 1);
    
    float2 frac = prevPos - float2(coord0);
    
    float4 sample0 = source.read(coord0);
    float4 sample1 = source.read(coord1);
    float4 sample2 = source.read(coord2);
    float4 sample3 = source.read(coord3);
    
    float4 result = mix(
        mix(sample0, sample1, frac.x),
        mix(sample2, sample3, frac.x),
        frac.y
    );
    
    destination.write(result, gid);
}

// OPTIMIZED: Diffusion kernel with Jacobi iteration
kernel void diffusion_kernel(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> destination [[texture(1)]],
    constant MetalFluidUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) return;
    
    float alpha = uniforms.dt * uniforms.diffusion * uniforms.width * uniforms.height;
    float beta = 1.0 + 4.0 * alpha;
    
    float4 center = source.read(gid);
    
    // Sample neighbors with boundary conditions
    float4 left = (gid.x > 0) ? source.read(uint2(gid.x - 1, gid.y)) : center;
    float4 right = (gid.x < uniforms.width - 1) ? source.read(uint2(gid.x + 1, gid.y)) : center;
    float4 down = (gid.y > 0) ? source.read(uint2(gid.x, gid.y - 1)) : center;
    float4 up = (gid.y < uniforms.height - 1) ? source.read(uint2(gid.x, gid.y + 1)) : center;
    
    float4 result = (center + alpha * (left + right + down + up)) / beta;
    destination.write(result, gid);
}

// OPTIMIZED: Projection divergence calculation
kernel void projection_divergence_kernel(
    texture2d<float, access::read> velocity [[texture(0)]],
    texture2d<float, access::write> divergence [[texture(1)]],
    constant MetalFluidUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) return;
    if (gid.x == 0 || gid.x == uniforms.width - 1 || gid.y == 0 || gid.y == uniforms.height - 1) {
        divergence.write(float4(0), gid);
        return;
    }
    
    float2 velRight = velocity.read(uint2(gid.x + 1, gid.y)).xy;
    float2 velLeft = velocity.read(uint2(gid.x - 1, gid.y)).xy;
    float2 velUp = velocity.read(uint2(gid.x, gid.y + 1)).xy;
    float2 velDown = velocity.read(uint2(gid.x, gid.y - 1)).xy;
    
    float div = -0.5 * ((velRight.x - velLeft.x) + (velUp.y - velDown.y)) / uniforms.width;
    divergence.write(float4(div, 0, 0, 0), gid);
}

// OPTIMIZED: Projection pressure solver (same as diffusion)
kernel void projection_pressure_kernel(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> destination [[texture(1)]],
    constant MetalFluidUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) return;
    
    float4 center = source.read(gid);
    
    // Sample neighbors with boundary conditions
    float4 left = (gid.x > 0) ? source.read(uint2(gid.x - 1, gid.y)) : center;
    float4 right = (gid.x < uniforms.width - 1) ? source.read(uint2(gid.x + 1, gid.y)) : center;
    float4 down = (gid.y > 0) ? source.read(uint2(gid.x, gid.y - 1)) : center;
    float4 up = (gid.y < uniforms.height - 1) ? source.read(uint2(gid.x, gid.y + 1)) : center;
    
    float4 result = (center + left + right + down + up) / 4.0;
    destination.write(result, gid);
}

// OPTIMIZED: Projection gradient subtraction
kernel void projection_gradient_kernel(
    texture2d<float, access::read> pressure [[texture(0)]],
    texture2d<float, access::read_write> velocity [[texture(1)]],
    constant MetalFluidUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) return;
    if (gid.x == 0 || gid.x == uniforms.width - 1 || gid.y == 0 || gid.y == uniforms.height - 1) {
        return;
    }
    
    float pRight = pressure.read(uint2(gid.x + 1, gid.y)).x;
    float pLeft = pressure.read(uint2(gid.x - 1, gid.y)).x;
    float pUp = pressure.read(uint2(gid.x, gid.y + 1)).x;
    float pDown = pressure.read(uint2(gid.x, gid.y - 1)).x;
    
    float2 vel = velocity.read(gid).xy;
    vel.x -= 0.5 * (pRight - pLeft) * uniforms.width;
    vel.y -= 0.5 * (pUp - pDown) * uniforms.width;
    
    velocity.write(float4(vel, 0, 0), gid);
}

// OPTIMIZED: Add force with smooth falloff
kernel void add_force_kernel(
    texture2d<float, access::read_write> velocity [[texture(0)]],
    texture2d<float, access::read_write> density [[texture(1)]],
    texture2d<float, access::read_write> color [[texture(2)]],
    constant ForceData& force [[buffer(0)]],
    constant MetalFluidUniforms& uniforms [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) return;
    
    float2 pos = float2(gid);
    float2 forcePos = force.position * float2(uniforms.width, uniforms.height);
    
    float dist = length(pos - forcePos);
    if (dist > force.radius) return;
    
    // Smooth falloff
    float falloff = 1.0 - smoothstep(0.0, force.radius, dist);
    
    // Add velocity
    float2 vel = velocity.read(gid).xy;
    vel += force.velocity * falloff * uniforms.forceMultiplier * uniforms.dt;
    velocity.write(float4(vel, 0, 0), gid);
    
    // Add density
    float dens = density.read(gid).x;
    dens += falloff * 0.5;
    density.write(float4(dens, 0, 0, 0), gid);
    
    // Add color
    float3 col = color.read(gid).xyz;
    col += force.color * falloff * 0.3;
    color.write(float4(col, 1.0), gid);
}

// OPTIMIZED: Fade kernel
kernel void fade_kernel(
    texture2d<float, access::read_write> texture [[texture(0)]],
    constant MetalFluidUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) return;
    
    float4 value = texture.read(gid);
    value *= uniforms.fadeRate;
    texture.write(value, gid);
}

// FIXED: Render fragment shader for final display
fragment float4 fluid_display_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    texture2d<float> densityTexture [[texture(1)]],
    sampler textureSampler [[sampler(0)]]
) {
    // Use sample() with provided sampler - this is the correct approach
    float4 color = colorTexture.sample(textureSampler, in.texCoord);
    float density = densityTexture.sample(textureSampler, in.texCoord).x;
    
    // Combine color and density with beautiful blending
    float alpha = max(density, length(color.rgb) / 3.0);
    
    // Add subtle glow effect
    alpha = pow(alpha, 0.8);
    
    return float4(color.rgb, alpha);
}

// Vertex shader for fullscreen quad
vertex VertexOut fluid_display_vertex(uint vertexID [[vertex_id]]) {
    float2 positions[] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(1, -1), float2(1, 1), float2(-1, 1)
    };
    
    float2 texCoords[] = {
        float2(0, 1), float2(1, 1), float2(0, 0),
        float2(1, 1), float2(1, 0), float2(0, 0)
    };
    
    VertexOut out;
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = texCoords[vertexID];
    return out;
}
