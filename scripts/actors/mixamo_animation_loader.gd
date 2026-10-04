extends RefCounted
class_name MixamoAnimationLoader

# Baked offline by tools/bake_player_animations.gd. No runtime FBX scan/instancing.
const LIBRARY: AnimationLibrary = preload("res://assets/animations/player/player_locomotion.res")

static func attach(target: Skeleton3D, player: AnimationPlayer) -> Dictionary:
	var attached: Dictionary = {}
	if target == null:
		return attached
	# The authoritative model owns this AnimationPlayer; paths are relative to it.
	var animation_root := player.get_node(player.root_node)
	if str(animation_root.get_path_to(target)) != "Skeleton3D":
		push_error("Player skeleton path changed; rebake or update animation bindings.")
		return attached
	for name_value in player.get_animation_library_list():
		player.remove_animation_library(name_value)
	player.add_animation_library("locomotion", LIBRARY)
	for name_value in LIBRARY.get_animation_list():
		attached[str(name_value)] = "locomotion/" + str(name_value)
	return attached
