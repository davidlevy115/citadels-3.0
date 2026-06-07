# A SubViewport that renders one procedural 3D vignette (character or district)
# with cinematic lighting: shadowed key light, cool rim, bloom, filmic tone
# mapping, an atmospheric backdrop and floating dust motes.
class_name CardArt
extends SubViewport

var rig: Node3D
var spin_speed := 0.5
var _time := 0.0
var animated := true


static func create(art_name: String, px: int, p_animated := true, accent := Color(0.5, 0.45, 0.7)) -> CardArt:
	var vp := CardArt.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.animated = p_animated
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if p_animated else SubViewport.UPDATE_ONCE
	vp.msaa_3d = Viewport.MSAA_4X
	vp.positional_shadow_atlas_size = 1024

	# ── Key light: warm, casts soft shadows
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, 0.55, 0)
	sun.light_energy = 1.6
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 12.0
	vp.add_child(sun)

	# ── Rim light: cool, from behind — silhouettes pop
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.35, PI + 0.65, 0)
	rim.light_energy = 1.1
	rim.light_color = accent.lightened(0.45)
	vp.add_child(rim)

	# ── Fill: soft violet bounce from the left
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.2, -1.4, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.55, 0.50, 0.75)
	vp.add_child(fill)

	# ── Accent point light hovering above the diorama
	var spark := OmniLight3D.new()
	spark.position = Vector3(0, 2.1, 0.8)
	spark.light_energy = 0.5
	spark.omni_range = 5.0
	spark.light_color = accent.lightened(0.3)
	vp.add_child(spark)

	# ── Environment: ambient, bloom, filmic tonemap
	var env_node := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.38, 0.36, 0.50)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 1.05
	env_node.environment = e
	vp.add_child(env_node)

	# ── Atmospheric backdrop: huge unshaded radial-gradient disc behind the scene
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		accent.darkened(0.55) * Color(1, 1, 1, 0.85),
		Color(0.03, 0.02, 0.06, 0.0),
	])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	var back_mat := StandardMaterial3D.new()
	back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	back_mat.albedo_texture = gtex
	back_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(7.0, 7.0)
	var backdrop := MeshInstance3D.new()
	backdrop.mesh = quad
	backdrop.material_override = back_mat
	backdrop.position = Vector3(0, 1.0, -2.2)
	vp.add_child(backdrop)

	# ── Floating dust motes
	if p_animated:
		var motes := CPUParticles3D.new()
		motes.amount = 14
		motes.lifetime = 6.0
		motes.preprocess = 6.0
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		motes.emission_box_extents = Vector3(1.4, 1.2, 1.0)
		motes.position = Vector3(0, 1.1, 0)
		motes.direction = Vector3(0, 1, 0)
		motes.spread = 25.0
		motes.gravity = Vector3.ZERO
		motes.initial_velocity_min = 0.05
		motes.initial_velocity_max = 0.16
		motes.scale_amount_min = 0.012
		motes.scale_amount_max = 0.035
		var mote_mesh := SphereMesh.new()
		mote_mesh.radius = 1.0
		mote_mesh.height = 2.0
		mote_mesh.radial_segments = 6
		mote_mesh.rings = 3
		motes.mesh = mote_mesh
		var mote_mat := StandardMaterial3D.new()
		mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mote_mat.albedo_color = accent.lightened(0.55) * Color(1, 1, 1, 0.65)
		mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mote_mesh.material = mote_mat
		vp.add_child(motes)

	# ── Camera: low heroic angle
	var cam := Camera3D.new()
	var cam_pos := Vector3(0, 1.35, 3.05)
	var target := Vector3(0, 0.62, 0)
	cam.transform = Transform3D(Basis.looking_at((target - cam_pos).normalized(), Vector3.UP), cam_pos)
	cam.fov = 35
	vp.add_child(cam)

	# ── Turntable rig + model
	vp.rig = Node3D.new()
	vp.rig.name = "Rig"
	var model := Models.build(art_name)
	vp.rig.add_child(model)
	vp.add_child(vp.rig)
	vp.rig.rotation.y = randf() * TAU

	return vp


func _process(delta: float) -> void:
	if not animated or rig == null:
		return
	_time += delta
	rig.rotation.y += delta * spin_speed
	# gentle bob for a "floating diorama" feel
	rig.position.y = sin(_time * 1.3) * 0.025
