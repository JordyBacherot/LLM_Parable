extends Node3D

const X_MIN = -11.5
const X_MAX = 11.3
const Y_MIN = -2.3
const Y_MAX = -1.2

@onready var list_wall : Array[CSGBox3D] = [
	$RoomStart/Wall,
	$RoomStart/Wall2,
	$RoomStart/Wall3,
	$RoomStart/Wall4
]

@onready var door: CSGBox3D = get_node_or_null("RoomStart/Wall/Door")
@onready var grid_manager: GridManager = get_node_or_null("GridManager")

func _ready():
	if grid_manager:
		# Masquer l'ancienne pièce de test pour laisser place aux pièces modulaires
		if has_node("RoomStart"):
			$RoomStart.visible = false
			for child in $RoomStart.get_children():
				if child is CollisionObject3D:
					child.collision_layer = 0
					child.collision_mask = 0
				for subchild in child.get_children():
					if subchild is CollisionObject3D:
						subchild.collision_layer = 0
						subchild.collision_mask = 0
		if has_node("Timer"):
			$Timer.stop()
		
		# Initialiser la pièce de départ [0, 0, 0] avec ouvertures
		grid_manager.create_room(Vector3i(0, 0, 0), "normal", ["north", "south"])
		
		# Cube et zone initiale (qui peuvent aussi être manipulés par le premier appel LLM)
		grid_manager.spawn_object("cube_starter", "cube", Vector3i(0, 0, 0), Vector3(3.0, 1.0, 2.0))
		grid_manager.create_drop_zone("zone_starter", Vector3i(0, 0, 0), "cube", Vector3(-3.0, 0.0, 2.0))
		
		print("=== SYSTÈME SPATIAL LLM INITIALISÉ ===")
		print("Appuyez sur T pour parler à l'IA, ou F1 pour ouvrir la console d'actions LLM !")
	else:
		randomize_door_setup()

func randomize_door_setup():
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# 1. Sélection du mur cible
	var random_index = rng.randi_range(0, list_wall.size() - 1)
	var target_wall = list_wall[random_index]

	# SÉCURITÉ : Vérification de l'échelle (Scale)
	if target_wall.scale != Vector3.ONE:
		push_warning("ATTENTION : Le mur " + target_wall.name + " a une scale différente de (1,1,1) ! Cela déforme la porte.")

	# 2. Changement de parent
	# On utilise 'true' pour que la porte ne "saute" pas visuellement pendant le changement
	door.reparent(target_wall, true)

	# 3. Rotation LOCALE (La clé du succès)
	# On ne s'occupe pas de l'angle du mur. On dit juste à la porte :
	# "Tourne-toi de 90° PAR RAPPORT au mur".
	door.rotation_degrees.y = 90

	# 4. Calcul de la position aléatoire (Réintégré !)
	var random_x = rng.randf_range(X_MIN, X_MAX)
	var random_y = rng.randf_range(Y_MIN, Y_MAX)
	
	# La position est maintenant relative au nouveau parent (le mur)
	door.position = Vector3(random_x, random_y, 0)

	# 5. Mise à jour forcée du moteur CSG et des transformations
	door.force_update_transform()
	if target_wall is CSGBox3D:
		target_wall.force_update_transform()

	# Affichage de la porte
	door.show()
	
	# DEBUG LOGS
	print("--- CONFIGURATION RÉUSSIE ---")
	print("Mur cible : ", target_wall.name)
	print("Rotation Locale Porte : ", door.rotation_degrees.y)
	print("Rotation Globale Porte : ", door.global_rotation_degrees.y)
	print("Position Locale Porte : ", door.position)

	# Vérification AnimationPlayer
	var anim = get_tree().root.find_child("AnimationPlayer", true, false)
	if anim and anim.is_playing():
		push_warning("ALERTE : Un AnimationPlayer est actif et pourrait écraser la rotation !")

func _on_timer_timeout() -> void:
	randomize_door_setup()
