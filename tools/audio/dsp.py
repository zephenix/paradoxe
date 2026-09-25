"""
Boîte à outils de synthèse sonore pour PARADOXE.

Toutes les fonctions travaillent sur des tableaux numpy de nombres réels
compris entre -1.0 et 1.0 (un nombre par échantillon, 44 100 par seconde).

Analogie Excel : un son est une colonne de 44 100 lignes par seconde ;
chaque fonction ci-dessous calcule une nouvelle colonne à partir d'autres
(additionner deux colonnes = mixer deux sons, multiplier par une enveloppe
= faire varier le volume dans le temps, etc.).

Contenu :
  - générateurs : oscillateurs, bruits (blanc, rose, brun), impulsions ;
  - enveloppes : attaque/déclin, ADSR, courbes ;
  - filtres : passe-bas, passe-haut, passe-bande, résonateurs ;
  - outils : normalisation, fondus, bouclage sans couture, inversion ;
  - écriture WAV 16 bits avec points de boucle lisibles par Godot.
"""

from __future__ import annotations

import struct
from pathlib import Path

import numpy as np
from scipy import signal

SAMPLE_RATE = 44_100  # échantillons par seconde (qualité CD)


# ---------------------------------------------------------------------------
# Temps
# ---------------------------------------------------------------------------

def n_samples(duration: float) -> int:
    """Nombre d'échantillons pour une durée en secondes."""
    return max(1, int(round(duration * SAMPLE_RATE)))


def time_axis(duration: float) -> np.ndarray:
    """Colonne des instants (en secondes) : 0, 1/44100, 2/44100…"""
    return np.arange(n_samples(duration)) / SAMPLE_RATE


# ---------------------------------------------------------------------------
# Générateurs
# ---------------------------------------------------------------------------

def sine(freq, duration: float, phase: float = 0.0) -> np.ndarray:
    """Sinusoïde. `freq` peut être un nombre ou une colonne (glissando)."""
    return np.sin(_phase(freq, duration) + phase)


def saw(freq, duration: float) -> np.ndarray:
    """Dent de scie (son riche, « électrique »), version simple."""
    ph = _phase(freq, duration) / (2 * np.pi)
    return 2.0 * (ph - np.floor(ph + 0.5))


def square(freq, duration: float, duty: float = 0.5) -> np.ndarray:
    """Signal carré (son creux, « rétro »)."""
    ph = (_phase(freq, duration) / (2 * np.pi)) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def white_noise(duration: float, rng: np.random.Generator) -> np.ndarray:
    """Bruit blanc : toutes les fréquences à égalité (souffle « chhh »)."""
    return rng.uniform(-1.0, 1.0, n_samples(duration))


def pink_noise(duration: float, rng: np.random.Generator) -> np.ndarray:
    """Bruit rose : plus doux que le blanc (pluie, vent, cascade)."""
    n = n_samples(duration)
    spectrum = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1.0 / SAMPLE_RATE)
    freqs[0] = 1.0
    spectrum /= np.sqrt(freqs)
    return normalize(np.fft.irfft(spectrum, n))


def brown_noise(duration: float, rng: np.random.Generator) -> np.ndarray:
    """Bruit brun : très grave (grondement, rumeur lointaine)."""
    walk = np.cumsum(rng.standard_normal(n_samples(duration)))
    walk = signal.sosfilt(signal.butter(1, 20, "highpass", fs=SAMPLE_RATE, output="sos"), walk)
    return normalize(walk)


def crackle(duration: float, rng: np.random.Generator, density: float = 30.0) -> np.ndarray:
    """Crépitements : impulsions aléatoires (électricité, braises, grésillement).
    `density` = nombre moyen d'impulsions par seconde."""
    n = n_samples(duration)
    out = np.zeros(n)
    count = rng.poisson(density * duration)
    positions = rng.integers(0, n, count)
    out[positions] = rng.uniform(-1.0, 1.0, count)
    return out


def _phase(freq, duration: float) -> np.ndarray:
    """Phase cumulée : permet des fréquences variables sans « clics »."""
    n = n_samples(duration)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return 2 * np.pi * np.cumsum(f) / SAMPLE_RATE


# ---------------------------------------------------------------------------
# Enveloppes (volume qui évolue dans le temps)
# ---------------------------------------------------------------------------

def exp_decay(duration: float, decay_time: float) -> np.ndarray:
    """Déclin exponentiel : le volume est divisé par ~1000 (-60 dB) en `decay_time` s."""
    t = time_axis(duration)
    return np.exp(-6.9 * t / max(decay_time, 1e-4))


def adsr(duration: float, attack: float, decay: float, sustain: float, release: float) -> np.ndarray:
    """Enveloppe classique Attaque / Déclin / Maintien / Relâchement."""
    n = n_samples(duration)
    a, d, r = n_samples(attack), n_samples(decay), n_samples(release)
    s = max(0, n - a - d - r)
    env = np.concatenate([
        np.linspace(0.0, 1.0, a, endpoint=False),
        np.linspace(1.0, sustain, d, endpoint=False),
        np.full(s, sustain),
        np.linspace(sustain, 0.0, r),
    ])
    return _fit(env, n)


def ramp(duration: float, start: float, end: float, curve: float = 1.0) -> np.ndarray:
    """Rampe de `start` à `end`. curve > 1 : lent puis rapide ; < 1 : l'inverse."""
    x = np.linspace(0.0, 1.0, n_samples(duration)) ** curve
    return start + (end - start) * x


