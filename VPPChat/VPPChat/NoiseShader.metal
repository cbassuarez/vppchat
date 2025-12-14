//
//  NoiseShader.metal
//  VPPChat
//
//  Canonical animated halftone background:
//  - Rotated grid (π/4)
//  - FBM "life field" on cellIndex + time
//  - Radius-based pop in/out (no hard occupancy gating)
//  - Activity uniform gently scales time + dot size
//  - Pointer hover locally increases activity
//  - Clicks spawn an expanding ripple that swells + darkens dots along a ring
//

#include <metal_stdlib>
using namespace metal;

// ------------------------------------------------------------
// Shared structs (must match Swift NoiseUniforms)
// ------------------------------------------------------------

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct NoiseUniforms {
    float  time;             // seconds
    float  activity;         // 0 = idle, 1 = intense thinking
    float2 resolution;       // pixel resolution of drawable
    float3 structuralColor;  // RGB
    float3 exceptionColor;   // RGB

    float2 pointerUV;        // 0..1, pointer location in UV space
    float  pointerDown;      // 0 = up, 1 = mouse button down
    float  pointerPresent;   // 0 = outside view, 1 = hovering inside

    float2 rippleCenter;     // 0..1, UV of last click
    float  rippleTime;       // time of last click (same units as time)
    float  rippleActive;     // 0/1 – allows disabling ripple if desired
};

// ------------------------------------------------------------
// Hash + value noise + fbm
// ------------------------------------------------------------

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));

    float2 u = f * f * (3.0 - 2.0 * f); // smoothstep-like

    float ab = mix(a, b, u.x);
    float cd = mix(c, d, u.x);
    return mix(ab, cd, u.y);
}

float fbm(float2 p) {
    float v   = 0.0;
    float amp = 0.5;
    float freq = 1.0;

    // 4 octaves is enough for a smooth "life field"
    for (int i = 0; i < 4; ++i) {
        v    += amp * valueNoise(p * freq);
        freq *= 2.0;
        amp  *= 0.5;
    }
    return v;
}

// ------------------------------------------------------------
// Full-screen passthrough vertex shader
// ------------------------------------------------------------

vertex VertexOut vertex_passthrough(uint vid [[vertex_id]],
                                    const device float4 *vertices [[buffer(0)]]) {
    VertexOut out;
    float4 pos = vertices[vid];
    out.position = pos;

    // NDC [-1,1] → UV [0,1]
    out.uv = pos.xy * 0.5 + 0.5;
    return out;
}

// ------------------------------------------------------------
// Fragment: animated halftone with hover + ripple
// ------------------------------------------------------------

