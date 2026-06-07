# Painted card art that MOVES — Magic-Arena style.
#
# Primary mode (when a depth map exists): true 2.5D parallax. The painting is
# re-projected through its depth map on a slowly orbiting camera, tilts toward
# the mouse on hover, gets a depth-aware light sweep gliding over the relief
# and a rim light catching silhouettes — smooth 60 fps at full art resolution.
# Per-subject effect layers play on top: magic rays from the magician's hands,
# a shimmer crowning the king, rising embers at the smithy, ghost-wisps over
# the haunted city…
#
# Art images live in res://assets/art/<slug>.png (tools/generate_art_local.py),
# depth maps in res://assets/depth/<slug>.png (tools/generate_depth.py, white =
# near). Fallback chain: depth parallax → AnimateDiff motion sheet → painted
# still with cinemagraph shader → procedural 3D diorama (elsewhere).
class_name LivingArt
extends TextureRect

# effect kinds (must match the shader's `kind` branches)
const AMBIENT := 0      # breathing zoom + cloud-shadow drift
const WATER := 1        # waves: displacement below water_level + glints
const RAYS := 2         # rotating light beams from `focus` (magic / holy light)
const SPARKS := 3       # particle sparks around `focus` (embers, gold glints)
const WISPS := 4        # slow large ghostly motes drifting upward
const CROWN := 5        # golden shimmer descends onto `focus`, bursts, repeats
const STARS := 6        # twinkling star field in the upper half
const MIST := 7         # rolling low mist + slow smoke

const SHADER_CODE := "
shader_type canvas_item;

uniform int kind = 0;
uniform float seed_offset = 0.0;
uniform vec2 focus = vec2(0.5, 0.55);
uniform vec4 fx_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float water_level = 0.6;
uniform float strength = 1.0;

// 2.5D parallax
uniform sampler2D depth_tex;
uniform bool use_depth = false;
uniform float parallax = 0.05;       // max UV displacement at full tilt
uniform vec2 tilt = vec2(0.0);       // hover tilt from the script, -1..1

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// one layer of grid particles drifting along dir; returns brightness
float particles(vec2 uv, float t, float scale, float speed, vec2 dir) {
	vec2 g = uv * scale + seed_offset;
	vec2 id = floor(g);
	float h = hash(id);
	vec2 p = fract(g);
	vec2 pp = vec2(fract(h * 7.13 + dir.x * t * speed),
	               fract(h * 3.71 - dir.y * t * speed));
	float d = length(p - pp);
	float tw = 0.55 + 0.45 * sin(t * 5.0 + h * 31.0);
	return smoothstep(0.16, 0.0, d) * tw * step(0.35, h);
}

