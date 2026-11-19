#!/usr/bin/env python3
# Glutwacht: Umgebungsschleifen, Tier-, Welt- und Stimmlaute, vollständig synthetisch (keine Samples).
# Ergänzt tools/musik.py und benutzt dessen Hilfsfunktionen (Filter, Hall, WAV-Ausgabe, Nahtprüfung).
# Aufruf:  python3 tools/klang.py                    alles
#          python3 tools/klang.py amb_regen sfx_tuer nur einzelne Dateien (Namen ohne Endung)
#          python3 tools/klang.py amb | sfx | stimme  nur eine Gruppe
# Braucht numpy und ffmpeg. Ergebnisse landen in ../audio/.
#
# Loop-Prinzip der Schleifen (wie in musik.py): Alles lebt in einem Ringpuffer fester Länge (2^20 Samples,
# 23,78 s). Rauschen wird über die FFT gefiltert (zirkulär), langsame Verläufe sind zirkulär geglättetes
# Rauschen, Einzelereignisse (Vogel, Tropfen, Stimme) werden über das Ende hinaus an den Anfang gefaltet,
# durchlaufende Töne haben ganzzahlig viele Perioden, der Hall wird zirkulär gefaltet.

import math
import os
import re
import subprocess
import sys
import tempfile
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import musik as M                                                     # noqa: E402
from musik import (SR, PI2, AUDIO, FFMPEG, fftfilter, tp, hp, hall_ir, ausblenden, svf_bp, hallen, zeit,  # noqa: E402
                   lege, ping, schreibe_wav, naht, db, encoder, mi, hz)

N = 1 << 20                 # Länge aller Schleifen (Vielfaches von 64, siehe musik.py; 2er-Potenz = schnelle FFT)
T = N / SR
RNG = np.random.default_rng(1)


# ---------------------------------------------------------------- Hilfen

def rau(n, lo=None, hi=None):
    """Rauschen (Standardabweichung 1), optional bandbegrenzt; mit dem eigenen Zufallsgenerator."""
    return M.rauschen(n, lo, hi, RNG)


def langsam(fc):
    """Zirkulärer, langsamer Zufallsverlauf in Schleifenlänge (Mittel 0, Streuung 1)."""
    return rau(N, None, fc)


def korn(n, hz_=60):
    return np.abs(rau(n, None, hz_)) ** 1.5


def kurve(n, punkte):
    """Stückweise linearer Verlauf über n Samples aus Punkten (x in 0..1, Wert)."""
    xs, ys = zip(*punkte)
    return np.interp(np.linspace(0, 1, n), xs, ys)


def glatt(x, ms):
    k = max(3, int(ms * SR / 1000)) | 1
    w = np.hanning(k)
    return np.convolve(x, w / w.sum(), mode="same")


def falte(x, k):
    m = len(x) + len(k)
    return np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(k, m), m)


def ring(buf, i0, sig, pan=0.0, gain=1.0):
    """Signal in den Stereo-Ringpuffer mischen; was über das Ende ragt, landet am Anfang."""
    if sig.ndim == 1:
        w = (pan + 1) * math.pi / 4
        sig = np.vstack((sig * math.cos(w), sig * math.sin(w)))
    n = buf.shape[1]
    i0 %= n
    m = sig.shape[1]
    p = 0
    while p < m:
        k = min(m - p, n - i0)
        buf[:, i0:i0 + k] += gain * sig[:, p:p + k]
        p += k
        i0 = (i0 + k) % n


def raumhall(x, rt, hell, seed, anteil):
    """Zirkulärer Stereohall für Schleifen (läuft um die Naht)."""
    IR = np.fft.rfft(hall_ir(rt, hell, seed), n=N, axis=1)
    return x + anteil * np.fft.irfft(np.fft.rfft(x, axis=1) * IR, n=N, axis=1)


def ton(f, ph=0.0):
    """Durchlaufender Sinus mit ganzzahlig vielen Perioden je Schleife."""
    return np.sin(PI2 * round(f * T) * np.arange(N) / N + ph)


def streu(anzahl, kern, dichte=None, expo=2.0):
    """Viele zufällige Impulse (schwere Amplitudenverteilung), zirkulär mit einem kurzen Kern gefaltet."""
    a = np.zeros(N)
    if dichte is None:
        idx = RNG.integers(0, N, anzahl)
    else:
        idx = RNG.choice(N, anzahl, p=dichte / dichte.sum())
    np.add.at(a, idx, np.minimum(RNG.exponential(1.0, anzahl), 5.0) ** expo * RNG.choice([-1.0, 1.0], anzahl))
    return np.fft.irfft(np.fft.rfft(a) * np.fft.rfft(kern, N), N)


def kern(f, abkl, m=2048):
    t = np.arange(m) / SR
    return np.sin(PI2 * f * t) * np.exp(-t * abkl) * np.minimum(1, t / 0.0002)


def blub(f, steig, d):
    """Luftblase/Tropfen: kurzer Sinus mit steigender Tonhöhe."""
    n, t = zeit(d)
    fr = f * (1 + (steig - 1) * (t / d) ** 0.6)
    s = np.sin(PI2 * np.cumsum(fr) / SR) * np.minimum(1, t / 0.003) * np.exp(-t * 4.5 / d)
    return ausblenden(s, 4)


def bums(fa, fb, abkl, d):
    """Dumpfer Schlag: Sinus, der von fa schnell auf fb fällt."""
    n, t = zeit(d)
    return np.sin(PI2 * np.cumsum(fb + (fa - fb) * np.exp(-t * 30)) / SR) * np.exp(-t * abkl)


def modi(d, liste):
    """Summe gedämpfter Eigenschwingungen (Frequenz, Amplitude, Abklingrate)."""
    n, t = zeit(d)
    return sum(a * np.sin(PI2 * f * t) * np.exp(-t * k) for f, a, k in liste) * np.minimum(1, t / 0.0005)


