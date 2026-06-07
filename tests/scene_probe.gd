# Probe: load the real Main.tscn and inspect layout sizes.
extends SceneTree

func _init() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	await process_frame
	var main := current_scene as Control
	print("viewport: ", root.size)
	print("Main size: ", main.size, " anchors: ", main.anchor_right, ",", main.anchor_bottom)
	for child in main.get_children():
		if child is Control:
			print("  child %s size=%s pos=%s" % [child.get_class(), child.size, child.position])
			for gc in child.get_children():
				if gc is Control:
					print("    gc %s size=%s pos=%s" % [gc.get_class(), gc.size, gc.position])
	quit(0)
