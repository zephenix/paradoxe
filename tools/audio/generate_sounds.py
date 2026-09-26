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
J3 : sons provisoires du combat (arme, bouclier, impacts, voix des Sentinelles).
J4 : sons du rembobinage.
J5 : Foley par surface, respiration, ambiances de zone, sons d'interface.
J5 : bibliothèque complète (Foley, ambiances, arme, créatures, musique).
"""

from __future__ import annotations

import argparse
import json
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
# Combat provisoire (J3) — arme, bouclier, impacts, voix des Sentinelles
# =============================================================================

def _zap(rng: np.random.Generator, duration: float, f_start: float, f_end: float,
         curve: float, noise_amount: float, thump_hz: float) -> np.ndarray:
    """Décharge d'énergie : une fréquence qui plonge très vite (le « piou »),
    un souffle d'étincelles au départ et un petit coup grave (le recul)."""
    sweep = dsp.ramp(duration, f_start, f_end, curve)
    tone = dsp.sine(sweep, duration) + 0.35 * dsp.saw(sweep * 0.5, duration)
    tone *= dsp.exp_decay(duration, duration * 0.9)
    burst = dsp.highpass(dsp.white_noise(duration, rng), 2500) * dsp.exp_decay(duration, 0.04) * noise_amount
    thump = dsp.sine(thump_hz, duration) * dsp.exp_decay(duration, 0.08)
    return dsp.fade(dsp.normalize(0.8 * tone + burst + 0.6 * thump, 0.9), 0.0005, 0.02)


@sound("weapon_shot", "combat", description="Tir du pistolet d'Élias : décharge brève et claire (provisoire J3).")
def weapon_shot(rng: np.random.Generator) -> np.ndarray:
    # --- Paramètres ---
    duration = 0.22
    f_start, f_end = 2600.0, 260.0        # la fréquence plonge : c'est le « piou »
    # ------------------
    return _zap(rng, duration, f_start, f_end, 0.35, 0.7, 110.0)


@sound("weapon_shot_charged", "combat", description="Tir chargé : décharge lourde, grave, avec crépitements (provisoire J3).")
def weapon_shot_charged(rng: np.random.Generator) -> np.ndarray:
    # --- Paramètres ---
    duration = 0.7
    f_start, f_end = 1900.0, 90.0
    # ------------------
    core = _zap(rng, duration, f_start, f_end, 0.5, 1.0, 55.0)
    sparks = dsp.bandpass(dsp.crackle(duration, rng, 140.0), 1500, 9000, order=1) * dsp.exp_decay(duration, 0.5)
    sub = dsp.sine(dsp.ramp(duration, 90.0, 40.0), duration) * dsp.exp_decay(duration, 0.4)
    return dsp.fade(dsp.normalize(core + 0.5 * dsp.normalize(sparks) + 0.6 * sub, 0.95), 0.0005, 0.05)


@sound("weapon_shot_sentinel", "combat",
       description="Tir des Sentinelles : plus grave et bourdonnant, pour le distinguer du nôtre (provisoire J3).")
def weapon_shot_sentinel(rng: np.random.Generator) -> np.ndarray:
    # --- Paramètres ---
    duration = 0.32
    f_start, f_end = 950.0, 180.0
    vibrato_hz = 38.0                     # « grain » organique : la fréquence tremble vite
    # ------------------
    t = dsp.time_axis(duration)
    sweep = dsp.ramp(duration, f_start, f_end, 0.6) * (1.0 + 0.06 * np.sin(2 * np.pi * vibrato_hz * t))
    buzz = dsp.lowpass(dsp.square(sweep, duration, 0.3), 3500) * dsp.exp_decay(duration, 0.28)
    burst = dsp.bandpass(dsp.white_noise(duration, rng), 800, 5000) * dsp.exp_decay(duration, 0.05)
    thump = dsp.sine(80.0, duration) * dsp.exp_decay(duration, 0.1)
    return dsp.fade(dsp.normalize(buzz + 0.6 * burst + 0.7 * thump, 0.9), 0.0005, 0.03)


@sound("weapon_charge", "combat", description="Charge du tir : tension qui monte pendant 0,8 s (provisoire J3).")
def weapon_charge(rng: np.random.Generator) -> np.ndarray:
    # --- Paramètres ---
    duration = 0.8                        # = temps de charge du pistolet (pistol.tres)
    f_start, f_end = 180.0, 1400.0
    # ------------------
    t = dsp.time_axis(duration)
    sweep = dsp.ramp(duration, f_start, f_end, 1.6)
    tremolo = 0.6 + 0.4 * np.sin(2 * np.pi * dsp.ramp(duration, 6.0, 28.0) * t)
    tone = (dsp.saw(sweep, duration) + 0.5 * dsp.sine(sweep * 2.0, duration)) * tremolo
    hiss = dsp.bandpass(dsp.white_noise(duration, rng), 3000, 9000) * dsp.ramp(duration, 0.0, 0.4, 2.0)
    env = dsp.ramp(duration, 0.2, 1.0, 1.3)
    return dsp.fade(dsp.normalize(dsp.lowpass(tone, 4000) * env + hiss, 0.7), 0.01, 0.02)