# ---------------------------------------------------------------- Stimme (additive Formantsynthese)

VOKALE = {"a": (730, 1090, 2440), "e": (530, 1840, 2480), "i": (290, 2250, 3010), "o": (570, 840, 2410),
          "u": (320, 870, 2240), "ö": (500, 1500, 2500), "ä": (660, 1720, 2410)}
VLISTE = list(VOKALE)
# weiche Konsonanten: Formant-Ansatzpunkte (F1, F2) und wie weit die Lautstärke einbricht
KONS = [(250, 1100, 0.22), (250, 1700, 0.22), (350, 1300, 0.4), (250, 900, 0.06), (250, 1700, 0.06),
        (300, 800, 0.35), (280, 2200, 0.45)]


def formantklang(f0, F, B=(70, 90, 130), G=(1.0, 0.6, 0.35), neigung=1.0, fmax=5000.0):
    """Stimmhafter Klang: Obertöne von f0 (Verlauf), deren Stärke der Formantkurve folgt. F: Verläufe oder Zahlen."""
    ph = PI2 * np.cumsum(f0) / SR
    s = np.zeros(len(f0))
    for k in range(1, int(fmax / f0.min()) + 1):
        fk = k * f0
        a = 0.02
        for Fi, Bi, Gi in zip(F, B, G):
            a = a + Gi / np.sqrt(1 + ((fk - Fi) / Bi) ** 2)
        s += a * (fk < fmax) / k ** neigung * np.sin(k * ph)
    return s / np.max(np.abs(s))


def ruf(dauer, f0, F, env, B=(70, 90, 130), G=(1.0, 0.6, 0.35), neigung=1.0, rauh=(0, 0), zittern=0.0,
        hauch=0.0, fmax=6000.0):
    """Tier- oder Menschenlaut: Tonhöhe, Formanten und Hüllkurve als Punktlisten (x in 0..1)."""
    n, t = zeit(dauer)
    f = kurve(n, f0)
    if zittern:
        f = f * (1 + zittern * rau(n, None, 40))
    s = formantklang(f, [kurve(n, x) if isinstance(x, list) else x for x in F], B, G, neigung, fmax)
    if rauh[0]:
        s *= 1 - rauh[1] * (0.5 + 0.5 * np.sin(PI2 * rauh[0] * t))
    if hauch:
        s += hauch * rau(n, 900, 5000)
    return s * kurve(n, env)


def brabbel(dauer, silben, f0, skala=1.0, melodie=None, fmax=5000.0, hauch=0.04):
    """Unverständliches Brabbeln: Silben aus weichem Konsonant + Zufallsvokal, mit Tonhöhenverlauf."""
    n, t = zeit(dauer)
    w = RNG.uniform(0.7, 1.3, silben)
    w[-1] *= 1.3
    g = np.concatenate(([0.0], np.cumsum(w) / w.sum()))
    if melodie is None:
        melodie = 1 + RNG.uniform(-0.12, 0.2, silben)
    xf, f1, f2, f3, xa, amp, xp, pit = [], [], [], [], [], [], [], []
    for i in range(silben):
        a, d = g[i], g[i + 1] - g[i]
        v = VOKALE[VLISTE[RNG.integers(len(VLISTE))]]
        k1, k2, dip = KONS[RNG.integers(len(KONS))]
        akz = RNG.uniform(0.75, 1.0)
        xf += [a, a + 0.3 * d, a + 0.75 * d]
        f1 += [k1, v[0], v[0]]
        f2 += [0.5 * (k2 + v[1]), v[1], v[1]]
        f3 += [0.5 * (2500 + v[2]), v[2], v[2]]
        xa += [a, a + 0.22 * d, a + 0.7 * d]
        amp += [dip * akz, akz, 0.8 * akz]
        xp += [a + 0.1 * d, a + 0.5 * d, a + 0.9 * d]
        pit += [melodie[i] * 0.97, melodie[i] * 1.03, melodie[i] * 0.98]
    amp[0] = 0.0
    xa.append(1.0)
    amp.append(0.0)
    x = np.linspace(0, 1, n)
    F = [np.interp(x, xf, f) * skala for f in (f1, f2, f3)]
    f0t = f0 * np.interp(x, xp, pit) * (1 - 0.06 * x) * (1 + 0.012 * np.sin(PI2 * 5.5 * t + RNG.uniform(0, PI2)))
    f0t *= 1 + 0.01 * rau(n, None, 30)
    env = glatt(np.interp(x, xa, amp), 12)
    s = formantklang(f0t, F, neigung=0.9, fmax=fmax) + hauch * rau(n, 1500, 4500)
    return ausblenden(s * env, 10, 4)


# ---------------------------------------------------------------- Umgebungsschleifen (Stereo, Ringpuffer)

def piep(d, fa, fb, vib=0.0, vhz=30.0, form=1.0):
    """Einzelner Vogelton: Sinus mit Tonhöhengleiten und schneller Frequenzmodulation."""
    n, t = zeit(d)
    x = t / d
    f = fa * (fb / fa) ** (x ** form) * (1 + vib * np.sin(PI2 * vhz * t))
    ph = PI2 * np.cumsum(f) / SR
    return (np.sin(ph) + 0.12 * np.sin(2 * ph)) * np.sin(np.pi * x ** 0.7) ** 1.5


