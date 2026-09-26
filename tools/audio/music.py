"""
Musique procédurale de PARADOXE (J8, PLAN §6.7).

Le jeu est surtout silencieux : la musique n'arrive qu'à des moments choisis.
Ce module compose, avec les outils de dsp.py :

  - trois COUCHES DE TENSION de même durée (20 s, 96 battements par minute), jouées
    ensemble et en boucle. Leur volume suit le niveau d'alerte des ennemis :
    nappe (un peu inquiet), pulsation grave (très inquiet), percussions (combat) ;
  - des THÈMES courts : intro, arrivée, rencontre (Marek), poursuite (en boucle),
    mort, fin.

Fil rouge : le MOTIF DE LA SPIRALE, six notes qui tournent en montant
(ré fa mi sol fa la), comme la spirale du pendentif. On l'entend dans l'intro,
à la rencontre de Marek et à la fin.

Comment c'est construit (analogie Excel) : une « piste » (Timeline) est une
colonne de 44 100 lignes par seconde, remplie de zéros ; poser une note, c'est
ADDITIONNER la colonne de la note à partir de la bonne ligne. Pour une boucle,
ce qui déborde à la fin revient au début (comme un modulo) : le raccord est
parfait, sans fondu.

Ce fichier est chargé par generate_sounds.py (catégorie « music ») :
    python3 tools/audio/generate_sounds.py mus_tension_pad    # une seule piste
"""

from __future__ import annotations

from typing import Callable

import numpy as np

import dsp

SR = dsp.SAMPLE_RATE

# ---------------------------------------------------------------------------
# Notes
# ---------------------------------------------------------------------------

_NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
               "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def hz(name: str) -> float:
    """Fréquence d'une note écrite à l'anglaise : « D3 » (ré), « Bb2 » (si bémol),
    « F#4 » (fa dièse). Le la 440 Hz est « A4 »."""
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + _NOTE_INDEX[pitch]
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def chord(*names: str) -> list[float]:
    return [hz(n) for n in names]


# Le motif de la spirale : ré fa mi sol fa la (monte d'une tierce, redescend d'un
# ton, remonte d'une tierce…). Octave 5 : aigu, cristallin.
SPIRAL_MOTIF = ["D5", "F5", "E5", "G5", "F5", "A5"]


# ---------------------------------------------------------------------------
# Piste : on y pose des notes
# ---------------------------------------------------------------------------

class Timeline:
    """Une piste de `length` secondes. En boucle (`loop`), ce qui dépasse la fin
    repart au début ; sinon la piste s'allonge pour laisser sonner les queues."""

    def __init__(self, length: float, loop: bool):
        self.n = dsp.n_samples(length)
        self.loop = loop
        self.buf = np.zeros(self.n if loop else self.n + dsp.n_samples(8.0))

    def add(self, start: float, sound: np.ndarray, gain: float = 1.0) -> None:
        i = int(round(start * SR))
        s = sound * gain
        if not self.loop:
            end = min(len(self.buf), i + len(s))
            if end > i:
                self.buf[i:end] += s[: end - i]
            return
        pos, k = i % self.n, 0
        while k < len(s):  # remplit jusqu'à la fin, puis repart au début
            count = min(len(s) - k, self.n - pos)
            self.buf[pos: pos + count] += s[k: k + count]
            k += count
            pos = 0

    def render(self) -> np.ndarray:
        if self.loop:
            return self.buf.copy()
        active = np.nonzero(np.abs(self.buf) > 1e-4)[0]
        end = active[-1] + 1 if len(active) else self.n
        return self.buf[: max(end, self.n)].copy()


# ---------------------------------------------------------------------------
# Réverbération (salle virtuelle)
# ---------------------------------------------------------------------------

