#!/usr/bin/env python3
"""Mesure le niveau de chaque son du jeu et vérifie l'équilibre du mixage.

    python3 tools/audio/measure_levels.py          # tableau + vérification des familles
    python3 tools/audio/measure_levels.py --all    # affiche aussi les sons hors famille

Pour chaque son de la bibliothèque (resources/audio/sound_library.tres), l'outil
lit ses fichiers WAV et calcule :

- le **niveau du fichier** : moyenne quadratique (RMS) de la partie active du son,
  en dB (les silences ne comptent pas, sinon un son court paraîtrait trop faible) ;
- le **niveau effectif** : niveau du fichier + volume_db de la bibliothèque. C'est
  ce qu'on entend, avant les volumes des bus et l'effet de la distance ;
- la **crête effective** : le point le plus fort du fichier + volume_db. Au-dessus
  de 0 dB, le limiteur du bus Master doit écraser le son : à éviter.

Les sons sont rangés en **familles** (table FAMILIES ci-dessous) : des sons qui
doivent sonner au même niveau les uns par rapport aux autres (tous les pas, tous
les tirs…). Chaque famille a un niveau cible et une tolérance. L'outil signale
chaque son hors tolérance et chaque crête trop forte, et renvoie un code d'erreur.

Analogie Excel : une colonne « niveau mesuré », une colonne « cible » et une mise
en forme conditionnelle qui colore en rouge les écarts.

Attention : un niveau égal n'est pas une sonie (« loudness ») parfaitement égale,
l'oreille est plus sensible aux médiums. C'est un premier réglage objectif, que
l'oreille affine ensuite au banc d'écoute.

Dépendances : numpy, scipy (./setup.sh --python).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import warnings
from pathlib import Path

import numpy as np
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[2]
LIBRARY = ROOT / "resources/audio/sound_library.tres"
SOUND_DIR = ROOT / "assets/audio/generated"

# Crête effective maximale (dB par rapport à la pleine échelle).
MAX_PEAK_DB = 0.0

# Familles : nom -> (niveau cible en dB, tolérance ± dB, identifiants).
# Pour les pas, c'est le pas de COURSE ; la marche et l'accroupi sont plus doux
# (resources/audio/foley.tres).
FAMILIES: dict[str, tuple[float, float, list[str]]] = {
    "Pas (course)": (-22.0, 2.0, [
        "foley_step_stone", "foley_step_metal", "foley_step_plant", "foley_step_water"]),
    "Réceptions et chutes": (-21.5, 1.5, ["foley_land", "foley_land_heavy", "foley_body_fall"]),
    "Gestes": (-27.5, 2.0, [
        "foley_jump", "foley_roll", "foley_slide", "foley_skid", "foley_grab", "foley_climb"]),
    "Petits gestes": (-35.0, 2.5, ["foley_turn", "foley_crouch", "weapon_draw", "weapon_holster"]),
    "Tirs": (-21.0, 1.5, ["weapon_shot", "weapon_shot_sentinel", "weapon_shot_charged"]),
    "Impacts": (-24.0, 1.5, ["impact_wall", "impact_body", "shield_hit"]),
    "Bouclier levé / baissé": (-28.0, 2.0, ["shield_up", "shield_down"]),
    "Signaux de l'arme": (-31.5, 2.0, ["weapon_charge_ready", "weapon_empty"]),
    "Voix des Sentinelles": (-21.0, 1.5, [
        "creature_alert", "creature_calm", "creature_curious", "creature_death", "creature_search"]),
    "Couches d'ambiance": (-32.0, 2.5, [
        "amb_city_loop", "amb_electric_loop", "amb_hall_loop", "amb_lab_loop",
        "amb_shaft_loop", "amb_wind_loop"]),
    "Évènements d'ambiance": (-32.5, 2.0, ["amb_buzz", "amb_creak", "amb_cry", "amb_debris", "amb_drip"]),
    "Interface": (-20.0, 1.5, ["ui_confirm", "ui_back"]),
}


def read_library() -> dict[str, dict]:
    """Lit la bibliothèque : identifiant -> {volume_db, bus, files}."""
    text = LIBRARY.read_text(encoding="utf-8")
    paths = dict(re.findall(r'\[ext_resource type="AudioStream" path="res://([^"]+)" id="([^"]+)"\]', text))
    paths = {v: k for k, v in paths.items()}  # id de ressource -> chemin
    entries: dict[str, dict] = {}
    for block in text.split("[sub_resource")[1:]:
        m = re.search(r'^id = &"([^"]+)"', block, re.M)
        if not m:
            continue
        volume = re.search(r"^volume_db = (-?[\d.]+)", block, re.M)
        bus = re.search(r'^bus = &"([^"]+)"', block, re.M)
        ids = re.findall(r'ExtResource\("([^"]+)"\)', block.split("streams =", 1)[1].split("\n", 1)[0]) \
            if "streams =" in block else []
        entries[m.group(1)] = {
            "volume_db": float(volume.group(1)) if volume else 0.0,  # 0 dB n'est pas écrit (valeur par défaut)
            "bus": bus.group(1) if bus else "SFX",
            "files": [ROOT / paths[i] for i in ids if i in paths],
        }
    return entries


def measure(path: Path) -> tuple[float, float]:
    """(niveau RMS de la partie active, crête) d'un fichier, en dB."""
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")  # bloc « smpl » (points de boucle) : sans importance ici
        rate, data = wavfile.read(path)
    x = data.astype(np.float64)
    if data.dtype.kind == "i":
        x /= float(np.iinfo(data.dtype).max) + 1.0
    if x.ndim > 1:
        x = x.mean(axis=1)
    window = max(1, int(rate * 0.05))  # fenêtres de 50 ms
    count = max(1, len(x) // window)
    frames = x[: count * window].reshape(count, -1) if len(x) >= window else x.reshape(1, -1)
    rms = np.sqrt((frames ** 2).mean(axis=1) + 1e-12)
    active = rms[rms > 10 ** (-50 / 20)]  # au-dessus de -50 dB : le son « joue »
    level = 20 * np.log10(np.sqrt((active ** 2).mean())) if len(active) else -120.0
    peak = 20 * np.log10(np.abs(x).max() + 1e-12)
    return float(level), float(peak)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--all", action="store_true", help="affiche aussi les sons hors famille")
    args = parser.parse_args()

    entries = read_library()
    results: dict[str, tuple[float, float]] = {}
    for sound_id, entry in entries.items():
        if not entry["files"]:
            continue
        levels = [measure(f) for f in entry["files"]]
        file_level = float(np.mean([lv for lv, _ in levels]))
        peak = max(pk for _, pk in levels)
        results[sound_id] = (file_level + entry["volume_db"], peak + entry["volume_db"])

    problems = 0
    grouped: set[str] = set()
    header = f"  {'son':24s} {'bus':8s} {'volume':>7s} {'effectif':>9s} {'crête':>7s}"
    for family, (target, tolerance, ids) in FAMILIES.items():
        print(f"\n{family} : cible {target:.1f} dB (± {tolerance:.1f})")
        print(header)
        for sound_id in ids:
            grouped.add(sound_id)
            if sound_id not in results:
                print(f"  {sound_id:24s} ABSENT de la bibliothèque")
                problems += 1
                continue
            level, peak = results[sound_id]
            flags = []
            if abs(level - target) > tolerance:
                flags.append(f"écart {level - target:+.1f} dB")
            if peak > MAX_PEAK_DB:
                flags.append(f"crête {peak:+.1f} dB")
            problems += len(flags)
            entry = entries[sound_id]
            print(f"  {sound_id:24s} {entry['bus']:8s} {entry['volume_db']:7.1f} {level:9.1f} {peak:7.1f}"
                  + ("   <-- " + ", ".join(flags) if flags else ""))
    others = sorted(set(results) - grouped)
    if args.all and others:
        print("\nHors famille (niveaux libres : respiration, boucles d'effets, sons de test…)")
        print(header)
        for sound_id in others:
            level, peak = results[sound_id]
            entry = entries[sound_id]
            print(f"  {sound_id:24s} {entry['bus']:8s} {entry['volume_db']:7.1f} {level:9.1f} {peak:7.1f}")
    print(f"\n{problems} écart(s)." if problems else "\nMixage équilibré : aucun écart.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
