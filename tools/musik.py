#!/usr/bin/env python3
# Glutwacht: Musik und Soundeffekte, vollständig synthetisch erzeugt (keine Samples).
# Aufruf:  python3 tools/musik.py            alles
#          python3 tools/musik.py dorf sfx   nur einzelne Teile (dorf wildnis kampf menue sfx)
# Braucht numpy und ffmpeg (OGG Vorbis). Ergebnisse landen in ../audio/.
#
# Loop-Prinzip: Jedes Stück ist ein Ringpuffer mit taktgenauer Länge. Ausklingende Noten
# werden über das Ende hinaus an den Anfang gefaltet, Hall, Filter und Kompressor rechnen
# zirkulär (FFT). Damit gibt es an der Naht weder Knacken noch Hallabriss.

import math
import os
import shutil
import subprocess
import sys
import time
import wave

import numpy as np

SR = 44100
TAB = 4096
PI2 = 2 * math.pi
WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(WURZEL, "audio")
FFMPEG = "/opt/homebrew/bin/ffmpeg" if os.path.exists("/opt/homebrew/bin/ffmpeg") else (shutil.which("ffmpeg") or "ffmpeg")
RNG = np.random.default_rng(1)


# ---------------------------------------------------------------- Grundlagen

NOTEN = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}  # B = deutsches H


def mi(s):
    """Notenname ("F#4", "Bb2") -> MIDI-Nummer."""
    n = NOTEN[s[0]]
    i = 1
    while s[i] in "#b":
        n += 1 if s[i] == "#" else -1
        i += 1
    return 12 * (int(s[i:]) + 1) + n


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def cent(c):
    return 2 ** (c / 1200)


def tabelle(harm):
    """Bandbegrenzte Wellentabelle aus Obertonamplituden."""
    t = np.arange(TAB) / TAB
    w = sum(a * np.sin(PI2 * (k + 1) * t) for k, a in enumerate(harm))
    return w / np.max(np.abs(w))


T_SIN = tabelle([1])
T_PAD = tabelle([1, 0.5, 0.33, 0.2, 0.12, 0.08, 0.05, 0.03])
T_DUNKEL = tabelle([1, 0.4, 0.2, 0.1, 0.05])
T_FLOETE = tabelle([1, 0.28, 0.09, 0.03, 0.015])
T_BASS = tabelle([1, 0.45, 0.15, 0.08, 0.03])
T_WEICH = tabelle([1, 0.5, 0.25, 0.1, 0.04])
T_BLECH = tabelle([1, 0.8, 0.65, 0.5, 0.38, 0.28, 0.2, 0.14, 0.1, 0.07, 0.05, 0.03])
T_STREICH = tabelle([1 / k ** 1.35 for k in range(1, 13)])
T_SAEGE = tabelle([1 / k ** 1.5 for k in range(1, 9)])


def phase(f, n, ph=0.0):
    if np.isscalar(f):
        return ph + (f / SR) * np.arange(n)
    return ph + np.cumsum(f) / SR


def osz(tab, f, n, ph=0.0):
    return tab[(phase(f, n, ph) * TAB).astype(np.int64) & (TAB - 1)]


def adsr(gate, a, d, s, r):
    """Hüllkurve: linearer Anstieg, exponentieller Abfall auf s, quadratisches Ausklingen."""
    n = int((gate + r) * SR)
    t = np.arange(n) / SR
    e = np.where(t < a, t / a, s + (1 - s) * np.exp(-(t - a) / d * 3))
    g = min(int(gate * SR), n - 1)
    x = np.clip((t[g:] - gate) / r, 0, 1)
    e[g:] = e[g] * (1 - x) ** 2
    return e


def tp(f, fc, o=2):
    return 1 / np.sqrt(1 + (f / fc) ** (2 * o))


def hp(f, fc, o=2):
    return (f / fc) ** o / np.sqrt(1 + (f / fc) ** (2 * o))


def fftfilter(x, fn):
    """Nullphasiges (zirkuläres) Filter über die FFT, fn(f) liefert den Frequenzgang."""
    n = x.shape[-1]
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * fn(np.fft.rfftfreq(n, 1 / SR)), n=n, axis=-1)


def rauschen(n, lo=None, hi=None, rng=None):
    r = (rng or RNG).standard_normal(n)
    if lo or hi:
        r = fftfilter(r, lambda f: (hp(f, lo) if lo else 1) * (tp(f, hi) if hi else 1))
    return r / (np.std(r) + 1e-12)


def ausblenden(x, ms=8, ein_ms=0):
    k = min(int(ms * SR / 1000), x.shape[-1])
    x[..., -k:] *= np.linspace(1, 0, k)
    if ein_ms:
        k = int(ein_ms * SR / 1000)
        x[..., :k] *= np.linspace(0, 1, k)
    return x


def hall_ir(rt, hell, seed, kan=2):
    """Künstliche Impulsantwort: Rauschen mit frequenzabhängigem Abklingen (Höhen kürzer)."""
    rng = np.random.default_rng(seed)
    n = int(rt * 1.25 * SR)
    t = np.arange(n) / SR
    r = rng.standard_normal((kan, n))
    tief = fftfilter(r, lambda f: tp(f, hell, 1))
    ir = tief * 10 ** (-3 * t / rt) + (r - tief) * 10 ** (-3 * t / (rt * 0.35))
    ir *= np.minimum(1, t / 0.008)
    ausblenden(ir, 20)
    ir = np.concatenate((np.zeros((kan, int(0.018 * SR))), ir), axis=1)
    ir = fftfilter(ir, lambda f: hp(f, 160, 1))
    return ir / np.sqrt((ir ** 2).sum(axis=1, keepdims=True))


# ---------------------------------------------------------------- Instrumente

def pad(m, dauer, vel=1.0, tab=T_PAD, a=1.0, r=1.8):
    """Weiches Flächen-Pad, je Kanal zwei verstimmte Stimmen (Chorus, Stereobreite)."""
    env = adsr(dauer, a, 1.0, 0.85, r)
    n = len(env)
    t = np.arange(n) / SR
    f = hz(m)
    k = []
    for c1, c2 in ((-9, 4), (-3, 10)):
        s = osz(tab, f * cent(c1), n, RNG.random()) + osz(tab, f * cent(c2), n, RNG.random())
        k.append(s * (1 + 0.12 * np.sin(PI2 * RNG.uniform(0.15, 0.3) * t + RNG.uniform(0, PI2))))
    return np.vstack(k) * env * (0.5 * vel)