def _comb(x: np.ndarray, delay: int, g: float) -> np.ndarray:
    """Filtre en peigne : y[n] = x[n] + g·y[n - delay] (un écho qui se répète).
    Calculé par blocs de `delay` échantillons : rapide avec numpy."""
    y = x.copy()
    for k in range(delay, len(y), delay):
        end = min(k + delay, len(y))
        y[k:end] += g * y[k - delay: end - delay]
    return y


def _allpass(x: np.ndarray, delay: int, g: float) -> np.ndarray:
    """Passe-tout : brouille les échos sans colorer le son."""
    y = -g * x
    y[delay:] += x[:-delay]
    for k in range(delay, len(y), delay):
        end = min(k + delay, len(y))
        y[k:end] += g * y[k - delay: end - delay]
    return y


def reverb(x: np.ndarray, wet: float = 0.3, decay: float = 2.2, loop: bool = False,
           damping_hz: float = 5000.0) -> np.ndarray:
    """Réverbération de Schroeder (4 peignes en parallèle, 2 passe-tout en série).
    `decay` : temps pour que l'écho s'éteigne (s). En boucle, la queue de la fin
    retombe au début (on traite deux tours et on garde le second)."""
    src = np.concatenate([x, x]) if loop else np.concatenate([x, np.zeros(dsp.n_samples(decay))])
    src_f = dsp.lowpass(src, damping_hz)
    wet_sum = np.zeros(len(src))
    for ms in (29.7, 37.1, 41.1, 43.7):
        d = int(ms * SR / 1000)
        wet_sum += _comb(src_f, d, 10 ** (-3.0 * (ms / 1000) / decay))
    wet_sum /= 4.0
    for ms in (5.0, 1.7):
        wet_sum = _allpass(wet_sum, int(ms * SR / 1000), 0.7)
    # Passe-haut à 30 Hz : retire le décalage continu (une grosse caisse est
    # asymétrique) sans toucher aux graves audibles. En boucle, sur les deux tours.
    out = dsp.highpass(src + wet * wet_sum, 30.0)
    return out[len(x):] if loop else out


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def pad(freqs: list[float], dur: float, attack: float = 1.2, release: float = 1.8,
        cutoff: float = 1200.0, detune: float = 0.004, drift_hz: float = 0.15) -> np.ndarray:
    """Nappe : trois dents de scie légèrement désaccordées par note (un « chœur »
    de cordes synthétiques), adoucies par un filtre, qui entrent et sortent lentement."""
    total = dur + release
    t = dsp.time_axis(total)
    out = np.zeros(len(t))
    for i, f in enumerate(freqs):
        for k, d in enumerate((-detune, 0.0, detune)):
            phase = (0.37 * i + 0.29 * k) % 1.0
            p = (f * (1.0 + d) * t + phase) % 1.0
            out += 2.0 * p - 1.0
    out = dsp.lowpass(out, cutoff, order=2)
    out *= 1.0 + 0.08 * np.sin(2 * np.pi * drift_hz * t)  # respiration lente
    env = dsp.adsr(total, attack, 0.0, 1.0, release)
    return out * env / (3.0 * max(len(freqs), 1))


def bell(freq: float, dur: float = 3.0, bright: float = 1.0) -> np.ndarray:
    """Cloche de verre (synthèse modale : partiels non harmoniques)."""
    t = dsp.time_axis(dur)
    body = dsp.modal_body(dur, [(freq, 1.0, dur), (freq * 2.0, 0.3, dur * 0.55),
                                (freq * 2.76, 0.22 * bright, dur * 0.3), (freq * 5.4, 0.1 * bright, dur * 0.15)])
    return body * np.minimum(1.0, t / 0.003) * 0.5


def pluck(freq: float, dur: float = 1.0) -> np.ndarray:
    """Corde pincée synthétique : les harmoniques aigus s'éteignent plus vite."""
    out = np.zeros(dsp.n_samples(dur))
    for h in range(1, 9):
        if freq * h > 9000:
            break
        out += (1.0 / h) * dsp.sine(freq * h, dur) * dsp.exp_decay(dur, dur / h ** 0.8)
    t = dsp.time_axis(dur)
    return out * np.minimum(1.0, t / 0.002) * 0.35


