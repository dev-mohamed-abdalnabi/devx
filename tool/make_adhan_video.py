#!/usr/bin/env python3
"""يرسم فيديو خلفية شاشة الأذان (حلقة 10 ثوانٍ) بألوان ثيم التطبيق ورسمة المسجد نفسها.
الاستخدام: python3 tool/make_adhan_video.py   (يحتاج Pillow + numpy + ffmpeg)"""
import math, random, subprocess, pathlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "packages/azkari_native/android/src/main/res/raw/adhan_bg.mp4"
W, H, FPS, SECS = 720, 1280, 24, 10
N = FPS * SECS
BG_TOP, BG_BOT = (10, 14, 10), (24, 36, 22)           # من ألوان ثيم الداكن
GOLD, MINT, LEAF = (212, 174, 90), (36, 51, 32), (111, 174, 90)
SS = 2  # تنعيم الرسم الثابت

def gradient():
    t = np.linspace(0, 1, H)[:, None, None] ** 1.2
    a = np.array(BG_TOP)[None, None, :]; b = np.array(BG_BOT)[None, None, :]
    return np.repeat(a + (b - a) * t, W, axis=1)

def star8(d, cx, cy, r, w, col):
    pts = []
    for i in range(16):
        rr = r if i % 2 == 0 else r * 0.62
        ang = math.pi * i / 8 - math.pi / 2
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    d.line(pts + [pts[0]], fill=col, width=w, joint="curve")

def pattern_layer():
    im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    step = 120 * SS
    for gy in range(-1, H * SS // step + 2):
        for gx in range(-1, W * SS // step + 2):
            ox = step // 2 if gy % 2 else 0
            star8(d, gx * step + ox, gy * step, 38 * SS, SS, GOLD + (26,))
    return im.resize((W, H), Image.LANCZOS)

def mosque_layers():
    """رسمة المسجد (viewBox 150x110) عند عرض الشاشة. يُرجع (silhouette, windows)."""
    k = W / 150 * SS
    oy = H * SS - 110 * k
    sil = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0)); d = ImageDraw.Draw(sil)
    win = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0)); w = ImageDraw.Draw(win)
    P = lambda x, y: (x * k, oy + y * k)
    def rect(dr, x, y, ww, hh, c): dr.rectangle([*P(x, y), *P(x + ww, y + hh)], fill=c)
    def arch(dr, x, y, ww, hh, c):  # فتحة بقوس علوي
        r = ww / 2
        dr.rectangle([*P(x, y + r), *P(x + ww, y + hh)], fill=c)
        dr.pieslice([*P(x, y), *P(x + ww, y + ww)], 180, 360, fill=c)
    S = (46, 68, 40, 255)
    rect(d, 0, 100, 150, 10, S); rect(d, 38, 72, 64, 28, S)
    d.pieslice([*P(40, 42), *P(100, 102)], 180, 360, fill=S)
    arch(d, 24, 83, 14, 17, S); arch(d, 102, 83, 14, 17, S)
    for mx in (8, 130):
        rect(d, mx, 54, 12, 46, S); rect(d, mx - 3, 52, 18, 3, S); rect(d, mx + 2, 42, 8, 10, S)
        d.polygon([P(mx + 1, 42), P(mx + 6, 28), P(mx + 11, 42)], fill=S)
    # قبّة: قوس الذروة
    rect(d, 69.5, 27, 1, 16, GOLD + (255,))
    # نوافذ مضيئة
    arch(w, 46, 86, 8, 8, (255, 214, 130, 255)); arch(w, 86, 86, 8, 8, (255, 214, 130, 255))
    arch(w, 64, 86, 12, 14, (255, 200, 110, 255))
    for mx in (13, 135):
        rect(w, mx, 64, 2, 8, (255, 214, 130, 255)); rect(w, mx, 80, 2, 8, (255, 214, 130, 255))
    f = lambda im: im.resize((W, H), Image.LANCZOS)
    return f(sil), f(win), (70 * W / 150, H - 110 * W / 150 + 19 * W / 150, 7 * W / 150)

def crescent(cx, cy, r):
    im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=GOLD + (255,))
    off = r * 0.36
    d.ellipse([(cx + off - r * 0.8) * SS, (cy - off * .6 - r * 0.8) * SS,
               (cx + off + r * 0.8) * SS, (cy - off * .6 + r * 0.8) * SS], fill=(0, 0, 0, 0))
    return im.resize((W, H), Image.LANCZOS)

def blob(cx, cy, rx, ry):
    yy, xx = np.mgrid[0:H, 0:W]
    return np.exp(-(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2))

def over(base, layer, alpha=1.0):
    a = np.asarray(layer, dtype=np.float32)
    al = a[..., 3:4] / 255 * alpha
    return base * (1 - al) + a[..., :3] * al

def main():
    random.seed(7)
    base = gradient().astype(np.float32)
    base = over(base, pattern_layer())
    sil, win, (mx, my, mr) = mosque_layers()
    moon_c = (W * 0.5, H * 0.17, 62)  # توهّج خلف الشعار (الشعار نفسه فيه الهلال)
    moon = crescent(*moon_c)
    glow_moon = blob(moon_c[0], moon_c[1], 330, 330)[..., None]
    glow_mid = blob(W / 2, H * 0.62, 520, 360)[..., None]
    win_glow = blob(W / 2, H - 60, 300, 120)[..., None]
    stars = [(random.uniform(0, W), random.uniform(0, H * 0.62), random.uniform(.8, 2.2),
              random.uniform(0, 1), random.choice((1, 2, 3))) for _ in range(70)]
    proc = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-an", "-c:v", "libx264",
         "-preset", "slow", "-crf", "27", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
         "-g", str(FPS), str(OUT)], stdin=subprocess.PIPE)
    for f in range(N):
        t = f / N; s = math.sin(2 * math.pi * t)
        fr = base.copy()
        fr += glow_mid * (10 + 6 * s) * np.array([.5, 1, .45])           # توهّج أخضر هادئ
        fr += glow_moon * (26 + 10 * math.sin(2 * math.pi * t + 1)) * np.array([1, .8, .4])
        im = Image.fromarray(np.clip(fr, 0, 255).astype(np.uint8)).convert("RGBA")
        d = ImageDraw.Draw(im, "RGBA")
        for x, y, r, ph, cyc in stars:                                   # نجوم متلألئة
            a = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(2 * math.pi * (t * cyc + ph))) ** 2
            d.ellipse([x - r, y - r, x + r, y + r], fill=(245, 232, 190, int(255 * a)))
        fr = np.asarray(im.convert("RGB"), dtype=np.float32)
        fr = over(fr, sil, 1.0)
        pulse = 0.78 + 0.22 * math.sin(2 * math.pi * t * 2)
        fr += win_glow * 38 * pulse * np.array([1, .75, .3])
        fr = over(fr, win, 0.55 + 0.45 * pulse)
        proc.stdin.write(np.clip(fr, 0, 255).astype(np.uint8).tobytes())
    proc.stdin.close(); proc.wait()
    print("ok", OUT, OUT.stat().st_size // 1024, "KB")

if __name__ == "__main__":
    main()
