#!/usr/bin/env python3
"""Generates every pixel-art PNG of the game into ../art (run: python3 make_art.py).

Sprites are drawn on tiny canvases and used in Godot scaled with the nearest filter,
so each art pixel becomes a clean square. UI 9-patches are rendered at 3x already
(see UI_SCALE) because StyleBoxTexture works in texture pixels.
"""
import os, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")
os.makedirs(OUT, exist_ok=True)
OUTLINE = (26, 16, 20, 255)


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


class Canvas:
    def __init__(self, w, h):
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, x0, y0, x1, y1, c):  # inclusive corners
        self.d.rectangle([x0, y0, x1, y1], fill=hexc(c) if isinstance(c, str) else c)

    def px(self, x, y, c):
        self.im.putpixel((x, y), hexc(c) if isinstance(c, str) else c)

    def poly(self, pts, c):
        self.d.polygon(pts, fill=hexc(c) if isinstance(c, str) else c)

    def line(self, pts, c, w=1):
        self.d.line(pts, fill=hexc(c) if isinstance(c, str) else c, width=w)

    def ellipse(self, x0, y0, x1, y1, c):
        self.d.ellipse([x0, y0, x1, y1], fill=hexc(c) if isinstance(c, str) else c)

    def outline(self, color=OUTLINE):
        src = self.im.copy()
        w, h = src.size
        for y in range(h):
            for x in range(w):
                if src.getpixel((x, y))[3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] > 0:
                            self.im.putpixel((x, y), color)
                            break

    def save(self, name, scale=1):
        im = self.im if scale == 1 else self.im.resize((self.im.width * scale, self.im.height * scale), Image.NEAREST)
        im.save(os.path.join(OUT, name))


# --------------------------------------------------------------------- characters
def cangaceiro():
    c = Canvas(56, 64)
    # boots + legs
    c.rect(19, 56, 27, 61, "#3a2216"); c.rect(29, 56, 38, 61, "#3a2216")
    c.rect(19, 60, 27, 61, "#241309"); c.rect(29, 60, 38, 61, "#241309")
    c.rect(20, 57, 21, 58, "#5a3a24"); c.rect(30, 57, 31, 58, "#5a3a24")
    c.rect(21, 44, 27, 56, "#9a7448"); c.rect(29, 44, 35, 56, "#9a7448")
    c.rect(21, 44, 22, 56, "#b38a58"); c.rect(29, 44, 30, 56, "#b38a58")
    c.rect(26, 46, 27, 56, "#7a5a36"); c.rect(34, 46, 35, 56, "#7a5a36")
    # back arm
    c.rect(16, 30, 20, 43, "#8a4e2a"); c.rect(16, 42, 20, 45, "#e8b98a")
    # torso (leather jacket)
    c.rect(19, 28, 37, 44, "#a8643a")
    c.rect(19, 28, 21, 44, "#c27a47"); c.rect(35, 28, 37, 44, "#85492a")
    c.rect(19, 43, 37, 45, "#3a2414"); c.rect(27, 43, 30, 45, "#e3b341")  # belt + buckle
    # knife on belt
    c.rect(32, 45, 33, 50, "#c9d1d9"); c.rect(32, 44, 33, 44, "#3a2414")
    # bandolier (diagonal) with cartridges
    for i in range(15):
        x, y = 20 + i, 29 + i
        c.rect(x, y, x + 2, y + 1, "#d9a45b")
        if i % 3 == 0:
            c.px(x + 1, y, "#8a5a2a")
    # neckerchief
    c.poly([(22, 26), (34, 26), (31, 31), (25, 31)], "#c0392b")
    c.rect(22, 26, 34, 27, "#e0503e")
    # head
    c.rect(24, 16, 33, 26, "#e8b98a")
    c.rect(24, 16, 25, 26, "#f2c9a0"); c.rect(32, 16, 33, 26, "#c8946a")
    c.px(31, 20, "#1a1014"); c.px(32, 20, "#1a1014")
    c.rect(29, 23, 33, 23, "#3a2214")  # mustache
    c.px(34, 21, "#e8b98a"); c.px(34, 22, "#e8b98a")  # nose
    # hat: crown, band, upturned brim, gold star
    c.rect(20, 5, 37, 13, "#8a5628"); c.rect(21, 4, 36, 4, "#8a5628")
    c.rect(20, 5, 22, 13, "#a8693a"); c.rect(35, 5, 37, 13, "#6a3f1c")
    c.rect(20, 11, 37, 12, "#3a2414")
    c.poly([(10, 8), (14, 12), (14, 16), (10, 14)], "#7a4a22")   # brim tips up
    c.poly([(47, 8), (43, 12), (43, 16), (47, 14)], "#7a4a22")
    c.rect(13, 14, 44, 17, "#7a4a22"); c.rect(13, 14, 44, 14, "#9a6232"); c.rect(13, 17, 44, 17, "#5a3414")
    c.rect(28, 8, 29, 9, "#ffd34d"); c.px(28, 7, "#ffd34d"); c.px(29, 10, "#ffd34d")
    # front arm + bacamarte
    c.rect(33, 31, 41, 35, "#8a4e2a"); c.rect(33, 31, 41, 31, "#a8643a")
    c.rect(41, 33, 43, 36, "#e8b98a")
    c.rect(36, 35, 42, 38, "#5a3a24"); c.rect(36, 35, 42, 35, "#7a5232")       # stock
    c.rect(42, 33, 51, 36, "#4b4f5c"); c.rect(42, 33, 51, 33, "#7a8090")        # barrel
    c.poly([(50, 30), (55, 29), (55, 40), (50, 37)], "#3a3d48")                  # flared muzzle
    c.rect(52, 31, 53, 38, "#161a22")
    c.rect(44, 37, 45, 37, "#e3b341")
    c.outline()
    return c