fragment float4 fragment_noise(VertexOut in [[stage_in]],
                               constant NoiseUniforms &u [[buffer(0)]]) {

    float2 uv       = in.uv;
    float  time     = u.time;
    float  activity = clamp(u.activity, 0.0, 1.0);
    float2 res      = u.resolution;

    // --------------------------------------------------------
    // Base aerogel tint: window color + subtle vertical gradient
    // --------------------------------------------------------

    float3 baseLight   = float3(0.96, 0.97, 0.99);
    float3 structural  = u.structuralColor;
    float3 exception   = u.exceptionColor;

    float  grad        = smoothstep(0.0, 1.0, uv.y);
    float3 gradTint    = mix(structural, exception, grad);
    float3 base        = mix(baseLight, gradTint, 0.06);

    // --------------------------------------------------------
    // Pointer influence (hover)
    // --------------------------------------------------------

    float2 pointerUV      = u.pointerUV;
    float  pointerDown    = u.pointerDown;
    float  pointerPresent = u.pointerPresent;

    float pointerInfluence = 0.0;
    if (pointerPresent > 0.5) {
        float2 d    = uv - pointerUV;
        float  dist = length(d);
        float  radius = 0.25; // normalized UV radius of influence
        float  falloff = smoothstep(radius, 0.0, dist); // 1 at center → 0 at edge
        pointerInfluence = falloff;
    }

    // --------------------------------------------------------
    // Click ripple: expanding ring that swells/darkens dots along its path
    // --------------------------------------------------------

    float ripple = 0.0;
    if (u.rippleActive > 0.5) {
        float dt = time - u.rippleTime;
        if (dt >= 0.0 && dt < 2.0) {
            float2 d    = uv - u.rippleCenter;
            float  dist = length(d);

            float  speed = 0.6;   // UV units per second
            float  band  = 0.10;  // ring thickness
            float  radius = dt * speed;

            float  ring = 1.0 - smoothstep(0.0, band, fabs(dist - radius));
            float  fade = smoothstep(2.0, 0.0, dt); // fade to 0 at 2s

            ripple = ring * fade;
        }
    }

    // --------------------------------------------------------
    // Local activity from hover + ripple
    // --------------------------------------------------------

    float hoverBoost  = 0.35 * pointerInfluence;
    float rippleBoost = 0.65 * ripple;    // stronger on the ripple path

    float localActivity = clamp(activity + hoverBoost + rippleBoost, 0.0, 1.0);

    // Time scale: idle → slow drift, thinking/interaction → faster evolution
    float timeScale = mix(0.18, 0.55, localActivity);
    float t         = time * timeScale;

    // --------------------------------------------------------
    // Halftone grid in rotated pixel space (canonical look)
    // --------------------------------------------------------

    float2 center    = res * 0.5;
    float2 screenPos = float2(uv.x * res.x, uv.y * res.y);
    float2 p         = screenPos - center;

    // Rotate by 45 degrees so grid isn't axis-aligned
    const float angle = 0.78539816339;  // π/4
    float s = sin(angle);
    float c = cos(angle);

    float2 pr;
    pr.x = p.x * c - p.y * s;
    pr.y = p.x * s + p.y * c;

    // Dot spacing – 7–8 px gives a dense but readable halftone
    const float cellSize = 7.5;

    float2 gridCoord  = pr / cellSize;
    float2 cellIndex  = floor(gridCoord);
    float2 cellCenter = (cellIndex + 0.5) * cellSize;
    float2 local      = pr - cellCenter;  // local coords inside one cell

    // --------------------------------------------------------
    // Coherent "life field" over the grid (clusters of alive cells)
    // --------------------------------------------------------

    const float  clusterScale = 0.25;
    const float2 drift        = float2(0.07, -0.04);

    float2 lifeCoord = cellIndex * clusterScale + t * drift;
    float  life      = fbm(lifeCoord);    // 0..1
    life             = life * 2.0 - 1.0;  // ~[-1,1]

    // Bias alive fraction slightly with activity, but keep it smooth
    float aliveSoft = smoothstep(
        -0.35 - 0.10 * activity,
         0.35 + 0.10 * activity,
         life
    ); // 0..1

    // Sharpen so blobs have clearer edges
    float alive = pow(aliveSoft, 1.6);

    // Hard-ish gating to make a lot of cells truly off (no dot),
    // but not so harsh that it becomes sparse.
    float aliveHard = smoothstep(0.22, 0.55, alive);

    // --------------------------------------------------------
    // Dot radius per cell (pop in/out via radius, not binary presence)
    // --------------------------------------------------------

    // Per-cell static phase jitter
    float phaseJitter = hash21(cellIndex);

    // Slow pulsing, modulated by local activity
    float basePulseFreq = mix(0.65, 1.0, localActivity);
    float pulsate = 0.5 + 0.5 * sin(t * basePulseFreq + phaseJitter * 6.28318);

    // Activity-scaled radius range (canonical values)
    float minRadius = mix(0.16, 0.20, activity);
    float maxRadius = mix(0.34, 0.50, activity);

    float radiusNorm = aliveHard * mix(minRadius, maxRadius, pulsate);

    // Optional "neuronal" standing waves: modulate radius slightly,
    // do NOT gate dots.
    float waveX = sin(uv.x * 3.2 + t * 0.9);
    float waveY = sin(uv.y * 2.1 + t * 0.7);
    float wave  = waveX * waveY;              // -1..1
    float waveNorm = 0.5 * (wave + 1.0);      // 0..1

    float waveAmount = 0.15 * localActivity;  // small swell/shrink only
    float waveFactor = mix(1.0, waveNorm, waveAmount);

    radiusNorm *= waveFactor;

    // Also let the ripple swell dots on its ring a bit more
    radiusNorm *= (1.0 + 0.35 * ripple);

    // --------------------------------------------------------
    // Circle mask in normalized cell space
    // --------------------------------------------------------

    float r = length(local) / (cellSize * 0.5);

    const float edge = 0.15; // soft edge for halftone look
    float circle = 1.0 - smoothstep(radiusNorm, radiusNorm + edge, r);

    // Apply aliveHard again so nearly-dead cells fully fade out
    circle *= aliveHard;

    // --------------------------------------------------------
    // Compose final color: dots as darkening of base aerogel
    // --------------------------------------------------------

    const float dotStrengthBase = 0.23;

    // Slightly stronger dots as activity ramps, plus ripple accent
    float dotStrength = dotStrengthBase * (0.85 + 0.45 * localActivity);
    dotStrength      *= (1.0 + 0.50 * ripple);

    float3 color = base * (1.0 - dotStrength * circle);

    // 🔑 Aerogel alpha: tweak 0.6–0.85 to taste
    float alpha = 0.78;

    return float4(color, alpha);

}
