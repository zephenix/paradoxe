"""
Sons de la mise en scène de PARADOXE (J8) : la cinématique d'ouverture, le
Traqueur (le prédateur de l'écran 2) et les bruits des écrans 2 à 8.

Même principe que generate_sounds.py : chaque son est une fonction de synthèse
dont les paramètres sont écrits en tête. Ce fichier est chargé par
generate_sounds.py, qui appelle register(sound).
"""

from __future__ import annotations

from typing import Callable

import numpy as np

import dsp


def _loop(out: np.ndarray, crossfade: float, peak: float) -> np.ndarray:
    return dsp.normalize(dsp.make_seamless_loop(out, crossfade), peak)


def _thump(rng: np.random.Generator, duration: float, body_hz: float, body_decay: float,
           noise_cutoff: float, noise_amount: float) -> np.ndarray:
    """Choc sourd : une sinusoïde grave qui s'éteint + un peu de bruit filtré."""
    body = dsp.sine(dsp.ramp(duration, body_hz * 1.4, body_hz, 0.3), duration) * dsp.exp_decay(duration, body_decay)
    noise = dsp.lowpass(dsp.white_noise(duration, rng), noise_cutoff) * dsp.exp_decay(duration, body_decay * 0.4)
    return body + noise_amount * noise


# =============================================================================
# Cinématique d'ouverture
# =============================================================================

def amb_rain_loop(rng: np.random.Generator) -> np.ndarray:
    """Pluie d'orage : un rideau de bruit (le « chhh ») + des gouttes qui claquent."""
    # --- Paramètres ---
    length, crossfade = 12.0, 1.0
    drops_per_second = 350.0
    # ------------------
    d = length + crossfade
    t = dsp.time_axis(d)
    curtain = dsp.bandpass(dsp.pink_noise(d, rng), 700, 7000) * (0.8 + 0.2 * np.sin(2 * np.pi * t / 4.3))
    drops = dsp.highpass(dsp.crackle(d, rng, drops_per_second), 2500) * 0.6
    low = dsp.lowpass(dsp.brown_noise(d, rng), 180) * 0.4
    return _loop(dsp.normalize(curtain) + drops + low, crossfade, 0.7)


def _thunder(rng: np.random.Generator, i: int) -> np.ndarray:
    """Tonnerre lointain : un craquement, puis un grondement qui roule et s'éteint."""
    d = 5.5
    t = dsp.time_axis(d)
    delay = 0.05 + 0.1 * i
    crack = dsp.highpass(dsp.white_noise(d, rng), 900) * dsp.exp_decay(d, 0.25)
    crack = np.concatenate([np.zeros(dsp.n_samples(delay)), crack])[: len(t)]
    rolls = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * t * (0.9 + 0.3 * i)) * np.sin(2 * np.pi * t * 0.37))
    rumble = dsp.lowpass(dsp.brown_noise(d, rng), 160) * dsp.adsr(d, 0.15, 0.5, 0.7, 4.0) * rolls
    return dsp.fade(dsp.normalize(0.35 * crack + rumble, 0.9), 0.002, 0.3)


def sfx_lightning_strike(rng: np.random.Generator) -> np.ndarray:
    """La foudre frappe le bâtiment : claquement énorme, chute d'infra-basse, grondement."""
    d = 5.0
    crack = dsp.white_noise(d, rng) * dsp.exp_decay(d, 0.35)
    sub = dsp.sine(dsp.ramp(d, 70.0, 28.0, 0.4), d) * dsp.exp_decay(d, 2.5)
    rumble = dsp.lowpass(dsp.brown_noise(d, rng), 220) * dsp.adsr(d, 0.05, 0.4, 0.6, 4.0)
    fizz = dsp.bandpass(dsp.crackle(d, rng, 300.0), 1500, 8000) * dsp.exp_decay(d, 1.2) * 0.5
    return dsp.fade(dsp.normalize(0.7 * crack + 0.9 * sub + 0.8 * rumble + fizz, 0.95), 0.0005, 0.3)