def corpo_seco():
    c = Canvas(56, 64)
    # bare feet
    c.rect(17, 59, 25, 62, "#a69172"); c.rect(31, 59, 39, 62, "#a69172")
    c.rect(17, 59, 25, 59, "#c4b08e"); c.rect(31, 59, 39, 59, "#c4b08e")
    # ragged cloak
    c.poly([(19, 20), (37, 20), (45, 58), (11, 58)], "#5a4636")
    for i, x in enumerate(range(11, 46, 4)):  # torn hem
        c.poly([(x, 58), (x + 4, 58), (x + 2, 61 if i % 2 else 60)], "#5a4636")
    c.line([(22, 24), (18, 56)], "#3d2f25"); c.line([(34, 24), (38, 56)], "#3d2f25")
    c.line([(28, 30), (28, 57)], "#3d2f25"); c.line([(25, 28), (22, 50)], "#6e5844")
    # open chest showing ribs
    c.rect(25, 28, 31, 42, "#1a0f1c")
    for y in (30, 33, 36, 39):
        c.rect(25, y, 31, y, "#c9b896")
    c.rect(28, 28, 28, 42, "#a69172")
    # hood
    c.ellipse(18, 4, 38, 26, "#6e5844")
    c.rect(19, 14, 37, 24, "#6e5844")
    c.ellipse(21, 8, 35, 24, "#241528")
    c.rect(22, 14, 34, 20, "#241528")
    c.rect(18, 4, 19, 12, "#86705a")
    # glowing purple eyes + stitched mouth
    c.rect(24, 15, 26, 17, "#d9a8ff"); c.rect(30, 15, 32, 17, "#d9a8ff")
    c.px(25, 16, "#ffffff"); c.px(31, 16, "#ffffff")
    for x in range(25, 32, 2):
        c.rect(x, 21, x, 22, "#a69172")
    c.rect(25, 21, 31, 21, "#a69172")
    # long bony arms reaching forward (facing left)
    c.rect(4, 27, 18, 29, "#a69172"); c.rect(4, 27, 18, 27, "#c4b08e")
    c.rect(1, 25, 4, 31, "#a69172")
    for y in (25, 27, 29, 31):
        c.px(0, y, "#a69172")
    c.rect(38, 30, 47, 32, "#a69172"); c.rect(47, 29, 50, 33, "#a69172")
    c.outline()
    # floating purple wisps (not outlined)
    for x, y in ((6, 10), (49, 14), (8, 44), (50, 46), (46, 4)):
        c.px(x, y, "#b06cf0"); c.px(x - 1, y, "#7a3fb0"); c.px(x + 1, y, "#7a3fb0")
        c.px(x, y - 1, "#7a3fb0"); c.px(x, y + 1, "#7a3fb0")
    return c