@sound("weapon_charge_ready", "combat", description="Charge complète : tintement bref (provisoire J3).")
def weapon_charge_ready(rng: np.random.Generator) -> np.ndarray:
    duration = 0.35
    ping = dsp.sine(1760.0, duration) + 0.6 * dsp.sine(2640.0, duration) + 0.2 * dsp.sine(3520.0, duration)
    return dsp.fade(dsp.normalize(ping * dsp.exp_decay(duration, 0.3), 0.5))


@sound("weapon_empty", "combat", description="Clic à vide : plus d'énergie, rien ne part (provisoire J3).")
def weapon_empty(rng: np.random.Generator) -> np.ndarray:
    duration = 0.12
    def click(delay: float) -> np.ndarray:
        body = dsp.modal_body(duration, [(2350, 1.0, 0.03), (3900, 0.6, 0.02), (5200, 0.3, 0.015)])
        tick = dsp.highpass(dsp.white_noise(duration, rng), 4000) * dsp.exp_decay(duration, 0.008)
        return np.concatenate([np.zeros(dsp.n_samples(delay)), body + tick])
    return dsp.fade(dsp.normalize(dsp.mix(click(0.0), 0.6 * click(0.035)), 0.6), 0.0005, 0.02)


@sound("weapon_draw", "combat", description="Dégainer : frottement de tissu et déclic métallique (provisoire J3).")
def weapon_draw(rng: np.random.Generator) -> np.ndarray:
    duration = 0.25
    swish = dsp.bandpass(dsp.pink_noise(duration, rng), 1200, 6000) * dsp.adsr(duration, 0.03, 0.05, 0.3, 0.1)
    clack = np.concatenate([np.zeros(dsp.n_samples(0.1)),
                            dsp.modal_body(0.15, [(1800, 1.0, 0.04), (3100, 0.5, 0.03)])])
    return dsp.fade(dsp.normalize(dsp.mix(0.6 * swish, clack), 0.6))


def _shield_hum(rng: np.random.Generator, duration: float) -> np.ndarray:
    """Grésillement d'un mur d'énergie : bourdonnement grave + crépitements."""
    t = dsp.time_axis(duration)
    hum = dsp.saw(110.0, duration) + dsp.saw(110.7, duration) + 0.5 * dsp.saw(221.0, duration)
    hum = dsp.lowpass(hum, 900, order=4) * (0.8 + 0.2 * np.sin(2 * np.pi * 3.0 * t))
    fizz = dsp.bandpass(dsp.crackle(duration, rng, 60.0), 2000, 8000, order=1)
    return dsp.normalize(hum) * 0.7 + 0.4 * dsp.normalize(fizz)


@sound("shield_loop", "combat", loop=True, description="Bouclier levé : grésillement continu (boucle, provisoire J3).")
def shield_loop(rng: np.random.Generator) -> np.ndarray:
    # --- Paramètres ---
    loop_length = 2.0
    crossfade = 0.25
    # ------------------
    return dsp.normalize(dsp.make_seamless_loop(_shield_hum(rng, loop_length + crossfade), crossfade), 0.6)


@sound("shield_up", "combat", description="Le bouclier s'allume : montée brève (provisoire J3).")
def shield_up(rng: np.random.Generator) -> np.ndarray:
    duration = 0.25
    rise = dsp.sine(dsp.ramp(duration, 200.0, 900.0, 0.6), duration) * dsp.adsr(duration, 0.02, 0.1, 0.5, 0.12)
    return dsp.fade(dsp.normalize(rise + 0.5 * _shield_hum(rng, duration) * dsp.ramp(duration, 0.0, 1.0), 0.6))


@sound("shield_down", "combat", description="Le bouclier s'éteint : descente brève (provisoire J3).")
def shield_down(rng: np.random.Generator) -> np.ndarray:
    duration = 0.25
    fall = dsp.sine(dsp.ramp(duration, 800.0, 150.0, 0.6), duration) * dsp.exp_decay(duration, 0.2)
    return dsp.fade(dsp.normalize(fall + 0.4 * _shield_hum(rng, duration) * dsp.ramp(duration, 1.0, 0.0), 0.5))


