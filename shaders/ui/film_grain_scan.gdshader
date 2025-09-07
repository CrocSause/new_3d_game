shader_type canvas_item;

// ==== Grain controls ====
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float grain_scale     : hint_range(0.5, 4.0) = 1.0;
uniform float grain_speed     : hint_range(0.0, 5.0) = 1.2;

// ==== Scanline controls ====
uniform float scan_intensity  : hint_range(0.0, 1.0) = 0.06;
uniform float scan_density    : hint_range(50.0, 2000.0) = 720.0; // lines per screen height
uniform float scan_speed      : hint_range(-10.0, 10.0) = -1.0;   // drift speed

// ==== Flicker (very subtle) ====
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.02;
uniform float flicker_speed     : hint_range(0.0, 20.0) = 6.0;

// Cheap hash (textureless noise), stable in 4.x
float hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return fract(sin(p.x + p.y) * 43758.5453123);
}

void fragment() {
    vec2 suv = SCREEN_UV;

    // Grain: animate a sampling grid over time
    vec2 g_uv = suv * (800.0 / max(grain_scale, 0.001)) + vec2(TIME * grain_speed, -TIME * 0.9);
    float grain = hash(floor(g_uv));

    // Less grain in the center, more toward edges (retro look)
    float center = length(suv * 2.0 - 1.0);
    float center_weight = smoothstep(1.0, 0.2, center);
    float grain_amt = grain_intensity * mix(0.7, 1.0, center_weight);

    // Horizontal scanlines
    float lines = sin((suv.y + TIME * scan_speed) * scan_density * 3.14159265);
    lines = (lines * 0.5 + 0.5) * scan_intensity;

    // Subtle global flicker
    float flicker = (sin(TIME * flicker_speed) * 0.5 + 0.5) * flicker_intensity;

    // Combine to a luminance multiplier
    float shade = 1.0 - lines - flicker + (grain - 0.5) * 2.0 * grain_amt;

    COLOR = vec4(vec3(shade), 1.0);
}


void light() {
	// Called for every pixel for every light affecting the material.
}