void fragment() {
	vec2 suv = UV;          // screen-stable uv for effects
	float t = TIME;

	// camera: slow orbital drift; the hover tilt (from the script) takes over
	vec2 cam = vec2(cos(t * 0.26 + seed_offset), sin(t * 0.19 + seed_offset * 1.7)) * 0.30;
	cam = cam * (1.0 - 0.7 * min(1.0, length(tilt))) + tilt;

	// zoom in just enough that parallax offsets never reveal the border
	float z = 1.0 + parallax * 2.4 + 0.012 * sin(t * 0.15 + seed_offset);
	vec2 uv = (UV - 0.5) / z + 0.5;

	float dnear = 0.5;
	if (use_depth) {
		// iterative parallax: re-project the painting through its depth map
		vec2 off = vec2(0.0);
		for (int i = 0; i < 3; i++) {
			float d = texture(depth_tex, uv + off).r;
			off = (d - 0.45) * cam * parallax;
		}
		uv += off;
		dnear = texture(depth_tex, uv).r;
	} else {
		// organic sway — the painting subtly moves like fabric in a draft
		vec2 sway = vec2(vnoise(uv * 2.6 + t * 0.14),
		                 vnoise(uv * 2.6 - t * 0.11 + 7.0)) - 0.5;
		uv += sway * 0.007 * strength;
	}

	if (kind == 1) {
		// water: ripple displacement grows below the waterline, the whole
		// region bobs gently — boats ride the swell
		float m = smoothstep(water_level - 0.04, water_level + 0.10, uv.y);
		uv.x += m * sin(uv.y * 70.0 + t * 1.9) * 0.0065;
		uv.y += m * (sin(uv.x * 46.0 - t * 1.4) * 0.005 + sin(t * 0.9) * 0.006);
	} else if (kind == 7) {
		// mist: heavier smoke-like distortion
		uv += (vec2(vnoise(uv * 4.0 + t * 0.3), vnoise(uv * 4.0 - t * 0.25 + 3.0)) - 0.5) * 0.012;
	}

	vec4 col = texture(TEXTURE, uv);

	if (use_depth) {
		// near elements pop: gentle depth-keyed contrast
		col.rgb *= 0.93 + 0.16 * dnear;
		// rim light catching silhouettes (depth gradient facing the key light)
		vec2 e = vec2(0.014, 0.0);
		vec2 grad = vec2(texture(depth_tex, uv - e.xy).r - texture(depth_tex, uv + e.xy).r,
		                 texture(depth_tex, uv - e.yx).r - texture(depth_tex, uv + e.yx).r);
		float gl = length(grad);
		float rim = clamp(dot(grad, normalize(vec2(0.6, 0.8))) * 6.0, 0.0, 1.0)
		          * smoothstep(0.02, 0.14, gl);
		col.rgb += rim * fx_color.rgb * 0.16;
	}

	if (kind == 0 && !use_depth) {
		// drifting cloud shadows
		float cloud = vnoise(suv * 1.6 + vec2(t * 0.045, 0.0));
		col.rgb *= 0.92 + 0.13 * cloud;
	} else if (kind == 1) {
		// glints dancing on the water
		float m = smoothstep(water_level, water_level + 0.12, suv.y);
		float g = pow(vnoise(suv * vec2(46.0, 16.0) + vec2(t * 0.7, -t * 0.22)), 4.0);
		col.rgb += m * g * fx_color.rgb * 0.8 * strength;
	} else if (kind == 2) {
		// rotating rays from the focus + outward-flying sparks
		vec2 d = suv - focus;
		float ang = atan(d.y, d.x);
		float dist = length(d);
		float beams = pow(abs(sin(ang * 4.0 + t * 1.6)), 14.0) * exp(-dist * 4.0);
		float pulse = 0.75 + 0.25 * sin(t * 2.3 + seed_offset);
		col.rgb += beams * pulse * fx_color.rgb * 1.35 * strength;
		float core = exp(-dist * 9.0) * (0.5 + 0.5 * sin(t * 3.1));
		col.rgb += core * fx_color.rgb * 0.9;
		float sp = particles(suv, t, 9.0, 0.35, normalize(d + vec2(0.001)) * vec2(1.0, -1.0));
		col.rgb += sp * exp(-dist * 3.0) * fx_color.rgb * 1.2;
	} else if (kind == 3) {
		// sparks / embers rising near focus
		float zone = exp(-length((suv - focus) * vec2(1.6, 1.2)) * 2.2);
		float sp = particles(suv, t, 11.0, 0.5, vec2(0.06, 1.0))
		         + particles(suv, t, 19.0, 0.8, vec2(-0.04, 1.0)) * 0.6;
		col.rgb += sp * zone * fx_color.rgb * 1.5 * strength;
		col.rgb += zone * 0.10 * fx_color.rgb * (0.6 + 0.4 * sin(t * 3.7));
	} else if (kind == 4) {
		// ghostly wisps floating up
		float sp = particles(suv, t, 5.0, 0.16, vec2(0.18, 1.0));
		float sp2 = particles(suv + 3.7, t, 7.5, 0.11, vec2(-0.12, 1.0));
		col.rgb += (sp + sp2 * 0.7) * fx_color.rgb * 0.9 * strength;
		float fog = vnoise(suv * 2.4 + vec2(t * 0.06, t * 0.02));
		col.rgb += smoothstep(0.55, 1.0, suv.y) * fog * fx_color.rgb * 0.16;
	} else if (kind == 5) {
		// the crown comes alive: a golden shimmer descends, lands, bursts
		float cycle = fract(t * 0.16 + seed_offset);
		float drop = smoothstep(0.0, 0.42, cycle);
		float beam_y = mix(-0.15, focus.y, drop);
		float beam = exp(-pow((suv.y - beam_y) * 9.0, 2.0))
		           * exp(-pow((suv.x - focus.x) * 3.4, 2.0));
		float alive = 1.0 - smoothstep(0.42, 0.58, cycle);
		col.rgb += beam * alive * fx_color.rgb * 0.55;
		float burst = exp(-pow((cycle - 0.46) * 9.0, 2.0));
		float star = pow(max(0.0, 1.0 - length((suv - focus) * vec2(5.0, 7.0))), 2.5);
		col.rgb += burst * star * fx_color.rgb * 1.3;
		float sp = particles(suv, t, 13.0, 0.3, vec2(0.0, 1.0));
		col.rgb += sp * star * 0.8 * fx_color.rgb;
	} else if (kind == 6) {
		// twinkling stars in the sky region
		float sky = smoothstep(0.55, 0.15, suv.y);
		float s1 = particles(suv, t, 16.0, 0.015, vec2(0.2, 0.1));
		float s2 = particles(suv + 11.3, t, 26.0, 0.01, vec2(-0.1, 0.05));
		col.rgb += (s1 + s2 * 0.7) * sky * fx_color.rgb * 1.1;
	} else if (kind == 7) {
		// rolling ground mist
		float fog = vnoise(suv * 3.0 + vec2(t * 0.08, 0.0))
		          * vnoise(suv * 1.5 - vec2(t * 0.05, 0.0));
		float low = smoothstep(0.45, 0.95, suv.y);
		col.rgb = mix(col.rgb, fx_color.rgb * 0.55 + 0.25, fog * low * 0.34 * strength);
		float sp = particles(suv, t, 6.0, 0.1, vec2(0.3, 0.6));
		col.rgb += sp * low * fx_color.rgb * 0.35;
	}

	// roaming light sweep — glides over the relief when depth is available
	float band = fract(t * 0.05 + seed_offset * 0.13);
	float sweep = smoothstep(0.09, 0.0, abs(suv.x + suv.y * 0.45 - band * 2.4 + 0.4));
	float relief = use_depth ? (0.35 + 1.25 * dnear) : 1.0;
	col.rgb += sweep * 0.07 * relief;

	// vignette
	float vig = smoothstep(0.95, 0.45, length(UV - 0.5) * 1.32);
	col.rgb *= mix(0.72, 1.04, vig);
	COLOR = col;
}
"

