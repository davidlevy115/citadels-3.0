# Arranges CardNode children in a Magic-Arena style arc at the bottom of the screen.
class_name HandFan
extends Control

const ARC_RADIUS := 1100.0
const MAX_SPREAD_DEG := 36.0
const PER_CARD_DEG := 5.2


func relayout(animate := true) -> void:
	var cards: Array = []
	for child in get_children():
		if child is CardNode:
			cards.push_back(child)
	var n := cards.size()
	if n == 0:
		return

	var spread: float = min(MAX_SPREAD_DEG, n * PER_CARD_DEG)
	var center := Vector2(size.x / 2.0, size.y + ARC_RADIUS - 205.0)

	for i in range(n):
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		var ang := deg_to_rad(lerp(-spread / 2.0, spread / 2.0, t))
		var pos := center + Vector2(sin(ang), -cos(ang)) * ARC_RADIUS
		var card: CardNode = cards[i]
		card.rotation = ang
		var target := pos - Vector2(CardNode.FULL_W / 2.0, 0)
		if animate and card.is_inside_tree():
			var tw := card.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "position", target, 0.28)
		else:
			card.position = target


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		relayout(false)
