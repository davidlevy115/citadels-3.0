# Procedural 3D model factory — every character and district gets its own
# hand-built low-poly vignette assembled from mesh primitives.
# All geometry/materials are generated in code: zero external (paid) assets.
class_name Models

# ── Shared palette ──────────────────────────────────────────────
const STONE := Color(0.62, 0.60, 0.58)
const STONE_DARK := Color(0.42, 0.40, 0.40)
const WOOD := Color(0.45, 0.30, 0.17)
const WOOD_DARK := Color(0.32, 0.21, 0.12)
const GRASS := Color(0.30, 0.45, 0.22)
const GOLD := Color(0.95, 0.78, 0.25)
const FLAME := Color(1.0, 0.55, 0.15)
const SKIN := Color(0.87, 0.67, 0.53)


# ── Procedural surface textures (shared, generated once) ───────

static var _grain_albedo: NoiseTexture2D
static var _grain_normal: NoiseTexture2D


static func _surface_textures() -> void:
	if _grain_albedo != null:
		return
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.045
	n.fractal_octaves = 4

	_grain_albedo = NoiseTexture2D.new()
	_grain_albedo.noise = n
	_grain_albedo.seamless = true
	_grain_albedo.width = 128
	_grain_albedo.height = 128
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.82, 0.82, 0.82), Color(1, 1, 1)])
	_grain_albedo.color_ramp = ramp

	_grain_normal = NoiseTexture2D.new()
	_grain_normal.noise = n
	_grain_normal.seamless = true
	_grain_normal.width = 128
	_grain_normal.height = 128
	_grain_normal.as_normal_map = true
	_grain_normal.bump_strength = 4.0


# ── Material / primitive helpers ────────────────────────────────

