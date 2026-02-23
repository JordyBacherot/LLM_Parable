extends Node3D

const X_MIN = -11.5
const X_MAX = 11.3
const Y_MIN = -2.3
const Y_MAX = -1.2

# On utilise directement la taille du tableau pour éviter les erreurs
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

	var random_index = rng.randi_range(0, list_wall.size() - 1)
	print(random_index)
	var target_wall = list_wall[random_index]

	# 1. On change le parent d'abord
	door.reparent(target_wall)

	if random_index == 1 or random_index == 2: # Plus précis que > 0 and < 3
		door.global_rotation_degrees.y = 90
	else:
		door.global_rotation_degrees.y = 0

	door.show()
	
	# 2. Changer le parent de la porte
	# On utilise reparent() qui gère proprement le changement de nœud
	door.reparent(target_wall)
	
	# 3. Calcul de la position aléatoire
	var random_x = rng.randf_range(X_MIN, X_MAX)
	var random_y = rng.randf_range(Y_MIN, Y_MAX)
	
	# Comme la porte est maintenant ENFANT du mur, 
	# sa position est RELATIVE au centre du mur choisi.
	door.position = Vector3(random_x, random_y, 0)
	
	print("La porte est fixée sur : ", target_wall.name, " à la position locale : ", door.position)


func _on_timer_timeout() -> void:
	randomize_door_setup()
	pass # Replace with function body.