def sfx_glider_pass(rng: np.random.Generator) -> np.ndarray:
    """Un glisseur électrique arrive et se pose : le moteur siffle puis décroît."""
    d = 6.0
    whine = dsp.sine(dsp.ramp(d, 1250.0, 480.0, 1.3), d) * 0.25
    motor = dsp.bandpass(dsp.saw(dsp.ramp(d, 190.0, 85.0, 1.2), d), 120, 1500) * 0.6
    air = dsp.bandpass(dsp.pink_noise(d, rng), 300, 2500) * 0.3
    env = dsp.adsr(d, 1.2, 1.0, 0.7, 3.0)
    return dsp.fade(dsp.normalize((whine + motor + air) * env, 0.8), 0.05, 0.3)


def sfx_bio_scan(rng: np.random.Generator) -> np.ndarray:
    """Lecteur biométrique : balayage bref, puis deux bips montants (« accepté »)."""
    d = 0.9
    sweep = dsp.bandpass(dsp.white_noise(0.3, rng), 2000, 5000) * dsp.adsr(0.3, 0.05, 0.1, 0.4, 0.15) * 0.3
    def beep(f: float) -> np.ndarray:
        bd = 0.12
        return (dsp.sine(f, bd) + 0.2 * dsp.square(f, bd)) * dsp.adsr(bd, 0.004, 0.03, 0.6, 0.05)
    out = np.zeros(dsp.n_samples(d))
    out[: len(sweep)] += sweep
    for k, f in enumerate([880.0, 1320.0]):
        s = dsp.n_samples(0.35 + 0.16 * k)
        b = beep(f)
        out[s: s + len(b)] += b
    return dsp.fade(dsp.normalize(out, 0.7))


def sfx_airlock(rng: np.random.Generator) -> np.ndarray:
    """Sas pneumatique : chuintement d'air, glissement, butée sourde."""
    d = 1.8
    hiss = dsp.highpass(dsp.white_noise(d, rng), 2000) * dsp.adsr(d, 0.02, 0.3, 0.35, 1.0) * 0.5
    slide = dsp.bandpass(dsp.pink_noise(d, rng), 200, 900) * dsp.adsr(d, 0.1, 0.6, 0.3, 0.8) * 0.5
    stop = _thump(rng, 0.5, 70.0, 0.15, 900.0, 0.3)
    out = hiss + slide
    s = dsp.n_samples(1.0)
    out[s: s + len(stop)] += stop[: len(out) - s]
    return dsp.fade(dsp.normalize(out, 0.8), 0.003, 0.2)


def _key(rng: np.random.Generator, i: int) -> np.ndarray:
    """Touche de clavier : petit clic plastique."""
    d = 0.09
    click = dsp.bandpass(dsp.white_noise(d, rng), 1500 + 300 * i, 6000) * dsp.exp_decay(d, 0.02)
    body = dsp.modal_body(d, [(420 + 60 * i, 0.5, 0.03), (1900, 0.25, 0.015)])
    return dsp.fade(dsp.normalize(click + body, 0.6), 0.0005, 0.01)


def sfx_terminal_rise(rng: np.random.Generator) -> np.ndarray:
    """Le terminal lance l'expérience : bips de plus en plus aigus et rapprochés."""
    d = 3.2
    out = np.zeros(dsp.n_samples(d))
    t, k = 0.0, 0
    while t < 2.8:
        f = 600.0 * 2 ** (k / 7.0)
        bd = 0.07
        b = dsp.sine(f, bd) * dsp.adsr(bd, 0.003, 0.02, 0.5, 0.03)
        s = dsp.n_samples(t)
        out[s: s + len(b)] += b[: len(out) - s]
        t += max(0.07, 0.32 * 0.85 ** k)
        k += 1
    return dsp.fade(dsp.normalize(out, 0.6))


def sfx_portal_charge(rng: np.random.Generator) -> np.ndarray:
    """L'anneau du portail se charge : un bourdonnement qui monte en tension,
    des arcs électriques de plus en plus nombreux."""
    d = 8.0
    t = dsp.time_axis(d)
    f = dsp.ramp(d, 52.0, 118.0, 1.6)
    hum = dsp.lowpass(dsp.saw(f, d) + 0.5 * dsp.saw(f * 2.01, d), 1400) * dsp.ramp(d, 0.2, 1.0, 1.0)
    whine = dsp.sine(f * 12.0, d) * dsp.ramp(d, 0.0, 0.25, 2.5)
    arcs = dsp.bandpass(dsp.crackle(d, rng, 40.0) * dsp.ramp(d, 0.1, 6.0, 2.0), 1500, 9000)
    wobble = 1.0 + 0.15 * np.sin(2 * np.pi * t * dsp.ramp(d, 3.0, 11.0))
    return dsp.fade(dsp.normalize((dsp.normalize(hum) * wobble + whine + 0.6 * dsp.normalize(arcs)), 0.9), 0.3, 0.01)