def vogelphrase(art, fc):
    teile = []
    if art == 0:                                   # absteigende "tsiu"-Rufe
        ab = RNG.uniform(0.17, 0.24)
        for i in range(RNG.integers(2, 5)):
            teile.append((i * ab, piep(0.11, fc * 1.35, fc * 0.8, 0.01, 45), 1.0))
    elif art == 1:                                 # Triller auf einem Ton
        ab = RNG.uniform(0.05, 0.07)
        k = RNG.integers(6, 13)
        for i in range(k):
            teile.append((i * ab, piep(0.036, fc * 0.93, fc * 1.05), 0.5 + 0.5 * math.sin(math.pi * (i + 0.5) / k)))
    elif art == 2:                                 # Zweiklang "zi-zä" (meisenartig)
        for i in range(RNG.integers(2, 4)):
            teile.append((i * 0.3, piep(0.12, fc * 1.26, fc * 1.24, 0.004, 28), 1.0))
            teile.append((i * 0.3 + 0.14, piep(0.13, fc, fc * 0.97, 0.004, 28), 0.85))
    else:                                          # flötendes Motiv mit wechselnden Tönen (amselartig)
        t0 = 0.0
        for i in range(RNG.integers(4, 8)):
            d = RNG.uniform(0.07, 0.16)
            f = fc * 2 ** (RNG.integers(-4, 6) / 12)
            teile.append((t0, piep(d, f, f * RNG.uniform(0.88, 1.15), 0.03, RNG.uniform(22, 38)), RNG.uniform(0.6, 1)))
            t0 += d + RNG.uniform(0.01, 0.07)
    s = np.zeros(int(max(a + len(b) / SR for a, b, _ in teile) * SR) + 2)
    for a, b, g in teile:
        lege(s, a, b, g)
    return s


def amb_tag():
    """Wiese am Tag: leichter Wind, Blätterrascheln, vereinzelt Vögel."""
    g = np.clip(1 + 0.45 * langsam(0.12) + 0.15 * langsam(0.6), 0.25, None)
    y = np.vstack([rau(N, 180, 800) * g * (1 + 0.15 * langsam(0.3)) + 0.3 * rau(N, 2500, 7000) * g ** 2
                   for _ in range(2)]) * 0.085
    vogel = np.zeros((2, N))
    k = 10
    for i in range(k):
        art = int(RNG.integers(0, 4))
        fc = RNG.uniform(*((3200, 5200), (4000, 6200), (3400, 4800), (1900, 2900))[art])
        ring(vogel, int((i + RNG.uniform(0.1, 0.9)) * T / k * SR), vogelphrase(art, fc),
             RNG.uniform(-0.85, 0.85), RNG.uniform(0.22, 1.0))
    return y + raumhall(vogel, 1.0, 6000, 51, 0.22)


def zirp(fc, pulse, abstand=0.017, pd=0.012):
    s = np.zeros(int((pulse * abstand + 0.01) * SR))
    for i in range(pulse):
        n, t = zeit(pd)
        lege(s, i * abstand, np.sin(PI2 * fc * t) * np.sin(np.pi * t / pd) ** 2, 0.6 + 0.4 * i / pulse)
    return s


def huu(d, f):
    n, t = zeit(d)
    x = t / d
    ph = PI2 * np.cumsum(f * (1 + 0.04 * np.sin(np.pi * x)) * (1 - 0.05 * x)) / SR
    return (np.sin(ph) + 0.15 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)) * np.sin(np.pi * x ** 0.8) ** 1.2


def amb_nacht():
    """Nacht: mehrere Grillen, durchgehender leiser Zirp-Teppich, sehr leiser Wind, ein Eulenruf je Durchlauf."""
    y = np.vstack([rau(N, 120, 500) for _ in range(2)]) * np.clip(1 + 0.4 * langsam(0.1), 0.3, None) * 0.035
    for fc, pulse, periode, pan, gain in ((4350, 3, 0.52, -0.6, 0.55), (4800, 4, 0.71, 0.5, 0.4), (3950, 3, 0.44, 0.15, 0.22),
                                          (5200, 2, 0.37, -0.25, 0.14), (4550, 3, 0.63, 0.8, 0.18)):
        z = zirp(fc, pulse)
        k = round(T / periode)
        aktiv = np.clip(0.75 + 0.5 * langsam(0.15), 0.0, 1.0)          # Grillen setzen zeitweise aus
        for i in range(k):
            i0 = int((i + RNG.uniform(-0.04, 0.04)) * N / k) % N
            if aktiv[i0] > 0.05:
                ring(y, i0, z, pan, gain * aktiv[i0] * RNG.uniform(0.85, 1.0))
    teppich = ton(3100) * np.abs(ton(21.0)) ** 4 * np.clip(1 + 0.4 * langsam(0.2), 0.2, None)
    ring(y, 0, teppich, -0.2, 0.035)
    eule = np.zeros((2, N))
    for t0, d, f, g in ((0.0, 0.42, 352, 0.8), (0.72, 0.17, 345, 0.6), (0.97, 0.17, 345, 0.7), (1.38, 0.62, 338, 1.0)):
        ring(eule, int((8.2 + t0) * SR), huu(d, f), -0.45, 0.42 * g)
    return y + raumhall(eule, 2.0, 2500, 52, 0.6)


def amb_regen():
    """Gleichmäßiger Regen: Rauschbett, dichter Teppich feiner Tropfen, einzelne nahe Tropfen."""
    kan = []
    for _ in range(2):
        bett = 0.5 * rau(N, 400, 3000) + 0.55 * rau(N, 2000, 9000) + 0.3 * rau(N, 80, 400)
        bett *= 1 + 0.1 * langsam(0.3)
        tr = sum(streu(int(T * rate), kern(f, ab), expo=1.5) * g
                 for f, ab, rate, g in ((2300, 900, 260, 0.06), (3900, 1400, 320, 0.05), (6100, 2200, 300, 0.04),
                                        (1300, 500, 60, 0.07)))
        kan.append(0.11 * bett + tr)
    y = np.vstack(kan)
    for _ in range(int(T * 5)):
        ring(y, int(RNG.integers(N)), blub(RNG.uniform(700, 2300), RNG.uniform(1.2, 1.7), RNG.uniform(0.02, 0.05)),
             RNG.uniform(-0.9, 0.9), 0.5 * RNG.uniform(0.15, 1.0) ** 2)
    return y


def pfeifen(f):
    """Schmalbandiges Rauschen um eine wandernde Frequenz; Phase schließt sich über die Schleife."""
    zyk = f.sum() / SR
    return rau(N, None, 20) * np.sin(PI2 * np.cumsum(f * round(zyk) / zyk) / SR)


