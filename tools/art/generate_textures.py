#!/usr/bin/env python3
"""Générateur des textures du décor et des personnages (essai graphique, après J8).

Comme pour les sons (tools/audio/), aucune image n'est dessinée à la main ni
téléchargée : tout est calculé ici, avec numpy, à partir de bruit et de motifs.

Chaque matière donne DEUX images, toutes deux « sans raccord » (le bord droit
continue le bord gauche, le bas continue le haut : on peut les répéter comme un
carrelage sans voir de couture) :
  - <nom>.png    la COULEUR (surtout des gris : le jeu la teinte avec la couleur
                 du bloc, comme un filtre coloré posé dessus) ;
  - <nom>_n.png  le RELIEF (« normal map ») : pour chaque pixel, la direction vers
                 laquelle la surface est tournée, codée en couleur. Godot s'en sert
                 pour que la lumière d'une lampe accroche les aspérités.

Usage :  python3 tools/art/generate_textures.py   (puis réimport Godot :
         godot --headless --path . --import)

Analogie Excel : chaque texture est un grand tableau de nombres (une cellule par
pixel). On additionne des tableaux (bruit fin, taches, fissures), puis on calcule
les « pentes » entre cellules voisines pour obtenir le relief.
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures", "generated")


# ---------------------------------------------------------------------------
# Outils : bruit qui se répète, relief, enregistrement
# ---------------------------------------------------------------------------

def periodic_noise(size: int, beta: float, seed: int) -> np.ndarray:
    """Bruit « sans raccord » : un bruit blanc filtré dans le domaine des
    fréquences (FFT). beta grand = grosses taches douces ; beta petit = grain fin.
    La FFT est périodique par nature : l'image se répète sans couture.
    Résultat entre 0 et 1."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spectrum = np.fft.fft2(white) / f ** (beta * 0.5)
    spectrum[0, 0] = 0.0
    field = np.real(np.fft.ifft2(spectrum))
    field -= field.min()
    return field / max(field.max(), 1e-9)


def blur(a: np.ndarray, radius: int) -> np.ndarray:
    """Flou « en boîte », en enroulant les bords (garde l'absence de raccord)."""
    out = a.copy()
    for axis in (0, 1):
        acc = np.zeros_like(out)
        for k in range(-radius, radius + 1):
            acc += np.roll(out, k, axis=axis)
        out = acc / (2 * radius + 1)
    return out


def normal_map(height: np.ndarray, strength: float) -> np.ndarray:
    """Relief -> normal map. Pentes horizontales et verticales (différences entre
    voisins, bords enroulés), puis un vecteur (−pente x, −pente y, 1) normalisé,
    rangé dans les couleurs : rouge = x, vert = y, bleu = z.
    Convention de Godot : vert vers le HAUT (style OpenGL)."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx = -dx * strength
    ny = dy * strength  # image : y vers le bas ; normal map : y vers le haut
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / length, ny / length, nz / length], axis=-1)
    return ((rgb * 0.5 + 0.5) * 255.0).clip(0, 255).astype(np.uint8)


def save(name: str, color: np.ndarray, height: np.ndarray, strength: float) -> None:
    """Enregistre <name>.png (couleur, gris ou RVB) et <name>_n.png (relief)."""
    os.makedirs(OUT_DIR, exist_ok=True)
    if color.ndim == 2:
        color = np.stack([color] * 3, axis=-1)
    Image.fromarray((color.clip(0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT_DIR, name + ".png"))
    Image.fromarray(normal_map(height, strength), "RGB").save(os.path.join(OUT_DIR, name + "_n.png"))
    print("  %-10s %dx%d" % (name, color.shape[1], color.shape[0]))


def cracks(size: int, count: int, seed: int, length: int = 150) -> np.ndarray:
    """Fissures : des marches au hasard qui partent dans une direction et dévient
    un peu à chaque pas. Renvoie un tableau 0..1 (1 = dans la fissure)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    for _ in range(count):
        x, y = rng.uniform(0, size, 2)
        angle = rng.uniform(0, 2 * np.pi)
        for step in range(int(length * rng.uniform(0.5, 1.2))):
            angle += rng.normal(0, 0.16)
            x = (x + np.cos(angle)) % size
            y = (y + np.sin(angle)) % size
            out[int(y), int(x)] = 1.0
            if rng.random() < 0.04:  # petite branche
                bx, by, ba = x, y, angle + rng.choice([-1, 1]) * rng.uniform(0.6, 1.2)
                for _ in range(int(rng.uniform(5, 18))):
                    ba += rng.normal(0, 0.3)
                    bx = (bx + np.cos(ba)) % size
                    by = (by + np.sin(ba)) % size
                    out[int(by), int(bx)] = 0.7
    return np.maximum(out, blur(out, 1) * 0.8)