# Per-subject effect configuration: kind, focus point, color, extras.
const EFFECTS := {
	# Characters
	"Assassin": {"kind": MIST, "color": Color(0.55, 0.25, 0.65), "strength": 0.8},
	"Thief": {"kind": SPARKS, "focus": Vector2(0.52, 0.68), "color": Color(1.0, 0.85, 0.35), "strength": 0.8},
	"Magician": {"kind": RAYS, "focus": Vector2(0.5, 0.58), "color": Color(0.72, 0.45, 1.0)},
	"King": {"kind": CROWN, "focus": Vector2(0.5, 0.22), "color": Color(1.0, 0.85, 0.4)},
	"Bishop": {"kind": RAYS, "focus": Vector2(0.5, 0.16), "color": Color(1.0, 0.95, 0.75), "strength": 0.55},
	"Merchant": {"kind": SPARKS, "focus": Vector2(0.5, 0.62), "color": Color(1.0, 0.85, 0.35), "strength": 0.7},
	"Architect": {"kind": STARS, "color": Color(0.95, 0.9, 0.75), "strength": 0.6},
	"Warlord": {"kind": SPARKS, "focus": Vector2(0.5, 0.85), "color": Color(1.0, 0.45, 0.15)},

	# Districts
	"Manor": {"kind": AMBIENT},
	"Castle": {"kind": AMBIENT},
	"Palace": {"kind": SPARKS, "focus": Vector2(0.5, 0.3), "color": Color(1.0, 0.9, 0.5), "strength": 0.45},
	"Temple": {"kind": RAYS, "focus": Vector2(0.5, 0.3), "color": Color(1.0, 0.9, 0.6), "strength": 0.4},
	"Church": {"kind": RAYS, "focus": Vector2(0.5, 0.28), "color": Color(1.0, 0.93, 0.7), "strength": 0.4},
	"Monastery": {"kind": AMBIENT},
	"Cathedral": {"kind": RAYS, "focus": Vector2(0.5, 0.3), "color": Color(0.8, 0.7, 1.0), "strength": 0.45},
	"Tavern": {"kind": SPARKS, "focus": Vector2(0.45, 0.55), "color": Color(1.0, 0.7, 0.3), "strength": 0.55},
	"Market": {"kind": AMBIENT},
	"Trading Post": {"kind": AMBIENT},
	"Docks": {"kind": WATER, "water": 0.62, "color": Color(0.65, 0.85, 1.0)},
	"Harbor": {"kind": WATER, "water": 0.58, "color": Color(1.0, 0.85, 0.55)},
	"Town Hall": {"kind": AMBIENT},
	"Watchtower": {"kind": SPARKS, "focus": Vector2(0.5, 0.25), "color": Color(1.0, 0.6, 0.2)},
	"Prison": {"kind": MIST, "color": Color(0.5, 0.55, 0.6), "strength": 0.6},
	"Battlefield": {"kind": MIST, "color": Color(0.7, 0.55, 0.45)},
	"Fortress": {"kind": AMBIENT},
	"Haunted City": {"kind": WISPS, "color": Color(0.35, 1.0, 0.7)},
	"Keep": {"kind": AMBIENT},
	"Laboratory": {"kind": SPARKS, "focus": Vector2(0.5, 0.55), "color": Color(0.4, 1.0, 0.5), "strength": 0.8},
	"Smithy": {"kind": SPARKS, "focus": Vector2(0.5, 0.6), "color": Color(1.0, 0.55, 0.15)},
	"Graveyard": {"kind": WISPS, "color": Color(0.55, 0.95, 0.75), "strength": 0.8},
	"Observatory": {"kind": STARS, "color": Color(0.85, 0.9, 1.0)},
	"Library": {"kind": SPARKS, "focus": Vector2(0.5, 0.5), "color": Color(1.0, 0.85, 0.5), "strength": 0.35},
	"School of Magic": {"kind": RAYS, "focus": Vector2(0.5, 0.35), "color": Color(0.6, 0.5, 1.0), "strength": 0.8},
	"Dragon Gate": {"kind": RAYS, "focus": Vector2(0.5, 0.55), "color": Color(1.0, 0.35, 0.1), "strength": 0.9},
	"University": {"kind": AMBIENT},
	"Great Wall": {"kind": AMBIENT},
}

