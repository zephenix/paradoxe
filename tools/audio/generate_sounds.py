#!/usr/bin/env python3
"""
Générateur de sons procéduraux de PARADOXE.

Chaque son est une petite fonction Python décorée par @sound(...). Ses
paramètres (fréquences, durées, filtres…) sont écrits en clair au début de
la fonction : modifie-les, relance le script, puis réimporte dans Godot
(l'éditeur le fait tout seul à la prochaine ouverture du projet).

Usage (depuis la racine du dépôt) :
    python3 tools/audio/generate_sounds.py            # génère tous les sons
    python3 tools/audio/generate_sounds.py --list     # liste les sons
    python3 tools/audio/generate_sounds.py ui_confirm test_impact   # seulement ceux-là
    python3 tools/audio/generate_sounds.py --seed 7   # autres variations aléatoires

Les fichiers sont écrits dans assets/audio/generated/<catégorie>/<nom>.wav.
Le hasard est « graine fixe » : relancer le script donne exactement les mêmes
fichiers (pas de modification inutile dans Git), sauf si on change --seed.

J1 : trois sons de test pour valider la chaîne audio (bus, effets, Web).
J5 : bibliothèque complète (Foley, ambiances, arme, créatures, musique).
"""

from __future__ import annotations

import argparse
import sys
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dsp  # noqa: E402  (import après avoir complété le chemin de recherche)

REPO_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = REPO_ROOT / "assets" / "audio" / "generated"


@dataclass
class SoundSpec:
    name: str
    category: str
    loop: bool
    description: str
    build: Callable[[np.random.Generator], np.ndarray]


SOUNDS: dict[str, SoundSpec] = {}


def sound(name: str, category: str, loop: bool = False, description: str = ""):
    """Décorateur : enregistre une fonction de synthèse dans le catalogue."""
    def register(build: Callable[[np.random.Generator], np.ndarray]):
        SOUNDS[name] = SoundSpec(name, category, loop, description, build)
        return build
    return register


# =============================================================================
# Sons de test (J1)
# =============================================================================

@sound("ui_confirm", "ui", description="Validation dans un menu : deux notes brèves, douces.")
def ui_confirm(rng: np.random.Generator) -> np.ndarray:
    # --- Paramètres ---
    note_1_hz, note_2_hz = 660.0, 990.0   # quinte ascendante = « oui »
    note_length = 0.07                    # secondes par note
    tail = 0.12                           # queue de résonance
    # ------------------
    def blip(freq: float) -> np.ndarray:
        d = note_length + tail
        tone = dsp.sine(freq, d) + 0.25 * dsp.sine(freq * 2, d) + 0.1 * dsp.sine(freq * 3, d)
        return tone * dsp.adsr(d, 0.004, note_length, 0.3, tail) * dsp.exp_decay(d, 0.35)
    first = blip(note_1_hz)
    second = blip(note_2_hz)
    gap = dsp.n_samples(note_length)
    out = dsp.mix(first, np.concatenate([np.zeros(gap), second]))
    return dsp.fade(dsp.normalize(out, 0.6))


@sound("test_impact", "sfx",
       description="Choc métallique : transitoire bruité + résonances. Idéal pour entendre la réverbération.")
def test_impact(rng: np.random.Generator) -> np.ndarray:
    # --- Paramètres ---
    duration = 1.6
    # (fréquence Hz, amplitude, déclin s) : fréquences non harmoniques = métal
    modes = [(182, 1.0, 1.1), (431, 0.7, 0.8), (887, 0.45, 0.5), (1523, 0.3, 0.3), (2710, 0.18, 0.15)]
    transient_ms = 6.0                    # durée du « clac » initial
    # ------------------
    body = dsp.modal_body(duration, modes)
    click = dsp.highpass(dsp.white_noise(duration, rng), 1500) * dsp.exp_decay(duration, transient_ms / 1000 * 4)
    out = 0.8 * body + 0.9 * click
    return dsp.fade(dsp.normalize(out, 0.9), 0.0005, 0.05)


@sound("portal_hum_loop", "ambience", loop=True,
       description="Bourdonnement du portail (boucle de 8 s) : drone grave, battements, crépitements.")
def portal_hum_loop(rng: np.random.Generator) -> np.ndarray:
    # --- Paramètres ---
    loop_length = 8.0                     # durée de la boucle finale (s)
    crossfade = 0.5                       # fondu de raccord (s)
    base_hz = 55.0                        # note fondamentale (La grave)
    detune_hz = 0.37                      # léger désaccord -> battements lents
    drone_cutoff = 420.0                  # filtre du drone (Hz)
    crackle_density = 9.0                 # crépitements par seconde
    # ------------------
    d = loop_length + crossfade
    t = dsp.time_axis(d)
    drone = dsp.saw(base_hz, d) + dsp.saw(base_hz + detune_hz, d) + 0.5 * dsp.saw(base_hz * 2 - detune_hz, d)
    drone = dsp.lowpass(drone, drone_cutoff, order=4)
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * t / 4.0)          # respiration toutes les 4 s
    harmonic = dsp.sine(base_hz * 3, d) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 2.0 + 1.0))
    shimmer = dsp.bandpass(dsp.pink_noise(d, rng), 2200, 4200) * (0.4 + 0.6 * np.sin(2 * np.pi * t / 8.0) ** 2)
    sparks = dsp.bandpass(dsp.crackle(d, rng, crackle_density), 1500, 7000, order=1)
    out = dsp.normalize(drone) * swell * 0.7 + 0.12 * harmonic + 0.08 * dsp.normalize(shimmer) \
        + 0.35 * dsp.normalize(sparks)
    return dsp.normalize(dsp.make_seamless_loop(out, crossfade), 0.7)


# =============================================================================
# Programme principal
# =============================================================================

def main() -> int:
    parser = argparse.ArgumentParser(description="Génère les sons procéduraux de PARADOXE.")
    parser.add_argument("names", nargs="*", help="sons à générer (par défaut : tous)")
    parser.add_argument("--list", action="store_true", help="affiche le catalogue et quitte")
    parser.add_argument("--seed", type=int, default=0, help="graine du hasard (défaut 0)")
    parser.add_argument("--out", type=Path, default=OUTPUT_DIR, help="dossier de sortie")
    args = parser.parse_args()

    if args.list:
        for spec in SOUNDS.values():
            print(f"{spec.category:<10} {spec.name:<22} {'(boucle) ' if spec.loop else ''}{spec.description}")
        return 0

    unknown = [n for n in args.names if n not in SOUNDS]
    if unknown:
        print(f"Sons inconnus : {', '.join(unknown)} (voir --list)", file=sys.stderr)
        return 1

    for spec in (SOUNDS[n] for n in args.names) if args.names else SOUNDS.values():
        # Graine propre à chaque son : ajouter un son ne change pas les autres.
        rng = np.random.default_rng(zlib.crc32(spec.name.encode()) + args.seed)
        samples = spec.build(rng)
        if not np.all(np.isfinite(samples)):
            print(f"ERREUR : {spec.name} contient des valeurs invalides", file=sys.stderr)
            return 1
        path = args.out / spec.category / f"{spec.name}.wav"
        dsp.write_wav(path, samples, loop=spec.loop)
        print(f"{path.relative_to(REPO_ROOT) if path.is_relative_to(REPO_ROOT) else path}"
              f"  {len(samples) / dsp.SAMPLE_RATE:5.2f} s{'  boucle' if spec.loop else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