def bass(freq: float, dur: float, cutoff: float = 420.0) -> np.ndarray:
    """Basse : sinusoïde (le poids) + dent de scie filtrée (le grain)."""
    s = 0.75 * dsp.sine(freq, dur) + 0.45 * dsp.lowpass(dsp.saw(freq, dur), cutoff)
    return s * dsp.adsr(dur, 0.006, dur * 0.35, 0.55, min(0.07, dur * 0.3))


def kick(dur: float = 0.45) -> np.ndarray:
    f = dsp.ramp(dur, 115.0, 42.0, 0.3)
    return dsp.sine(f, dur) * dsp.exp_decay(dur, 0.32)


def tom(freq: float, dur: float = 0.6, rng: np.random.Generator | None = None) -> np.ndarray:
    """Tambour grave (taïko synthétique) : peau accordée qui descend + frappe bruitée."""
    body = dsp.sine(dsp.ramp(dur, freq * 1.5, freq, 0.25), dur) * dsp.exp_decay(dur, dur * 0.8)
    if rng is not None:
        hit = dsp.lowpass(dsp.white_noise(dur, rng), 1800) * dsp.exp_decay(dur, 0.05) * 0.35
        body = body + hit
    return body


def hat(rng: np.random.Generator, dur: float = 0.06) -> np.ndarray:
    """Charleston fermé : bruit dans les aigus, très bref (discret : il ne doit pas siffler)."""
    t = dsp.time_axis(dur)
    noise = dsp.bandpass(dsp.white_noise(dur, rng), 4500, 9500)
    return noise * dsp.exp_decay(dur, 0.03) * np.minimum(1.0, t / 0.001) * 0.3


def tick(rng: np.random.Generator) -> np.ndarray:
    """Petit choc métallique (baguette sur un tuyau)."""
    d = 0.25
    return dsp.modal_body(d, [(1870, 1.0, 0.12), (2930, 0.6, 0.08), (4410, 0.3, 0.05)]) * 0.35


def swell(dur: float, rng: np.random.Generator, low: float = 300.0, high: float = 3000.0) -> np.ndarray:
    """Souffle qui monte (tension) : bruit filtré dont le volume croît."""
    noise = dsp.bandpass(dsp.pink_noise(dur, rng), low, high)
    return noise * dsp.ramp(dur, 0.0, 1.0, 2.0)


# ---------------------------------------------------------------------------
# Couches de tension (boucles synchronisées, mêmes durées)
# ---------------------------------------------------------------------------

TENSION_BPM = 96.0
TENSION_BARS = 8
# Accords par tranches de 2 mesures : ré mineur, si bémol, sol mineur, la majeur
# (la tierce majeure du dernier accord crée l'attente du retour à ré).
TENSION_CHORDS = [
    ("D2", ["D3", "F3", "A3"]),
    ("Bb1", ["Bb2", "D3", "F3"]),
    ("G1", ["G2", "Bb2", "D3"]),
    ("A1", ["A2", "C#3", "E3"]),
]


def _tension_length() -> tuple[float, float]:
    beat = 60.0 / TENSION_BPM
    return beat, beat * 4 * TENSION_BARS


def mus_tension_pad(rng: np.random.Generator) -> np.ndarray:
    beat, length = _tension_length()
    tl = Timeline(length, loop=True)
    span = beat * 8  # 2 mesures par accord
    top_line = ["A4", "Bb4", "Bb4", "A4"]  # note tenue, très douce, au-dessus
    for i, (_, notes) in enumerate(TENSION_CHORDS):
        tl.add(i * span, pad(chord(*notes), span, attack=1.4, release=1.6, cutoff=1000.0))
        tl.add(i * span, pad([hz(top_line[i])], span, attack=2.0, release=1.6, cutoff=1800.0, detune=0.003), 0.35)
    return dsp.normalize(reverb(tl.render(), wet=0.35, decay=3.0, loop=True), 0.7)


