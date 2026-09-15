# Documentation de l'API & Protocole d'Échange Godot <-> LLM

Ce document fournit à l'équipe (Godot & Backend API) les spécifications exactes des données spatiales transmises et des commandes d'action exécutables par le LLM.

---

## 1. Vue d'Ensemble & Repères Spatiaux

Le monde 3D est discrétisé sous forme d'une grille à 3 dimensions entières `[x, y, z]` :
- **X (Axe Horizontal Ouest/Est)** : Négatif = Ouest, Positif = Est.
- **Y (Axe Vertical / Étages)** : `0` = Rez-de-chaussée, `1` = Étage 1, `2` = Étage 2, `-1` = Sous-sol.
- **Z (Axe Horizontal Nord/Sud)** : Négatif = Nord, Positif = Sud.

**Taille d'une pièce standard** : `20m (X) x 6m (Y) x 20m (Z)`.
La pièce initiale où le joueur commence se trouve aux coordonnées `[0, 0, 0]`.

---

## 2. Données Envoyées au LLM (État Spatial en JSON)

À chaque cycle, événement clé (joueur franchit une porte, dépose un objet, etc.) ou requête de l'API, Godot transmet l'état suivant :

```json
{
  "player": {
    "grid_coords": [0, 0, 0],
    "world_position": [1.4, 0.9, -2.1],
    "carrying_object": null
  },
  "rooms": {
    "0,0,0": {
      "type": "normal",
      "coords": [0, 0, 0],
      "doors": {
        "north": {
          "open": true,
          "leads_to": [0, 0, -1]
        },
        "south": {
          "open": true,
          "leads_to": [0, 0, 1]
        },
        "east": null,
        "west": null
      }
    },
    "0,0,1": {
      "type": "normal",
      "coords": [0, 0, 1],
      "doors": {
        "north": {
          "open": true,
          "leads_to": [0, 0, 0]
        },
        "south": null,
        "east": null,
        "west": null
      }
    },
    "0,1,0": {
      "type": "stairs",
      "coords": [0, 1, 0],
      "direction": "north",
      "to_floor_offset": 1
    }
  },
  "objects": {
    "cube_starter": {
      "type": "cube",
      "grid_coords": [0, 0, 0],
      "world_pos": [3.0, 1.0, 2.0],
      "is_held": false
    }
  },
  "drop_zones": {
    "zone_starter": {
      "accepted_type": "cube",
      "is_satisfied": false,
      "current_object": "",
      "grid_coords": [0, 0, 0]
    }
  },
  "recent_events": [
    "[15:40:02] player_entered_room: 0,0,0",
    "[15:40:15] drop_zone_completed: zone_starter with cube_starter"
  ]
}
```

---

## 3. Commandes / Outils LLM Exécutables (Format des Actions)

L'API renvoie soit un objet action individuel :
```json
{
  "action": "<nom_de_l_action>",
  "params": { ... }
}
```
Soit une liste ordonnée d'actions :
```json
{
  "actions": [
    { "action": "generate_room", "params": { "coords": [0, 0, 1], "doors": ["north"] } },
    { "action": "spawn_object", "params": { "coords": [0, 0, 1], "object_type": "cube" } }
  ]
}
```

### Détail des Fonctions :

### `generate_room`
Génère une pièce modulaire standard aux coordonnées de grille indiquées.
- **Paramètres** :
  - `coords` : `[x, y, z]` (ex: `[0, 0, 1]`)
  - `room_type` : `string` (défaut: `"normal"`)
  - `doors` : `array` de directions parmi `["north", "south", "east", "west"]`
- **Exemple** :
```json
{
  "action": "generate_room",
  "params": {
    "coords": [0, 0, 1],
    "doors": ["north", "south"]
  }
}
```

---

### `generate_stairs`
Génère une cage d'escalier modulaire praticable reliant l'étage actuel à l'étage supérieur.
- **Paramètres** :
  - `coords` : `[x, y, z]`
  - `direction` : `"north" | "south" | "east" | "west"` (sens de montée)
  - `to_floor_offset` : `int` (défaut: `1`)
- **Exemple** :
```json
{
  "action": "generate_stairs",
  "params": {
    "coords": [0, 1, 0],
    "direction": "north",
    "to_floor_offset": 1
  }
}
```

---

### `spawn_object`
Fait apparaître un objet interactif physique (que le joueur peut porter avec la touche `E`).
- **Paramètres** :
  - `object_type` : `"cube" | "companion_cube"`
  - `coords` : `[x, y, z]`
  - `relative_pos` : `[x, y, z]` (décalage en mètres par rapport au centre de la pièce, ex: `[0, 1.5, 2]`)
  - `object_id` (optionnel) : `string` identifiant unique
- **Exemple** :
```json
{
  "action": "spawn_object",
  "params": {
    "object_type": "cube",
    "coords": [0, 0, 0],
    "relative_pos": [2, 1, 0],
    "object_id": "test_cube_01"
  }
}
```

---

### `despawn_object`
Fait disparaître instantanément un objet physique du jeu.
- **Paramètres** :
  - `object_id` : `string`
- **Exemple** :
```json
{
  "action": "despawn_object",
  "params": {
    "object_id": "test_cube_01"
  }
}
```

---

### `add_door` / `spawn_door`
Ouvre une porte dans le mur d'une pièce existante.
- **Paramètres** :
  - `coords` : `[x, y, z]`
  - `wall` : `"north" | "south" | "east" | "west"`