def zupf(m, dauer=2.5, vel=1.0, expo=1.3, ort=0.19, daempf=1.0):
    """Gezupfte Saite (Harfe/Laute): Obertöne klingen umso schneller ab, je höher sie liegen."""
    f = hz(m)
    n = int(dauer * SR)
    t = np.arange(n) / SR
    k = np.arange(1, max(2, min(12, int(15000 / f))) + 1)[:, None]
    amp = np.abs(np.sin(np.pi * k * ort)) / k ** expo
    rate = daempf * (1.0 + 0.45 * k) * (f / 220) ** 0.35
    s = (amp * np.sin(PI2 * f * k * np.sqrt(1 + 0.0002 * k * k) * t) * np.exp(-rate * t)).sum(axis=0)
    s *= np.minimum(1, t / 0.002)
    return ausblenden(s, 30) * vel


def laute(m, dauer=2.0, vel=1.0):
    return zupf(m, max(dauer, 1.2), vel, expo=1.0, ort=0.12, daempf=1.5)


def floete(m, dauer, vel=1.0):
    """Flöte: fast reiner Ton, verzögert einsetzendes Vibrato, etwas Anblasgeräusch."""
    env = adsr(dauer, 0.06, 0.25, 0.82, 0.22)
    n = len(env)
    t = np.arange(n) / SR
    lfo = np.clip((t - 0.18) / 0.35, 0, 1) * np.sin(PI2 * 5.2 * t + RNG.uniform(0, PI2))
    s = osz(T_FLOETE, hz(m) * (1 + 0.0045 * lfo), n, RNG.random()) * (1 + 0.07 * lfo)
    hauch = rauschen(n, 1500, 5000) * (0.014 + 0.1 * np.exp(-t * 30))
    return (s + hauch) * env * vel


def bass(m, dauer, vel=1.0):
    env = adsr(dauer, 0.015, 0.5, 0.55, 0.25)
    n = len(env)
    return (0.7 * osz(T_BASS, hz(m), n) + 0.5 * osz(T_SIN, hz(m), n)) * env * vel


def tief(m, dauer, vel=1.0):
    """Sehr weicher Subbass für die Wildnis."""
    env = adsr(dauer, 2.0, 1.0, 0.9, 3.0)
    n = len(env)
    return (osz(T_SIN, hz(m), n) + 0.3 * osz(T_SIN, 2 * hz(m), n, 0.25)) * env * vel


def blech(m, dauer, vel=1.0, a=0.045, hell=1.0):
    """Blechbläser: Klangfarbe wird mit der Lautstärke heller (Überblenden zweier Tabellen)."""
    env = adsr(dauer, a, 0.25, 0.8, 0.14)
    n = len(env)
    t = np.arange(n) / SR
    vib = np.clip((t - 0.25) / 0.3, 0, 1) * 0.003 * np.sin(PI2 * 5.5 * t)
    b = np.clip(env ** 1.5 * vel * hell, 0, 1)
    s = 0
    for c in (-5, 5):
        i = (phase(hz(m) * cent(c) * (1 + vib), n, RNG.random()) * TAB).astype(np.int64) & (TAB - 1)
        s = s + T_WEICH[i] * (1 - b) + T_BLECH[i] * b
    return s * env * (0.5 * vel)


def horn(m, dauer, vel=1.0):
    return blech(m, dauer, vel, a=0.11, hell=0.5)


def streicher(m, dauer, vel=1.0, a=0.09, r=0.2, s=0.85, tab=T_STREICH):
    env = adsr(dauer, a, 0.3, s, r)
    n = len(env)
    t = np.arange(n) / SR
    vib = np.clip((t - 0.2) / 0.3, 0, 1) * 0.004 * np.sin(PI2 * 5.8 * t + RNG.uniform(0, PI2))
    x = sum(osz(tab, hz(m) * cent(c) * (1 + vib), n, RNG.random()) for c in (-8, 0, 7))
    return x * env * (vel / 3)


def stakkato(m, dauer, vel=1.0):
    return streicher(m, min(dauer, 0.11), vel, a=0.008, r=0.09, s=0.5)


def ostinato(m, dauer, vel=1.0):
    """Kurzer, knurrender Bass für das Kampf-Ostinato."""
    env = adsr(dauer * 0.8, 0.006, 0.12, 0.45, 0.06)
    n = len(env)
    return (osz(T_SAEGE, hz(m), n) + 0.6 * osz(T_SIN, hz(m), n)) * env * vel


def glocke(m, dauer=5.0, vel=1.0):
    """Glocke mit unharmonischen Teiltönen (Moll-Terz wie bei echten Glocken)."""
    f = hz(m)
    n = int(dauer * SR)
    t = np.arange(n) / SR
    R = np.array([0.5, 1, 1.2, 1.5, 2, 2.5, 3, 4.2])[:, None]
    A = np.array([0.25, 1, 0.45, 0.2, 0.35, 0.12, 0.12, 0.06])[:, None]
    D = np.array([0.7, 1, 1.4, 1.8, 2.2, 3, 4, 6])[:, None] * 1.1 * (f / 600) ** 0.3
    s = (A * np.sin(PI2 * f * R * t) * np.exp(-D * t)).sum(axis=0) * np.minimum(1, t / 0.003)
    return ausblenden(s, 60) * vel


def trommel(f0, dauer, fall, abkl, rausch, fc=900, obert=(), vel=1.0):
    """Trommel: Sinus mit Tonhöhenabfall plus tiefgefilterter Rauschimpuls."""
    n = int(dauer * SR)
    t = np.arange(n) / SR
    ph = PI2 * np.cumsum(f0 * (1 + fall * np.exp(-t * 28))) / SR
    s = np.sin(ph) * np.exp(-t * abkl)
    for ratio, amp, dk in obert:
        s += amp * np.sin(ph * ratio) * np.exp(-t * dk)
    s += rausch * rauschen(n, None, fc) * np.exp(-t * 45)
    return ausblenden(s, 15) * vel