def amb_wind():
    """Starker, böiger Wind: je kräftiger die Böe, desto heller; dazu heulendes Pfeifen."""
    g = 0.3 + 0.7 * (0.5 + 0.5 * np.tanh(0.9 * langsam(0.16) + 0.3 * langsam(0.9)))   # Böenstärke 0,3..1
    kan = []
    for c in range(2):
        gc = np.clip(g * (1 + 0.2 * langsam(0.3)), 0, None) * (1 + 0.12 * langsam(3.0))
        s = 0.8 * rau(N, 40, 160) * gc + rau(N, 150, 450) * gc ** 1.2 + 0.9 * rau(N, 400, 1100) * gc ** 2
        s += 0.45 * rau(N, 1000, 3500) * gc ** 3
        f = (430, 690)[c] * (1 + 0.55 * g + 0.04 * langsam(0.5))
        s += 0.9 * pfeifen(f) * gc ** 2.2 + 0.35 * pfeifen(f * 1.51) * gc ** 3
        kan.append(s)
    y = np.vstack(kan)
    return y + 0.25 * y[::-1]                      # etwas Übersprechen, damit die Kanäle nicht auseinanderfallen


def amb_hoehle():
    """Höhle: tiefes Dröhnen mit langsamen Schwebungen, leiser Luftzug, hallende Wassertropfen."""
    kan = []
    for c in range(2):
        s = np.zeros(N)
        for f, a in ((55, 1.0), (55.17, 0.8), (82.4, 0.6), (82.65, 0.45), (110.1, 0.4), (164.9, 0.16), (220.3, 0.07)):
            s += a * ton(f + 0.04 * c, RNG.uniform(0, PI2)) * np.clip(1 + 0.35 * langsam(0.08), 0.2, None)
        s = 0.05 * s + 0.07 * rau(N, 25, 90) * np.clip(1 + 0.5 * langsam(0.1), 0.2, None)
        s += 0.012 * rau(N, 300, 1200) * np.clip(1 + 0.5 * langsam(0.2), 0.2, None)
        kan.append(s)
    y = np.vstack(kan)
    tropf = np.zeros((2, N))
    k = 9
    for i in range(k):
        i0 = int((i + RNG.uniform(0.1, 0.9)) * T / k * SR)
        f = RNG.uniform(750, 1700)
        pan = RNG.uniform(-0.7, 0.7)
        gain = RNG.uniform(0.3, 0.75)
        ring(tropf, i0, blub(f, 1.5, 0.16), pan, gain)
        if RNG.random() < 0.6:
            ring(tropf, i0 + int(RNG.uniform(0.06, 0.1) * SR), blub(f * RNG.uniform(1.3, 1.7), 1.3, 0.09), pan, gain * 0.4)
    return y + raumhall(tropf, 3.5, 3000, 53, 1.3)


def amb_feuer():
    """Kaminfeuer: tiefes Fauchen mit Flackern, dichtes feines Knistern, einzelne Knackser."""
    dichte = np.clip(1 + 0.7 * langsam(0.5), 0.15, None)
    kan = []
    for _ in range(2):
        s = 0.09 * rau(N, 40, 350) * np.clip(1 + 0.3 * rau(N, None, 8), 0.2, None)
        s += 0.012 * rau(N, 1500, 6000) * np.clip(1 + 0.5 * langsam(3.0), 0.2, None)
        for f, ab, rate, gg in ((1800, 1500, 14, 0.05), (3200, 2500, 22, 0.04), (5500, 4000, 22, 0.03)):
            s += gg * streu(int(T * rate), kern(f, ab, 512), dichte, expo=1.6)
        kan.append(s)
    y = np.vstack(kan)
    for _ in range(int(T * 2.2)):
        n, t = zeit(0.05)
        p = rau(n, RNG.uniform(300, 900), RNG.uniform(1800, 4000)) * np.exp(-t * RNG.uniform(70, 160))
        p += 0.5 * np.sin(PI2 * RNG.uniform(90, 180) * t) * np.exp(-t * 90)
        ring(y, int(RNG.choice(N, p=dichte / dichte.sum())), ausblenden(p, 3), RNG.uniform(-0.5, 0.5),
             0.28 * min(RNG.exponential(0.5), 1.3))
    return y


def krug():
    """Tonkrug auf Holztisch: helles, kurz gedämpftes Klacken plus dumpfer Aufsetzer."""
    f = RNG.uniform(650, 1150)
    s = modi(0.12, [(f, 1, 70), (f * 2.32, 0.5, 90), (f * 3.71, 0.3, 120), (f * 5.2, 0.15, 160)])
    n, t = zeit(0.12)
    return ausblenden(s + 0.6 * rau(n, None, 500) * np.exp(-t * 70) + 0.3 * rau(n, 2000, None) * np.exp(-t * 400), 5)


def amb_wirtshaus():
    """Wirtshaus: viele überlagerte Brabbelstimmen (jede Phrase mehrfach, leicht umgestimmt), Krugklappern."""
    stimmen = np.zeros((2, N))
    for _ in range(26):
        frau = RNG.random() < 0.3
        d = RNG.uniform(1.0, 2.4)
        s = brabbel(d, int(d * RNG.uniform(3.5, 5.0)), RNG.uniform(185, 250) if frau else RNG.uniform(92, 150),
                    1.16 if frau else 1.0, fmax=3800.0, hauch=0.03)
        for _ in range(4):
            fak = RNG.uniform(0.92, 1.08)
            r = np.interp(np.arange(0, len(s) - 1, fak), np.arange(len(s)), s)
            ring(stimmen, int(RNG.integers(N)), r, RNG.uniform(-0.9, 0.9), RNG.uniform(0.25, 1.0) ** 1.5)
    stimmen = fftfilter(stimmen, lambda f: tp(f, 3200, 1))
    y = raumhall(stimmen, 0.9, 3500, 54, 0.9)
    y *= 0.16 / math.sqrt((y ** 2).mean())
    y += 0.012 * np.vstack([rau(N, 60, 300) for _ in range(2)])
    kl = np.zeros((2, N))
    k = 5
    for i in range(k):
        i0 = int((i + RNG.uniform(0.15, 0.85)) * T / k * SR)
        pan = RNG.uniform(-0.7, 0.7)
        t0 = 0.0
        for j in range(RNG.integers(1, 4)):
            ring(kl, i0 + int(t0 * SR), krug(), pan, RNG.uniform(0.25, 0.5))
            t0 += RNG.uniform(0.09, 0.22)
    return y + raumhall(kl, 0.7, 4000, 55, 0.35)


