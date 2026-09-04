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

@onready var door: CSGBox3D = $RoomStart/Wall/Door

func _ready():
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