@sound("shield_hit", "combat", description="Tir arrêté par un bouclier : claquement électrique (provisoire J3).")
def shield_hit(rng: np.random.Generator) -> np.ndarray:
    duration = 0.35
    zap = dsp.bandpass(dsp.white_noise(duration, rng), 1500, 7000) * dsp.exp_decay(duration, 0.08)
    ring = dsp.modal_body(duration, [(660, 1.0, 0.25), (1570, 0.6, 0.15), (2890, 0.3, 0.08)])
    sparks = dsp.bandpass(dsp.crackle(duration, rng, 200.0), 3000, 9000, order=1) * dsp.exp_decay(duration, 0.2)
    return dsp.fade(dsp.normalize(zap + 0.5 * ring + 0.4 * dsp.normalize(sparks), 0.85), 0.0005, 0.03)


@sound("shield_break", "combat", description="Bouclier brisé par un tir chargé : éclatement (provisoire J3).")
def shield_break(rng: np.random.Generator) -> np.ndarray:
    duration = 0.9
    shatter = dsp.bandpass(dsp.crackle(duration, rng, 900.0), 2000, 12000, order=1) * dsp.exp_decay(duration, 0.5)
    fall = dsp.saw(dsp.ramp(duration, 700.0, 60.0, 0.5), duration) * dsp.exp_decay(duration, 0.6)
    boom = dsp.sine(55.0, duration) * dsp.exp_decay(duration, 0.3)
    return dsp.fade(dsp.normalize(dsp.normalize(shatter) + 0.5 * dsp.lowpass(fall, 2500) + 0.7 * boom, 0.95),
                    0.0005, 0.08)


@sound("impact_wall", "combat", description="Tir qui frappe le décor : choc et grésillement (provisoire J3).")
def impact_wall(rng: np.random.Generator) -> np.ndarray:
    duration = 0.3
    hit = _thump(rng, duration, 140.0, 0.06, 3000.0, 0.8)
    sizzle = dsp.bandpass(dsp.white_noise(duration, rng), 3000, 9000) * dsp.exp_decay(duration, 0.2) * 0.4
    return dsp.fade(dsp.normalize(hit + sizzle, 0.8), 0.0005, 0.03)


@sound("impact_body", "combat", description="Tir qui touche un corps : coup sourd (provisoire J3).")
def impact_body(rng: np.random.Generator) -> np.ndarray:
    duration = 0.35
    thud = dsp.lowpass(_thump(rng, duration, 70.0, 0.15, 700.0, 0.2), 1200)
    sizzle = dsp.bandpass(dsp.white_noise(duration, rng), 2000, 6000) * dsp.exp_decay(duration, 0.12) * 0.25
    return dsp.fade(dsp.normalize(thud + sizzle, 0.9), 0.0005, 0.03)


# Voix des Sentinelles : aucune langue réelle. Une « glotte » (dent de scie
# dont la hauteur varie) passe dans des résonateurs placés sur les formants
# d'une voyelle. L'INTONATION porte l'émotion (PLAN §6.6).
VOWELS = {  # formants (Hz) des voyelles, voix grave
    "a": (730, 1090, 2440), "o": (500, 850, 2400), "u": (340, 870, 2240),
    "e": (480, 1720, 2520), "i": (300, 2100, 2900),
}


def _syllable(rng: np.random.Generator, duration: float, f0_start: float, f0_end: float,
              vowel: str, rasp: float = 0.2) -> np.ndarray:
    t = dsp.time_axis(duration)
    f0 = dsp.ramp(duration, f0_start, f0_end) * (1.0 + 0.015 * np.sin(2 * np.pi * 5.5 * t))
    source = dsp.saw(f0, duration) + rasp * dsp.white_noise(duration, rng)
    f1, f2, f3 = VOWELS[vowel]
    voiced = dsp.resonator(source, f1, 6.0) + 0.7 * dsp.resonator(source, f2, 9.0) + 0.3 * dsp.resonator(source, f3, 12.0)
    return dsp.normalize(voiced) * dsp.adsr(duration, 0.03, 0.05, 0.8, duration * 0.35)


def _phrase(rng: np.random.Generator, syllables: list[tuple[float, float, float, str, float]],
            gap: float = 0.04) -> np.ndarray:
    """Enchaîne des syllabes (durée, hauteur départ, hauteur fin, voyelle, raucité)."""
    parts = []
    for duration, f_a, f_b, vowel, rasp in syllables:
        parts.append(_syllable(rng, duration, f_a, f_b, vowel, rasp))
        parts.append(np.zeros(dsp.n_samples(gap)))
    return dsp.fade(dsp.normalize(np.concatenate(parts), 0.8), 0.005, 0.05)


@sound("creature_calm", "creature", description="Sentinelle calme : deux syllabes descendantes (provisoire J3).")
def creature_calm(rng: np.random.Generator) -> np.ndarray:
    return _phrase(rng, [(0.22, 120, 105, "o", 0.1), (0.3, 110, 85, "u", 0.1)])


