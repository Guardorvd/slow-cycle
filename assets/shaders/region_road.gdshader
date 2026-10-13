// PR1 region surface shader: one material for FinalSurface tiles. Road
// shading from the renderer's UV (x = lateral offset, y = riding half width;
// terrain vertices carry x = 100), so the road edge follows the real roadbed.
// Gravel for BACKBONE / SECONDARY (half width >= 1 m), packed earth for
// SINGLETRACK / TECHNICAL; terrain from slope, height and world noise
// (meadow grass, darker forest floor, rock on steep ground). World-space
// noise keeps tile seams invisible. BC1 trails: vertices near a trail band
// carry UV (lateral, -half width); the band is worn earth with a trodden
// grass edge, the same edge the collision layers follow.
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 grass_light : source_color = vec3(0.39, 0.47, 0.22);
uniform vec3 grass_dark : source_color = vec3(0.23, 0.33, 0.15);
uniform vec3 forest_floor : source_color = vec3(0.24, 0.22, 0.14);
uniform vec3 rock : source_color = vec3(0.46, 0.44, 0.41);
uniform vec3 gravel : source_color = vec3(0.66, 0.59, 0.47);
uniform vec3 earth : source_color = vec3(0.47, 0.36, 0.25);
uniform vec3 shoulder : source_color = vec3(0.50, 0.46, 0.33);
uniform vec3 trail_earth : source_color = vec3(0.36, 0.27, 0.18);
uniform vec3 trail_edge : source_color = vec3(0.40, 0.40, 0.24);

varying float lateral;
varying float half_width;
varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return 0.5 * noise(p) + 0.3 * noise(p * 2.1) + 0.2 * noise(p * 4.3);
}

void vertex() {
	lateral = UV.x;
	half_width = UV.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float patches = fbm(world_pos.xz * 0.012);
	float detail = fbm(world_pos.xz * 0.35);
	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.3, 0.75, patches));
	grass = mix(grass, forest_floor, smoothstep(0.55, 0.85, fbm(world_pos.xz * 0.004 + 7.0)) * 0.6);
	vec3 terrain = mix(grass, rock, smoothstep(0.32, 0.55, slope + 0.08 * (detail - 0.5)));
	terrain *= 0.88 + 0.24 * detail;
	// Road: inside the riding width, a soft shoulder band to the plane edge.
	float d = abs(lateral) - half_width;
	bool is_trail = half_width < 0.0;
	bool is_road = lateral < 50.0 && !is_trail;
	vec3 surface = half_width >= 1.0 ? gravel : earth;
	surface *= 0.86 + 0.28 * fbm(world_pos.xz * 1.7);
	float ruts = half_width >= 1.0 ? smoothstep(0.15, 0.0, abs(abs(lateral) - half_width * 0.45)) * 0.08 : 0.0;
	surface *= 1.0 - ruts;
	vec3 color = terrain;
	if (is_trail) {
		float edge = abs(lateral) + half_width;
		vec3 dirt = trail_earth * (0.80 + 0.32 * fbm(world_pos.xz * 2.3));
		float band = 1.0 - smoothstep(-0.10, 0.06, edge + 0.06 * (detail - 0.5));
		float trodden = 1.0 - smoothstep(0.0, 0.7, edge);
		color = mix(mix(terrain, trail_edge, trodden * 0.6), dirt, band);
	} else if (is_road) {
		float road = 1.0 - smoothstep(-0.08, 0.10, d);
		float verge = 1.0 - smoothstep(0.1, 0.9, d);
		color = mix(mix(terrain, shoulder, verge * 0.7), surface, road);
	}
	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
}
