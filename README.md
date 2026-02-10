# Prototype Godot 4.5.1

Projet prototype de système de combat 2D top-down avec optimisations de performance et architecture modulaire.

## 📁 Structure du projet

```
prototype/
├── assets/
│   └── sprites/          # Sprites et ressources visuelles
│       ├── characters/   # Personnages (warrior, zombie)
│       └── ui/           # Interface utilisateur (barres de vie)
├── docs/                 # Documentation
│   ├── OPTIMIZATIONS.md  # Guide détaillé des optimisations
│   └── README.md         # Documentation générale
├── scenes/
│   ├── entities/         # Scènes d'entités réutilisables
│   │   ├── combat_entity.tscn        # Entité de combat de base
│   │   ├── player_warrior.tscn       # Guerrier joueur
│   │   └── enemy_zombie.tscn         # Zombie ennemi
│   └── levels/           # Scènes de niveaux
│       └── test_arena.tscn           # Arène de test
└── scripts/
    ├── autoload/         # Singletons (autoload Godot)
    │   └── hit_pause_manager.gd
    ├── components/       # Composants réutilisables
    │   ├── health_bar_component.gd
    │   ├── targeting_system.gd
    │   ├── combat_feedback.gd
    │   └── README.md
    ├── debug/            # Outils de debug
    │   └── performance_monitor.gd
    └── entities/         # Scripts d'entités
        └── combat_entity.gd
```

## 🚀 Démarrage rapide

1. Ouvrir le projet dans **Godot 4.5.1+**
2. Lancer la scène de test : `scenes/levels/test_arena.tscn` (F5)
3. Contrôles :
   - **WASD** / **Flèches** : Déplacement
   - Le guerrier attaque automatiquement les zombies à portée

## 🎯 Fonctionnalités

- ✅ Système de combat avec ciblage automatique
- ✅ Barres de vie avec effet "ghost" (FTL-style)
- ✅ Feedback de combat (hit-pause, flash, knockback, i-frames)
- ✅ IA ennemie basique
- ✅ Architecture modulaire avec composants réutilisables

## 📚 Documentation

- **[OPTIMIZATIONS.md](docs/OPTIMIZATIONS.md)** - Guide complet des optimisations de performance
- **[Components README](scripts/components/README.md)** - Documentation des composants réutilisables

## 🏗️ Architecture

Le projet utilise une architecture en composants pour maximiser la réutilisabilité :

### Composants principaux

- **HealthBarComponent** - Gestion des barres de vie avec styles multiples
- **TargetingSystem** - Ciblage optimisé avec cache
- **CombatFeedback** - Feedback visuel et physique (flash, knockback, i-frames)

### Singletons (Autoload)

- **HitPauseManager** - Gestion globale des "hit-pause" (freeze lors des impacts)

## 🔧 Développement

### Créer une nouvelle entité

1. Dupliquer `scenes/entities/combat_entity.tscn`
2. Ajouter les composants nécessaires (HealthBarComponent, TargetingSystem, CombatFeedback)
3. Créer un script qui hérite ou utilise `combat_entity.gd`
4. Configurer les exports dans l'Inspector

Voir [scripts/components/README.md](scripts/components/README.md) pour plus de détails.

## 📊 Optimisations

Le projet inclut de nombreuses optimisations de performance :

- Cache de ciblage (rafraîchissement tous les 0.1s au lieu de chaque frame)
- Préchargement des textures avec `preload()`
- Singleton centralisé pour hit-pause
- Réutilisation des Tweens
- Un seul `move_and_slide()` par frame

Voir [docs/OPTIMIZATIONS.md](docs/OPTIMIZATIONS.md) pour les détails.

## 🛠️ Technologies

- **Godot Engine** 4.5.1
- **Langage** : GDScript
- **Renderer** : gl_compatibility (compatibilité maximale)

## 📝 Licence

Projet prototype à usage éducatif et de démonstration.
CI test