@sound("creature_curious", "creature", description="Sentinelle intriguée : intonation montante (provisoire J3).")
def creature_curious(rng: np.random.Generator) -> np.ndarray:
    return _phrase(rng, [(0.16, 110, 118, "e", 0.15), (0.34, 115, 190, "a", 0.15)], gap=0.06)


@sound("creature_alert", "creature", description="Sentinelle en alerte : aiguë et hachée (provisoire J3).")
def creature_alert(rng: np.random.Generator) -> np.ndarray:
    return _phrase(rng, [(0.09, 210, 240, "a", 0.3), (0.09, 230, 250, "a", 0.3),
                         (0.2, 250, 200, "i", 0.35)], gap=0.025)


@sound("creature_search", "creature", description="Sentinelle qui cherche : grognement grave, interrogatif (provisoire J3).")
def creature_search(rng: np.random.Generator) -> np.ndarray:
    return _phrase(rng, [(0.35, 90, 100, "u", 0.25), (0.25, 95, 120, "o", 0.2)], gap=0.1)


@sound("creature_death", "creature", description="Sentinelle touchée : cri qui retombe (provisoire J3).")
def creature_death(rng: np.random.Generator) -> np.ndarray:
    return _phrase(rng, [(0.12, 260, 300, "a", 0.4), (0.55, 280, 90, "o", 0.5)], gap=0.0)


@sound("checkpoint_on", "sfx", description="Checkpoint atteint : trois notes douces qui montent (provisoire J3).")
def checkpoint_on(rng: np.random.Generator) -> np.ndarray:
    notes = [523.25, 659.25, 783.99]      # do, mi, sol : accord majeur = « rassurant »
    step = 0.09
    tail = 0.6
    out = np.zeros(dsp.n_samples(step * len(notes) + tail))
    for i, freq in enumerate(notes):
        d = tail + step * (len(notes) - i)
        tone = (dsp.sine(freq, d) + 0.3 * dsp.sine(freq * 2, d)) * dsp.adsr(d, 0.005, 0.05, 0.4, d * 0.8)
        start = dsp.n_samples(step * i)
        out[start:start + len(tone)] += tone[: len(out) - start]
    return dsp.fade(dsp.normalize(out, 0.5))


# =============================================================================
# Rembobinage (J4)
# =============================================================================

@sound("rewind_loop", "sfx", loop=True,
       description="Défilement arrière du temps : souffles inversés et sifflement de bande qui ondule (boucle, provisoire J4).")
def rewind_loop(rng: np.random.Generator) -> np.ndarray:
    # --- Paramètres ---
    loop_length = 2.0
    crossfade = 0.3
    swell_rate = 4.0                      # souffles « à l'envers » par seconde
    whirr_hz = 520.0                      # sifflement de bande
    # ------------------
    d = loop_length + crossfade
    t = dsp.time_axis(d)
    # Un souffle qui décline, joué à l'envers, devient une « aspiration » qui monte.
    swell = np.zeros(dsp.n_samples(d))
    step = dsp.n_samples(1.0 / swell_rate)
    for start in range(0, len(swell), step):
        burst = dsp.reverse(dsp.bandpass(dsp.pink_noise(1.0 / swell_rate, rng), 300, 5000)
                            * dsp.exp_decay(1.0 / swell_rate, 0.2))
        swell[start:start + len(burst)] += burst[: len(swell) - start]
    wobble = whirr_hz * (1.0 + 0.08 * np.sin(2 * np.pi * 7.0 * t))
    whirr = dsp.sine(wobble, d) * 0.25 + 0.1 * dsp.sine(wobble * 1.5, d)
    out = 0.8 * dsp.normalize(swell) + whirr
    return dsp.normalize(dsp.make_seamless_loop(out, crossfade), 0.6)


@sound("rewind_release", "sfx", description="Reprise après un rembobinage : souffle vers l'avant et coup sourd (provisoire J4).")
def rewind_release(rng: np.random.Generator) -> np.ndarray:
    d = 0.6
    whoosh = dsp.bandpass(dsp.pink_noise(d, rng), 400, 6000) * dsp.adsr(d, 0.01, 0.1, 0.4, 0.4)
    drop = dsp.sine(dsp.ramp(d, 900.0, 120.0, 0.5), d) * dsp.exp_decay(d, 0.4) * 0.5
    thump = dsp.sine(60.0, d) * dsp.exp_decay(d, 0.2)
    return dsp.fade(dsp.normalize(whoosh + drop + 0.7 * thump, 0.8), 0.002, 0.05)


# =============================================================================
# Foley complet (J5) : pas selon la surface, respiration, petits gestes
# =============================================================================

def _step_metal(rng: np.random.Generator, i: int) -> np.ndarray:
    # --- Paramètres ---
    duration = 0.35
    modes = [(310 + 23 * i, 0.8, 0.18), (870 + 41 * i, 0.5, 0.12), (1930 + 67 * i, 0.3, 0.07)]
    # ------------------
    heel = _thump(rng, duration, 110.0 + 8 * i, 0.05, 2500.0, 0.3)
    ring = dsp.modal_body(duration, modes)          # la tôle résonne un peu
    return dsp.fade(dsp.normalize(heel + 0.35 * ring, 0.9), 0.001, 0.03)


