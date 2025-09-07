shader_type canvas_item;

// Uniforms show as editable properties on the ShaderMaterial
uniform vec3 vignette_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float inner = 0.40;     // radius where vignette starts (0..1)
uniform float outer = 0.98;     // radius where fully dark
uniform float softness = 1.5;   // >1 = softer falloff
uniform float intensity = 0.85; // 0..1 overall darkening

void fragment() {
    // SCREEN_UV is 0..1 across the whole viewport (Godot 4.x)
    vec2 uv = SCREEN_UV * 2.0 - 1.0; // center at (0,0), range -1..1
    float r = length(uv);

    // Blend from inner→outer radius
    float t = clamp((r - inner) / max(outer - inner, 0.0001), 0.0, 1.0);
    t = pow(t, softness);

    // Mix white (no change) to vignette_color
    vec3 col = mix(vec3(1.0), vignette_color, t * intensity);
    COLOR = vec4(col, 1.0);
}


void light() {
	// Called for every pixel for every light affecting the material.
}