def pauke(f, vel=1.0):
    return trommel(f, 1.4, 0.25, 3.5, 0.35, 700, ((1.5, 0.5, 5), (1.99, 0.3, 7), (2.44, 0.15, 9)), vel)


def gross(vel=1.0):
    return trommel(52, 0.7, 1.4, 7, 0.5, 500, (), vel)


def tom(f, vel=1.0):
    return trommel(f, 0.45, 0.6, 10, 0.4, 1500, ((1.6, 0.3, 16),), vel)


def klack(vel=1.0):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    s = rauschen(n, 1500, 5000) * np.exp(-t * 60) + 0.6 * np.sin(PI2 * 410 * t) * np.exp(-t * 70)
    return ausblenden(s, 5) * vel


def schuettel(vel=1.0):
    n = int(0.07 * SR)
    t = np.arange(n) / SR
    return ausblenden(rauschen(n, 5000, None) * np.minimum(1, t / 0.004) * np.exp(-t * 55), 5) * vel


def becken(dauer=2.2, vel=1.0):
    n = int(dauer * SR)
    t = np.arange(n) / SR
    return ausblenden(rauschen(n, 3500, 11000) * np.minimum(1, t / 0.01) * np.exp(-t * 2.6), 80) * vel


# ---------------------------------------------------------------- Ringpuffer und Abmischung

class Stueck:
    def __init__(self, bpm, takte, schlaege=4):
        self.sb = 60.0 / bpm                       # Sekunden je Schlag
        self.beats = takte * schlaege
        # Länge auf ein Vielfaches von 64 Samples runden: der Vorbis-Encoder von ffmpeg füllt sonst
        # den letzten Block mit Stille auf, was im Loop eine Lücke von bis zu 1,5 ms ergäbe
        self.n = int(round(self.beats * self.sb * SR / 64)) * 64
        self.sb = self.n / SR / self.beats
        self.spuren = {}

    def add(self, spur, beat, sig, pan=0.0, gain=1.0):
        """Signal bei Schlag 'beat' einmischen; was über das Ende ragt, wird an den Anfang gefaltet."""
        buf = self.spuren.get(spur)
        if buf is None:
            buf = self.spuren[spur] = np.zeros((2, self.n))
        if sig.ndim == 1:
            w = (pan + 1) * math.pi / 4
            sig = np.vstack((sig * math.cos(w), sig * math.sin(w)))
        i0 = int(round(beat * self.sb * SR)) % self.n
        m = sig.shape[1]
        p = 0
        while p < m:
            k = min(m - p, self.n - i0)
            buf[:, i0:i0 + k] += gain * sig[:, p:p + k]
            p += k
            i0 = (i0 + k) % self.n

    def mischen(self, pegel, rt, hell, seed, komp=0.3, max_rms_db=-19.0):
        """pegel: Spur -> (Ziel-RMS in dB, Hallanteil). Liefert das fertige Stereosignal."""
        n = self.n
        f = np.fft.rfftfreq(n, 1 / SR)
        X = np.zeros((2, len(f)), dtype=complex)
        S = np.zeros((2, len(f)), dtype=complex)
        for name, (db, h) in pegel.items():
            x = self.spuren[name]
            g = 10 ** (db / 20) / aktiv_rms(x)
            F = np.fft.rfft(x, axis=1) * g
            X += F
            S += F * h
        IR = np.fft.rfft(hall_ir(rt, hell, seed), n=n, axis=1)   # zirkuläre Faltung = Hall läuft um die Naht
        H = hp(f, 28, 2) * tp(f, 14000, 1)
        y = np.fft.irfft((X + S * IR) * H, n=n, axis=1)
        y = kompressor(y, komp)
        y *= 10 ** (-3 / 20) / np.max(np.abs(y))
        rms = math.sqrt((y ** 2).mean())
        grenze = 10 ** (max_rms_db / 20)
        if rms > grenze:
            y *= grenze / rms
        return y


def aktiv_rms(x):
    p = (x ** 2).mean(axis=0)
    return math.sqrt(p[p > p.max() * 1e-3].mean())


def kompressor(x, staerke=0.3, sigma=0.12):
    """Sanfter Pegelausgleich: Gewinn aus zirkulär geglätteter Leistung (also loopsicher)."""
    n = x.shape[1]
    p = (x ** 2).mean(axis=0)
    f = np.fft.rfftfreq(n, 1 / SR)
    env = np.sqrt(np.maximum(np.fft.irfft(np.fft.rfft(p) * np.exp(-2 * (math.pi * sigma * f) ** 2), n=n), 1e-12))
    ref = math.sqrt(p.mean())
    return x * (np.maximum(env, ref * 0.15) / ref) ** (-staerke)


def lies(s, summe=None):
    """"A4:1 D5:.5 -:2 | ..." -> Liste (MIDI oder None, Schläge)."""
    out = []
    for w in s.replace("|", " ").split():
        a, b = w.split(":")
        out.append((None if a == "-" else mi(a), float(b)))
    if summe is not None:
        assert abs(sum(d for _, d in out) - summe) < 1e-6, (s, sum(d for _, d in out))
    return out


def spiele(st, spur, beat0, noten, instr, transp=0, pan=0.0, legato=0.96, vel=1.0):
    b = beat0
    for m, d in noten:
        if m is not None:
            v = vel * RNG.uniform(0.85, 1.0)
            st.add(spur, b + RNG.uniform(-0.01, 0.01), instr(m + transp, d * st.sb * legato, vel=v), pan)
        b += d


def akkorde(folge, takt=4):
    """"D A/C# Asus+A ..." -> Liste (Startschlag, Schläge, Name); '+' teilt einen Takt."""
    out = []
    b = 0.0
    for w in folge.replace("|", " ").split():
        teile = w.split("+")
        for x in teile:
            out.append((b, takt / len(teile), x))
            b += takt / len(teile)
    return out


def akkord_bei(liste, beat):
    for b, d, name in liste:
        if b <= beat < b + d:
            return name
    return liste[-1][2]


# ---------------------------------------------------------------- Stücke