# --------------------------------------------------------------------- scenery
def sky(name, palette, sun_pos, sun_cols, mesa_cols, seed=3):
    rnd = random.Random(seed)
    c = Canvas(320, 180)
    bands = len(palette)
    for i, col in enumerate(palette):
        y0 = int(i * 131 / bands); y1 = int((i + 1) * 131 / bands)
        c.rect(0, y0, 319, y1, col)
        if i + 1 < bands:  # dithered transition
            for x in range(0, 320):
                for y in range(y1 - 2, y1 + 1):
                    if (x + y) % 2 == 0:
                        c.px(x, y, palette[i + 1])
    # stars (only if dark top)
    for _ in range(40):
        c.px(rnd.randrange(320), rnd.randrange(50), "#ffe9b0")
    # sun with bands
    sx, sy = sun_pos
    c.ellipse(sx - 24, sy - 24, sx + 24, sy + 24, sun_cols[0])
    c.ellipse(sx - 18, sy - 18, sx + 18, sy + 18, sun_cols[1])
    c.ellipse(sx - 11, sy - 11, sx + 11, sy + 11, sun_cols[2])
    # thin clouds
    for cx, cy, w in ((60, 30, 50), (150, 46, 38), (270, 26, 44), (200, 70, 30)):
        c.rect(cx, cy, cx + w, cy + 2, mesa_cols[3]); c.rect(cx + 6, cy - 2, cx + w - 8, cy - 1, mesa_cols[3])
    # far mesas
    c.poly([(0, 118), (0, 100), (30, 98), (36, 88), (70, 88), (76, 100), (110, 102), (120, 118)], mesa_cols[0])
    c.poly([(150, 118), (160, 104), (190, 102), (196, 92), (236, 92), (244, 104), (290, 106), (320, 100), (320, 118)], mesa_cols[0])
    # near ridge
    pts = [(0, 130)]
    x = 0
    while x < 320:
        x += rnd.randrange(14, 30)
        pts.append((x, 118 + rnd.randrange(0, 10)))
    pts += [(320, 130), (320, 135), (0, 135)]
    c.poly(pts, mesa_cols[1])
    # earth below horizon
    c.rect(0, 130, 319, 179, mesa_cols[2])
    for _ in range(260):
        x, y = rnd.randrange(320), rnd.randrange(130, 180)
        c.px(x, y, mesa_cols[4])
    # cacti
    for cx in (28, 96, 150, 214, 296):
        h = rnd.randrange(14, 22)
        col = mesa_cols[5]
        c.rect(cx, 128 - h, cx + 2, 130, col)
        c.rect(cx - 5, 128 - h + 6, cx - 3, 128 - h + 11, col); c.rect(cx - 5, 128 - h + 11, cx, 128 - h + 12, col)
        c.rect(cx + 5, 128 - h + 3, cx + 7, 128 - h + 8, col); c.rect(cx + 2, 128 - h + 8, cx + 7, 128 - h + 9, col)
    return c


def ground_tile():
    # 64x40 final pixels = 16x10 art pixels at 4x; dirt strip the characters stand on.
    c = Canvas(16, 10)
    rnd = random.Random(7)
    c.rect(0, 0, 15, 9, "#2e1a1c")
    c.rect(0, 0, 15, 0, "#6a3d2c"); c.rect(0, 1, 15, 1, "#4a2a24")
    for _ in range(14):
        c.px(rnd.randrange(16), rnd.randrange(2, 10), "#3d2326")
    for _ in range(6):
        c.px(rnd.randrange(16), rnd.randrange(2, 10), "#1f1114")
    c.save("ground_tile.png", 4)


