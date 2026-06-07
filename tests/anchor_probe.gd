# Probe: does set_anchors_preset before add_child stretch the child?
extends SceneTree

func _init() -> void:
	var root_ctrl := Control.new()
	root_ctrl.size = Vector2(1920, 1080)
	root.add_child(root_ctrl)

	# pattern A: preset BEFORE add_child
	var a := Control.new()
	a.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(a)

	# pattern B: preset AFTER add_child
	var b := Control.new()
	root_ctrl.add_child(b)
	b.set_anchors_preset(Control.PRESET_FULL_RECT)

	# pattern C: anchors+offsets preset after add
	var c := Control.new()
	root_ctrl.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	await process_frame
	await process_frame
	print("A (preset before add): ", a.size)
	print("B (preset after add):  ", b.size)
	print("C (anchors+offsets):   ", c.size)
	quit(0)