# ── Motion sheets: 16-frame AnimateDiff clips in a 4x4 grid, played back as
# looping video. Kept as a fallback for art that has no depth map yet.
const MOTION_SHADER_CODE := "
shader_type canvas_item;

uniform float seed_offset = 0.0;
uniform float fps = 9.0;
uniform float cols = 4.0;
uniform float rows = 4.0;
uniform float frames = 16.0;
uniform int loop_mode = 0;   // 0 = ping-pong, 1 = forward then hold, repeat

void fragment() {
	float t = TIME * fps + seed_offset * 10.0;
	float f;
	if (loop_mode == 0) {
		float total = frames * 2.0 - 2.0;
		float k = mod(t, total);
		f = (k < frames) ? k : (total - k);
	} else {
		float cycle = frames * 1.9;   // play, hold on last frame, restart
		f = min(frames - 1.0, mod(t, cycle));
	}
	float fi = clamp(floor(f), 0.0, frames - 1.0);
	vec2 cell = vec2(mod(fi, cols), floor(fi / cols));
	vec2 uv = (UV + cell) / vec2(cols, rows);
	vec4 col = texture(TEXTURE, uv);
	float vig = smoothstep(0.95, 0.45, length(UV - 0.5) * 1.32);
	col.rgb *= mix(0.74, 1.04, vig);
	COLOR = col;
}
"

# One-shot motions hold their final pose before replaying.
const ONE_SHOT := ["King", "Assassin", "Warlord", "Architect", "Magician"]