# --------------------------------------------------------------------- UI 9-patches
UI_SCALE = 3


def ui_box(name, size, fill, border, hi, lo, notch=True, inner=None, draw_fill=True):
    c = Canvas(size, size)
    w = size - 1
    if draw_fill:
        c.rect(0, 0, w, w, border)
        c.rect(1, 1, w - 1, w - 1, fill)
        c.rect(1, 1, w - 1, 1, hi); c.rect(1, 1, 1, w - 1, hi)
        c.rect(1, w - 1, w - 1, w - 1, lo); c.rect(w - 1, 1, w - 1, w - 1, lo)
        if inner:
            c.rect(2, 2, w - 2, w - 2, inner)
    else:
        c.rect(0, 0, w, w, border)
        c.rect(1, 1, w - 1, w - 1, (0, 0, 0, 0))
        c.rect(1, 1, w - 1, w - 1, (0, 0, 0, 0))
    if notch:
        for x, y in ((0, 0), (w, 0), (0, w), (w, w)):
            c.px(x, y, (0, 0, 0, 0))
    c.save(name, UI_SCALE)


def ui():
    # parchment-brown panel with gold frame, used for panels and menus
    c = Canvas(12, 12)
    w = 11
    c.rect(0, 0, w, w, hexc("#120a0e"))
    c.rect(1, 1, w - 1, w - 1, hexc("#d6a84e"))
    c.rect(2, 2, w - 2, w - 2, hexc("#2a1a22"))
    c.rect(3, 3, w - 3, w - 3, hexc("#38242a"))
    c.rect(2, 2, w - 2, 2, hexc("#4a3238")); c.rect(2, 2, 2, w - 2, hexc("#4a3238"))
    for x, y in ((0, 0), (w, 0), (0, w), (w, w)):
        c.px(x, y, (0, 0, 0, 0))
    for x, y in ((1, 1), (w - 1, 1), (1, w - 1), (w - 1, w - 1)):
        c.px(x, y, hexc("#ffe08a"))
    c.save("ui_panel.png", UI_SCALE)

    # darker, sturdier panel for the combat HUD
    c = Canvas(12, 12)
    c.rect(0, 0, w, w, hexc("#0c0710"))
    c.rect(1, 1, w - 1, w - 1, hexc("#b88a46"))
    c.rect(2, 2, w - 2, w - 2, hexc("#1c1420"))
    c.rect(3, 3, w - 3, 3, hexc("#2a1f2e")); c.rect(3, 3, 3, w - 3, hexc("#2a1f2e"))
    for x, y in ((0, 0), (w, 0), (0, w), (w, w)):
        c.px(x, y, (0, 0, 0, 0))
    c.save("ui_hud.png", UI_SCALE)

    ui_box("ui_btn_normal.png", 10, hexc("#7a4426"), hexc("#1d100a"), hexc("#a8693a"), hexc("#4a2814"))
    ui_box("ui_btn_hover.png", 10, hexc("#9a5a30"), hexc("#1d100a"), hexc("#d38a4a"), hexc("#5a3018"))
    ui_box("ui_btn_pressed.png", 10, hexc("#4a2814"), hexc("#1d100a"), hexc("#3a1e0e"), hexc("#7a4426"))
    ui_box("ui_btn_disabled.png", 10, hexc("#4a4044"), hexc("#241c20"), hexc("#5a4e54"), hexc("#383034"))
    ui_box("ui_btn_focus.png", 10, None, hexc("#ffdb59"), None, None, notch=True, draw_fill=False)