def mus_tension_pulse(rng: np.random.Generator) -> np.ndarray:
    beat, length = _tension_length()
    tl = Timeline(length, loop=True)
    eighth = beat / 2
    accents = [1.0, 0.5, 0.7, 0.5, 0.9, 0.5, 0.7, 0.55]
    for i, (root, _) in enumerate(TENSION_CHORDS):
        for step in range(16):  # 2 mesures de croches
            f = hz(root) * (2.0 if step % 8 == 6 else 1.0)  # un saut d'octave par mesure
            tl.add(i * beat * 8 + step * eighth, bass(f, eighth * 0.9), accents[step % 8])
    return dsp.normalize(reverb(dsp.lowpass(tl.render(), 900), wet=0.12, decay=1.5, loop=True), 0.75)


def mus_tension_perc(rng: np.random.Generator) -> np.ndarray:
    beat, length = _tension_length()
    tl = Timeline(length, loop=True)
    for bar in range(TENSION_BARS):
        t0 = bar * beat * 4
        tl.add(t0, kick(), 1.0)
        tl.add(t0 + beat * 2.5, kick(), 0.8)
        tl.add(t0 + beat * 3.0, tom(82.0, 0.7, rng), 0.7)
        if bar % 2 == 1:
            tl.add(t0 + beat * 3.5, tom(98.0, 0.6, rng), 0.55)
        for e in range(8):
            tl.add(t0 + e * beat / 2, hat(rng), 0.3 if e % 2 else 0.15)
        if bar % 4 == 2:
            tl.add(t0 + beat * 1.75, tick(rng), 0.6)
    # Dernière mesure : roulement de toms qui descend vers le retour au début.
    t0 = (TENSION_BARS - 1) * beat * 4
    for k, f in enumerate([140.0, 124.0, 110.0, 98.0]):
        tl.add(t0 + beat * 2 + k * beat / 4, tom(f, 0.4, rng), 0.5 + 0.1 * k)
    return dsp.normalize(reverb(tl.render(), wet=0.2, decay=1.8, loop=True), 0.8)


# ---------------------------------------------------------------------------
# Thèmes
# ---------------------------------------------------------------------------

def mus_theme_intro(rng: np.random.Generator) -> np.ndarray:
    """Intro (plans 7 à 9) : arpèges qui tournent, le motif de la spirale, puis une
    montée de tension. La cinématique le coupe net au plan 10 (silence total)."""
    # --- Paramètres ---
    step = 0.25          # une double croche d'arpège (s)
    chords = [["D3", "A3", "E4", "F4"], ["Bb2", "F3", "A3", "D4"], ["G2", "D3", "Bb3", "A4"], ["A2", "E3", "A3", "D4"]]
    span = 4.0           # durée d'un accord (s)
    build = 8.0          # montée finale (s)
    # ------------------
    length = span * len(chords) + build
    tl = Timeline(length, loop=False)
    for i, notes in enumerate(chords):
        freqs = chord(*notes)
        tl.add(i * span, pad(freqs, span, attack=1.5, release=2.0, cutoff=900.0), 0.8)
        pattern = [0, 1, 2, 3, 2, 1, 2, 3]
        for k in range(int(span / step)):
            tl.add(i * span + k * step, pluck(freqs[pattern[k % 8]] * 2, 0.9), 0.45)
    for k, note in enumerate(SPIRAL_MOTIF):
        tl.add(4.0 + k * 1.5, bell(hz(note), 3.5), 0.6)
    b0 = span * len(chords)
    tl.add(b0, pad(chord("D2", "A2", "D3", "Eb3", "A3"), build, attack=build * 0.8, release=0.3, cutoff=1500.0), 1.1)
    tl.add(b0, swell(build, rng), 0.5)
    for k in range(int(build / step)):
        tl.add(b0 + k * step, bass(hz("D2"), step * 0.8), 0.3 + 0.6 * k * step / build)
    return dsp.fade(dsp.normalize(reverb(tl.render(), wet=0.35, decay=2.8), 0.8), 0.01, 0.05)