def amb_wasser():
    """Seeufer: sanft anrollende kleine Wellen, auslaufendes Zischen, Glucksen und Plätschern."""
    m = int(3.4 * SR)
    x = np.arange(m) / SR
    form = (1 - np.exp(-x / 0.4)) * np.exp(-x / 0.95)
    form = ausblenden(form / form.max(), 400)
    env = np.zeros((1, N))
    k = 7
    for i in range(k):
        ring(env, int((i + RNG.uniform(-0.15, 0.15)) * N / k), form[None, :], gain=RNG.uniform(0.6, 1.0))
    env = env[0]
    kan = []
    for c in range(2):
        e = np.roll(env, int((0.2 * c - 0.1) * SR))
        s = 0.1 * rau(N, 250, 1800) * (0.3 + e) + 0.045 * rau(N, 2500, 8000) * np.roll(e, int(0.55 * SR)) ** 1.5
        s += 0.03 * rau(N, 600, 2500) * np.abs(rau(N, None, 12)) ** 2 * (0.4 + e)
        kan.append(s)
    y = np.vstack(kan)
    d = 0.12 + np.roll(env, int(0.3 * SR))
    for i0 in RNG.choice(N, int(T * 7), p=d / d.sum()):
        ring(y, int(i0), blub(RNG.uniform(350, 1500), RNG.uniform(1.3, 2.0), RNG.uniform(0.03, 0.09)),
             RNG.uniform(-0.8, 0.8), 0.3 * RNG.uniform(0.2, 1.0) ** 2)
    return y


AMB = {"tag": amb_tag, "nacht": amb_nacht, "regen": amb_regen, "wind": amb_wind, "hoehle": amb_hoehle,
       "feuer": amb_feuer, "wirtshaus": amb_wirtshaus, "wasser": amb_wasser}


# ---------------------------------------------------------------- Einzelklänge (Mono)

def sfx_donner():
    n, t = zeit(2.9)
    env = np.zeros(n)
    for t0, a, ab in ((0.0, 1.0, 3.0), (0.3, 0.6, 4.0), (0.75, 0.8, 2.5), (1.35, 0.45, 2.5), (1.85, 0.3, 2.5)):
        x = np.clip(t - t0, 0, None)
        env += a * np.minimum(1, x / 0.03) * np.exp(-x * ab) * (t >= t0)
    env *= 0.6 + 0.4 * np.abs(rau(n, None, 6))
    s = rau(n, 25, 140) * env + 0.45 * rau(n, 100, 600) * env ** 1.5
    s += 0.5 * rau(n, 400, 3000) * korn(n, 80) * np.exp(-t * 8)
    return ausblenden(hallen(s, 1.5, 0.4, 31)[:int(3.0 * SR)], 500)


def sfx_huhn():
    s = np.zeros(int(1.05 * SR))
    for t0, f, g in ((0.0, 430, 0.6), (0.15, 450, 0.7), (0.29, 440, 0.65), (0.42, 470, 0.75), (0.54, 500, 0.8)):
        lege(s, t0, ruf(0.075, [(0, f), (0.3, f * 1.22), (1, f * 0.95)], (1200, 2300, 3400),
                        [(0, 0), (0.1, 1), (0.5, 0.6), (1, 0)], B=(150, 200, 250), neigung=0.5, rauh=(70, 0.3)), g)
    lege(s, 0.64, ruf(0.34, [(0, 480), (0.25, 780), (0.6, 720), (1, 470)],
                      ([(0, 900), (0.3, 1500), (1, 1100)], 2600, 3600),
                      [(0, 0), (0.08, 1), (0.6, 0.85), (1, 0)], B=(150, 200, 250), neigung=0.5, rauh=(63, 0.5)))
    return s


def sfx_ente():
    s = np.zeros(int(0.75 * SR))
    for t0, d, f, g in ((0.0, 0.22, 265, 1.0), (0.27, 0.17, 250, 0.8), (0.49, 0.16, 238, 0.65)):
        lege(s, t0, ruf(d, [(0, f), (0.2, f * 1.1), (1, f * 0.82)], ([(0, 500), (0.25, 1000), (1, 850)], 1900, 2900),
                        [(0, 0), (0.08, 1), (0.6, 0.8), (1, 0)], B=(120, 150, 200), G=(1, 0.9, 0.5), neigung=0.6,
                        rauh=(f * 0.5, 0.55), zittern=0.02, hauch=0.03), g)
    return s


def sfx_wolf():
    s = np.zeros(int(0.85 * SR))
    lege(s, 0, ruf(0.58, [(0, 68), (0.6, 78), (1, 95)], (420, 1000, 2400), [(0, 0), (0.25, 0.5), (0.9, 0.9), (1, 0.5)],
                   B=(110, 140, 200), neigung=0.8, rauh=(27, 0.65), zittern=0.07, hauch=0.06), 0.75)
    lege(s, 0.56, ruf(0.2, [(0, 170), (0.2, 250), (1, 130)], ([(0, 400), (0.3, 800), (1, 500)], 1300, 2500),
                      [(0, 0.3), (0.1, 1), (0.5, 0.7), (1, 0)], B=(120, 150, 200), neigung=0.7, rauh=(55, 0.4),
                      zittern=0.05, hauch=0.2))
    return np.tanh(1.8 * s)