# How fast the hover tilt follows the mouse (exponential smoothing rate).
const TILT_RATE := 7.0

static var _shader: Shader
static var _motion_shader: Shader

var _tilt := Vector2.ZERO


static func slug(art_name: String) -> String:
	return art_name.to_lower().replace(" ", "_")


static func art_path(art_name: String) -> String:
	return "res://assets/art/%s.png" % slug(art_name)


static func has_art(art_name: String) -> bool:
	return ResourceLoader.exists(art_path(art_name))


static func depth_path(art_name: String) -> String:
	return "res://assets/depth/%s.png" % slug(art_name)


static func has_depth(art_name: String) -> bool:
	return ResourceLoader.exists(depth_path(art_name))


static func motion_path(art_name: String) -> String:
	return "res://assets/motion/%s.webp" % slug(art_name)


static func has_motion(art_name: String) -> bool:
	return ResourceLoader.exists(motion_path(art_name))


static func has_any(art_name: String) -> bool:
	return has_art(art_name) or has_motion(art_name)


static func motion_material(art_name: String) -> ShaderMaterial:
	if _motion_shader == null:
		_motion_shader = Shader.new()
		_motion_shader.code = MOTION_SHADER_CODE
	var sm := ShaderMaterial.new()
	sm.shader = _motion_shader
	sm.set_shader_parameter("seed_offset", randf() * 20.0)
	sm.set_shader_parameter("loop_mode", 1 if art_name in ONE_SHOT else 0)
	return sm


static func make_material(art_name := "") -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var sm := ShaderMaterial.new()
	sm.shader = _shader
	sm.set_shader_parameter("seed_offset", randf() * 20.0)
	var fx: Dictionary = EFFECTS.get(art_name, {"kind": AMBIENT})
	sm.set_shader_parameter("kind", fx.get("kind", AMBIENT))
	sm.set_shader_parameter("focus", fx.get("focus", Vector2(0.5, 0.55)))
	sm.set_shader_parameter("fx_color", fx.get("color", Color(1.0, 0.85, 0.4)))
	sm.set_shader_parameter("water_level", fx.get("water", 0.6))
	sm.set_shader_parameter("strength", fx.get("strength", 1.0))
	if art_name != "" and has_depth(art_name):
		sm.set_shader_parameter("use_depth", true)
		sm.set_shader_parameter("depth_tex", load(depth_path(art_name)))
	return sm


static func make(art_name: String, animated := true) -> LivingArt:
	var node := LivingArt.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	node.clip_contents = true
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if animated and has_art(art_name) and has_depth(art_name):
		# 2.5D parallax over the full-res painting (the Arena look)
		node.texture = load(art_path(art_name))
		node.material = make_material(art_name)
		node.set_process(true)
	elif animated and has_motion(art_name):
		# video playback from the AnimateDiff sprite sheet (no depth map yet)
		node.texture = load(motion_path(art_name))
		node.material = motion_material(art_name)
	elif has_motion(art_name) and not has_art(art_name):
		# static contexts (mini city tiles): first frame of the clip
		var sheet: Texture2D = load(motion_path(art_name))
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(0, 0, sheet.get_width() / 4.0, sheet.get_height() / 4.0)
		node.texture = at
	else:
		node.texture = load(art_path(art_name))
		if animated:
			node.material = make_material(art_name)
	return node


func _ready() -> void:
	# only the depth-parallax path needs per-frame tilt tracking
	if not (material is ShaderMaterial and (material as ShaderMaterial).shader == _shader):
		set_process(false)


func _process(delta: float) -> void:
	# tilt toward the mouse while it is over the art; ease back to the idle
	# orbit when it leaves
	var r := get_global_rect()
	if r.size.x <= 0.0:
		return
	var n := (get_global_mouse_position() - r.get_center()) / (r.size * 0.5)
	var target := n.limit_length(1.0) if (absf(n.x) <= 1.05 and absf(n.y) <= 1.05) else Vector2.ZERO
	_tilt = _tilt.lerp(target, 1.0 - exp(-TILT_RATE * delta))
	(material as ShaderMaterial).set_shader_parameter("tilt", _tilt)