def mus_theme_arrival(rng: np.random.Generator) -> np.ndarray:
    """Arrivée (écran 2) : émerveillement et étrangeté. Mode lydien de ré (le sol
    dièse donne cette couleur « flottante »), cloches clairsemées, grande réverbération."""
    # --- Paramètres ---
    chords = [["D3", "A3", "E4", "G#4"], ["E3", "B3", "D4", "G#4"], ["D3", "A3", "F#4", "C#5"], ["B2", "F#3", "D4", "E4"]]
    span = 6.0
    scale = ["D5", "E5", "F#5", "G#5", "A5", "C#6", "E6"]
    # ------------------
    tl = Timeline(span * len(chords), loop=False)
    for i, notes in enumerate(chords):
        tl.add(i * span, pad(chord(*notes), span, attack=2.2, release=3.0, cutoff=1400.0, drift_hz=0.1), 0.9)
    t = 0.8
    while t < span * len(chords) - 2.0:  # cloches à des instants un peu irréguliers
        tl.add(t, bell(hz(scale[int(rng.integers(0, len(scale)))]), 4.0, bright=0.7), rng.uniform(0.25, 0.5))
        t += rng.choice([0.75, 1.0, 1.5, 2.0])
    return dsp.fade(dsp.normalize(reverb(tl.render(), wet=0.5, decay=4.0), 0.75), 0.5, 2.0)


def mus_theme_meeting(rng: np.random.Generator) -> np.ndarray:
    """Rencontre (écran 5) : Marek touche son pendentif. Le motif de la spirale,
    lent, sur une nappe chaude : la seule musique « tendre » du prototype."""
    tl = Timeline(12.0, loop=False)
    tl.add(0.0, pad(chord("D3", "A3", "E4"), 4.0, attack=1.5, release=2.0, cutoff=900.0))
    tl.add(4.0, pad(chord("Bb2", "F3", "A3", "D4"), 4.0, attack=1.5, release=2.0, cutoff=900.0))
    tl.add(8.0, pad(chord("F2", "C3", "A3", "E4"), 4.0, attack=1.5, release=3.0, cutoff=900.0))
    for k, note in enumerate(SPIRAL_MOTIF):
        tl.add(0.6 + k * 1.3, bell(hz(note), 4.0, bright=0.5), 0.55)
    return dsp.fade(dsp.normalize(reverb(tl.render(), wet=0.45, decay=3.5), 0.7), 0.2, 2.0)


CHASE_BPM = 138.0


