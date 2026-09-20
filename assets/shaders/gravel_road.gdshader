shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Rich warm dirt & gravel path with compacted tire tracks
const vec3 BASE_GRAVEL = vec3(0.36, 0.28, 0.20);
const vec3 RUT_COLOR = vec3(0.26, 0.20, 0.14);
const vec3 PEBBLE_LIGHT = vec3(0.44, 0.37, 0.28);
const vec3 PEBBLE_DARK = vec3(0.22, 0.17, 0.12);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
    vec2 uv = UV;
    float lateral = uv.x;
    
    // Multi-frequency pebble noise
    float fine_pebbles = noise(uv * vec2(20.0, 80.0));
    float coarse_dirt = noise(uv * vec2(4.0, 16.0));
    
    // Two defined tire ruts at 26% and 74% across road width
    float rut_left = 1.0 - smoothstep(0.0, 0.14, abs(lateral - 0.26));
    float rut_right = 1.0 - smoothstep(0.0, 0.14, abs(lateral - 0.74));
    float in_ruts = max(rut_left, rut_right);
    
    vec3 col = mix(BASE_GRAVEL, RUT_COLOR, in_ruts * 0.55);
    col = mix(col, PEBBLE_LIGHT, fine_pebbles * 0.2);
    col = mix(col, PEBBLE_DARK, (1.0 - fine_pebbles) * 0.15);
    col *= (0.85 + 0.25 * coarse_dirt);
    
    // Center grassy/dirt strip between ruts
    float center_ridge = 1.0 - smoothstep(0.0, 0.16, abs(lateral - 0.5));
    col = mix(col, BASE_GRAVEL * 1.05, center_ridge * 0.25);

    ALBEDO = col;
    ROUGHNESS = 0.94;
    SPECULAR = 0.1;
}