def sfx_heulen():
    s = ruf(2.2, [(0, 285), (0.16, 425), (0.5, 455), (0.8, 440), (1, 320)], (520, 1050, 2400),
            [(0, 0), (0.12, 0.7), (0.5, 1), (0.82, 0.8), (1, 0)], B=(90, 110, 150), G=(1, 0.45, 0.08), neigung=1.5,
            zittern=0.006, hauch=0.01)
    n, t = zeit(2.2)
    s *= 1 + 0.06 * np.sin(PI2 * 5 * t) * np.clip(t - 0.6, 0, 1)
    return ausblenden(hallen(s, 1.3, 0.35, 32)[:int(2.6 * SR)], 300)


def sfx_hund():
    s = np.zeros(int(0.5 * SR))
    for t0, f, g in ((0.0, 320, 0.9), (0.25, 350, 1.0)):
        lege(s, t0, ruf(0.15, [(0, f), (0.25, f * 1.45), (1, f * 0.85)], ([(0, 500), (0.3, 900), (1, 600)], 1500, 2700),
                        [(0, 0.2), (0.12, 1), (0.5, 0.6), (1, 0)], B=(120, 150, 200), neigung=0.8, rauh=(75, 0.3),
                        zittern=0.03, hauch=0.15), g)
    return s


def sfx_geist():
    n, t = zeit(1.9)
    x = t / t[-1]
    r = rau(n)
    hauch = svf_bp(r, kurve(n, [(0, 450), (0.4, 800), (1, 380)]), 0.12)
    hauch += 0.6 * svf_bp(r, kurve(n, [(0, 1300), (0.5, 1050), (1, 1700)]), 0.1)
    env = np.sin(np.pi * x ** 0.7) ** 1.5 * (1 + 0.3 * x * np.sin(PI2 * 6.5 * t))
    gl = kurve(n, [(0, 1.03), (1, 0.93)])
    klang = sum(np.sin(PI2 * np.cumsum(f * gl) / SR + RNG.uniform(0, PI2)) for f in (311, 317, 440, 447))
    s = hauch / np.abs(hauch).max() * env + 0.06 * klang * env ** 2
    return ausblenden(hallen(s, 1.6, 0.5, 33)[:int(2.5 * SR)], 400)


def sfx_sumpf():
    n, t = zeit(1.3)
    s = 0.12 * rau(n, None, 300) * korn(n, 25) * np.sin(np.pi * t / t[-1])
    for t0 in sorted(RNG.uniform(0.0, 0.95, 9)):
        lege(s, t0, blub(RNG.uniform(120, 340), RNG.uniform(1.6, 2.3), RNG.uniform(0.05, 0.11)), RNG.uniform(0.4, 1.0))
    lege(s, 1.0, blub(95, 2.4, 0.16), 1.0)
    return fftfilter(s, lambda f: tp(f, 2500, 1))


def sfx_tuer():
    s = np.zeros(int(1.1 * SR))
    n, t = zeit(0.56)                                   # Knarren: unregelmäßige Haft-Gleit-Impulse regen Holz an
    rate = kurve(n, [(0, 22), (0.5, 60), (1, 30)]) * (1 + 0.2 * rau(n, None, 15))
    imp = (np.diff(np.floor(np.cumsum(rate) / SR), prepend=0) > 0) * RNG.uniform(0.5, 1.0, n)
    kn = falte(imp, modi(0.05, [(520, 1, 70), (1130, 0.7, 90), (1870, 0.5, 120), (2640, 0.3, 150)]))[:n]
    lege(s, 0, kn * np.sin(np.pi * t / t[-1]) ** 0.7, 0.5)
    m, tt = zeit(0.3)                                   # Zufallen: dumpfer Schlag, Holzmoden, Riegel
    zu = bums(140, 80, 25, 0.3) + 0.7 * modi(0.3, [(240, 1, 40), (410, 0.6, 50), (690, 0.4, 70)])
    zu += 0.8 * rau(m, None, 1200) * np.exp(-tt * 80)
    lege(s, 0.62, zu)
    lege(s, 0.72, ping(1900, 0.05, 90, ((1, 1.0), (1.63, 0.5))) + 0.5 * rau(int(0.05 * SR), 3000, None) * np.exp(-zeit(0.05)[1] * 300), 0.3)
    return hallen(s, 0.4, 0.2, 34)[:int(1.3 * SR)]


def sfx_pfeil():
    s = np.zeros(int(0.55 * SR))
    lege(s, 0, M.zupf(mi("A2"), 0.3, 1.0, expo=0.8, ort=0.3, daempf=9.0))
    m, tt = zeit(0.03)
    lege(s, 0, rau(m, 2000, None) * np.exp(-tt * 300), 0.5)
    n, t = zeit(0.45)
    x = t / t[-1]
    z = svf_bp(rau(n), kurve(n, [(0, 1500), (0.35, 5200), (1, 2400)]), 0.4) * np.sin(np.pi * x ** 0.45) ** 2
    lege(s, 0.02, z / np.abs(z).max(), 0.8)
    return s


def sfx_schwer():
    s = np.zeros(int(0.95 * SR))
    n, t = zeit(0.17)
    w = svf_bp(rau(n), kurve(n, [(0, 300), (1, 1300)]), 0.5) * (t / t[-1]) ** 2
    lege(s, 0, w / np.abs(w).max(), 0.25)
    m, tt = zeit(0.6)
    h = bums(115, 42, 8, 0.6) + 0.7 * rau(m, None, 700) * np.exp(-tt * 28)
    h += 0.45 * rau(m, 800, 3000) * korn(m, 90) * np.exp(-tt * 22)
    lege(s, 0.16, np.tanh(2.5 * h))
    return hallen(s, 0.5, 0.2, 35)[:int(1.1 * SR)]