def _step_plant(rng: np.random.Generator, i: int) -> np.ndarray:
    # --- Paramètres ---
    duration = 0.4
    # ------------------
    soft = _thump(rng, duration, 80.0 + 6 * i, 0.06, 900.0, 0.1) * 0.6
    leaves = dsp.bandpass(dsp.crackle(duration, rng, 260.0 + 30 * i), 1500, 7000, order=1)
    leaves *= dsp.adsr(duration, 0.01, 0.08, 0.3, 0.2)
    swish = dsp.bandpass(dsp.pink_noise(duration, rng), 800, 4000) * dsp.adsr(duration, 0.02, 0.1, 0.2, 0.15) * 0.5
    return dsp.fade(dsp.normalize(soft + 0.8 * dsp.normalize(leaves) + swish, 0.8), 0.002, 0.04)


def _step_water(rng: np.random.Generator, i: int) -> np.ndarray:
    # --- Paramètres ---
    duration = 0.45
    # ------------------
    splash = dsp.bandpass(dsp.white_noise(duration, rng), 600, 5000) * dsp.exp_decay(duration, 0.18)
    bubbles = np.zeros(dsp.n_samples(duration))
    for k in range(3 + i % 2):                       # quelques « plocs » : petites bulles
        start = dsp.n_samples(0.02 + 0.05 * k + 0.01 * rng.uniform())
        d = 0.08
        f = rng.uniform(500, 1100)
        blip = dsp.sine(dsp.ramp(d, f, f * 1.8), d) * dsp.exp_decay(d, 0.06)
        bubbles[start:start + len(blip)] += blip[: len(bubbles) - start]
    thud = _thump(rng, duration, 70.0, 0.05, 700.0, 0.0) * 0.4
    return dsp.fade(dsp.normalize(splash + 0.4 * bubbles + thud, 0.8), 0.002, 0.05)


def _register_surface_steps() -> None:
    makers = {"metal": _step_metal, "plant": _step_plant, "water": _step_water}
    labels = {"metal": "métal", "plant": "végétation", "water": "eau"}
    for surface, maker in makers.items():
        for i in range(1, 5):
            def build(rng: np.random.Generator, i: int = i, maker=maker) -> np.ndarray:
                return maker(rng, i)
            sound(f"foley_step_{surface}_{i:02d}", "foley",
                  description=f"Pas sur {labels[surface]}, variante {i} (J5).")(build)


_register_surface_steps()


def _breath(rng: np.random.Generator, inhale: float, exhale: float, gap: float, loud: float,
            low: float, high: float) -> np.ndarray:
    """Une respiration : souffle filtré (inspiration puis expiration)."""
    def puff(d: float, lo: float, hi: float, level: float) -> np.ndarray:
        return dsp.bandpass(dsp.pink_noise(d, rng), lo, hi) * dsp.adsr(d, d * 0.3, d * 0.2, 0.7, d * 0.4) * level
    a = puff(inhale, low * 1.2, high * 1.3, 0.6)
    b = puff(exhale, low, high, 1.0)
    out = np.concatenate([a, np.zeros(dsp.n_samples(gap)), b])
    return dsp.fade(dsp.normalize(out, loud), 0.01, 0.05)


def _register_breaths() -> None:
    # (nom, inspiration s, expiration s, pause s, volume, bande grave, bande aiguë)
    table = [
        ("breath_calm", 0.7, 0.9, 0.15, 0.35, 250, 1800, "Respiration calme"),
        ("breath_effort", 0.35, 0.45, 0.05, 0.55, 300, 2600, "Respiration d'effort (après une course)"),
        ("breath_exhausted", 0.22, 0.3, 0.03, 0.7, 350, 3200, "Essoufflement (effort prolongé)"),
    ]
    for name, inhale, exhale, gap, loud, lo, hi, label in table:
        for i in range(1, 3):
            def build(rng: np.random.Generator, a=inhale, b=exhale, g=gap, l=loud, lo=lo, hi=hi, i=i) -> np.ndarray:
                k = 1.0 + 0.08 * (i - 1)
                return _breath(rng, a * k, b * k, g, l, lo, hi)
            sound(f"{name}_{i:02d}", "voice", description=f"{label}, variante {i} (J5).")(build)


_register_breaths()


@sound("foley_turn", "foley", description="Demi-tour : bref froissement de la blouse (J5).")
def foley_turn(rng: np.random.Generator) -> np.ndarray:
    d = 0.2
    swish = dsp.bandpass(dsp.pink_noise(d, rng), 1500, 6000) * dsp.adsr(d, 0.04, 0.05, 0.3, 0.1)
    return dsp.fade(dsp.normalize(swish, 0.4))


