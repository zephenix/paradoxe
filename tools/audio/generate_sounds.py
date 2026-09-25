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
# Foley provisoire du déplacement (J2) — remplacé par la bibliothèque J5
# =============================================================================

def _thump(rng: np.random.Generator, duration: float, body_hz: float, body_decay: float,
           click_cutoff: float, grit: float) -> np.ndarray:
    """Impact de pas : corps grave amorti + petit claquement filtré + grain."""
    body = dsp.sine(body_hz * rng.uniform(0.9, 1.1), duration) * dsp.exp_decay(duration, body_decay)
    click = dsp.lowpass(dsp.white_noise(duration, rng), click_cutoff) * dsp.exp_decay(duration, 0.03)
    sand = dsp.bandpass(dsp.white_noise(duration, rng), 1500, 6000) * dsp.exp_decay(duration, 0.06) * grit
    return dsp.fade(dsp.normalize(0.7 * body + click + sand, 0.9), 0.001, 0.02)


def _register_step_variants() -> None:
    for i in range(1, 5):
        def build(rng: np.random.Generator, i: int = i) -> np.ndarray:
            # --- Paramètres ---
            duration = 0.22
            body_hz = 95.0 + 12.0 * i      # chaque variante a sa hauteur propre
            # ------------------
            return _thump(rng, duration, body_hz, 0.08, 2200.0, 0.35)
        sound(f"foley_step_stone_{i:02d}", "foley",
              description=f"Pas sur pierre, variante {i} (provisoire J2).")(build)


_register_step_variants()


@sound("foley_land", "foley", description="Réception légère : double impact pieds (provisoire J2).")
def foley_land(rng: np.random.Generator) -> np.ndarray:
    a = _thump(rng, 0.3, 85.0, 0.1, 1800.0, 0.5)
    b = _thump(rng, 0.3, 90.0, 0.1, 1800.0, 0.4)
    return dsp.normalize(dsp.mix(a, np.concatenate([np.zeros(dsp.n_samples(0.035)), 0.8 * b])), 0.9)


@sound("foley_land_heavy", "foley", description="Réception lourde : impact grave + souffle (provisoire J2).")
def foley_land_heavy(rng: np.random.Generator) -> np.ndarray:
    hit = _thump(rng, 0.6, 60.0, 0.22, 1200.0, 0.8)
    grunt = dsp.bandpass(dsp.white_noise(0.6, rng), 300, 1200) * dsp.adsr(0.6, 0.02, 0.1, 0.3, 0.3) * 0.25
    return dsp.normalize(hit + grunt, 0.95)


@sound("foley_jump", "foley", description="Impulsion d'un saut : frottement de tissu rapide (provisoire J2).")
def foley_jump(rng: np.random.Generator) -> np.ndarray:
    d = 0.28
    swish = dsp.bandpass(dsp.pink_noise(d, rng), 900, 5000) * dsp.adsr(d, 0.05, 0.08, 0.4, 0.15)
    push = _thump(rng, d, 80.0, 0.05, 1500.0, 0.2) * 0.6
    return dsp.fade(dsp.normalize(swish + push, 0.7))


@sound("foley_roll", "foley", description="Roulade : frottements de tissu et d'épaule au sol (provisoire J2).")
def foley_roll(rng: np.random.Generator) -> np.ndarray:
    d = 0.55
    t = dsp.time_axis(d)
    rustle = dsp.bandpass(dsp.pink_noise(d, rng), 400, 3500) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t) ** 2)
    rustle *= dsp.adsr(d, 0.03, 0.1, 0.7, 0.2)
    thud = np.concatenate([np.zeros(dsp.n_samples(0.08)), _thump(rng, 0.3, 70.0, 0.1, 900.0, 0.3)])
    return dsp.fade(dsp.normalize(dsp.mix(0.8 * rustle, 0.7 * thud), 0.8))


@sound("foley_slide", "foley", description="Glissade : raclement qui s'éteint (provisoire J2).")
def foley_slide(rng: np.random.Generator) -> np.ndarray:
    d = 0.7
    scrape = dsp.bandpass(dsp.white_noise(d, rng), 600, 4000) * dsp.ramp(d, 1.0, 0.0, 0.7)
    grit = dsp.bandpass(dsp.crackle(d, rng, 120.0), 2000, 8000, order=1) * dsp.ramp(d, 1.0, 0.0, 0.5)
    return dsp.fade(dsp.normalize(scrape + 0.6 * dsp.normalize(grit), 0.7), 0.01, 0.1)


@sound("foley_skid", "foley", description="Dérapage : semelles qui frottent (provisoire J2).")
def foley_skid(rng: np.random.Generator) -> np.ndarray:
    d = 0.32
    squeak = dsp.bandpass(dsp.white_noise(d, rng), 1200, 3500) * dsp.adsr(d, 0.01, 0.1, 0.5, 0.15)
    return dsp.fade(dsp.normalize(squeak, 0.55))


@sound("foley_grab", "foley", description="Mains qui agrippent un rebord (provisoire J2).")
def foley_grab(rng: np.random.Generator) -> np.ndarray:
    d = 0.2
    slap = dsp.bandpass(dsp.white_noise(d, rng), 800, 5000) * dsp.exp_decay(d, 0.04)
    knock = dsp.sine(160.0, d) * dsp.exp_decay(d, 0.05) * 0.5
    return dsp.fade(dsp.normalize(slap + knock, 0.8), 0.0005, 0.02)


@sound("foley_climb", "foley", description="Effort pour se hisser : frottement + souffle (provisoire J2).")
def foley_climb(rng: np.random.Generator) -> np.ndarray:
    d = 0.6
    effort = dsp.bandpass(dsp.white_noise(d, rng), 400, 1600) * dsp.adsr(d, 0.15, 0.2, 0.4, 0.2) * 0.4
    cloth = dsp.bandpass(dsp.pink_noise(d, rng), 1000, 5000) * dsp.adsr(d, 0.05, 0.3, 0.3, 0.2)
    return dsp.fade(dsp.normalize(effort + cloth, 0.6))


@sound("foley_body_fall", "foley", description="Corps qui s'effondre au sol (provisoire J2).")
def foley_body_fall(rng: np.random.Generator) -> np.ndarray:
    first = _thump(rng, 0.5, 55.0, 0.2, 900.0, 0.6)
    second = _thump(rng, 0.4, 70.0, 0.12, 1100.0, 0.4) * 0.6
    return dsp.normalize(dsp.mix(first, np.concatenate([np.zeros(dsp.n_samples(0.12)), second])), 0.95)


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