def sfx_flash_breath(rng: np.random.Generator) -> np.ndarray:
    """Après le flash : un souffle grave qui s'éloigne, puis rien."""
    d = 6.0
    t = dsp.time_axis(d)
    cutoff = 600.0 * np.exp(-t / 1.5) + 60.0
    noise = dsp.brown_noise(d, rng)
    # Filtre qui se referme : on mélange deux versions filtrées selon le temps.
    bright, dark = dsp.lowpass(noise, 600.0), dsp.lowpass(noise, 70.0)
    k = (cutoff - 60.0) / 600.0
    breath = (k * bright + (1 - k) * dark) * dsp.adsr(d, 0.05, 0.5, 0.6, 5.0)
    sub = dsp.sine(38.0, d) * dsp.exp_decay(d, 4.0) * 0.5
    return dsp.fade(dsp.normalize(breath + sub, 0.8), 0.01, 0.5)


def sfx_paper_fall(rng: np.random.Generator) -> np.ndarray:
    """La photo tombe : un frôlement de papier, puis un petit claquement au sol."""
    d = 1.4
    t = dsp.time_axis(d)
    flutter = dsp.bandpass(dsp.white_noise(d, rng), 1500, 6000) * (0.5 + 0.5 * np.sin(2 * np.pi * 17 * t)) \
        * dsp.adsr(d, 0.2, 0.4, 0.5, 0.4) * 0.3
    tap = dsp.bandpass(dsp.white_noise(0.08, rng), 800, 5000) * dsp.exp_decay(0.08, 0.03)
    s = dsp.n_samples(1.05)
    flutter[s: s + len(tap)] += tap[: len(flutter) - s]
    return dsp.fade(dsp.normalize(flutter, 0.5))


# =============================================================================
# Inscription au catalogue
# =============================================================================

def register(sound: Callable) -> None:
    sound("amb_rain_loop", "ambience", loop=True,
          description="Pluie d'orage : rideau de pluie et gouttes (boucle de 12 s, intro).")(amb_rain_loop)
    for i in range(1, 3):
        def build(rng: np.random.Generator, i: int = i) -> np.ndarray:
            return _thunder(rng, i)
        sound(f"sfx_thunder_{i:02d}", "sfx", description=f"Tonnerre lointain qui roule, variante {i} (intro).")(build)
    sound("sfx_lightning_strike", "sfx", description="La foudre frappe le laboratoire : claquement, infra-basse, grondement (intro, plan 9).")(sfx_lightning_strike)
    sound("sfx_glider_pass", "sfx", description="Glisseur électrique qui arrive et se pose (intro, plan 3).")(sfx_glider_pass)
    sound("sfx_bio_scan", "sfx", description="Lecteur biométrique : balayage et deux bips « accepté » (intro, plan 4).")(sfx_bio_scan)
    sound("sfx_airlock", "sfx", description="Sas pneumatique : air, glissement, butée (intro, plan 4).")(sfx_airlock)
    for i in range(1, 4):
        def build_key(rng: np.random.Generator, i: int = i) -> np.ndarray:
            return _key(rng, i)
        sound(f"sfx_key_{i:02d}", "sfx", description=f"Touche de clavier, variante {i} (intro, plan 7).")(build_key)
    sound("sfx_terminal_rise", "sfx", description="Le terminal lance l'expérience : bips qui montent (intro, plan 7).")(sfx_terminal_rise)
    sound("sfx_portal_charge", "sfx", description="L'anneau se charge : bourdonnement qui monte, arcs (intro, plan 8).")(sfx_portal_charge)
    sound("sfx_flash_breath", "sfx", description="Après le flash : souffle grave qui s'éteint (intro, plan 11).")(sfx_flash_breath)
    sound("sfx_paper_fall", "sfx", description="La photo tombe au sol (intro, plan 11).")(sfx_paper_fall)