@sound("foley_crouch", "foley", description="S'accroupir : tissu et genou qui se plie (J5).")
def foley_crouch(rng: np.random.Generator) -> np.ndarray:
    d = 0.3
    cloth = dsp.bandpass(dsp.pink_noise(d, rng), 700, 4500) * dsp.adsr(d, 0.03, 0.1, 0.3, 0.15)
    knee = np.concatenate([np.zeros(dsp.n_samples(0.1)), _thump(rng, 0.2, 90.0, 0.04, 800.0, 0.1) * 0.4])
    return dsp.fade(dsp.normalize(dsp.mix(cloth, knee), 0.45))


@sound("weapon_holster", "combat", description="Rengainer : déclic puis frottement (J5).")
def weapon_holster(rng: np.random.Generator) -> np.ndarray:
    clack = dsp.modal_body(0.12, [(1600, 1.0, 0.04), (2800, 0.4, 0.03)])
    swish = dsp.bandpass(dsp.pink_noise(0.22, rng), 1000, 5000) * dsp.adsr(0.22, 0.02, 0.05, 0.3, 0.12)
    out = dsp.mix(clack, np.concatenate([np.zeros(dsp.n_samples(0.06)), 0.6 * swish]))
    return dsp.fade(dsp.normalize(out, 0.5))


# =============================================================================
# Ambiances de zone (J5) : boucles longues de durées différentes + événements
# =============================================================================
# Plusieurs boucles de durées différentes (11, 13, 17 s…) jouées ensemble ne
# retombent en phase qu'au bout de très longtemps (11 × 13 × 17 s ≈ 40 min) :
# l'oreille ne repère aucune répétition.

def _loop(out: np.ndarray, crossfade: float, peak: float) -> np.ndarray:
    return dsp.normalize(dsp.make_seamless_loop(out, crossfade), peak)


@sound("amb_wind_loop", "ambience", loop=True, description="Vent dans les ruines : souffle grave qui enfle et retombe (17 s, J5).")
def amb_wind_loop(rng: np.random.Generator) -> np.ndarray:
    d = 17.0 + 1.0
    t = dsp.time_axis(d)
    gusts = 0.55 + 0.45 * np.sin(2 * np.pi * t / 6.3) * np.sin(2 * np.pi * t / 9.7 + 1.0)
    body = dsp.lowpass(dsp.brown_noise(d, rng), 500) * gusts
    whistle = dsp.bandpass(dsp.pink_noise(d, rng), 900, 1600) * np.clip(gusts - 0.5, 0, 1) * 0.6
    return _loop(dsp.normalize(body) + whistle, 1.0, 0.6)


@sound("amb_city_loop", "ambience", loop=True, description="Ville morte au loin : rumeur sourde, tintements métalliques rares (13 s, J5).")
def amb_city_loop(rng: np.random.Generator) -> np.ndarray:
    d = 13.0 + 1.0
    rumble = dsp.lowpass(dsp.brown_noise(d, rng), 180)
    ting = dsp.bandpass(dsp.crackle(d, rng, 0.8), 2500, 6000, order=1)
    ting = dsp.lowpass(ting, 5000)
    return _loop(dsp.normalize(rumble) + 0.3 * dsp.normalize(ting), 1.0, 0.5)


@sound("amb_lab_loop", "ambience", loop=True, description="Laboratoire : ventilation et bourdonnement électrique à 50 Hz (13 s, J5).")
def amb_lab_loop(rng: np.random.Generator) -> np.ndarray:
    d = 13.0 + 1.0
    hvac = dsp.lowpass(dsp.pink_noise(d, rng), 900)
    mains = dsp.sine(50.0, d) + 0.5 * dsp.sine(100.0, d) + 0.25 * dsp.sine(150.0, d)
    return _loop(dsp.normalize(hvac) * 0.7 + 0.25 * mains, 1.0, 0.5)


@sound("amb_electric_loop", "ambience", loop=True, description="Grésillement électrique irrégulier (11 s, J5).")
def amb_electric_loop(rng: np.random.Generator) -> np.ndarray:
    d = 11.0 + 1.0
    t = dsp.time_axis(d)
    flicker = (np.sin(2 * np.pi * t * 0.37) > 0.6).astype(float) * 0.8 + 0.2
    fizz = dsp.bandpass(dsp.crackle(d, rng, 90.0), 2500, 9000, order=1) * flicker
    return _loop(dsp.normalize(fizz), 1.0, 0.35)


