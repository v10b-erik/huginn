#!/usr/bin/env python3
"""Genererer app-ikonforslag (1024x1024 PNG, ingen alfa) + galleri.
Bruk: python3 -I Scripts/gen-ikon.py [utkatalog=design/ikon]
Farger fra design/tokens.css (mørk): flate #0E1526, aksent #8191E8, fyll #5A6CD6.
Motiv: 5x7 punktmatrise (LCD). Ingen tekst; mening bæres av form (fylt/ring/plassering), ikke farge alene."""
import sys, os
from PIL import Image, ImageDraw, ImageFilter

S = 1024; SS = 2
BG = (0x0E, 0x15, 0x26); AKS = (0x81, 0x91, 0xE8); FYLL = (0x5A, 0x6C, 0xD6)
SLUKKET = (0x2A, 0x35, 0x5C)
COLS, ROWS = 5, 7
PITCH = 128; R = 46          # prikkradius; gitteret 5x7 sentreres (640 x 896 flate)
X0 = (S - (COLS - 1) * PITCH) / 2; Y0 = (S - (ROWS - 1) * PITCH) / 2

def pos(c, r): return X0 + c * PITCH, Y0 + r * PITCH

def disc(d, c, r, rad, fill=None, outline=None, w=0):
    x, y = pos(c, r)
    d.ellipse([(x-rad)*SS, (y-rad)*SS, (x+rad)*SS, (y+rad)*SS], fill=fill, outline=outline, width=w*SS)

def render(lit, ring=(), dim=True, strong=()):
    """lit: lysende prikker (c,r). strong: de som fylles med aksent (resten av lit i fyll). ring: konturprikker."""
    img = Image.new("RGB", (S*SS, S*SS), BG)
    glow = Image.new("RGB", (S*SS, S*SS), (0, 0, 0))
    gd = ImageDraw.Draw(glow); d = ImageDraw.Draw(img)
    for r in range(ROWS):
        for c in range(COLS):
            k = (c, r)
            if k in lit:
                col = AKS if (not strong or k in strong) else FYLL
                disc(gd, c, r, R+8, fill=col); disc(d, c, r, R, fill=col)
            elif k in ring:
                disc(d, c, r, R-6, outline=FYLL, w=9)
            elif dim:
                disc(d, c, r, R-14, fill=SLUKKET)
    glow = glow.filter(ImageFilter.GaussianBlur(40*SS))
    from PIL import ImageChops
    img = ImageChops.add(img, glow.point(lambda v: int(v*0.55)))
    # prikkene tegnes på nytt over gløden så kantene er skarpe
    d = ImageDraw.Draw(img)
    for (c, r) in lit:
        disc(d, c, r, R, fill=AKS if (not strong or (c, r) in strong) else FYLL)
    return img.resize((S, S), Image.LANCZOS)

def rader(m):
    return {(c, r) for r, row in enumerate(m) for c, ch in enumerate(row) if ch == "#"}

# A «Ett lys»: hele matrisen slukket, én prikk tent (noe krever deg; plassering + lys, ikke bare farge).
A = render({(2, 3)})
# B «Godkjenn»: hake tegnet i prikker (formen sier «godkjent» uten tekst).
B = render(rader([".....", "....#", "...#.", "#.#..", ".#...", ".....", "....."]), dim=True)
# C «Kø»: søyler av prikker i fyll-tone (pågår); to prikker øverst i den høyeste søylen i aksent (krever deg). Form (høyde) bærer tallet.
h = [2, 3, 4, 6, 5]
lit = {(c, ROWS-1-i) for c, n in enumerate(h) for i in range(n)}
C = render(lit, strong={(3, 1), (3, 2)}, dim=True)

if __name__ == "__main__":
    ut = sys.argv[1] if len(sys.argv) > 1 else "design/ikon"
    os.makedirs(ut, exist_ok=True)
    for navn, im in zip("abc", (A, B, C)):
        im.save(f"{ut}/forslag-{navn}.png", optimize=True)