static func mat(albedo: Color, emission := Color.BLACK, energy := 1.0, metallic := 0.0, roughness := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = roughness
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	else:
		# every lit surface gets subtle grain + bump — kills the "plastic" look
		_surface_textures()
		m.albedo_texture = _grain_albedo
		m.normal_enabled = true
		m.normal_texture = _grain_normal
		m.normal_scale = 0.55
		m.uv1_scale = Vector3(2.2, 2.2, 2.2)
	return m


static func add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return add_mesh(parent, m, pos, material, rot)


static func cyl(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 20
	return add_mesh(parent, m, pos, material, rot)


static func cone(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 20
	return add_mesh(parent, m, pos, material)


static func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return add_mesh(parent, m, pos, material)


static func torus(parent: Node3D, inner: float, outer: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	return add_mesh(parent, m, pos, material, rot)


static func prism(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	return add_mesh(parent, m, pos, material, rot)


# ── Composite helpers ───────────────────────────────────────────

static func ground(parent: Node3D, color := GRASS, radius := 1.25) -> void:
	# layered stone pedestal with a soft glowing seam — a museum diorama base
	var base := CylinderMesh.new()
	base.top_radius = radius * 1.04
	base.bottom_radius = radius * 1.16
	base.height = 0.1
	base.radial_segments = 32
	add_mesh(parent, base, Vector3(0, -0.16, 0), mat(Color(0.16, 0.15, 0.20), Color.BLACK, 1.0, 0.15, 0.55))
	var seam := TorusMesh.new()
	seam.inner_radius = radius * 0.99
	seam.outer_radius = radius * 1.05
	add_mesh(parent, seam, Vector3(0, -0.11, 0), mat(Color(0.2, 0.18, 0.26), Color(0.45, 0.38, 0.85), 0.55))
	var top := CylinderMesh.new()
	top.top_radius = radius
	top.bottom_radius = radius * 1.04
	top.height = 0.12
	top.radial_segments = 32
	add_mesh(parent, top, Vector3(0, -0.05, 0), mat(color))


static func tower(parent: Node3D, pos: Vector3, radius: float, height: float, roof_color: Color, stone_color := STONE, lit := true) -> void:
	cyl(parent, radius, height, pos + Vector3(0, height / 2.0, 0), mat(stone_color))
	cone(parent, radius * 1.3, radius * 2.6, pos + Vector3(0, height + radius * 1.25, 0), mat(roof_color))
	if lit:
		box(parent, Vector3(radius * 0.34, radius * 0.5, 0.02), pos + Vector3(0, height * 0.72, radius), mat(Color(0.1, 0.08, 0.05), GOLD, 2.2))


static func house(parent: Node3D, pos: Vector3, size: Vector3, roof_color: Color, wall_color := Color(0.78, 0.72, 0.60), rot_y := 0.0) -> void:
	box(parent, size, pos + Vector3(0, size.y / 2.0, 0), mat(wall_color), Vector3(0, rot_y, 0))
	prism(parent, Vector3(size.x * 1.15, size.y * 0.62, size.z * 1.15), pos + Vector3(0, size.y + size.y * 0.31, 0), mat(roof_color), Vector3(0, rot_y, 0))
	# door
	box(parent, Vector3(size.x * 0.2, size.y * 0.45, 0.02), pos + Vector3(0, size.y * 0.22, size.z * 0.51).rotated(Vector3.UP, rot_y), mat(WOOD_DARK), Vector3(0, rot_y, 0))


static func crenellated_wall(parent: Node3D, pos: Vector3, length: float, height: float, thickness: float, stone_color := STONE, rot_y := 0.0) -> void:
	box(parent, Vector3(length, height, thickness), pos + Vector3(0, height / 2.0, 0), mat(stone_color), Vector3(0, rot_y, 0))
	var teeth := int(length / 0.22)
	for i in range(teeth):
		if i % 2 == 0:
			var x: float = -length / 2.0 + (i + 0.5) * (length / teeth)
			var offset := Vector3(x, height + 0.05, 0).rotated(Vector3.UP, rot_y)
			box(parent, Vector3(length / teeth * 0.9, 0.1, thickness), pos + offset, mat(stone_color.darkened(0.06)), Vector3(0, rot_y, 0))


static func banner(parent: Node3D, pos: Vector3, color: Color, pole_h := 0.9) -> void:
	cyl(parent, 0.02, pole_h, pos + Vector3(0, pole_h / 2.0, 0), mat(WOOD_DARK))
	box(parent, Vector3(0.26, 0.34, 0.015), pos + Vector3(0.14, pole_h - 0.2, 0), mat(color, color, 0.35))


static func gravestone(parent: Node3D, pos: Vector3, h: float, rot_y := 0.0) -> void:
	box(parent, Vector3(0.16, h, 0.05), pos + Vector3(0, h / 2.0, 0), mat(STONE_DARK), Vector3(0, rot_y, 0.06))


# Stylized character figure: hooded cloak, arms, cape and head on a stone dais.
static func figure(parent: Node3D, cloak: Color, trim := Color.BLACK) -> Node3D:
	var f := Node3D.new()
	parent.add_child(f)
	var accent := trim if trim != Color.BLACK else cloak.lightened(0.3)

	# two-tier stone dais with glowing rune seam
	var base := CylinderMesh.new()
	base.top_radius = 0.88
	base.bottom_radius = 1.02
	base.height = 0.10
	base.radial_segments = 32
	add_mesh(f, base, Vector3(0, -0.13, 0), mat(Color(0.15, 0.14, 0.19), Color.BLACK, 1.0, 0.15, 0.55))
	var seam := TorusMesh.new()
	seam.inner_radius = 0.82
	seam.outer_radius = 0.89
	add_mesh(f, seam, Vector3(0, -0.085, 0), mat(Color(0.2, 0.18, 0.26), accent, 0.8))
	var dais := CylinderMesh.new()
	dais.top_radius = 0.78
	dais.bottom_radius = 0.88
	dais.height = 0.14
	dais.radial_segments = 32
	add_mesh(f, dais, Vector3(0, -0.04, 0), mat(Color(0.30, 0.28, 0.33), Color.BLACK, 1.0, 0.2, 0.5))

	# cloak body (wide cone) + fabric skirt flare
	cone(f, 0.52, 1.25, Vector3(0, 0.625, 0), mat(cloak, Color.BLACK, 1.0, 0.0, 0.95))
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.40
	skirt.bottom_radius = 0.56
	skirt.height = 0.22
	add_mesh(f, skirt, Vector3(0, 0.11, 0), mat(cloak.darkened(0.12), Color.BLACK, 1.0, 0.0, 0.95))

	# belt
	torus(f, 0.035, 0.355, Vector3(0, 0.72, 0), mat(accent, accent, 0.25, 0.6, 0.4))

	# cape flowing behind
	var cape := BoxMesh.new()
	cape.size = Vector3(0.55, 0.95, 0.07)
	add_mesh(f, cape, Vector3(0, 0.78, -0.30), mat(cloak.darkened(0.22), Color.BLACK, 1.0, 0.0, 1.0), Vector3(0.12, 0, 0))

	# shoulders + pauldrons
	sphere(f, 0.30, Vector3(0, 1.12, 0), mat(cloak.darkened(0.08)))
	sphere(f, 0.12, Vector3(-0.30, 1.18, 0), mat(cloak.darkened(0.18)))
	sphere(f, 0.12, Vector3(0.30, 1.18, 0), mat(cloak.darkened(0.18)))

	# arms reaching slightly forward + hands
	var arm := CapsuleMesh.new()
	arm.radius = 0.085
	arm.height = 0.62
	add_mesh(f, arm, Vector3(-0.36, 0.92, 0.10), mat(cloak.darkened(0.10)), Vector3(0.35, 0, 0.42))
	add_mesh(f, arm, Vector3(0.36, 0.92, 0.10), mat(cloak.darkened(0.10)), Vector3(0.35, 0, -0.42))
	sphere(f, 0.075, Vector3(-0.45, 0.68, 0.22), mat(SKIN))
	sphere(f, 0.075, Vector3(0.45, 0.68, 0.22), mat(SKIN))

	# head
	sphere(f, 0.185, Vector3(0, 1.42, 0), mat(SKIN))
	# hood ring
	if trim != Color.BLACK:
		torus(f, 0.04, 0.20, Vector3(0, 1.30, 0), mat(trim, trim, 0.3))
	return f


# ── Build dispatcher ────────────────────────────────────────────

static func build(art_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	match art_name:
		# Characters
		"Assassin": _assassin(root)
		"Thief": _thief(root)
		"Magician": _magician(root)
		"King": _king(root)
		"Bishop": _bishop(root)
		"Merchant": _merchant(root)
		"Architect": _architect(root)
		"Warlord": _warlord(root)
		# Noble districts
		"Manor": _manor(root)
		"Castle": _castle(root)
		"Palace": _palace(root)
		# Religious
		"Temple": _temple(root)
		"Church": _church(root)
		"Monastery": _monastery(root)
		"Cathedral": _cathedral(root)
		# Trade
		"Tavern": _tavern(root)
		"Market": _market(root)
		"Trading Post": _trading_post(root)
		"Docks": _docks(root)
		"Harbor": _harbor(root)
		"Town Hall": _town_hall(root)
		# Military
		"Watchtower": _watchtower(root)
		"Prison": _prison(root)
		"Battlefield": _battlefield(root)
		"Fortress": _fortress(root)
		# Special
		"Haunted City": _haunted_city(root)
		"Keep": _keep(root)
		"Laboratory": _laboratory(root)
		"Smithy": _smithy(root)
		"Graveyard": _graveyard(root)
		"Observatory": _observatory(root)
		"Library": _library(root)
		"School of Magic": _school_of_magic(root)
		"Dragon Gate": _dragon_gate(root)
		"University": _university(root)
		"Great Wall": _great_wall(root)
		_: _generic(root)
	return root


# ── Characters ──────────────────────────────────────────────────

static func _assassin(root: Node3D) -> void:
	var purple := Color(0.26, 0.10, 0.28)
	var f := figure(root, purple, Color(0.55, 0.18, 0.50))
	# deep hood instead of face: dark sphere overlapping head
	sphere(f, 0.20, Vector3(0, 1.43, 0.03), mat(purple.darkened(0.3)))
	# glowing eyes
	sphere(f, 0.025, Vector3(-0.06, 1.44, 0.17), mat(Color.RED, Color(1, 0.1, 0.2), 4.0))
	sphere(f, 0.025, Vector3(0.06, 1.44, 0.17), mat(Color.RED, Color(1, 0.1, 0.2), 4.0))
	# dagger — blade + crossguard + grip, raised
	var blade := mat(Color(0.85, 0.88, 0.95), Color(0.5, 0.6, 0.9), 0.6, 0.9, 0.2)
	box(f, Vector3(0.05, 0.42, 0.012), Vector3(0.46, 1.30, 0.18), blade, Vector3(0, 0, -0.35))
	box(f, Vector3(0.16, 0.035, 0.03), Vector3(0.39, 1.10, 0.18), mat(GOLD, GOLD, 0.4, 0.8, 0.3), Vector3(0, 0, -0.35))
	cyl(f, 0.025, 0.14, Vector3(0.36, 1.03, 0.18), mat(WOOD_DARK), Vector3(0, 0, -0.35))


static func _thief(root: Node3D) -> void:
	var teal := Color(0.10, 0.30, 0.31)
	var f := figure(root, teal, Color(0.2, 0.6, 0.6))
	# bandit mask
	box(f, Vector3(0.30, 0.07, 0.06), Vector3(0, 1.45, 0.13), mat(Color(0.08, 0.08, 0.1)))
	# sack of gold over shoulder
	sphere(f, 0.24, Vector3(-0.40, 1.18, -0.08), mat(Color(0.52, 0.42, 0.26)))
	torus(f, 0.025, 0.09, Vector3(-0.40, 1.39, -0.08), mat(WOOD_DARK))
	# spilled coins
	for i in range(5):
		var a := i * 1.25
		cyl(f, 0.055, 0.02, Vector3(cos(a) * 0.45, 0.02, sin(a) * 0.42), mat(GOLD, GOLD, 1.2, 0.9, 0.25))


static func _magician(root: Node3D) -> void:
	var violet := Color(0.27, 0.16, 0.55)
	var f := figure(root, violet, Color(0.6, 0.4, 1.0))
	# wizard hat
	cone(f, 0.22, 0.45, Vector3(0, 1.66, 0), mat(violet.darkened(0.15)))
	torus(f, 0.03, 0.23, Vector3(0, 1.50, 0), mat(GOLD, GOLD, 0.6))
	# staff with floating orb
	cyl(f, 0.025, 1.3, Vector3(0.48, 0.72, 0), mat(WOOD_DARK))
	sphere(f, 0.11, Vector3(0.48, 1.50, 0), mat(Color(0.65, 0.45, 1.0), Color(0.6, 0.35, 1.0), 3.5))
	# orbiting motes
	for i in range(3):
		var a := i * TAU / 3.0
		sphere(f, 0.035, Vector3(cos(a) * 0.7, 1.0 + 0.2 * sin(a * 2), sin(a) * 0.7), mat(Color(0.8, 0.6, 1.0), Color(0.7, 0.5, 1.0), 3.0))


static func _king(root: Node3D) -> void:
	var royal := Color(0.55, 0.10, 0.16)
	var f := figure(root, royal, GOLD)
	# crown: gold band + spikes
	torus(f, 0.035, 0.17, Vector3(0, 1.56, 0), mat(GOLD, GOLD, 1.0, 0.9, 0.25))
	for i in range(5):
		var a := i * TAU / 5.0
		cone(f, 0.035, 0.12, Vector3(cos(a) * 0.155, 1.64, sin(a) * 0.155), mat(GOLD, GOLD, 1.0, 0.9, 0.25))
	# scepter
	cyl(f, 0.022, 0.9, Vector3(0.45, 0.95, 0.1), mat(GOLD, GOLD, 0.4, 0.9, 0.3))
	sphere(f, 0.07, Vector3(0.45, 1.43, 0.1), mat(Color(0.9, 0.2, 0.3), Color(0.9, 0.15, 0.3), 2.0))
	# ermine trim
	torus(f, 0.05, 0.45, Vector3(0, 0.18, 0), mat(Color(0.95, 0.93, 0.90)))


static func _bishop(root: Node3D) -> void:
	var blue := Color(0.16, 0.30, 0.60)
	var f := figure(root, blue, Color(0.85, 0.85, 0.95))
	# mitre
	prism(f, Vector3(0.30, 0.40, 0.22), Vector3(0, 1.70, 0), mat(Color(0.92, 0.90, 0.85)))
	box(f, Vector3(0.30, 0.05, 0.23), Vector3(0, 1.52, 0), mat(GOLD, GOLD, 0.5))
	# crozier (staff with hook)
	cyl(f, 0.022, 1.25, Vector3(0.46, 0.78, 0), mat(GOLD, GOLD, 0.4, 0.85, 0.3))
	torus(f, 0.022, 0.10, Vector3(0.40, 1.46, 0), mat(GOLD, GOLD, 0.5, 0.85, 0.3), Vector3(0, 0, 0))
	# glowing holy cross on chest
	box(f, Vector3(0.05, 0.22, 0.02), Vector3(0, 0.95, 0.40), mat(GOLD, GOLD, 2.0))
	box(f, Vector3(0.15, 0.05, 0.02), Vector3(0, 1.00, 0.40), mat(GOLD, GOLD, 2.0))


static func _merchant(root: Node3D) -> void:
	var green := Color(0.13, 0.38, 0.20)
	var f := figure(root, green, GOLD)
	# wide-brim hat
	cyl(f, 0.30, 0.03, Vector3(0, 1.54, 0), mat(WOOD))
	cyl(f, 0.14, 0.14, Vector3(0, 1.62, 0), mat(WOOD))
	# coin stacks
	for s in range(3):
		var sx := -0.55 + s * 0.22
		var n := 4 + (s % 3)
		for i in range(n):
			cyl(f, 0.075, 0.028, Vector3(sx, 0.014 + i * 0.03, 0.55), mat(GOLD, GOLD, 1.0, 0.9, 0.25))
	# scales of trade
	cyl(f, 0.018, 0.5, Vector3(0.50, 1.05, 0.05), mat(GOLD, GOLD, 0.3, 0.8, 0.3))
	box(f, Vector3(0.36, 0.015, 0.015), Vector3(0.50, 1.30, 0.05), mat(GOLD, GOLD, 0.3, 0.8, 0.3))
	cyl(f, 0.07, 0.02, Vector3(0.34, 1.20, 0.05), mat(GOLD, GOLD, 0.6, 0.8, 0.3))
	cyl(f, 0.07, 0.02, Vector3(0.66, 1.24, 0.05), mat(GOLD, GOLD, 0.6, 0.8, 0.3))


static func _architect(root: Node3D) -> void:
	var tan := Color(0.50, 0.36, 0.22)
	var f := figure(root, tan, Color(0.85, 0.75, 0.55))
	# blueprint scroll
	cyl(f, 0.06, 0.42, Vector3(0.45, 1.10, 0.1), mat(Color(0.55, 0.70, 0.92)), Vector3(0, 0, 1.57))
	# miniature tower model in front
	box(f, Vector3(0.30, 0.30, 0.30), Vector3(-0.05, 0.15, 0.62), mat(STONE))
	cyl(f, 0.09, 0.34, Vector3(-0.05, 0.47, 0.62), mat(STONE_DARK))
	cone(f, 0.12, 0.2, Vector3(-0.05, 0.74, 0.62), mat(Color(0.7, 0.3, 0.2)))
	# compass tool (two legs)
	box(f, Vector3(0.025, 0.3, 0.025), Vector3(0.52, 1.45, 0.08), mat(GOLD, GOLD, 0.5, 0.9, 0.3), Vector3(0, 0, 0.3))
	box(f, Vector3(0.025, 0.3, 0.025), Vector3(0.44, 1.45, 0.08), mat(GOLD, GOLD, 0.5, 0.9, 0.3), Vector3(0, 0, -0.3))


static func _warlord(root: Node3D) -> void:
	var red := Color(0.42, 0.10, 0.10)
	var f := figure(root, red, Color(0.85, 0.3, 0.2))
	# horned helm
	sphere(f, 0.20, Vector3(0, 1.46, 0), mat(Color(0.35, 0.34, 0.38), Color.BLACK, 1.0, 0.7, 0.35))
	cone(f, 0.05, 0.22, Vector3(-0.22, 1.58, 0), mat(Color(0.9, 0.88, 0.8)))
	cone(f, 0.05, 0.22, Vector3(0.22, 1.58, 0), mat(Color(0.9, 0.88, 0.8)))
	# greatsword planted in ground
	var steel := mat(Color(0.80, 0.84, 0.92), Color(0.4, 0.5, 0.8), 0.4, 0.9, 0.25)
	box(f, Vector3(0.09, 0.85, 0.02), Vector3(0.58, 0.46, 0.25), steel)
	box(f, Vector3(0.30, 0.05, 0.05), Vector3(0.58, 0.92, 0.25), mat(GOLD, GOLD, 0.5, 0.85, 0.3))
	cyl(f, 0.03, 0.18, Vector3(0.58, 1.04, 0.25), mat(WOOD_DARK))
	# shield
	cyl(f, 0.26, 0.05, Vector3(-0.52, 0.85, 0.18), mat(red.lightened(0.1), Color.BLACK, 1.0, 0.4, 0.5), Vector3(1.57, 0, 0))
	sphere(f, 0.07, Vector3(-0.52, 0.85, 0.22), mat(GOLD, GOLD, 0.8, 0.9, 0.3))


# ── Noble districts ─────────────────────────────────────────────

static func _manor(root: Node3D) -> void:
	ground(root)
	house(root, Vector3(0, 0, 0), Vector3(1.0, 0.55, 0.62), Color(0.72, 0.55, 0.18))
	house(root, Vector3(0.55, 0, 0.25), Vector3(0.45, 0.40, 0.45), Color(0.72, 0.55, 0.18), Color(0.78, 0.72, 0.60), 0.4)
	# hedge
	for i in range(4):
		sphere(root, 0.10, Vector3(-0.75 + i * 0.23, 0.08, 0.62), mat(GRASS.darkened(0.1)))
	banner(root, Vector3(-0.85, 0, -0.3), Visual.TYPE_COLORS["noble"])


static func _castle(root: Node3D) -> void:
	ground(root)
	box(root, Vector3(1.1, 0.6, 0.7), Vector3(0, 0.3, 0), mat(STONE))
	crenellated_wall(root, Vector3(0, 0.6, 0.34), 1.1, 0.08, 0.06)
	tower(root, Vector3(-0.62, 0, 0.32), 0.18, 0.85, Visual.TYPE_COLORS["noble"].darkened(0.2))
	tower(root, Vector3(0.62, 0, 0.32), 0.18, 0.85, Visual.TYPE_COLORS["noble"].darkened(0.2))
	tower(root, Vector3(0, 0, -0.30), 0.22, 1.1, Visual.TYPE_COLORS["noble"].darkened(0.2))
	# gate
	box(root, Vector3(0.28, 0.38, 0.04), Vector3(0, 0.19, 0.36), mat(WOOD_DARK))


static func _palace(root: Node3D) -> void:
	ground(root)
	box(root, Vector3(1.3, 0.5, 0.6), Vector3(0, 0.25, 0), mat(Color(0.88, 0.84, 0.74)))
	box(root, Vector3(0.7, 0.35, 0.5), Vector3(0, 0.67, 0), mat(Color(0.88, 0.84, 0.74)))
	# gold domes
	sphere(root, 0.20, Vector3(0, 0.95, 0), mat(GOLD, GOLD, 0.8, 0.9, 0.25))
	sphere(root, 0.12, Vector3(-0.55, 0.58, 0), mat(GOLD, GOLD, 0.8, 0.9, 0.25))
	sphere(root, 0.12, Vector3(0.55, 0.58, 0), mat(GOLD, GOLD, 0.8, 0.9, 0.25))
	# columns
	for i in range(5):
		cyl(root, 0.045, 0.5, Vector3(-0.5 + i * 0.25, 0.25, 0.33), mat(Color(0.95, 0.92, 0.85)))
	# glowing windows
	for i in range(3):
		box(root, Vector3(0.1, 0.16, 0.02), Vector3(-0.25 + i * 0.25, 0.72, 0.26), mat(Color(0.1, 0.08, 0.05), GOLD, 2.0))


# ── Religious districts ─────────────────────────────────────────

static func _temple(root: Node3D) -> void:
	ground(root)
	# stepped base
	box(root, Vector3(1.1, 0.12, 0.8), Vector3(0, 0.06, 0), mat(STONE))
	box(root, Vector3(0.9, 0.12, 0.62), Vector3(0, 0.18, 0), mat(STONE.lightened(0.06)))
	# columns
	for i in range(4):
		cyl(root, 0.06, 0.55, Vector3(-0.33 + i * 0.22, 0.5, 0.22), mat(Color(0.92, 0.90, 0.84)))
		cyl(root, 0.06, 0.55, Vector3(-0.33 + i * 0.22, 0.5, -0.22), mat(Color(0.92, 0.90, 0.84)))
	# roof
	prism(root, Vector3(1.0, 0.3, 0.72), Vector3(0, 0.92, 0), mat(Visual.TYPE_COLORS["religious"].darkened(0.25)))
	# altar flame
	sphere(root, 0.06, Vector3(0, 0.32, 0), mat(FLAME, FLAME, 3.0))


static func _church(root: Node3D) -> void:
	ground(root)
	box(root, Vector3(0.55, 0.5, 1.0), Vector3(0.1, 0.25, 0), mat(Color(0.85, 0.82, 0.74)))
	prism(root, Vector3(0.65, 0.35, 1.1), Vector3(0.1, 0.67, 0), mat(Color(0.45, 0.30, 0.30)), Vector3(0, 1.5708, 0))
	# steeple
	box(root, Vector3(0.3, 0.8, 0.3), Vector3(-0.45, 0.4, 0.3), mat(Color(0.85, 0.82, 0.74)))
	cone(root, 0.22, 0.5, Vector3(-0.45, 1.05, 0.3), mat(Visual.TYPE_COLORS["religious"].darkened(0.3)))
	# cross
	box(root, Vector3(0.035, 0.22, 0.035), Vector3(-0.45, 1.40, 0.3), mat(GOLD, GOLD, 1.2))
	box(root, Vector3(0.13, 0.035, 0.035), Vector3(-0.45, 1.44, 0.3), mat(GOLD, GOLD, 1.2))
	# rose window
	cyl(root, 0.09, 0.02, Vector3(0.1, 0.42, 0.51), mat(Color(0.2, 0.3, 0.7), Color(0.3, 0.5, 1.0), 2.0), Vector3(1.5708, 0, 0))


static func _monastery(root: Node3D) -> void:
	ground(root)
	# cloister: square of low buildings around a court
	box(root, Vector3(1.2, 0.35, 0.25), Vector3(0, 0.175, 0.45), mat(Color(0.80, 0.76, 0.66)))
	box(root, Vector3(1.2, 0.35, 0.25), Vector3(0, 0.175, -0.45), mat(Color(0.80, 0.76, 0.66)))
	box(root, Vector3(0.25, 0.35, 0.7), Vector3(-0.48, 0.175, 0), mat(Color(0.80, 0.76, 0.66)))
	box(root, Vector3(0.25, 0.35, 0.7), Vector3(0.48, 0.175, 0), mat(Color(0.80, 0.76, 0.66)))
	# bell tower
	box(root, Vector3(0.26, 0.85, 0.26), Vector3(0.48, 0.42, -0.45), mat(Color(0.80, 0.76, 0.66)))
	cone(root, 0.2, 0.32, Vector3(0.48, 1.0, -0.45), mat(Visual.TYPE_COLORS["religious"].darkened(0.3)))
	sphere(root, 0.05, Vector3(0.48, 0.78, -0.45), mat(GOLD, GOLD, 1.0, 0.9, 0.3))
	# courtyard tree
	cyl(root, 0.04, 0.25, Vector3(0, 0.125, 0), mat(WOOD_DARK))
	sphere(root, 0.17, Vector3(0, 0.35, 0), mat(GRASS.lightened(0.05)))


static func _cathedral(root: Node3D) -> void:
	ground(root, STONE_DARK.lightened(0.1))
	# tall nave
	box(root, Vector3(0.55, 0.85, 1.0), Vector3(0, 0.425, 0), mat(Color(0.82, 0.80, 0.76)))
	prism(root, Vector3(0.65, 0.4, 1.1), Vector3(0, 1.05, 0), mat(Color(0.35, 0.32, 0.42)), Vector3(0, 1.5708, 0))
	# twin spires
	for sx in [-0.42, 0.42]:
		box(root, Vector3(0.26, 1.1, 0.26), Vector3(sx, 0.55, 0.45), mat(Color(0.82, 0.80, 0.76)))
		cone(root, 0.18, 0.6, Vector3(sx, 1.4, 0.45), mat(Color(0.35, 0.32, 0.42)))
	# giant rose window
	cyl(root, 0.16, 0.02, Vector3(0, 0.62, 0.51), mat(Color(0.25, 0.2, 0.6), Color(0.45, 0.35, 1.0), 2.4), Vector3(1.5708, 0, 0))
	# flying buttress hints
	for z in [-0.3, 0.1]:
		box(root, Vector3(0.05, 0.5, 0.05), Vector3(-0.40, 0.35, z), mat(Color(0.82, 0.80, 0.76)), Vector3(0, 0, 0.5))
		box(root, Vector3(0.05, 0.5, 0.05), Vector3(0.40, 0.35, z), mat(Color(0.82, 0.80, 0.76)), Vector3(0, 0, -0.5))


# ── Trade districts ─────────────────────────────────────────────

static func _tavern(root: Node3D) -> void:
	ground(root)
	house(root, Vector3(0, 0, 0), Vector3(0.85, 0.5, 0.65), Color(0.50, 0.32, 0.20))
	# barrels
	for i in range(2):
		cyl(root, 0.10, 0.22, Vector3(0.58, 0.11, 0.25 - i * 0.28), mat(WOOD))
		torus(root, 0.012, 0.10, Vector3(0.58, 0.16, 0.25 - i * 0.28), mat(Color(0.3, 0.3, 0.32), Color.BLACK, 1.0, 0.6, 0.4))
	# hanging sign
	box(root, Vector3(0.03, 0.35, 0.03), Vector3(-0.52, 0.45, 0.36), mat(WOOD_DARK))
	box(root, Vector3(0.22, 0.16, 0.02), Vector3(-0.52, 0.42, 0.42), mat(GOLD, GOLD, 0.8))
	# warm window glow
	box(root, Vector3(0.14, 0.12, 0.02), Vector3(0.15, 0.28, 0.34), mat(Color(0.1, 0.08, 0.05), FLAME, 2.2))


static func _market(root: Node3D) -> void:
	ground(root)
	# stalls with canopies
	for d in [{"p": Vector3(-0.4, 0, 0.1), "c": Color(0.85, 0.30, 0.25), "r": 0.2}, {"p": Vector3(0.35, 0, -0.25), "c": Color(0.30, 0.55, 0.80), "r": -0.3}, {"p": Vector3(0.3, 0, 0.42), "c": Color(0.90, 0.70, 0.25), "r": 0.5}]:
		var p: Vector3 = d["p"]
		box(root, Vector3(0.4, 0.18, 0.3), p + Vector3(0, 0.09, 0), mat(WOOD), Vector3(0, d["r"], 0))
		for cx in [-0.17, 0.17]:
			cyl(root, 0.02, 0.45, p + Vector3(cx, 0.32, 0).rotated(Vector3.UP, d["r"]), mat(WOOD_DARK))
		prism(root, Vector3(0.5, 0.14, 0.42), p + Vector3(0, 0.6, 0), mat(d["c"]), Vector3(0, d["r"], 0))
	# produce
	sphere(root, 0.05, Vector3(-0.40, 0.22, 0.12), mat(Color(0.9, 0.4, 0.2)))
	sphere(root, 0.05, Vector3(-0.30, 0.22, 0.05), mat(Color(0.4, 0.7, 0.2)))


static func _trading_post(root: Node3D) -> void:
	ground(root)
	house(root, Vector3(-0.2, 0, -0.1), Vector3(0.6, 0.45, 0.5), WOOD, Color(0.62, 0.50, 0.36))
	# crates and sacks
	box(root, Vector3(0.22, 0.22, 0.22), Vector3(0.42, 0.11, 0.25), mat(WOOD))
	box(root, Vector3(0.16, 0.16, 0.16), Vector3(0.60, 0.08, -0.05), mat(WOOD.lightened(0.1)), Vector3(0, 0.5, 0))
	box(root, Vector3(0.18, 0.18, 0.18), Vector3(0.42, 0.40, 0.25), mat(WOOD.darkened(0.08)), Vector3(0, 0.3, 0))
	sphere(root, 0.12, Vector3(0.15, 0.10, 0.45), mat(Color(0.6, 0.5, 0.33)))
	# signpost
	cyl(root, 0.025, 0.7, Vector3(-0.7, 0.35, 0.35), mat(WOOD_DARK))
	box(root, Vector3(0.3, 0.08, 0.02), Vector3(-0.62, 0.6, 0.35), mat(WOOD))


static func _docks(root: Node3D) -> void:
	# water disc
	var m := CylinderMesh.new()
	m.top_radius = 1.25
	m.bottom_radius = 1.3
	m.height = 0.1
	add_mesh(root, m, Vector3(0, -0.05, 0), mat(Color(0.13, 0.30, 0.45), Color(0.1, 0.3, 0.5), 0.3, 0.1, 0.2))
	# pier
	box(root, Vector3(0.4, 0.07, 1.2), Vector3(-0.2, 0.10, 0), mat(WOOD))
	for i in range(4):
		cyl(root, 0.035, 0.3, Vector3(-0.38, 0.0, -0.5 + i * 0.33), mat(WOOD_DARK))
		cyl(root, 0.035, 0.3, Vector3(-0.02, 0.0, -0.5 + i * 0.33), mat(WOOD_DARK))
	# rowboat
	box(root, Vector3(0.28, 0.10, 0.6), Vector3(0.45, 0.06, 0.1), mat(WOOD.darkened(0.1)))
	box(root, Vector3(0.2, 0.06, 0.5), Vector3(0.45, 0.11, 0.1), mat(Color(0.2, 0.16, 0.12)))
	# crate on pier
	box(root, Vector3(0.16, 0.16, 0.16), Vector3(-0.2, 0.22, -0.35), mat(WOOD))


static func _harbor(root: Node3D) -> void:
	var m := CylinderMesh.new()
	m.top_radius = 1.25
	m.bottom_radius = 1.3
	m.height = 0.1
	add_mesh(root, m, Vector3(0, -0.05, 0), mat(Color(0.13, 0.30, 0.45), Color(0.1, 0.3, 0.5), 0.3, 0.1, 0.2))
	# quay
	box(root, Vector3(1.1, 0.16, 0.45), Vector3(0, 0.08, -0.5), mat(STONE))
	# lighthouse
	cyl(root, 0.14, 0.8, Vector3(-0.45, 0.55, -0.5), mat(Color(0.9, 0.88, 0.84)))
	cyl(root, 0.15, 0.1, Vector3(-0.45, 0.35, -0.5), mat(Color(0.85, 0.25, 0.2)))
	cyl(root, 0.15, 0.1, Vector3(-0.45, 0.65, -0.5), mat(Color(0.85, 0.25, 0.2)))
	sphere(root, 0.09, Vector3(-0.45, 1.02, -0.5), mat(FLAME, Color(1, 0.8, 0.3), 3.5))
	cone(root, 0.12, 0.15, Vector3(-0.45, 1.16, -0.5), mat(Color(0.3, 0.3, 0.34)))
	# sailing ship
	box(root, Vector3(0.3, 0.12, 0.75), Vector3(0.4, 0.08, 0.25), mat(WOOD.darkened(0.05)))
	cyl(root, 0.025, 0.75, Vector3(0.4, 0.5, 0.25), mat(WOOD_DARK))
	prism(root, Vector3(0.4, 0.5, 0.02), Vector3(0.4, 0.55, 0.32), mat(Color(0.93, 0.90, 0.82)), Vector3(0, 1.5708, 0))


static func _town_hall(root: Node3D) -> void:
	ground(root)
	box(root, Vector3(1.15, 0.6, 0.6), Vector3(0, 0.3, 0), mat(Color(0.83, 0.78, 0.68)))
	prism(root, Vector3(1.25, 0.35, 0.7), Vector3(0, 0.78, 0), mat(Color(0.40, 0.32, 0.28)))
	# clock tower
	box(root, Vector3(0.3, 1.0, 0.3), Vector3(0, 0.5, -0.05), mat(Color(0.83, 0.78, 0.68)))
	cone(root, 0.22, 0.35, Vector3(0, 1.18, -0.05), mat(Color(0.40, 0.32, 0.28)))
	# clock face
	cyl(root, 0.11, 0.02, Vector3(0, 0.88, 0.11), mat(PARCH(), GOLD, 1.4), Vector3(1.5708, 0, 0))
	# steps + columns
	box(root, Vector3(0.6, 0.08, 0.2), Vector3(0, 0.04, 0.40), mat(STONE))
	for i in range(3):
		cyl(root, 0.04, 0.45, Vector3(-0.2 + i * 0.2, 0.30, 0.32), mat(Color(0.92, 0.90, 0.84)))


static func PARCH() -> Color:
	return Color(0.93, 0.88, 0.76)


# ── Military districts ──────────────────────────────────────────

static func _watchtower(root: Node3D) -> void:
	ground(root, Color(0.36, 0.33, 0.28))
	cyl(root, 0.26, 1.1, Vector3(0, 0.55, 0), mat(STONE_DARK))
	cyl(root, 0.34, 0.18, Vector3(0, 1.19, 0), mat(STONE))
	for i in range(6):
		var a := i * TAU / 6.0
		box(root, Vector3(0.12, 0.12, 0.06), Vector3(cos(a) * 0.32, 1.34, sin(a) * 0.32), mat(STONE), Vector3(0, -a, 0))
	# signal brazier
	cyl(root, 0.10, 0.08, Vector3(0, 1.32, 0), mat(Color(0.25, 0.22, 0.2)))
	sphere(root, 0.09, Vector3(0, 1.42, 0), mat(FLAME, FLAME, 3.5))
	# arrow slits
	box(root, Vector3(0.04, 0.18, 0.02), Vector3(0, 0.7, 0.26), mat(Color(0.05, 0.05, 0.06)))
	box(root, Vector3(0.04, 0.18, 0.02), Vector3(0, 0.4, 0.26), mat(Color(0.05, 0.05, 0.06)))


static func _prison(root: Node3D) -> void:
	ground(root, Color(0.36, 0.33, 0.28))
	box(root, Vector3(1.0, 0.55, 0.7), Vector3(0, 0.275, 0), mat(STONE_DARK))
	box(root, Vector3(1.06, 0.1, 0.76), Vector3(0, 0.6, 0), mat(STONE_DARK.darkened(0.1)))
	# barred window
	box(root, Vector3(0.3, 0.22, 0.02), Vector3(-0.25, 0.34, 0.36), mat(Color(0.04, 0.04, 0.05)))
	for i in range(4):
		box(root, Vector3(0.02, 0.22, 0.025), Vector3(-0.34 + i * 0.065, 0.34, 0.365), mat(Color(0.5, 0.5, 0.55), Color.BLACK, 1.0, 0.8, 0.3))
	# heavy door + chains
	box(root, Vector3(0.26, 0.4, 0.03), Vector3(0.3, 0.2, 0.36), mat(Color(0.25, 0.20, 0.16)))
	torus(root, 0.015, 0.05, Vector3(0.3, 0.22, 0.39), mat(Color(0.5, 0.5, 0.55), Color.BLACK, 1.0, 0.8, 0.3), Vector3(1.5708, 0, 0))
	# corner watch turret
	cyl(root, 0.12, 0.5, Vector3(0.55, 0.75, -0.3), mat(STONE_DARK))
	cone(root, 0.15, 0.2, Vector3(0.55, 1.08, -0.3), mat(Color(0.3, 0.12, 0.1)))


static func _battlefield(root: Node3D) -> void:
	ground(root, Color(0.40, 0.30, 0.20))
	# planted swords
	var steel := mat(Color(0.75, 0.78, 0.85), Color(0.3, 0.4, 0.7), 0.3, 0.85, 0.3)
	for d in [Vector3(-0.45, 0, 0.25), Vector3(0.1, 0, -0.3), Vector3(0.5, 0, 0.35)]:
		box(root, Vector3(0.05, 0.5, 0.015), d + Vector3(0, 0.3, 0), steel, Vector3(0.12, 0, 0.18))
		box(root, Vector3(0.16, 0.035, 0.035), d + Vector3(0.015, 0.48, 0.04), mat(WOOD_DARK), Vector3(0.12, 0, 0.18))
	# torn war banner
	cyl(root, 0.022, 1.0, Vector3(-0.1, 0.5, 0.05), mat(WOOD_DARK), Vector3(0, 0, 0.1))
	box(root, Vector3(0.34, 0.4, 0.015), Vector3(0.08, 0.78, 0.05), mat(Visual.TYPE_COLORS["military"].darkened(0.15), Visual.TYPE_COLORS["military"], 0.4))
	# shield on ground + helmet
	cyl(root, 0.18, 0.04, Vector3(0.45, 0.03, -0.25), mat(Color(0.45, 0.15, 0.12), Color.BLACK, 1.0, 0.3, 0.5), Vector3(0.2, 0, 0))
	sphere(root, 0.11, Vector3(-0.55, 0.08, -0.35), mat(Color(0.4, 0.4, 0.45), Color.BLACK, 1.0, 0.7, 0.35))


static func _fortress(root: Node3D) -> void:
	ground(root, Color(0.36, 0.33, 0.28))
	# thick curtain walls in square
	crenellated_wall(root, Vector3(0, 0, 0.45), 1.15, 0.42, 0.12)
	crenellated_wall(root, Vector3(0, 0, -0.45), 1.15, 0.42, 0.12)
	crenellated_wall(root, Vector3(0.51, 0, 0), 0.9, 0.42, 0.12, STONE, 1.5708)
	crenellated_wall(root, Vector3(-0.51, 0, 0), 0.9, 0.42, 0.12, STONE, 1.5708)
	# corner towers
	for c in [Vector3(-0.55, 0, 0.45), Vector3(0.55, 0, 0.45), Vector3(-0.55, 0, -0.45), Vector3(0.55, 0, -0.45)]:
		cyl(root, 0.16, 0.62, c + Vector3(0, 0.31, 0), mat(STONE_DARK))
		cone(root, 0.2, 0.28, c + Vector3(0, 0.74, 0), mat(Visual.TYPE_COLORS["military"].darkened(0.3)))
	# central keep
	box(root, Vector3(0.45, 0.7, 0.45), Vector3(0, 0.35, 0), mat(STONE_DARK))
	banner(root, Vector3(0, 0.7, 0), Visual.TYPE_COLORS["military"], 0.55)


# ── Special districts ───────────────────────────────────────────

static func _haunted_city(root: Node3D) -> void:
	ground(root, Color(0.18, 0.16, 0.22))
	var ghost_stone := mat(Color(0.35, 0.36, 0.45))
	# crooked towers
	cyl(root, 0.14, 0.8, Vector3(-0.4, 0.4, 0.1), ghost_stone, Vector3(0, 0, 0.18))
	cone(root, 0.18, 0.35, Vector3(-0.47, 0.92, 0.1), mat(Color(0.22, 0.20, 0.30)))
	cyl(root, 0.11, 0.6, Vector3(0.35, 0.3, -0.2), ghost_stone, Vector3(0.1, 0, -0.22))
	cone(root, 0.15, 0.3, Vector3(0.41, 0.72, -0.23), mat(Color(0.22, 0.20, 0.30)))
	# ruined house
	box(root, Vector3(0.4, 0.3, 0.3), Vector3(0.1, 0.15, 0.45), ghost_stone)
	# ghostly wisps
	for i in range(4):
		var a := i * TAU / 4.0 + 0.5
		sphere(root, 0.05 + 0.02 * (i % 2), Vector3(cos(a) * 0.55, 0.5 + 0.25 * i * 0.3, sin(a) * 0.5), mat(Color(0.5, 0.9, 0.8, 0.8), Color(0.3, 1.0, 0.8), 3.0))
	# glowing spectral windows
	box(root, Vector3(0.08, 0.1, 0.02), Vector3(-0.4, 0.55, 0.25), mat(Color(0.05, 0.1, 0.1), Color(0.2, 1.0, 0.7), 2.6))
	box(root, Vector3(0.07, 0.09, 0.02), Vector3(0.35, 0.4, -0.05), mat(Color(0.05, 0.1, 0.1), Color(0.2, 1.0, 0.7), 2.6))
	# dead tree
	cyl(root, 0.035, 0.5, Vector3(0.62, 0.25, 0.4), mat(Color(0.2, 0.16, 0.14)), Vector3(0, 0, -0.15))
	cyl(root, 0.02, 0.25, Vector3(0.70, 0.52, 0.4), mat(Color(0.2, 0.16, 0.14)), Vector3(0, 0, -0.9))


static func _keep(root: Node3D) -> void:
	ground(root, Color(0.36, 0.33, 0.28))
	# massive central tower
	cyl(root, 0.40, 1.0, Vector3(0, 0.5, 0), mat(STONE_DARK))
	cyl(root, 0.48, 0.2, Vector3(0, 1.1, 0), mat(STONE))
	for i in range(8):
		var a := i * TAU / 8.0
		box(root, Vector3(0.14, 0.16, 0.08), Vector3(cos(a) * 0.45, 1.28, sin(a) * 0.45), mat(STONE), Vector3(0, -a, 0))
	# base skirt
	var m := CylinderMesh.new()
	m.top_radius = 0.42
	m.bottom_radius = 0.58
	m.height = 0.3
	add_mesh(root, m, Vector3(0, 0.15, 0), mat(STONE_DARK.darkened(0.08)))
	# gate + windows
	box(root, Vector3(0.22, 0.3, 0.04), Vector3(0, 0.15, 0.41), mat(WOOD_DARK))
	box(root, Vector3(0.07, 0.12, 0.02), Vector3(0, 0.75, 0.40), mat(Color(0.08, 0.07, 0.05), GOLD, 1.8))
	banner(root, Vector3(0, 1.38, 0), Visual.TYPE_COLORS["special"], 0.5)


static func _laboratory(root: Node3D) -> void:
	ground(root, Color(0.22, 0.20, 0.28))
	# alchemist tower
	cyl(root, 0.28, 0.75, Vector3(-0.15, 0.375, 0), mat(Color(0.55, 0.52, 0.60)))
	cone(root, 0.36, 0.45, Vector3(-0.15, 0.97, 0), mat(Color(0.30, 0.18, 0.45)))
	# giant glowing flask
	var glass := mat(Color(0.4, 0.9, 0.5, 0.85), Color(0.2, 1.0, 0.4), 2.4)
	sphere(root, 0.18, Vector3(0.45, 0.20, 0.25), glass)
	cyl(root, 0.05, 0.22, Vector3(0.45, 0.42, 0.25), glass)
	# bubbles rising
	sphere(root, 0.03, Vector3(0.45, 0.62, 0.25), mat(Color(0.5, 1.0, 0.6), Color(0.3, 1.0, 0.5), 3.0))
	sphere(root, 0.02, Vector3(0.50, 0.72, 0.22), mat(Color(0.5, 1.0, 0.6), Color(0.3, 1.0, 0.5), 3.0))
	# glowing window in tower
	box(root, Vector3(0.09, 0.12, 0.02), Vector3(-0.15, 0.55, 0.28), mat(Color(0.05, 0.1, 0.05), Color(0.3, 1.0, 0.4), 2.6))
	# book + scroll on bench
	box(root, Vector3(0.3, 0.08, 0.2), Vector3(0.45, 0.04, -0.25), mat(WOOD))
	box(root, Vector3(0.14, 0.03, 0.10), Vector3(0.45, 0.1, -0.25), mat(Color(0.6, 0.2, 0.2)))


static func _smithy(root: Node3D) -> void:
	ground(root, Color(0.30, 0.27, 0.24))
	# forge building (open front)
	box(root, Vector3(0.9, 0.5, 0.6), Vector3(0, 0.25, -0.2), mat(STONE_DARK))
	prism(root, Vector3(1.0, 0.35, 0.7), Vector3(0, 0.67, -0.2), mat(Color(0.25, 0.22, 0.20)))
	# chimney with ember glow
	box(root, Vector3(0.18, 0.5, 0.18), Vector3(0.3, 0.85, -0.3), mat(STONE_DARK.darkened(0.05)))
	sphere(root, 0.05, Vector3(0.3, 1.12, -0.3), mat(FLAME, FLAME, 2.5))
	# forge fire
	box(root, Vector3(0.3, 0.2, 0.05), Vector3(-0.15, 0.18, 0.12), mat(Color(0.1, 0.05, 0.04), FLAME, 3.2))
	# anvil
	box(root, Vector3(0.1, 0.12, 0.1), Vector3(0.3, 0.06, 0.3), mat(Color(0.2, 0.2, 0.24)))
	box(root, Vector3(0.26, 0.07, 0.1), Vector3(0.3, 0.16, 0.3), mat(Color(0.3, 0.3, 0.36), Color.BLACK, 1.0, 0.8, 0.3))
	# hammer
	box(root, Vector3(0.025, 0.22, 0.025), Vector3(0.52, 0.11, 0.42), mat(WOOD), Vector3(0, 0, 0.6))
	box(root, Vector3(0.1, 0.06, 0.06), Vector3(0.60, 0.20, 0.42), mat(Color(0.35, 0.35, 0.4), Color.BLACK, 1.0, 0.8, 0.3))


static func _graveyard(root: Node3D) -> void:
	ground(root, Color(0.20, 0.24, 0.18))
	# gravestones
	gravestone(root, Vector3(-0.5, 0, 0.3), 0.3, 0.2)
	gravestone(root, Vector3(-0.1, 0, 0.45), 0.24, -0.15)
	gravestone(root, Vector3(0.3, 0, 0.25), 0.34, 0.05)
	gravestone(root, Vector3(0.55, 0, -0.1), 0.26, -0.3)
	gravestone(root, Vector3(-0.35, 0, -0.2), 0.28, 0.4)
	# stone cross monument
	box(root, Vector3(0.07, 0.5, 0.07), Vector3(0.05, 0.25, -0.35), mat(STONE_DARK))
	box(root, Vector3(0.25, 0.07, 0.07), Vector3(0.05, 0.38, -0.35), mat(STONE_DARK))
	# dead tree
	cyl(root, 0.05, 0.7, Vector3(-0.65, 0.35, -0.3), mat(Color(0.18, 0.14, 0.12)), Vector3(0, 0, 0.12))
	cyl(root, 0.025, 0.35, Vector3(-0.52, 0.68, -0.3), mat(Color(0.18, 0.14, 0.12)), Vector3(0, 0, -1.0))
	cyl(root, 0.02, 0.3, Vector3(-0.75, 0.62, -0.3), mat(Color(0.18, 0.14, 0.12)), Vector3(0, 0, 0.9))
	# eerie lantern
	cyl(root, 0.02, 0.5, Vector3(0.7, 0.25, 0.35), mat(Color(0.2, 0.2, 0.24)))
	sphere(root, 0.06, Vector3(0.7, 0.55, 0.35), mat(Color(0.4, 1.0, 0.6), Color(0.3, 1.0, 0.5), 3.0))
	# ground mist
	for i in range(3):
		var a := i * 2.1
		sphere(root, 0.16, Vector3(cos(a) * 0.5, 0.04, sin(a) * 0.45), mat(Color(0.7, 0.8, 0.8, 0.25)))


static func _observatory(root: Node3D) -> void:
	ground(root, Color(0.20, 0.20, 0.30))
	# tower base
	cyl(root, 0.32, 0.6, Vector3(0, 0.3, 0), mat(Color(0.70, 0.68, 0.74)))
	# dome with slit
	var dome := SphereMesh.new()
	dome.radius = 0.4
	dome.height = 0.8
	dome.is_hemisphere = true
	add_mesh(root, dome, Vector3(0, 0.6, 0), mat(Color(0.30, 0.42, 0.60), Color(0.1, 0.2, 0.4), 0.4, 0.6, 0.4))
	box(root, Vector3(0.1, 0.42, 0.42), Vector3(0, 0.78, 0.1), mat(Color(0.12, 0.14, 0.22)))
	# telescope poking out
	cyl(root, 0.06, 0.55, Vector3(0, 0.95, 0.25), mat(GOLD, GOLD, 0.6, 0.9, 0.3), Vector3(-0.7, 0, 0))
	# floating stars
	for i in range(5):
		var a := i * TAU / 5.0 + 0.3
		sphere(root, 0.028, Vector3(cos(a) * 0.85, 0.9 + 0.3 * sin(i * 2.0), sin(a) * 0.85), mat(Color(0.9, 0.95, 1.0), Color(0.7, 0.8, 1.0), 3.5))
	# door
	box(root, Vector3(0.16, 0.26, 0.02), Vector3(0, 0.13, 0.32), mat(WOOD_DARK))


static func _library(root: Node3D) -> void:
	ground(root)
	box(root, Vector3(1.05, 0.6, 0.6), Vector3(0, 0.3, 0), mat(Color(0.80, 0.74, 0.62)))
	prism(root, Vector3(1.15, 0.32, 0.7), Vector3(0, 0.76, 0), mat(Color(0.35, 0.28, 0.40)))
	# columned entrance
	for i in range(4):
		cyl(root, 0.04, 0.5, Vector3(-0.3 + i * 0.2, 0.25, 0.33), mat(Color(0.92, 0.90, 0.84)))
	prism(root, Vector3(0.85, 0.18, 0.16), Vector3(0, 0.58, 0.36), mat(Color(0.88, 0.85, 0.78)))
	# giant stacked books at the side
	var book_colors := [Color(0.65, 0.2, 0.2), Color(0.2, 0.4, 0.65), Color(0.25, 0.5, 0.3), Color(0.7, 0.55, 0.2)]
	for i in range(4):
		box(root, Vector3(0.4 - i * 0.04, 0.09, 0.28), Vector3(0.62, 0.045 + i * 0.095, 0.3), mat(book_colors[i]), Vector3(0, i * 0.18, 0))
	# glowing window — knowledge burning bright
	box(root, Vector3(0.14, 0.2, 0.02), Vector3(0, 0.36, 0.31), mat(Color(0.1, 0.08, 0.05), GOLD, 2.2))


static func _school_of_magic(root: Node3D) -> void:
	ground(root, Color(0.18, 0.14, 0.30))
	# twisted spire: stacked, rotated boxes
	for i in range(6):
		var s := 0.5 - i * 0.06
		box(root, Vector3(s, 0.22, s), Vector3(0, 0.11 + i * 0.22, 0), mat(Color(0.40, 0.32, 0.62).lightened(i * 0.04), Color.BLACK, 1.0, 0.1, 0.6), Vector3(0, i * 0.3, 0))
	cone(root, 0.2, 0.45, Vector3(0, 1.55, 0), mat(Color(0.55, 0.35, 0.95), Color(0.4, 0.2, 0.9), 0.8))
	# great orbiting orb
	sphere(root, 0.10, Vector3(0.55, 1.1, 0.2), mat(Color(0.55, 0.85, 1.0), Color(0.3, 0.7, 1.0), 3.5))
	torus(root, 0.012, 0.16, Vector3(0.55, 1.1, 0.2), mat(GOLD, GOLD, 1.5), Vector3(0.6, 0, 0.3))
	# runic glow at base
	for i in range(4):
		var a := i * TAU / 4.0 + 0.4
		box(root, Vector3(0.06, 0.1, 0.02), Vector3(cos(a) * 0.27, 0.3, sin(a) * 0.27), mat(Color(0.1, 0.05, 0.2), Color(0.6, 0.3, 1.0), 3.0), Vector3(0, -a, 0))
	# floating books
	box(root, Vector3(0.16, 0.03, 0.12), Vector3(-0.55, 0.8, 0.25), mat(Color(0.65, 0.2, 0.2)), Vector3(0.2, 0.5, 0.1))
	box(root, Vector3(0.14, 0.03, 0.11), Vector3(-0.65, 1.0, 0.05), mat(Color(0.2, 0.4, 0.65)), Vector3(-0.15, 0.9, 0.2))


static func _dragon_gate(root: Node3D) -> void:
	ground(root, Color(0.30, 0.18, 0.16))
	# monumental gate
	box(root, Vector3(0.22, 1.0, 0.3), Vector3(-0.45, 0.5, 0), mat(Color(0.45, 0.20, 0.18)))
	box(root, Vector3(0.22, 1.0, 0.3), Vector3(0.45, 0.5, 0), mat(Color(0.45, 0.20, 0.18)))
	box(root, Vector3(1.2, 0.22, 0.34), Vector3(0, 1.1, 0), mat(Color(0.55, 0.25, 0.20)))
	# pagoda-style top
	prism(root, Vector3(1.45, 0.3, 0.5), Vector3(0, 1.35, 0), mat(GOLD, GOLD, 0.5, 0.7, 0.4))
	# dragon horns curling up from the lintel
	for sx in [-0.62, 0.62]:
		cone(root, 0.07, 0.4, Vector3(sx, 1.45, 0), mat(GOLD, GOLD, 0.8, 0.8, 0.3))
	# glowing portal between pillars
	box(root, Vector3(0.65, 0.85, 0.04), Vector3(0, 0.45, 0), mat(Color(1.0, 0.3, 0.1), Color(1.0, 0.35, 0.1), 2.6))
	# dragon eyes on lintel
	sphere(root, 0.05, Vector3(-0.2, 1.1, 0.19), mat(Color(1, 0.8, 0.2), Color(1, 0.7, 0.1), 4.0))
	sphere(root, 0.05, Vector3(0.2, 1.1, 0.19), mat(Color(1, 0.8, 0.2), Color(1, 0.7, 0.1), 4.0))
	# guardian statues
	cone(root, 0.12, 0.3, Vector3(-0.75, 0.15, 0.35), mat(STONE_DARK))
	cone(root, 0.12, 0.3, Vector3(0.75, 0.15, 0.35), mat(STONE_DARK))


static func _university(root: Node3D) -> void:
	ground(root)
	# grand hall
	box(root, Vector3(1.2, 0.55, 0.6), Vector3(0, 0.275, 0), mat(Color(0.86, 0.82, 0.72)))
	# central dome
	var dome := SphereMesh.new()
	dome.radius = 0.3
	dome.height = 0.6
	dome.is_hemisphere = true
	add_mesh(root, dome, Vector3(0, 0.55, 0), mat(Color(0.35, 0.55, 0.50), Color(0.1, 0.3, 0.25), 0.3, 0.5, 0.4))
	cone(root, 0.05, 0.18, Vector3(0, 0.92, 0), mat(GOLD, GOLD, 1.0, 0.9, 0.3))
	# wings with gables
	prism(root, Vector3(0.45, 0.25, 0.7), Vector3(-0.5, 0.67, 0), mat(Color(0.40, 0.34, 0.30)))
	prism(root, Vector3(0.45, 0.25, 0.7), Vector3(0.5, 0.67, 0), mat(Color(0.40, 0.34, 0.30)))
	# grand entrance columns
	for i in range(4):
		cyl(root, 0.045, 0.5, Vector3(-0.27 + i * 0.18, 0.25, 0.33), mat(Color(0.94, 0.92, 0.86)))
	prism(root, Vector3(0.8, 0.2, 0.16), Vector3(0, 0.6, 0.36), mat(Color(0.90, 0.87, 0.80)))
	# scholar flags
	banner(root, Vector3(-0.62, 0.8, 0.25), Color(0.25, 0.35, 0.65), 0.45)
	banner(root, Vector3(0.62, 0.8, 0.25), Color(0.25, 0.35, 0.65), 0.45)


static func _great_wall(root: Node3D) -> void:
	ground(root, Color(0.34, 0.38, 0.26))
	# sweeping wall across the scene
	crenellated_wall(root, Vector3(0, 0, 0), 2.0, 0.5, 0.22, STONE)
	# gate towers
	for sx in [-0.65, 0.65]:
		box(root, Vector3(0.32, 0.85, 0.4), Vector3(sx, 0.425, 0), mat(STONE_DARK))
		prism(root, Vector3(0.42, 0.22, 0.5), Vector3(sx, 0.96, 0), mat(Color(0.50, 0.28, 0.20)))
	# central gate
	box(root, Vector3(0.26, 0.36, 0.05), Vector3(0, 0.18, 0.12), mat(WOOD_DARK))
	# watch fire
	sphere(root, 0.06, Vector3(-0.65, 1.13, 0), mat(FLAME, FLAME, 3.0))
	banner(root, Vector3(0.65, 1.07, 0), Visual.TYPE_COLORS["special"], 0.4)


static func _generic(root: Node3D) -> void:
	ground(root)
	house(root, Vector3.ZERO, Vector3(0.7, 0.5, 0.5), STONE_DARK)