@sound("amb_shaft_loop", "ambience", loop=True, description="Puits : grondement très grave, air qui circule (13 s, J5).")
def amb_shaft_loop(rng: np.random.Generator) -> np.ndarray:
    d = 13.0 + 1.0
    t = dsp.time_axis(d)
    rumble = dsp.lowpass(dsp.brown_noise(d, rng), 120) * (0.8 + 0.2 * np.sin(2 * np.pi * t / 5.1))
    air = dsp.bandpass(dsp.pink_noise(d, rng), 200, 700) * 0.3
    return _loop(dsp.normalize(rumble) + air, 1.0, 0.6)


@sound("amb_hall_loop", "ambience", loop=True, description="Grand hall : présence de la pièce et machinerie lointaine (17 s, J5).")
def amb_hall_loop(rng: np.random.Generator) -> np.ndarray:
    d = 17.0 + 1.0
    t = dsp.time_axis(d)
    tone = dsp.lowpass(dsp.pink_noise(d, rng), 400) * 0.6
    machine = dsp.saw(38.0, d) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 4.25))
    machine = dsp.lowpass(machine, 250)
    return _loop(dsp.normalize(tone) + 0.35 * dsp.normalize(machine), 1.0, 0.5)


def _register_ambience_events() -> None:
    def drip(rng: np.random.Generator, i: int) -> np.ndarray:
        d = 0.35
        f = 900.0 + 250.0 * i
        blip = dsp.sine(dsp.ramp(d, f, f * 1.6, 0.3), d) * dsp.exp_decay(d, 0.08)
        tick = dsp.highpass(dsp.white_noise(d, rng), 3000) * dsp.exp_decay(d, 0.005) * 0.3
        return dsp.fade(dsp.normalize(blip + tick, 0.6), 0.0005, 0.05)

    def creak(rng: np.random.Generator, i: int) -> np.ndarray:
        d = 1.2 + 0.3 * i
        t = dsp.time_axis(d)
        f = 140.0 + 40 * i + 25 * np.sin(2 * np.pi * t * (1.3 + 0.4 * i))
        groan = dsp.bandpass(dsp.saw(f, d), 150, 1800) * dsp.adsr(d, 0.2, 0.2, 0.7, 0.5)
        return dsp.fade(dsp.normalize(groan, 0.5), 0.05, 0.2)

    def debris(rng: np.random.Generator, i: int) -> np.ndarray:
        d = 1.0
        out = np.zeros(dsp.n_samples(d))
        for k in range(5 + i):
            start = dsp.n_samples(rng.uniform(0.0, 0.6))
            hit = _thump(rng, 0.25, rng.uniform(150, 400), 0.04, 3000.0, 0.8) * rng.uniform(0.3, 1.0)
            out[start:start + len(hit)] += hit[: len(out) - start]
        return dsp.fade(dsp.normalize(out, 0.5), 0.001, 0.1)

    def buzz(rng: np.random.Generator, i: int) -> np.ndarray:
        d = 0.6 + 0.2 * i
        zap = dsp.lowpass(dsp.square(120.0 + 60 * i, d, 0.2), 3000) * dsp.adsr(d, 0.01, 0.05, 0.7, 0.1)
        fizz = dsp.bandpass(dsp.crackle(d, rng, 300.0), 3000, 9000, order=1)
        return dsp.fade(dsp.normalize(0.5 * zap + dsp.normalize(fizz), 0.4))

    def cry(rng: np.random.Generator, i: int) -> np.ndarray:
        # Cri d'animal lointain (faune inconnue) : glissando nasal, très filtré.
        d = 1.1
        f = dsp.ramp(d, 700.0 + 150 * i, 380.0 + 80 * i, 0.7)
        voice = dsp.saw(f, d) * dsp.adsr(d, 0.08, 0.2, 0.6, 0.5)
        voice = dsp.resonator(voice, 1200.0 + 200 * i, 5.0)
        return dsp.fade(dsp.normalize(dsp.lowpass(voice, 2500), 0.4), 0.02, 0.2)

    makers = {"amb_drip": (drip, 3, "Goutte qui tombe"), "amb_creak": (creak, 2, "Craquement de structure"),
              "amb_debris": (debris, 2, "Gravats qui roulent"), "amb_buzz": (buzz, 2, "Grésillement de lampe"),
              "amb_cry": (cry, 2, "Cri de faune lointain")}
    for base, (maker, count, label) in makers.items():
        for i in range(1, count + 1):
            def build(rng: np.random.Generator, i: int = i, maker=maker) -> np.ndarray:
                return maker(rng, i)
            sound(f"{base}_{i:02d}", "ambience", description=f"{label}, variante {i} (événement d'ambiance, J5).")(build)


_register_ambience_events()


@sound("ui_move", "ui", description="Déplacement dans un menu : tic bref (J5).")
def ui_move(rng: np.random.Generator) -> np.ndarray:
    d = 0.08
    tick = dsp.sine(1320.0, d) * dsp.exp_decay(d, 0.04)
    return dsp.fade(dsp.normalize(tick, 0.35))


