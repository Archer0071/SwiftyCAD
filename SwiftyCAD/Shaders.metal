//
//  Shaders.metal
//  Pipes
//
//  Created by Adil Hanif on 6/14/25.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};
struct GizmoVertex {
    float3 position;
    float4 color;
};

struct GizmoVertexOut {
    float4 position [[position]];
    float4 color;
};
// Gizmo vertex shader
vertex GizmoVertexOut gizmo_vertex(
    const device GizmoVertex *vertices [[buffer(0)]],
    constant float4x4 &mvp [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    GizmoVertexOut out;
    out.position = mvp * float4(vertices[vid].position, 1.0);
    out.color = vertices[vid].color;
    return out;
}

// Gizmo fragment shader
fragment float4 gizmo_fragment(GizmoVertexOut in [[stage_in]]) {
    return in.color;
}

// Main object vertex shader
vertex VertexOut vertex_main(
    VertexIn in [[stage_in]],
    constant float4x4 &mvp [[buffer(1)]],
    constant float4 &color [[buffer(2)]]
) {
    VertexOut out;
    out.position = mvp * float4(in.position, 1.0);
    out.color = color;  // Pass color to fragment shader
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}

// Grid vertex shader
vertex VertexOut grid_vertex(
    constant float3 *vertices [[buffer(0)]],
    constant float4x4 &mvp [[buffer(1)]],
    uint vertexID [[vertex_id]]
) {
    VertexOut out;
    out.position = mvp * float4(vertices[vertexID], 1.0);
    out.color = float4(0.5, 0.5, 0.5, 1.0);  // Changed to medium gray (RGB 0.5, 0.5, 0.5)
    return out;
}

// Grid fragment shader remains the same
fragment float4 grid_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}

// Axis vertex shader
vertex VertexOut axis_vertex(
    constant float3 *vertices [[buffer(0)]],
    constant float4x4 &mvp [[buffer(1)]],
    uint vertexID [[vertex_id]]
) {
    VertexOut out;
    out.position = mvp * float4(vertices[vertexID], 1.0);
    
    // Color axes differently
    if (vertexID < 2) {
        out.color = float4(1.0, 0.0, 0.0, 1.0);  // X axis (red)
    } else if (vertexID < 4) {
        out.color = float4(0.0, 1.0, 0.0, 1.0);  // Y axis (green)
    } else {
        out.color = float4(0.0, 0.0, 1.0, 1.0);  // Z axis (blue)
    }
    
    return out;
}