def sfx_falle():
    s = np.zeros(int(0.6 * SR))
    m, tt = zeit(0.04)
    lege(s, 0, rau(m, 1500, 5000) * np.exp(-tt * 200) + 0.6 * np.sin(PI2 * 900 * tt) * np.exp(-tt * 120), 0.6)
    for t0, sk in ((0.03, 1.0), (0.042, 1.07), (0.055, 0.94)):
        n, t = zeit(0.5)
        k = sum(a * (np.sin(PI2 * f * sk * t) + 0.6 * np.sin(PI2 * (f * sk + 11) * t + 1)) * np.exp(-t * d)
                for f, a, d in ((2900, 1, 13), (4100, 0.8, 16), (5300, 0.6, 20), (6700, 0.45, 24), (7900, 0.3, 28),
                                (9500, 0.2, 34)))
        k = k * 0.3 * np.minimum(1, t / 0.0004) + 0.9 * rau(n, 5000, None) * np.exp(-t * 45) * np.minimum(1, t / 0.004)
        lege(s, t0, k, 0.6)
    lege(s, 0.03, bums(260, 150, 50, 0.1), 0.8)
    return s


def sfx_hebel():
    s = np.zeros(int(2.0 * SR))
    t0 = 0.0
    for i in range(5):                                  # Ratsche des Hebels
        f = 760 + 70 * i
        m, tt = zeit(0.05)
        lege(s, t0, modi(0.05, [(f, 1, 80), (f * 2.4, 0.5, 110)]) + 0.5 * rau(m, 2000, 6000) * np.exp(-tt * 250), 0.35)
        t0 += 0.07 - 0.007 * i
    lege(s, 0.33, bums(190, 110, 30, 0.2) + 0.5 * modi(0.2, [(1400, 1, 35), (2270, 0.5, 50)]), 0.6)
    n, t = zeit(1.25)                                   # Steintor schleift
    env = np.minimum(1, t / 0.15) * np.minimum(1, (t[-1] - t) / 0.1)
    stein = rau(n, 50, 450) * (0.35 + korn(n, 35)) + 0.35 * rau(n, 500, 1800) * korn(n, 70)
    lege(s, 0.45, stein * env, 0.3)
    m, tt = zeit(0.3)
    lege(s, 1.68, bums(95, 50, 12, 0.3) + 0.7 * rau(m, None, 300) * np.exp(-tt * 25), 0.9)
    return ausblenden(hallen(s, 0.9, 0.3, 36)[:int(2.4 * SR)], 250)


def sfx_holz():
    n, t = zeit(0.4)
    s = 0.9 * rau(n, 1000, 6000) * np.exp(-t * 250)
    s += modi(0.4, [(180, 1, 35), (330, 0.8, 45), (560, 0.6, 60), (910, 0.4, 75), (1400, 0.25, 90)])
    s += bums(160, 90, 40, 0.4)
    m, tt = zeit(0.06)
    lege(s, 0.035, rau(m, 1500, 5000) * korn(m, 200) * np.exp(-tt * 70), 0.35)
    return s


def sfx_reise():
    n, t = zeit(1.5)
    x = t / t[-1]
    env = np.where(t < 1.0, (t / 1.0) ** 2, np.exp(-(t - 1.0) * 5))
    s = np.zeros(n)
    for name, a in (("D5", 1.0), ("A5", 0.8), ("D6", 0.7), ("F#6", 0.5), ("A6", 0.4)):
        for c in (-7, 6):
            s += a * np.sin(PI2 * hz(mi(name)) * M.cent(c) * t + RNG.uniform(0, PI2))
    s = 0.12 * s * env * (1 + 0.25 * np.sin(PI2 * 9 * t))
    z = svf_bp(rau(n), 2000 * 4.5 ** np.clip(t / 1.0, 0, 1), 0.3)
    s += 0.25 * z / np.abs(z).max() * env
    for i in range(22):                                 # Funkeln, zum Höhepunkt hin dichter
        t0 = 1.0 * (i / 22) ** 0.6
        lege(s, t0, ping(hz(86 + int(RNG.choice([0, 2, 4, 7, 9, 12, 14, 16]))), 0.25, 22), 0.08 + 0.1 * i / 22)
    lege(s, 1.0, M.glocke(mi("D6"), 0.5), 0.3)
    lege(s, 1.0, M.glocke(mi("A6"), 0.5), 0.2)
    return ausblenden(hallen(s, 0.9, 0.4, 37)[:int(1.6 * SR)], 250)


def sfx_fest():
    s = np.zeros(int(1.6 * SR))
    for f0 in (122, 138, 150, 165, 185, 225, 250, 290, 320, 205):
        f = f0 * RNG.uniform(0.96, 1.04)
        sk = 1.0 if f < 200 else 1.16
        v = VOKALE["aeoa"[RNG.integers(4)]]
        d = RNG.uniform(0.7, 1.1)
        r = ruf(d, [(0, f), (0.15, f * 1.45), (0.5, f * 1.35), (1, f * 0.95)],
                ([(0, 300 * sk), (0.2, v[0] * sk), (1, v[0] * sk)], [(0, 2100 * sk), (0.2, v[1] * sk), (1, v[1] * sk)],
                 v[2] * sk), [(0, 0), (0.1, 1), (0.6, 0.8), (1, 0)], zittern=0.02, hauch=0.08, fmax=5000.0)
        lege(s, RNG.uniform(0, 0.3), r, RNG.uniform(0.5, 1.0))
    for _ in range(9):                                  # ein paar Klatscher
        m, tt = zeit(0.04)
        lege(s, RNG.uniform(0.15, 1.25), rau(m, RNG.uniform(700, 1100), 3500) * np.exp(-tt * 75), RNG.uniform(0.5, 0.9))
    return ausblenden(hallen(s, 0.6, 0.3, 38)[:int(1.8 * SR)], 200)


def stimme(f0, skala, dauer, melodie):
    return lambda: brabbel(dauer, len(melodie), f0, skala, melodie)