# ---------------------------------------------------------------------------
# Les matières
# ---------------------------------------------------------------------------

def concrete(size: int = 256) -> None:
    """Béton usé : grain fin, grandes taches d'humidité, piqûres, fissures."""
    grain = periodic_noise(size, 0.6, 1)
    stains = periodic_noise(size, 3.2, 2)
    pits = (periodic_noise(size, 0.2, 3) > 0.83).astype(float)
    crack = cracks(size, 3, 4) * 0.7
    color = 0.78 + 0.12 * (grain - 0.5) - 0.22 * (stains - 0.5) ** 2 * 4 * (stains > 0.5)
    color = color - 0.2 * pits - 0.45 * crack
    height = 0.5 * grain + 0.6 * blur(stains, 2) - 1.4 * pits - 2.5 * crack
    save("concrete", color, height, 1.2)


def brick(size: int = 256) -> None:
    """Briques : rangées décalées, joints en creux, briques plus ou moins cuites,
    arêtes arrondies, quelques éclats."""
    bw, bh, joint = 64, 32, 3  # 256 = 4 briques de large, 8 rangées : le motif tombe juste
    # Un motif doit tomber juste dans l'image (et un nombre pair de rangées, à
    # cause du décalage d'une rangée sur deux), sinon une couture apparaît.
    assert size % bw == 0 and size % (2 * bh) == 0, "briques : le motif ne tombe pas juste"
    y, x = np.mgrid[0:size, 0:size]
    row = y // bh
    shift = (row % 2) * (bw // 2)
    col = (x + shift) // bw
    lx = (x + shift) % bw
    ly = y % bh
    # Distance au joint le plus proche (pour arrondir les arêtes).
    edge = np.minimum(np.minimum(lx, bw - 1 - lx), np.minimum(ly, bh - 1 - ly)).astype(float)
    in_brick = edge >= joint
    rng = np.random.default_rng(5)
    tone = rng.uniform(0.72, 1.0, (size // bh, size // bw))
    brick_tone = tone[row % tone.shape[0], col % tone.shape[1]]  # modulo : sans raccord
    grain = periodic_noise(size, 0.7, 6)
    chips = (periodic_noise(size, 1.6, 7) > 0.8) & in_brick
    color = np.where(in_brick, brick_tone * (0.85 + 0.2 * grain), 0.5 + 0.1 * grain)
    color = np.where(chips, color * 0.8, color)
    bevel = np.clip((edge - joint) / 4.0, 0.0, 1.0)
    height = np.where(in_brick, bevel + 0.25 * grain, 0.0) - 0.5 * chips
    save("brick", color, height * 2.0, 2.2)


def metal(size: int = 256) -> None:
    """Tôle : grandes plaques avec joints, rivets, rayures horizontales, rouille
    (taches orangées : c'est la seule matière en couleur)."""
    plate = 128
    assert size % plate == 0, "tôle : les plaques ne tombent pas juste"
    y, x = np.mgrid[0:size, 0:size]
    lx, ly = x % plate, y % plate
    seam = (lx < 2) | (ly < 2)
    rivet = np.zeros((size, size))
    for cx in (8, plate - 8):
        for cy in (8, plate - 8, plate // 2):
            d = np.sqrt((lx - cx) ** 2 + (ly - cy) ** 2)
            rivet = np.maximum(rivet, np.clip(1.0 - d / 3.5, 0.0, 1.0))
    streak = periodic_noise(size, 0.4, 8)
    streak = blur(np.repeat(streak[:, :1], size, axis=1) * 0.6 + streak * 0.4, 1)  # rayures étirées
    rust = np.clip((periodic_noise(size, 2.8, 9) - 0.55) * 3.0, 0.0, 1.0)
    base = 0.82 + 0.1 * (streak - 0.5) - 0.3 * seam + 0.15 * rivet
    rgb = np.stack([base, base, base], axis=-1)
    rust_color = np.array([0.95, 0.62, 0.38])
    rgb = rgb * (1 - rust[..., None] * 0.6) + rust[..., None] * 0.6 * rust_color * base[..., None]
    height = -1.0 * seam + 1.5 * rivet + 0.15 * streak + 0.3 * blur(rust, 1)
    save("metal", rgb, height, 2.0)


def planks(size: int = 256) -> None:
    """Planches (caisses) : lames verticales, veinage, nœuds, clous."""
    lw = 32
    assert size % lw == 0, "planches : les lames ne tombent pas juste"
    y, x = np.mgrid[0:size, 0:size]
    lane = x // lw
    lx = x % lw
    gap = (lx < 2).astype(float)
    rng = np.random.default_rng(10)
    tone = rng.uniform(0.75, 1.0, size // lw + 1)[lane]
    offset = rng.uniform(0, 100, size // lw + 1)[lane]
    wobble = periodic_noise(size, 2.5, 11)
    vein = 0.5 + 0.5 * np.sin((x + offset + wobble * 18.0) * 0.9)
    nail = np.zeros((size, size))
    for cy in (12, size // 2 + 12):
        d = np.sqrt((lx - lw // 2) ** 2 + (y % size - cy) ** 2)
        nail = np.maximum(nail, np.clip(1.0 - d / 2.0, 0.0, 1.0))
    color = tone * (0.82 + 0.12 * vein) - 0.45 * gap - 0.3 * nail
    height = 0.4 * vein - 1.5 * gap + 1.0 * nail
    save("planks", color, height, 1.8)


def fabric(size: int = 64) -> None:
    """Tissu (vêtements) : trame fine et irrégulière, à peine visible : à la
    taille des personnages, elle donne seulement du « grain »."""
    y, x = np.mgrid[0:size, 0:size]
    weave = 0.5 + 0.25 * np.sin(x * np.pi / 2.0) * np.sin(y * np.pi / 2.0)
    fuzz = periodic_noise(size, 0.8, 12)
    color = 0.9 + 0.08 * (weave - 0.5) + 0.06 * (fuzz - 0.5)
    height = 0.4 * weave + 0.6 * fuzz
    save("fabric", color, height, 0.9)


def scales(size: int = 128) -> None:
    """Écailles (peau du Traqueur) : des cellules irrégulières (« diagramme de
    Voronoï » : chaque pixel appartient à la graine la plus proche), bombées au
    centre, avec un sillon sombre entre elles. Les distances se mesurent en
    « enroulant » l'image (les 9 copies voisines) : sans raccord."""
    rng = np.random.default_rng(13)
    seeds = rng.uniform(0, size, (70, 2))
    y, x = np.mgrid[0:size, 0:size].astype(float)
    first = np.full((size, size), 1e9)
    second = np.full((size, size), 1e9)
    for sx, sy in seeds:
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d = np.sqrt((x - sx - ox) ** 2 + (y - sy - oy) ** 2)
                second = np.where(d < first, first, np.minimum(second, d))
                first = np.minimum(first, d)
    edge = np.clip((second - first) / 6.0, 0.0, 1.0)  # 0 au sillon, 1 au centre
    grain = periodic_noise(size, 0.8, 14)
    color = 0.62 + 0.3 * edge + 0.06 * (grain - 0.5)
    height = np.sqrt(edge) + 0.15 * grain
    save("scales", color, height, 2.4)


def main() -> None:
    print("Textures ->", os.path.normpath(OUT_DIR))
    concrete()
    brick()
    metal()
    planks()
    fabric()
    scales()


if __name__ == "__main__":
    main()