def dorf():
    """D-Dur, 88 BPM, 32 Takte (A A' B A''): Pad, Harfe, Bass, Melodie erst Laute, dann Flöte."""
    st = Stueck(88, 32)
    AK = {
        "D": ("D3", ["A3", "D4", "F#4"]), "A/C#": ("C#3", ["A3", "C#4", "E4"]),
        "Bm": ("B2", ["B3", "D4", "F#4"]), "G": ("G2", ["B3", "D4", "G4"]),
        "D/F#": ("F#2", ["A3", "D4", "F#4"]), "Em7": ("E2", ["B3", "D4", "E4", "G4"]),
        "Em": ("E2", ["B3", "E4", "G4"]), "A": ("A2", ["A3", "C#4", "E4"]),
        "Asus": ("A2", ["A3", "D4", "E4"]),
    }
    folge = akkorde("D A/C# Bm G D/F# G Em7 Asus+A | D A/C# Bm G Em A D D |"
                    "Bm G D A Bm G Em Asus+A | D A/C# Bm G Em A D D")
    for b, d, name in folge:
        bs, noten = AK[name]
        for x in noten:
            st.add("pad", b, pad(mi(x), d * st.sb, RNG.uniform(0.85, 1)))
        st.add("bass", b, bass(mi(bs), d * st.sb * 0.5 * 0.95))
        if d >= 4:
            st.add("bass", b + 2, bass(mi(bs) + (7 if mi(bs) < mi("A2") else 0), 1.8 * st.sb, 0.75))
    muster = ([0, 2, 3, 4, 5, 4, 3, 2], [0, 2, 3, 4, 5, 4, 3, 2], [0, 3, 2, 4, 3, 5, 4, 2], [0, 2, 3, 5, 4, 3, 4, 2])
    for takt in range(32):
        for i in range(8):
            b = takt * 4 + i * 0.5
            p = sorted(mi(x) for x in AK[akkord_bei(folge, b)][1])
            c = p + [x + 12 for x in p]
            m = c[muster[takt // 8][i]]
            v = (1.0 if i == 0 else 0.8 if i == 4 else 0.62) * RNG.uniform(0.85, 1)
            st.add("harfe", b + RNG.uniform(-0.012, 0.012), zupf(m, 2.6, v), pan=(m - 66) / 30)
    A1 = lies("A4:1 D5:1 F#5:1.5 E5:.5 | E5:2 C#5:1 A4:1 | B4:1 D5:1 F#5:1.5 E5:.5 | D5:3 -:1 |"
              "A4:1 D5:1 F#5:1 A5:1 | B5:1.5 A5:.5 G5:2 | G5:1 F#5:1 E5:1 D5:1 | E5:3 -:1", 32)
    A2 = lies("A4:1 D5:1 F#5:1.5 E5:.5 | E5:2 C#5:1 A4:1 | B4:1 D5:1 F#5:1.5 G5:.5 | B5:2 A5:1 G5:1 |"
              "G5:1.5 F#5:.5 E5:1 G5:1 | E5:1.5 F#5:.5 E5:1 C#5:1 | D5:4 | -:4", 32)
    B = lies("F#5:2 D5:1 B4:1 | B4:1 D5:1 G5:2 | F#5:1.5 E5:.5 D5:1 A4:1 | C#5:1 E5:3 |"
             "F#5:1 B5:2 A5:1 | G5:1.5 A5:.5 B5:2 | G5:1 E5:1 G5:1 B5:1 | A5:3 -:1", 32)
    A3 = lies("A4:1 D5:1 F#5:1.5 E5:.5 | E5:2 C#5:1 A4:1 | B4:1 D5:1 F#5:1.5 G5:.5 | B5:2 A5:1 G5:1 |"
              "G5:1.5 F#5:.5 E5:1 G5:1 | F#5:1 E5:1 C#5:1 E5:1 | D5:3 -:1 | -:4", 32)
    spiele(st, "laute", 0, A1, laute, pan=0.2)
    spiele(st, "floete", 32, A2, floete, pan=-0.15)
    spiele(st, "floete", 64, B, floete, pan=-0.15)
    spiele(st, "floete", 96, A3, floete, pan=-0.15)
    spiele(st, "laute", 96, A3, laute, transp=-12, pan=0.25, vel=0.7)
    return st.mischen({"pad": (-25, 0.35), "harfe": (-25, 0.4), "laute": (-23, 0.35),
                       "floete": (-21, 0.45), "bass": (-25, 0.1)}, rt=2.2, hell=4500, seed=21)


def wildnis():
    """e-Moll, 66 BPM, 24 Takte (12 Akkorde zu je 2 Takten): tiefe Pads, Glocken, Flötenfragmente, Wind."""
    st = Stueck(66, 24)
    W = [("E2", ["E3", "B3", "F#4", "G4"], "B5", [(2, "B5"), (5, "E5")]),            # Em(add9)
         ("C2", ["E3", "B3", "E4", "G4"], "B5", [(3, "G5"), (6, "B4")]),             # Cmaj7
         ("A2", ["E3", "A3", "C4", "E4"], "C6", [(2, "E5"), (4.5, "A5")]),           # Am
         ("B2", ["F#3", "B3", "D4", "F#4"], "A5", [(3, "F#5"), (6, "D5")]),          # Bm
         ("E2", ["E3", "B3", "E4", "G4"], "G5", [(1, "B5"), (2, "G5"), (5, "E5")]),  # Em
         ("G2", ["D3", "B3", "D4", "G4"], "B5", [(2, "D5"), (6, "B5")]),             # G
         ("A2", ["E3", "A3", "C4", "E4"], "C6", [(3, "C5"), (4, "E5")]),             # Am
         ("D2", ["D3", "A3", "E4", "F#4"], "A5", [(2, "F#5"), (5, "A5")]),           # Dsus2
         ("C2", ["E3", "G3", "C4", "E4"], "G5", [(1, "G5"), (4, "E5"), (7, "G4")]),  # C
         ("A2", ["E3", "A3", "C4", "E4"], "E5", [(3, "A5")]),                        # Am
         ("B2", ["F#3", "B3", "D4", "F#4"], "F#5", [(2, "F#5"), (5, "B4")]),         # Bm
         ("E2", ["E3", "B3", "E4", "G4"], "E5", [(3, "E5")])]                        # Em
    for i, (bs, noten, oben, gl) in enumerate(W):
        b = i * 8
        d = 8 * st.sb
        for x in noten:
            st.add("tiefpad", b, pad(mi(x), d, RNG.uniform(0.8, 1), tab=T_DUNKEL, a=2.5, r=3.2))
        st.add("hochpad", b, pad(mi(oben), d, 1, tab=T_SIN, a=3.0, r=3.5))
        st.add("sub", b, tief(mi(bs), d))
        for gb, x in gl:
            st.add("glocke", b + gb + RNG.uniform(-0.03, 0.03), glocke(mi(x), 6.0, RNG.uniform(0.6, 1)),
                   pan=RNG.uniform(-0.6, 0.6))
        if i % 4 == 0:
            st.add("pauke", b, pauke(hz(mi("E2"))), pan=0.1)
    spiele(st, "floete", 16, lies("-:1 E4:1.5 A4:.5 C5:2 B4:3 | F#4:1 B4:1 D5:1.5 B4:.5 A4:1 F#4:3", 16), floete, pan=-0.3)
    spiele(st, "floete", 48, lies("-:1 A4:1 C5:1 E5:2 D5:1 C5:.5 B4:.5 A4:1 | F#4:2 A4:1 D5:3 -:2", 16), floete, pan=0.3)
    spiele(st, "floete", 80, lies("-:2 B4:1 D5:1 F#5:2 E5:1 D5:1 | E5:1.5 B4:.5 G4:2 E4:3 -:1", 16), floete, pan=-0.2)
    # Wind: Rauschen in Loop-Länge, zirkulär gefiltert, Lautstärke schwankt mit ganzzahligen Perioden je Loop
    n = st.n
    t = np.arange(n) / n
    wind = np.vstack([rauschen(n, 250, 1400) for _ in range(2)])
    wind *= 0.55 + 0.25 * np.sin(PI2 * 3 * t + 1.0) + 0.2 * np.sin(PI2 * 7 * t + 4.0)
    st.add("wind", 0, wind)
    return st.mischen({"tiefpad": (-24, 0.5), "hochpad": (-35, 0.6), "sub": (-25, 0.1), "glocke": (-27, 0.9),
                       "floete": (-27, 0.9), "wind": (-37, 0.2), "pauke": (-30, 0.8)},
                      rt=5.0, hell=3500, seed=22, komp=0.2, max_rms_db=-21.0)


def kampf():
    """d-Moll, 140 BPM, 32 Takte: Bass-Ostinato, Stakkato-Streicher (3+3+2), Trommeln, Blechmelodie."""
    st = Stueck(140, 32)
    K = {"Dm": ("D2", ["D4", "F4", "A4"]), "Bb": ("Bb1", ["D4", "F4", "Bb4"]), "C": ("C2", ["E4", "G4", "C5"]),
         "A": ("A1", ["C#4", "E4", "A4"]), "F": ("F2", ["C4", "F4", "A4"]), "Gm": ("G2", ["D4", "G4", "Bb4"])}
    folge = akkorde("Dm Dm Bb C Dm Dm Bb A | F C Dm Bb Gm A Dm A |" * 2)
    lauf = [0, 0, 12, 0, 7, 0, 12, 7]
    akzent = [1, 0.5, 0.6, 1, 0.5, 0.6, 1, 0.65]
    g_cache = [gross() for _ in range(3)]
    k_cache = [klack() for _ in range(3)]
    s_cache = [schuettel() for _ in range(4)]
    for takt, (b, d, name) in enumerate(folge):
        bs, noten = K[name]
        teil = takt // 8
        for x in noten:
            st.add("flaeche", b, pad(mi(x) - 12, d * st.sb, 1, a=0.3, r=0.6))
        for i in range(8):
            be = b + i * 0.5
            st.add("bass", be, ostinato(mi(bs) + lauf[i], 0.5 * st.sb, 0.75 + 0.25 * akzent[i]))
            for j, x in enumerate(noten):
                st.add("stakk", be + RNG.uniform(-0.006, 0.006), stakkato(mi(x), 0.1, akzent[i] * RNG.uniform(0.85, 1)),
                       pan=(-0.45, 0.0, 0.45)[j])
            st.add("schuettel", be, s_cache[i % 4], pan=0.35, gain=1.0 if i % 2 else 0.55)
        fuell = takt % 4 == 3
        for be, v in ((0, 1.0), (1.5, 0.8), (3, 0.9)):
            if not (fuell and be == 3):
                st.add("gross", b + be, g_cache[takt % 3], gain=v)
        for be in (1, 3):
            if not (fuell and be == 3):
                st.add("klack", b + be, k_cache[takt % 3], pan=-0.25)
        st.add("klack", b + 2.5, k_cache[(takt + 1) % 3], pan=-0.25, gain=0.45)
        if fuell:                                    # Tom-Wirbel am Ende jeder Viertaktgruppe
            start = 2.0 if takt % 8 == 7 else 2.5
            schl = np.arange(start, 4.0, 0.25)
            for j, be in enumerate(schl):
                x = j / (len(schl) - 1)
                st.add("tom", b + be, tom(200 - 90 * x, 0.55 + 0.45 * x), pan=-0.5 + x)
        if takt % 8 == 0:
            st.add("becken", b, becken(), pan=0.2)
        if teil >= 2:                                # zweite Hälfte: Pauke auf dem Grundton
            f = hz(mi(bs))
            while f < 62:
                f *= 2
            st.add("pauke", b, pauke(f), pan=0.15)
            if takt % 2 == 1:
                st.add("pauke", b + 3.5, pauke(f, 0.6), pan=0.15)
    M1 = lies("D5:1.5 E5:.5 F5:1 A5:1 | G5:.5 F5:.5 E5:1 D5:2 | F5:1.5 G5:.5 F5:1 D5:1 | E5:2 G5:1 E5:1 |"
              "D5:1.5 E5:.5 F5:1 A5:1 | A5:1 D6:1 C6:1 A5:1 | Bb5:1.5 A5:.5 G5:1 F5:1 | A5:2 E5:1 C#5:1", 32)
    M2 = lies("A5:2 C6:1 A5:1 | G5:2 E5:1 G5:1 | F5:1 A5:1 D6:2 | D6:1 C6:1 Bb5:1 F5:1 |"
              "G5:1.5 A5:.5 Bb5:1 D6:1 | C#6:2 A5:1 E5:1 | D5:.5 E5:.5 F5:.5 G5:.5 A5:2 | C#5:1 E5:1 A5:1 C#6:1", 32)
    spiele(st, "cello", 0, M1, streicher, transp=-12, pan=0.15, legato=0.9)
    spiele(st, "blech", 32, M2, blech, pan=-0.1, legato=0.9)
    spiele(st, "blech", 64, M1, blech, pan=-0.1, legato=0.9)
    spiele(st, "cello", 64, M1, streicher, transp=-12, pan=0.2, legato=0.9, vel=0.8)
    spiele(st, "blech", 96, M2, blech, pan=-0.1, legato=0.9)
    spiele(st, "cello", 96, M2, streicher, pan=0.25, legato=0.9, vel=0.8)
    return st.mischen({"flaeche": (-27, 0.3), "bass": (-20, 0.05), "stakk": (-24, 0.3), "schuettel": (-33, 0.15),
                       "gross": (-19, 0.2), "klack": (-26, 0.3), "tom": (-22, 0.3), "becken": (-29, 0.4),
                       "pauke": (-23, 0.35), "cello": (-21, 0.35), "blech": (-19, 0.4)},
                      rt=1.6, hell=5000, seed=23, komp=0.35, max_rms_db=-17.0)


def menue():
    """d-Moll mit Dur-Schluss, 64 BPM, 16 Takte: feierliches Hornthema über Streicherfläche und Harfe."""
    st = Stueck(64, 16)
    AK = {"Dm": ("D2", ["A3", "D4", "F4"]), "Bb": ("Bb2", ["Bb3", "D4", "F4"]), "F": ("F2", ["A3", "C4", "F4"]),
          "C": ("C3", ["G3", "C4", "E4"]), "Gm": ("G2", ["Bb3", "D4", "G4"]), "A": ("A2", ["A3", "C#4", "E4"]),
          "Asus": ("A2", ["A3", "D4", "E4"]), "Dm/A": ("A2", ["A3", "D4", "F4"]), "D": ("D2", ["A3", "D4", "F#4"])}
    folge = akkorde("Dm Bb F C Dm Bb Gm A | Dm Bb F C Gm Dm/A Asus+A D")
    for b, d, name in folge:
        bs, noten = AK[name]
        for x in noten:
            st.add("pad", b, pad(mi(x), d * st.sb, RNG.uniform(0.85, 1), a=1.2, r=2.2))
        st.add("pad", b, pad(mi(bs) + 12, d * st.sb, 0.7, a=1.2, r=2.2))
        st.add("bass", b, streicher(mi(bs), d * st.sb, 1, a=0.3, r=0.8))
        st.add("bass", b, bass(mi(bs), d * st.sb * 0.9, 0.8))
    for takt in range(16):
        for i in range(8):
            b = takt * 4 + i * 0.5
            bs, noten = AK[akkord_bei(folge, b)]
            p = sorted(mi(x) for x in noten)
            c = [mi(bs) + 12] + p + [x + 12 for x in p]
            m = c[[0, 1, 2, 3, 4, 3, 2, 1][i]]
            v = (1.0 if i == 0 else 0.7) * RNG.uniform(0.85, 1)
            st.add("harfe", b + RNG.uniform(-0.01, 0.01), zupf(m, 3.2, v), pan=(m - 60) / 28)
    T1 = lies("D4:2 A4:2 | Bb4:1.5 A4:.5 F4:2 | A4:2 C5:2 | G4:3 E4:1 | F4:2 A4:2 | D5:3 Bb4:1 | Bb4:1.5 A4:.5 G4:2 | A4:4", 32)
    T2 = lies("D5:2 A4:2 | Bb4:1 D5:1 F5:2 | F5:1.5 E5:.5 C5:2 | E5:3 C5:1 | D5:2 Bb4:1 G4:1 | F4:1 A4:1 D5:2 |"
              "E5:1.5 D5:.5 C#5:2 | D5:4", 32)
    spiele(st, "horn", 0, T1, horn, pan=-0.1)
    spiele(st, "horn", 32, T2, horn, pan=-0.1)
    spiele(st, "floete", 32, T2, floete, transp=12, pan=0.25, vel=0.8)
    for b, f, v in ((0, "D2", 0.8), (32, "D2", 1.0), (60, "D2", 1.0)):
        st.add("pauke", b, pauke(hz(mi(f)) , v), pan=0.1)
    for j, be in enumerate(np.arange(58, 60, 0.25)):   # Paukenwirbel auf A vor dem Schlussakkord
        st.add("pauke", be, pauke(hz(mi("A2")), 0.25 + 0.09 * j), pan=0.1)
    for b, x in ((0, "A5"), (32, "D6"), (60, "A5")):
        st.add("glocke", b, glocke(mi(x), 6.0), pan=0.3)
    return st.mischen({"pad": (-24, 0.45), "harfe": (-27, 0.5), "horn": (-21, 0.5), "floete": (-26, 0.55),
                       "bass": (-24, 0.15), "pauke": (-27, 0.5), "glocke": (-29, 0.7)},
                      rt=3.5, hell=4000, seed=24, komp=0.25, max_rms_db=-19.5)


# ---------------------------------------------------------------- Soundeffekte

def svf_bp(x, fc, daempf):
    """Zustandsvariables Filter (Bandpass) mit zeitveränderlicher Mittenfrequenz, für kurze Signale."""
    low = band = 0.0
    out = []
    for xi, fi in zip(x.tolist(), (2 * np.sin(np.pi * fc / SR)).tolist()):
        high = xi - low - daempf * band
        band += fi * high
        low += fi * band
        out.append(band)
    return np.array(out)


def hallen(x, rt, anteil, seed):
    ir = hall_ir(rt, 5000, seed, 1)[0]
    n = len(x) + len(ir)
    return np.concatenate((x, np.zeros(len(ir)))) + anteil * np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)


def zeit(dauer):
    n = int(dauer * SR)
    return n, np.arange(n) / SR


def korn(n, hz_=60):
    """Körnige Zufallshüllkurve (für Knirschen, Rascheln)."""
    return np.abs(rauschen(n, None, hz_)) ** 1.5


def ping(f, dauer, abkl, teil=((1, 1.0), (2, 0.3), (3, 0.1))):
    n, t = zeit(dauer)
    s = sum(a * np.sin(PI2 * f * r * t) * np.exp(-t * abkl * (1 + 0.3 * (r - 1))) for r, a in teil)
    return s * np.minimum(1, t / 0.002)


def lege(ziel, t0, sig, gain=1.0):
    i = int(t0 * SR)
    k = min(len(sig), len(ziel) - i)
    ziel[i:i + k] += gain * sig[:k]


def sfx_schlag():
    n, t = zeit(0.38)
    x = t / t[-1]
    fc = np.where(x < 0.55, 500 * 8 ** (x / 0.55), 4000 * (1500 / 4000) ** ((x - 0.55) / 0.45))
    env = np.sin(np.pi * x ** 0.8) ** 2.5
    return (svf_bp(rauschen(n), fc, 0.35) + 0.15 * rauschen(n, 5000, None)) * env


def sfx_treffer():
    n, t = zeit(0.32)
    s = np.sin(PI2 * np.cumsum(140 * np.exp(-t * 18) + 48) / SR) * np.exp(-t * 16)
    s += 0.6 * rauschen(n, None, 900) * np.exp(-t * 45) + 0.3 * rauschen(n, 1200, 2500) * np.exp(-t * 90)
    return np.tanh(2.2 * s)


def sfx_block():
    n, t = zeit(0.6)
    s = np.zeros(n)
    for i, r in enumerate((1, 1.52, 2.31, 2.89, 3.77, 4.61, 5.93)):
        s += np.sin(PI2 * 1150 * r * t + RNG.uniform(0, PI2)) * np.exp(-t * (9 + 2.7 * i)) / (1 + 0.5 * i)
    s *= np.minimum(1, t / 0.0005)
    s += 1.2 * rauschen(n, 3000, None) * np.exp(-t * 200) + 0.8 * np.sin(PI2 * 320 * t) * np.exp(-t * 40)
    return s


def sfx_zauber():
    n, t = zeit(1.25)
    f = 440 * 2 ** (1.6 * np.clip(t / 0.9, 0, 1))
    env = np.sin(np.pi * np.clip(t / 1.1, 0, 1)) ** 1.5
    s = sum(np.sin(PI2 * np.cumsum(f * cent(c)) / SR) for c in (-8, 0, 9)) / 3
    s = 0.5 * s * env * (1 + 0.35 * np.sin(PI2 * 14 * t))
    skala = [0, 2, 4, 7, 9]
    for i in range(15):                                # aufsteigendes Funkeln (Pentatonik)
        m = 81 + 12 * (i // 5) + skala[i % 5]
        lege(s, 0.04 + 0.062 * i, ping(hz(m), 0.35, 16), 0.25 + 0.03 * i)
    s += 0.12 * rauschen(n, 6000, None) * np.sin(np.pi * np.clip(t / 1.2, 0, 1)) ** 3
    return hallen(s, 0.7, 0.35, 5)[:int(1.7 * SR)]


def sfx_aufheben():
    s = np.zeros(int(0.3 * SR))
    lege(s, 0, ping(hz(mi("E6")), 0.25, 24))
    lege(s, 0.07, ping(hz(mi("B6")), 0.22, 20))
    return s


def sfx_stufe():
    s = np.zeros(int(1.5 * SR))
    for i, (x, d) in enumerate((("C5", 0.13), ("E5", 0.13), ("G5", 0.13), ("C6", 0.85))):
        lege(s, 0.14 * i, blech(mi(x), d, 1.0, a=0.02))
    for x in ("E5", "G5", "C5"):
        lege(s, 0.42, blech(mi(x), 0.85, 0.7, a=0.03), 0.6)
    lege(s, 0.42, glocke(mi("C6"), 1.0), 0.25)
    return hallen(s, 0.8, 0.3, 6)[:int(1.6 * SR)]


def sfx_klick():
    n, t = zeit(0.05)
    f = 1200 + 700 * np.exp(-t * 120)
    return np.sin(PI2 * np.cumsum(f) / SR) * np.exp(-t * 140) + 0.3 * rauschen(n, 4000, None) * np.exp(-t * 400)


def sfx_muenze():
    teil = ((1, 1.0), (2.0, 0.5), (2.76, 0.35), (4.1, 0.2), (5.43, 0.12))
    s = np.zeros(int(0.55 * SR))
    lege(s, 0, ping(hz(mi("B5")), 0.09, 30, teil), 0.8)
    lege(s, 0.075, ping(hz(mi("E6")), 0.47, 9, teil))
    lege(s, 0, rauschen(400, 5000, None) * np.linspace(1, 0, 400) ** 2, 0.3)
    return s


def sfx_essen():
    s = np.zeros(int(0.52 * SR))
    for i, t0 in enumerate((0.0, 0.17, 0.33)):
        n, t = zeit(0.13)
        b = rauschen(n, 700 + 150 * i, 3500) * korn(n, 90) * np.minimum(1, t / 0.004) * np.exp(-t * 22)
        lege(s, t0, b + 0.3 * rauschen(n, None, 400) * np.exp(-t * 40), 1.0 - 0.15 * i)
    return s


def sfx_tod():
    n, t = zeit(1.15)
    s = 0.5 * np.sin(PI2 * np.cumsum(50 + 45 * np.exp(-t * 10)) / SR) * np.exp(-t * 12)
    s += 0.25 * rauschen(n, 200, 1500) * korn(n, 40) * np.exp(-t * 4)
    t0 = 0.02
    for i in range(13):                                # Knochenklappern: kurze hölzerne Klicks
        f = RNG.uniform(700, 2600)
        m, tt = zeit(0.06)
        k = (np.sin(PI2 * f * tt) + 0.5 * np.sin(PI2 * f * 2.7 * tt)) * np.exp(-tt * RNG.uniform(110, 200))
        k += 0.4 * rauschen(m, 2000, None) * np.exp(-tt * 500)
        lege(s, t0, k, (1.0 - 0.055 * i) * RNG.uniform(0.6, 1))
        t0 += RNG.uniform(0.03, 0.11)
    return s


def sfx_schritt():
    n, t = zeit(0.2)
    rascheln = rauschen(n, 1500, 6000) * korn(n, 120) * np.minimum(1, t / 0.01) * np.exp(-t * 28)
    dumpf = (rauschen(n, None, 180) + np.sin(PI2 * 75 * t)) * np.minimum(1, t / 0.004) * np.exp(-t * 40)
    return 0.5 * rascheln + 0.7 * dumpf


def sfx_schmiede():
    n, t = zeit(1.1)
    s = np.zeros(n)
    for f, a, d in ((2140, 1, 5), (3390, 0.7, 6), (4870, 0.5, 8), (5230, 0.4, 9), (6890, 0.3, 12), (8120, 0.2, 15)):
        s += a * (np.sin(PI2 * f * t) + 0.6 * np.sin(PI2 * (f + 7) * t + 1)) * np.exp(-t * d)
    s *= 0.35 * np.minimum(1, t / 0.0004)
    s += 1.5 * rauschen(n, 2000, None) * np.exp(-t * 300)
    s += 1.2 * np.sin(PI2 * 190 * t) * np.exp(-t * 35) + 0.7 * np.sin(PI2 * 420 * t) * np.exp(-t * 30)
    return np.tanh(1.3 * s)


def sfx_aufgabe():
    s = np.zeros(int(1.1 * SR))
    for i, x in enumerate(("G4", "C5", "E5", "G5")):
        lege(s, 0.035 * i, zupf(mi(x), 1.0, 1.0, expo=1.1), 0.9)
    lege(s, 0.12, glocke(mi("C6"), 0.95), 0.3)
    return hallen(s, 0.7, 0.3, 7)[:int(1.3 * SR)]


SFX = {"schlag": (sfx_schlag, -3), "treffer": (sfx_treffer, -3), "block": (sfx_block, -3), "zauber": (sfx_zauber, -3),
       "aufheben": (sfx_aufheben, -3), "stufe": (sfx_stufe, -3), "klick": (sfx_klick, -6), "muenze": (sfx_muenze, -3),
       "essen": (sfx_essen, -3), "tod": (sfx_tod, -3), "schritt": (sfx_schritt, -9), "schmiede": (sfx_schmiede, -3),
       "aufgabe": (sfx_aufgabe, -3)}


# ---------------------------------------------------------------- Ausgabe und Prüfung

def schreibe_wav(pfad, y):
    """y: (Kanäle, n) oder (n,), Werte -1..1 -> 16 bit mit etwas Dither."""
    y = np.atleast_2d(y)
    d = (np.random.default_rng(3).random(y.shape) - np.random.default_rng(4).random(y.shape))
    q = np.clip(np.round(y * 32767 + d), -32768, 32767).astype("<i2")
    with wave.open(pfad, "wb") as w:
        w.setnchannels(q.shape[0])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(q.T.tobytes())
    return q


def naht(y):
    """Sprung zwischen letztem und erstem Sample, absolut und im Verhältnis zum größten Sample-Schritt im Stück."""
    y = y.astype(float)
    d = np.abs(np.diff(y, axis=1))
    s = np.abs(y[:, 0] - y[:, -1]).max()
    return s, s / d.max()


def db(x):
    return 20 * math.log10(max(x, 1e-9))


def encoder():
    out = subprocess.run([FFMPEG, "-hide_banner", "-encoders"], capture_output=True, text=True).stdout
    return ["-c:a", "libvorbis", "-q:a", "6"] if "libvorbis" in out else ["-c:a", "vorbis", "-strict", "-2", "-q:a", "7"]


def musik(name, fn):
    global RNG
    t0 = time.time()
    RNG = np.random.default_rng(sum(map(ord, name)))
    y = fn()
    tmp = os.path.join(AUDIO, "_tmp_%s.wav" % name)
    ogg = os.path.join(AUDIO, "musik_%s.ogg" % name)
    q = schreibe_wav(tmp, y)
    try:
        subprocess.run([FFMPEG, "-y", "-v", "error", "-i", tmp] + encoder() + ["-ac", "2", "-ar", str(SR), ogg], check=True)
    finally:
        os.remove(tmp)
    # Prüfung: OGG zurückdekodieren, Länge, Spitze und Naht mit dem Original vergleichen
    roh = subprocess.run([FFMPEG, "-v", "error", "-i", ogg, "-f", "s16le", "-ac", "2", "-"], capture_output=True, check=True).stdout
    z = np.frombuffer(roh, dtype="<i2").reshape(-1, 2).T
    s0, v0 = naht(q)
    s1, v1 = naht(z)
    print("musik_%s.ogg  %.2f s  Spitze %.1f dBFS (OGG %.1f)  RMS %.1f dBFS  Samples %d/%d  Naht vorher %d (%.2f des größten Sample-Schritts), OGG %d (%.2f)  [%.1f s]"
          % (name, q.shape[1] / SR, db(np.abs(q).max() / 32768), db(np.abs(z).max() / 32768),
             db(math.sqrt((q.astype(float) ** 2).mean()) / 32768), z.shape[1], q.shape[1], s0, v0, s1, v1, time.time() - t0))
    if z.shape[1] == q.shape[1]:
        k = SR // 20
        f = (z.astype(float) - q.astype(float))
        rand = math.sqrt((np.concatenate((f[:, :k], f[:, -k:]), axis=1) ** 2).mean())
        print("    Kodierfehler an den Rändern %.1f dBFS, im ganzen Stück %.1f dBFS" % (db(rand / 32768), db(math.sqrt((f ** 2).mean()) / 32768)))


def effekte():
    global RNG
    for name, (fn, ziel) in SFX.items():
        RNG = np.random.default_rng(100 + sum(map(ord, name)))
        s = np.array(fn(), dtype=float)
        s -= s.mean()
        ausblenden(s, 6, 0.5)
        s *= 10 ** (ziel / 20) / np.max(np.abs(s))
        q = schreibe_wav(os.path.join(AUDIO, "sfx_%s.wav" % name), s)
        print("sfx_%s.wav  %.2f s  Spitze %.1f dBFS" % (name, q.shape[1] / SR, db(np.abs(q).max() / 32768)))


def main():
    os.makedirs(AUDIO, exist_ok=True)
    stuecke = {"dorf": dorf, "wildnis": wildnis, "kampf": kampf, "menue": menue}
    wahl = sys.argv[1:] or list(stuecke) + ["sfx"]
    t0 = time.time()
    for w in wahl:
        if w == "sfx":
            effekte()
        else:
            musik(w, stuecke[w])
    print("Gesamtlaufzeit %.1f s" % (time.time() - t0))


if __name__ == "__main__":
    main()