@sound("ui_back", "ui", description="Retour dans un menu : deux notes descendantes (J5).")
def ui_back(rng: np.random.Generator) -> np.ndarray:
    def blip(freq: float) -> np.ndarray:
        d = 0.14
        return dsp.sine(freq, d) * dsp.adsr(d, 0.004, 0.05, 0.3, 0.08)
    out = dsp.mix(blip(880.0), np.concatenate([np.zeros(dsp.n_samples(0.07)), blip(587.0)]))
    return dsp.fade(dsp.normalize(out, 0.5))


# =============================================================================
# Infiltration (J6) : lampe brisée, pierre lancée
# =============================================================================

@sound("lamp_break", "sfx", description="Lampe brisée par un tir : verre qui éclate, grésillement qui meurt (J6).")
def lamp_break(rng: np.random.Generator) -> np.ndarray:
    # --- Paramètres ---
    duration = 0.9
    # ------------------
    pop = _thump(rng, duration, 180.0, 0.03, 4000.0, 0.9) * 0.8          # l'ampoule éclate
    glass = np.zeros(dsp.n_samples(duration))
    for k in range(9):                                                    # éclats de verre qui tintent
        start = dsp.n_samples(rng.uniform(0.0, 0.35))
        d = 0.18
        f = rng.uniform(2600, 6200)
        shard = dsp.modal_body(d, [(f, 1.0, 0.04), (f * 1.47, 0.5, 0.03)]) * rng.uniform(0.2, 0.7)
        glass[start:start + len(shard)] += shard[: len(glass) - start]
    fizz = dsp.bandpass(dsp.crackle(duration, rng, 400.0), 2500, 9000, order=1)
    fizz *= dsp.ramp(duration, 1.0, 0.0, 2.0)                             # le filament grésille et meurt
    out = pop + 0.6 * glass + 0.25 * dsp.normalize(fizz)
    return dsp.fade(dsp.normalize(out, 0.9), 0.0005, 0.1)


@sound("stone_throw", "foley", description="Pierre lancée : bras qui fouette l'air (J6).")
def stone_throw(rng: np.random.Generator) -> np.ndarray:
    d = 0.25
    whoosh = dsp.bandpass(dsp.pink_noise(d, rng), 600, 3500) * dsp.adsr(d, 0.06, 0.06, 0.3, 0.1)
    return dsp.fade(dsp.normalize(whoosh, 0.45))


@sound("stone_pickup", "foley", description="Ramasser des pierres : cailloux qui s'entrechoquent (J6).")
def stone_pickup(rng: np.random.Generator) -> np.ndarray:
    d = 0.3
    out = np.zeros(dsp.n_samples(d))
    for k in range(3):
        start = dsp.n_samples(0.03 + 0.07 * k)
        clack = _thump(rng, 0.12, rng.uniform(900, 1500), 0.015, 6000.0, 0.6)
        out[start:start + len(clack)] += clack[: len(out) - start]
    return dsp.fade(dsp.normalize(out, 0.5))


def _register_stone_impacts() -> None:
    def impact(rng: np.random.Generator, i: int) -> np.ndarray:
        # La pierre frappe le sol, rebondit deux fois (de plus en plus faible), puis roule.
        d = 0.8
        out = np.zeros(dsp.n_samples(d))
        t = 0.0
        for k, level in enumerate((1.0, 0.45, 0.2)):
            hit = _thump(rng, 0.2, 260.0 + 60 * i + 40 * k, 0.03, 5000.0, 0.7) * level
            start = dsp.n_samples(t)
            out[start:start + len(hit)] += hit[: len(out) - start]
            t += 0.14 - 0.03 * k + 0.01 * i
        roll = dsp.bandpass(dsp.crackle(d, rng, 120.0), 1500, 6000, order=1) * dsp.ramp(d, 0.3, 0.0)
        return dsp.fade(dsp.normalize(out + 0.2 * dsp.normalize(roll), 0.9), 0.0005, 0.08)

    for i in range(1, 4):
        def build(rng: np.random.Generator, i: int = i) -> np.ndarray:
            return impact(rng, i)
        sound(f"stone_impact_{i:02d}", "foley",
              description=f"Pierre qui retombe et rebondit, variante {i} (diversion, J6).")(build)


_register_stone_impacts()


# =============================================================================
# Programme principal
# =============================================================================

def write_catalog(out_dir: Path) -> None:
    """Écrit catalog.json : nom, catégorie, boucle et description de chaque son.
    L'outil Godot tools/godot/build_sound_library.gd s'en sert pour remplir la
    bibliothèque de sons (resources/audio/sound_library.tres)."""
    catalog = {spec.name: {"category": spec.category, "loop": spec.loop, "description": spec.description}
               for spec in SOUNDS.values()}
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                                          encoding="utf-8")


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

    write_catalog(args.out)
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