# --------------------------------------------------------------------- map icons
def icons():
    # 16x16 symbols drawn in parchment colour on the node's dark disc
    P = "#e0b878"

    def mk(fn, name):
        c = Canvas(16, 16); fn(c); c.save(name)

    def skull(c):
        c.rect(4, 2, 11, 9, P); c.rect(3, 4, 12, 8, P); c.rect(5, 10, 10, 13, P)
        c.rect(4, 5, 6, 7, "#0d0810"); c.rect(9, 5, 11, 7, "#0d0810")
        c.rect(7, 8, 8, 9, "#0d0810")
        for x in (6, 8, 10):
            c.rect(x - 1 + 0, 11, x - 1, 13, "#0d0810") if x == 8 else None
        c.rect(7, 11, 7, 13, "#0d0810"); c.rect(9, 11, 9, 13, "#0d0810")

    def star(c):
        c.poly([(8, 0), (10, 5), (15, 6), (11, 10), (12, 15), (8, 12), (4, 15), (5, 10), (1, 6), (6, 5)], "#ffd34d")
        c.poly([(8, 3), (9, 6), (12, 7), (9, 9), (10, 12), (8, 10), (6, 12), (7, 9), (4, 7), (7, 6)], "#fff0a0")

    def question(c):
        for r in ((5, 2, 10, 3), (10, 4, 11, 6), (8, 7, 10, 8), (7, 8, 8, 10), (7, 12, 8, 13), (4, 4, 5, 5)):
            c.rect(*r, P)

    def fire(c):
        c.rect(2, 13, 13, 14, "#7a4a22"); c.line([(3, 14), (12, 11)], "#5a3414", 2); c.line([(12, 14), (3, 11)], "#5a3414", 2)
        c.poly([(8, 1), (12, 7), (11, 12), (5, 12), (4, 7), (6, 5)], "#e8672a")
        c.poly([(8, 5), (10, 9), (9, 12), (7, 12), (6, 9)], "#ffd34d")
        c.rect(7, 9, 8, 12, "#fff6c0")

    def cross(c):
        c.line([(3, 3), (12, 12)], P, 2); c.line([(12, 3), (3, 12)], P, 2)

    mk(skull, "icon_combat.png"); mk(star, "icon_boss.png"); mk(question, "icon_event.png")
    mk(fire, "icon_rest.png"); mk(cross, "icon_start.png")

    m = Canvas(12, 14)  # player marker: red cangaceiro hat + pin
    m.poly([(1, 5), (6, 0), (10, 5), (11, 6), (0, 6)], "#c0392b")
    m.rect(2, 5, 9, 6, "#7a1f16"); m.rect(0, 6, 11, 7, "#e0503e")
    m.poly([(2, 8), (9, 8), (6, 13), (5, 13)], "#c0392b")
    m.rect(5, 2, 6, 3, "#ffd34d")
    m.outline(); m.save("marker.png")


def ending_bg():
    c = sky("x", ["#120a2a", "#2a1440", "#5a2a58", "#a8485a", "#e8703a", "#ffb04d", "#ffd98a"],
            (160, 104), ("#ffe08a", "#fff0b0", "#ffffff"),
            ["#4a2a4a", "#2e1830", "#1e1020", "#7a4a6a", "#2a1630", "#120a14"], seed=11)
    # sunlit hill + cangaceiro silhouette
    c.poly([(60, 180), (80, 150), (120, 140), (170, 142), (220, 152), (250, 180)], hexc("#1a0e18"))
    c.save("bg_ending.png")


if __name__ == "__main__":
    cangaceiro().save("cangaceiro.png")
    corpo_seco().save("corpo_seco.png")
    sky("bg", ["#2a1638", "#4a2048", "#7a2e50", "#b04650", "#d9693a", "#f0a050"],
        (236, 100), ("#f6b25a", "#ffc873", "#ffe29a"),
        ["#3a1f2e", "#2a1622", "#2e1a1c", "#c46a50", "#3a2226", "#1d1018"]).save("bg_arena.png")
    ending_bg()
    ground_tile()
    ui()
    icons()
    print("done ->", os.path.abspath(OUT))