def mus_chase_loop(rng: np.random.Generator) -> np.ndarray:
    """Poursuite (écran 8) : basse obstinée en doubles croches, grosse caisse à
    chaque temps, accords secs en contretemps. 8 mesures en boucle."""
    beat = 60.0 / CHASE_BPM
    bars = 8
    tl = Timeline(beat * 4 * bars, loop=True)
    progression = [("D2", ["D3", "F3", "A3"]), ("Bb1", ["Bb2", "D3", "F3"]),
                   ("C2", ["C3", "E3", "G3"]), ("A1", ["A2", "C#3", "E3"])]
    riff = [0, 0, 12, 0, 3, 0, 2, 0, 0, 0, 12, 0, 5, 3, 2, 0]  # demi-tons au-dessus de la fondamentale
    for bar in range(bars):
        root, notes = progression[(bar // 2) % 4]
        t0 = bar * beat * 4
        for s in range(16):
            tl.add(t0 + s * beat / 4, bass(hz(root) * 2 ** (riff[s] / 12), beat / 4 * 0.85, 600.0), 0.55 if s % 4 else 0.8)
        for b in range(4):
            tl.add(t0 + b * beat, kick(0.35), 0.9)
            tl.add(t0 + b * beat + beat / 2, hat(rng), 0.3)
        for off in (1.5, 3.5):
            tl.add(t0 + off * beat, pad(chord(*notes), beat * 0.35, attack=0.01, release=0.15, cutoff=2200.0), 0.9)
        tl.add(t0 + beat * 3.75, tom(110.0, 0.4, rng), 0.5)
    return dsp.normalize(reverb(tl.render(), wet=0.15, decay=1.4, loop=True), 0.8)


def mus_sting_death(rng: np.random.Generator) -> np.ndarray:
    """Mort : un accord grave et dissonant qui gonfle puis retombe (3,5 s)."""
    d = 3.5
    tl = Timeline(d, loop=False)
    tl.add(0.0, pad(chord("D2", "Eb2", "A2"), d - 1.5, attack=0.4, release=1.5, cutoff=700.0))
    tl.add(0.0, tom(55.0, 2.0, rng), 0.6)
    return dsp.fade(dsp.normalize(reverb(tl.render(), wet=0.35, decay=2.5), 0.7), 0.005, 0.5)


def mus_theme_end(rng: np.random.Generator) -> np.ndarray:
    """Fin (écran 8, plan final) : le motif de la spirale, très lent, puis un accord
    qui ne se résout pas (ré majeur, puis sol mineur sur ré)."""
    tl = Timeline(16.0, loop=False)
    tl.add(0.0, pad(chord("D3", "F#3", "A3", "E4"), 7.0, attack=2.0, release=2.5, cutoff=1000.0))
    tl.add(7.0, pad(chord("D3", "G3", "Bb3", "A4"), 6.0, attack=2.0, release=4.0, cutoff=1000.0))
    for k, note in enumerate(SPIRAL_MOTIF):
        tl.add(0.8 + k * 1.8, bell(hz(note) / 2, 5.0, bright=0.6), 0.6)
    return dsp.fade(dsp.normalize(reverb(tl.render(), wet=0.5, decay=4.0), 0.7), 0.3, 3.0)


# ---------------------------------------------------------------------------
# Inscription au catalogue de generate_sounds.py
# ---------------------------------------------------------------------------

def register(sound: Callable) -> None:
    """Déclare les pistes de musique (catégorie « music », bus Musique)."""
    specs = [
        ("mus_tension_pad", True, "Tension, couche 1 : nappe en ré mineur (boucle de 20 s, 96 BPM). Monte dès que l'ennemi s'inquiète.", mus_tension_pad),
        ("mus_tension_pulse", True, "Tension, couche 2 : pulsation grave en croches (boucle de 20 s). Recherche et alerte.", mus_tension_pulse),
        ("mus_tension_perc", True, "Tension, couche 3 : percussions (boucle de 20 s). Combat.", mus_tension_perc),
        ("mus_theme_intro", False, "Thème de l'intro : arpèges, motif de la spirale, montée coupée net au plan 10.", mus_theme_intro),
        ("mus_theme_arrival", False, "Thème d'arrivée (écran 2) : lydien, cloches, grande réverbération.", mus_theme_arrival),
        ("mus_theme_meeting", False, "Rencontre avec Marek : le motif de la spirale sur une nappe chaude.", mus_theme_meeting),
        ("mus_chase_loop", True, "Poursuite (écran 8) : basse obstinée, 138 BPM (boucle).", mus_chase_loop),
        ("mus_sting_death", False, "Mort : accord grave et dissonant qui gonfle et retombe.", mus_sting_death),
        ("mus_theme_end", False, "Fin : motif de la spirale très lent, accord non résolu.", mus_theme_end),
    ]
    for name, loop, description, build in specs:
        sound(name, "music", loop=loop, description=description)(build)