def _fit(env: np.ndarray, n: int) -> np.ndarray:
    if len(env) >= n:
        return env[:n]
    return np.pad(env, (0, n - len(env)))


# ---------------------------------------------------------------------------
# Filtres
# ---------------------------------------------------------------------------

def lowpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    """Garde les graves, retire les aigus au-delà de `cutoff` Hz (son étouffé)."""
    sos = signal.butter(order, min(cutoff, SAMPLE_RATE * 0.45), "lowpass", fs=SAMPLE_RATE, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    """Retire les graves sous `cutoff` Hz (son plus léger, plus « fin »)."""
    sos = signal.butter(order, cutoff, "highpass", fs=SAMPLE_RATE, output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x: np.ndarray, low: float, high: float, order: int = 2) -> np.ndarray:
    """Ne garde qu'une bande de fréquences (téléphone, radio, sifflement)."""
    sos = signal.butter(order, [low, min(high, SAMPLE_RATE * 0.45)], "bandpass", fs=SAMPLE_RATE, output="sos")
    return signal.sosfilt(sos, x)


def resonator(x: np.ndarray, freq: float, q: float = 30.0) -> np.ndarray:
    """Fait « chanter » une fréquence précise (corps d'un objet qui résonne)."""
    b, a = signal.iirpeak(freq, q, fs=SAMPLE_RATE)
    return signal.lfilter(b, a, x)


def modal_body(duration: float, modes: list[tuple[float, float, float]]) -> np.ndarray:
    """Synthèse modale : un objet frappé vibre sur plusieurs fréquences propres
    (ses « modes »), chacune s'éteignant à son rythme. Des fréquences non
    multiples les unes des autres donnent un son métallique.
    `modes` = liste de (fréquence Hz, amplitude, durée de déclin s)."""
    out = np.zeros(n_samples(duration))
    for freq, amp, decay in modes:
        out += amp * sine(freq, duration) * exp_decay(duration, decay)
    return out


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

def normalize(x: np.ndarray, peak: float = 0.95) -> np.ndarray:
    """Met le son au volume maximal `peak` (sans saturer)."""
    m = np.max(np.abs(x))
    return x if m < 1e-9 else x * (peak / m)


def fade(x: np.ndarray, fade_in: float = 0.005, fade_out: float = 0.01) -> np.ndarray:
    """Petits fondus au début et à la fin : évite les « clics »."""
    y = x.copy()
    fi, fo = min(n_samples(fade_in), len(y)), min(n_samples(fade_out), len(y))
    if fi > 1:
        y[:fi] *= np.linspace(0.0, 1.0, fi)
    if fo > 1:
        y[-fo:] *= np.linspace(1.0, 0.0, fo)
    return y


def make_seamless_loop(x: np.ndarray, crossfade: float = 0.5) -> np.ndarray:
    """Rend un son bouclable sans raccord audible : la fin est fondue dans le début.
    Le résultat est plus court de `crossfade` secondes."""
    c = n_samples(crossfade)
    if c * 2 >= len(x):
        raise ValueError("Son trop court pour ce fondu de bouclage")
    body = x[:-c].copy()
    tail = x[-c:]
    w = np.linspace(0.0, 1.0, c)
    # Fondu à puissance constante (évite un creux de volume au raccord).
    body[:c] = body[:c] * np.sin(w * np.pi / 2) + tail * np.cos(w * np.pi / 2)
    return body


def reverse(x: np.ndarray) -> np.ndarray:
    """Son à l'envers (rembobinage)."""
    return x[::-1].copy()


def mix(*layers: np.ndarray) -> np.ndarray:
    """Additionne des sons de longueurs différentes (le plus long fixe la durée)."""
    n = max(len(layer) for layer in layers)
    out = np.zeros(n)
    for layer in layers:
        out[: len(layer)] += layer
    return out


# ---------------------------------------------------------------------------
# Écriture WAV
# ---------------------------------------------------------------------------

def write_wav(path: Path, x: np.ndarray, loop: bool = False) -> None:
    """Écrit un WAV mono 16 bits. Si `loop` est vrai, ajoute un bloc « smpl »
    qui indique à Godot de jouer le son en boucle du début à la fin
    (Godot le détecte à l'import : réglage « Loop Mode : Detect From WAV »)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(x, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2").tobytes()
    frames = len(x)

    fmt_chunk = struct.pack("<4sIHHIIHH", b"fmt ", 16, 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16)
    data_chunk = struct.pack("<4sI", b"data", len(pcm)) + pcm
    if len(pcm) % 2:
        data_chunk += b"\x00"
    chunks = fmt_chunk + data_chunk
    if loop:
        # En-tête smpl (9 champs de 32 bits) puis une boucle :
        # identifiant, type (0 = boucle avant), début, fin, fraction, nombre de répétitions (0 = infini).
        sample_period = int(1e9 / SAMPLE_RATE)
        smpl = struct.pack("<9I", 0, 0, sample_period, 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, frames, 0, 0)
        chunks += struct.pack("<4sI", b"smpl", len(smpl)) + smpl
    riff = struct.pack("<4sI4s", b"RIFF", 4 + len(chunks), b"WAVE")
    path.write_bytes(riff + chunks)