SFX = {"sfx_donner": sfx_donner, "sfx_huhn": sfx_huhn, "sfx_ente": sfx_ente, "sfx_wolf": sfx_wolf,
       "sfx_heulen": sfx_heulen, "sfx_hund": sfx_hund, "sfx_geist": sfx_geist, "sfx_sumpf": sfx_sumpf,
       "sfx_tuer": sfx_tuer, "sfx_pfeil": sfx_pfeil, "sfx_schwer": sfx_schwer, "sfx_falle": sfx_falle,
       "sfx_hebel": sfx_hebel, "sfx_holz": sfx_holz, "sfx_reise": sfx_reise, "sfx_fest": sfx_fest}
# Stimmlaute: 1 = Aussage (hoch, dann ab), 2 = Frage (am Ende hoch), 3 = kurzer Ausruf
for _g, _f0, _sk in (("m", 118, 1.0), ("w", 212, 1.16)):
    SFX["stimme_%s1" % _g] = stimme(_f0, _sk, 0.56, [1.0, 1.14, 0.93])
    SFX["stimme_%s2" % _g] = stimme(_f0, _sk, 0.76, [1.0, 0.95, 1.08, 1.26])
    SFX["stimme_%s3" % _g] = stimme(_f0, _sk, 0.44, [1.18, 0.98])


# ---------------------------------------------------------------- Ausgabe und Prüfung

def volumedetect(pfad):
    """Pegel mit ffmpeg messen: (max_volume, mean_volume) in dB."""
    err = subprocess.run([FFMPEG, "-hide_banner", "-nostats", "-i", pfad, "-af", "volumedetect", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    w = [re.search(r"%s_volume: (-?[\d.]+) dB" % k, err) for k in ("max", "mean")]
    return tuple(float(x.group(1)) if x else float("nan") for x in w)


def schleife(name, fn, tmpdir):
    global RNG
    t0 = time.time()
    RNG = np.random.default_rng(300 + sum(map(ord, name)))
    y = fftfilter(fn(), lambda f: hp(f, 30, 2) * tp(f, 15000, 1))      # zirkulär, also loopsicher
    y *= 10 ** (-9 / 20) / np.max(np.abs(y))
    tmp = os.path.join(tmpdir, "amb_%s.wav" % name)
    ogg = os.path.join(AUDIO, "amb_%s.ogg" % name)
    q = schreibe_wav(tmp, y)
    try:
        subprocess.run([FFMPEG, "-y", "-v", "error", "-i", tmp] + encoder() + ["-ac", "2", "-ar", str(SR), ogg], check=True)
    finally:
        os.remove(tmp)                                                 # Zwischen-WAV sofort wieder löschen
    # Prüfung wie in musik.py: OGG zurückdekodieren, Länge und Naht mit dem Original vergleichen
    roh = subprocess.run([FFMPEG, "-v", "error", "-i", ogg, "-f", "s16le", "-ac", "2", "-"], capture_output=True, check=True).stdout
    z = np.frombuffer(roh, dtype="<i2").reshape(-1, 2).T
    s0, v0 = naht(q)
    s1, v1 = naht(z)
    k = SR // 20
    rms = lambda a: db(math.sqrt((a.astype(float) ** 2).mean()) / 32768)
    print("amb_%s.ogg  %.2f s  Spitze %.1f dBFS (OGG %.1f)  RMS %.1f dBFS  Samples %d/%d  Naht vorher %d (%.2f des größten Sample-Schritts), OGG %d (%.2f)  [%.1f s]"
          % (name, q.shape[1] / SR, db(np.abs(q).max() / 32768), db(np.abs(z).max() / 32768), rms(q), z.shape[1],
             q.shape[1], s0, v0, s1, v1, time.time() - t0))
    print("    RMS letzte/erste 50 ms: %.1f / %.1f dBFS" % (rms(q[:, -k:]), rms(q[:, :k])), end="")
    if z.shape[1] == q.shape[1]:
        f = z.astype(float) - q.astype(float)
        rand = math.sqrt((np.concatenate((f[:, :k], f[:, -k:]), axis=1) ** 2).mean())
        print(",  Kodierfehler an den Rändern %.1f dBFS, im ganzen Stück %.1f dBFS"
              % (db(rand / 32768), db(math.sqrt((f ** 2).mean()) / 32768)))
    else:
        print(",  ACHTUNG: Länge nach dem Kodieren verändert")
    return ogg, q.shape[1] / SR


def einzel(name, fn):
    global RNG
    RNG = np.random.default_rng(200 + sum(map(ord, name)))
    s = np.array(fn(), dtype=float)
    s -= s.mean()
    ausblenden(s, 6, 0.5)
    s *= 10 ** (-3 / 20) / np.max(np.abs(s))
    pfad = os.path.join(AUDIO, name + ".wav")
    q = schreibe_wav(pfad, s)
    return pfad, q.shape[1] / SR


def main():
    os.makedirs(AUDIO, exist_ok=True)
    wahl = sys.argv[1:]
    will = lambda name, gruppe: not wahl or name in wahl or gruppe in wahl
    t0 = time.time()
    fertig = []
    with tempfile.TemporaryDirectory() as tmpdir:
        for name, fn in AMB.items():
            if will("amb_" + name, "amb"):
                fertig.append(schleife(name, fn, tmpdir))
    for name, fn in SFX.items():
        if will(name, name.split("_")[0]):
            fertig.append(einzel(name, fn))
    print("\nPegelprüfung mit ffmpeg volumedetect:")
    for pfad, dauer in fertig:
        mx, mittel = volumedetect(pfad)
        print("  %-20s %6.2f s  max %6.1f dB  mittel %6.1f dB%s"
              % (os.path.basename(pfad), dauer, mx, mittel, "   ACHTUNG: clippt" if not mx < -0.05 else ""))
    print("Gesamtlaufzeit %.1f s" % (time.time() - t0))


if __name__ == "__main__":
    main()