- **Exemple** :
```json
{
  "action": "add_door",
  "params": {
    "coords": [0, 0, 0],
    "wall": "east"
  }
}
```

---

### `remove_door`
Supprime une porte et mure complètement le passage (effet Stanley Parable quand le joueur se retourne !).
- **Paramètres** :
  - `coords` : `[x, y, z]`
  - `wall` : `"north" | "south" | "east" | "west"`
- **Exemple** :
```json
{
  "action": "remove_door",
  "params": {
    "coords": [0, 0, 0],
    "wall": "north"
  }
}
```

---

### `teleport_player`
Téléporte instantanément le joueur dans une pièce ou à des coordonnées précises.
- **Paramètres** :
  - `coords` : `[x, y, z]`
  - `relative_pos` : `[x, y, z]` (défaut: `[0, 1, 0]`)
- **Exemple** :
```json
{
  "action": "teleport_player",
  "params": {
    "coords": [0, 0, 0],
    "relative_pos": [0, 1, 0]
  }
}
```

---

### `create_drop_zone`
Crée une plaque de pression au sol exigeant qu'un certain type d'objet soit déposé dessus.
- **Paramètres** :
  - `coords` : `[x, y, z]`
  - `accepted_type` : `"cube"`
  - `relative_pos` : `[x, y, z]`
  - `zone_id` (optionnel) : `string`
- **Exemple** :
```json
{
  "action": "create_drop_zone",
  "params": {
    "coords": [0, 0, 0],
    "accepted_type": "cube",
    "relative_pos": [0, 0, 3],
    "zone_id": "pressure_plate_1"
  }
}
```

---

## 4. Schéma des Outils au Format OpenAI / Gemini Function Calling

Pour le développeur du backend Python / LLM, voici la définition JSON Schema des fonctions prêtes à être injectées dans le prompt ou `tools` :

```json
[
  {
    "type": "function",
    "function": {
      "name": "generate_room",
      "description": "Génère une nouvelle pièce modulaire dans la grille.",
      "parameters": {
        "type": "object",
        "properties": {
          "coords": {"type": "array", "items": {"type": "integer"}, "description": "[x, y, z]"},
          "doors": {"type": "array", "items": {"type": "string", "enum": ["north", "south", "east", "west"]}}
        },
        "required": ["coords"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "generate_stairs",
      "description": "Génère un escalier praticable pour monter à l'étage.",
      "parameters": {
        "type": "object",
        "properties": {
          "coords": {"type": "array", "items": {"type": "integer"}},
          "direction": {"type": "string", "enum": ["north", "south", "east", "west"]}
        },
        "required": ["coords"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "spawn_object",
      "description": "Fait apparaître un objet interactif.",
      "parameters": {
        "type": "object",
        "properties": {
          "object_type": {"type": "string", "enum": ["cube", "companion_cube"]},
          "coords": {"type": "array", "items": {"type": "integer"}},
          "relative_pos": {"type": "array", "items": {"type": "number"}}
        },
        "required": ["object_type", "coords"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "despawn_object",
      "description": "Fait disparaître un objet.",
      "parameters": {
        "type": "object",
        "properties": {
          "object_id": {"type": "string"}
        },
        "required": ["object_id"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "add_door",
      "description": "Ouvre un passage/porte sur un mur.",
      "parameters": {
        "type": "object",
        "properties": {
          "coords": {"type": "array", "items": {"type": "integer"}},
          "wall": {"type": "string", "enum": ["north", "south", "east", "west"]}
        },
        "required": ["coords", "wall"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "remove_door",
      "description": "Mure une porte existante pour piéger ou orienter le joueur.",
      "parameters": {
        "type": "object",
        "properties": {
          "coords": {"type": "array", "items": {"type": "integer"}},
          "wall": {"type": "string", "enum": ["north", "south", "east", "west"]}
        },
        "required": ["coords", "wall"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "teleport_player",
      "description": "Téléporte le joueur dans une pièce désignée.",
      "parameters": {
        "type": "object",
        "properties": {
          "coords": {"type": "array", "items": {"type": "integer"}}
        },
        "required": ["coords"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "create_drop_zone",
      "description": "Crée une zone d'objectif où le joueur doit déposer un objet.",
      "parameters": {
        "type": "object",
        "properties": {
          "coords": {"type": "array", "items": {"type": "integer"}},
          "accepted_type": {"type": "string"}
        },
        "required": ["coords"]
      }
    }
  }
]
```

---

## 5. Comment Tester dans Godot dès Maintenant

1. Lancez le jeu depuis l'éditeur Godot (Touche `F5`).
2. Vous commencez dans la pièce `[0, 0, 0]`. Devant vous se trouvent un cube interactif et une plaque de pression.
3. Appuyez sur **`E`** (ou clic droit) en visant le cube pour le ramasser, marchez sur la plaque et appuyez sur **`E`** pour le déposer : la plaque s'illumine en vert !
4. Appuyez sur **`F1`** : le panneau de test apparaît.
   - Vous pouvez cliquer sur les boutons `Générer Pièce`, `Générer Escalier`, `Téléporter`, etc.
   - Vous visualisez l'état JSON complet en direct dans la fenêtre de droite.
   - Vous pouvez coller n'importe quelle commande JSON dans le champ texte pour la tester instantanément !
