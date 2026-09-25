# Générateur de sons procéduraux

Tous les sons de PARADOXE sont **calculés** par ce script Python : bruits filtrés,
oscillateurs, enveloppes, résonances, boucles sans couture. Relancer le script redonne
exactement les mêmes fichiers. On peut donc modifier un paramètre, régénérer, et comparer
à l'oreille.

## Installation (une seule fois)

```bash
python3 -m pip install -r tools/audio/requirements.txt
# ou : ./setup.sh --python
```

Sous Windows : installez Python depuis <https://www.python.org>, puis tapez la même
commande dans un terminal (`py -m pip install -r tools/audio/requirements.txt`).

## Utilisation

Depuis la racine du dépôt :

```bash
python3 tools/audio/generate_sounds.py              # génère tous les sons
python3 tools/audio/generate_sounds.py --list       # liste le catalogue
python3 tools/audio/generate_sounds.py test_impact  # un seul son
python3 tools/audio/generate_sounds.py --seed 3     # autres tirages aléatoires
```

Les fichiers sont écrits dans `assets/audio/generated/<catégorie>/<nom>.wav`. Godot les
réimporte automatiquement à la prochaine ouverture de l'éditeur, ou avec
`./tools/run_tests.sh`.

## Modifier un son

Chaque son est une fonction de `generate_sounds.py` précédée de `@sound(...)`. Ses
réglages sont regroupés en tête de fonction, entre les lignes `# --- Paramètres ---` :

```python
@sound("test_impact", "sfx", description="Choc métallique…")
def test_impact(rng):
    # --- Paramètres ---
    duration = 1.6
    modes = [(182, 1.0, 1.1), (431, 0.7, 0.8), ...]   # (fréquence Hz, volume, déclin s)
    transient_ms = 6.0
    # ------------------
```

Par exemple, baisser toutes les fréquences de `modes` donne un objet plus gros et plus
grave, et allonger les déclins le fait résonner plus longtemps.

## Ajouter un son

1. Copiez une fonction existante, changez le nom dans `@sound("nouveau_nom", "catégorie")`.
2. Pour un son **en boucle** (ambiance), ajoutez `loop=True` et terminez par
   `dsp.make_seamless_loop(...)`. Le script inscrit alors les points de boucle dans le
   WAV, et Godot les détecte à l'import.
3. Relancez le script, puis ajoutez le son dans `docs/SOUND_DESIGN.md` et `CREDITS.md`.

## Boîte à outils (`dsp.py`)

| Famille | Fonctions |
|---|---|
| Générateurs | `sine`, `saw`, `square`, `white_noise`, `pink_noise`, `brown_noise`, `crackle` |
| Enveloppes | `exp_decay`, `adsr`, `ramp` |
| Filtres | `lowpass`, `highpass`, `bandpass`, `resonator`, `modal_body` |
| Outils | `normalize`, `fade`, `make_seamless_loop`, `reverse`, `mix`, `write_wav` |

Un son est un tableau de nombres entre -1 et 1, à raison de 44 100 valeurs par seconde.
On peut se le représenter comme une colonne Excel de 44 100 lignes par seconde : mixer
deux sons revient à additionner deux colonnes, et appliquer une enveloppe à multiplier
une colonne par une autre.
