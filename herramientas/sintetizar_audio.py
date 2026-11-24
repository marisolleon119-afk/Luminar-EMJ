"""Genera la música y los efectos de Luminar (audio original, creado por código).
Uso: python3 -I sintetizar_audio.py <carpeta_destino>
"""
import sys, os, subprocess
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
rng = np.random.default_rng(7)
OUT = sys.argv[1]
os.makedirs(OUT + "/musica", exist_ok=True)
os.makedirs(OUT + "/efectos", exist_ok=True)


def hz(n):  # n = semitonos desde A4
    return 440.0 * 2 ** (n / 12)


NOTA = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}


def n(nombre, octava):
    return hz(NOTA[nombre] + 12 * (octava - 4))


def t_arr(dur):
    return np.arange(int(dur * SR)) / SR


def env(dur, a=0.01, d=0.1, s=0.7, r=0.2):
    N = int(dur * SR)
    e = np.ones(N) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, N); e[:na] = np.linspace(0, 1, na, endpoint=False)
    nd = min(nd, N - na); e[na:na + nd] = np.linspace(1, s, nd, endpoint=False)
    if nr > 0 and nr < N:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def lp(x, fc, order=2):
    b, a = butter(order, min(fc / (SR / 2), 0.99), "low")
    return lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = butter(order, min(fc / (SR / 2), 0.99), "high")
    return lfilter(b, a, x)


# ---------- Instrumentos ----------
def campana(f, dur, vol=0.3):
    t = t_arr(dur)
    x = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t * 6)
         + 0.18 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 9))
    return vol * x * np.exp(-t * 3.2) * env(dur, 0.003, 0.0, 1.0, 0.05)


def pad(fs, dur, vol=0.12):
    t = t_arr(dur)
    x = np.zeros_like(t)
    for f in fs:
        for det in (-0.12, 0.0, 0.12):
            ff = f * 2 ** (det / 12)
            x += np.sin(2 * np.pi * ff * t) + 0.3 * np.sin(2 * np.pi * 2 * ff * t)
    x = lp(x, 1800)
    return vol * x / (3 * len(fs)) * env(dur, 0.6, 0.2, 0.9, 0.7)


def pluck(f, dur, vol=0.25, brillo=3000):
    t = t_arr(dur)
    saw = 2 * ((f * t) % 1.0) - 1
    x = lp(saw, brillo) * np.exp(-t * 7)
    return vol * x * env(dur, 0.002, 0.0, 1.0, 0.03)


def bajo(f, dur, vol=0.32):
    t = t_arr(dur)
    x = np.sin(2 * np.pi * f * t) + 0.4 * np.sign(np.sin(2 * np.pi * f * t)) * 0.3
    x = lp(x, 500)
    return vol * x * env(dur, 0.005, 0.08, 0.6, 0.05)


def hat(dur=0.05, vol=0.06):
    x = hp(rng.standard_normal(int(dur * SR)), 7000)
    return vol * x * np.exp(-np.arange(len(x)) / SR * 60)


def bombo(vol=0.5):
    t = t_arr(0.25)
    f = 110 * np.exp(-t * 18) + 45
    return vol * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14)


def poner(buf, x, inicio):
    i = int(inicio * SR)
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]


def reverb(x, mezcla=0.25):
    y = x.copy()
    for d, g in ((0.031, 0.5), (0.047, 0.45), (0.071, 0.4), (0.113, 0.35), (0.173, 0.3), (0.241, 0.25)):
        k = int(d * SR)
        eco = np.zeros_like(x)
        eco[k:] = x[:-k] * g
        for _ in range(3):
            eco2 = np.zeros_like(x); eco2[k:] = eco[:-k] * g
            eco += eco2
        y += mezcla * lp(eco, 4000, 1)
    return y


def normalizar(x, pico=0.85):
    return x / (np.max(np.abs(x)) + 1e-9) * pico


def guardar_wav(nombre, x, pico=0.85):
    x = normalizar(x, pico)
    wavfile.write(nombre, SR, (x * 32767).astype(np.int16))


def guardar_ogg(nombre, x, pico=0.8):
    tmp = nombre + ".tmp.wav"
    guardar_wav(tmp, x, pico)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", nombre], check=True)
    os.remove(tmp)


def bucle_sin_cortes(render, dur):
    """Renderiza dos vueltas y se queda con la segunda: la cola de reverb queda dentro del bucle."""
    buf = np.zeros(int(dur * 2 * SR) + SR * 3)
    render(buf, 0.0)
    render(buf, dur)
    buf = reverb(buf, 0.22)
    a = int(dur * SR)
    segunda = buf[a:2 * a].copy()
    # la cola que se sale del final se suma al inicio, así el bucle no se corta
    cola = buf[2 * a:]
    m = min(len(cola), len(segunda))
    segunda[:m] += cola[:m]
    return segunda


# =====================================================================
#  MÚSICA
# =====================================================================
def musica_menu():
    """'Ciudad Faro' — tranquila y misteriosa. 72 bpm, La menor."""
    bpm = 72; negra = 60 / bpm; compas = 4 * negra
    acordes = [
        [n("A", 3), n("C", 4), n("E", 4)], [n("F", 3), n("A", 3), n("C", 4)],
        [n("C", 3), n("E", 3), n("G", 3)], [n("G", 3), n("B", 3), n("D", 4)],
        [n("A", 3), n("C", 4), n("E", 4)], [n("F", 3), n("A", 3), n("C", 4)],
        [n("D", 3), n("F", 3), n("A", 3)], [n("E", 3), n("G#", 3), n("B", 3)],
    ]
    melodia = [  # (tiempo en negras, nota, octava, duración en negras)
        (0, "E", 5, 1), (1, "A", 5, 1), (2, "C", 6, 1.5), (3.5, "B", 5, 0.5),
        (4, "A", 5, 1), (5, "F", 5, 1), (6, "C", 6, 2),
        (8, "G", 5, 1), (9, "E", 5, 1), (10, "C", 5, 1.5), (11.5, "D", 5, 0.5),
        (12, "B", 4, 2), (14, "D", 5, 1), (15, "G", 5, 1),
        (16, "E", 5, 1), (17, "A", 5, 1), (18, "C", 6, 1.5), (19.5, "E", 6, 0.5),
        (20, "C", 6, 1), (21, "A", 5, 1), (22, "F", 5, 2),
        (24, "D", 5, 1), (25, "F", 5, 1), (26, "A", 5, 2),
        (28, "G#", 5, 2), (30, "B", 5, 1), (31, "E", 5, 1),
    ]
    dur = len(acordes) * compas

    def render(buf, t0):
        for i, ac in enumerate(acordes):
            poner(buf, pad(ac, compas + 0.6, 0.16), t0 + i * compas)
            poner(buf, bajo(ac[0] / 2, compas * 0.9, 0.18), t0 + i * compas)
            for k in range(8):  # arpegio suave en corcheas
                f = ac[[0, 1, 2, 1][k % 4]] * 2
                poner(buf, campana(f, 0.9, 0.05), t0 + i * compas + k * negra / 2)
        for (tn, nota, oc, d) in melodia:
            poner(buf, campana(n(nota, oc), d * negra + 1.2, 0.17), t0 + tn * negra)
    guardar_ogg(OUT + "/musica/menu.ogg", bucle_sin_cortes(render, dur))


def musica_juego():
    """'Calles apagadas' — pulso constante y algo de tensión. 104 bpm, Re menor."""
    bpm = 104; negra = 60 / bpm; compas = 4 * negra
    prog = [("D", "F", "A"), ("D", "F", "A"), ("A#", "D", "F"), ("A#", "D", "F"),
            ("G", "A#", "D"), ("G", "A#", "D"), ("A", "C#", "E"), ("A", "C#", "E")]
    bajos = ["D", "D", "A#", "A#", "G", "G", "A", "A"]
    motivo = [  # pequeña melodía de "farol" cada 4 compases
        (0, "A", 5, 0.5), (0.5, "D", 6, 0.5), (1, "F", 6, 1), (2.5, "E", 6, 0.5), (3, "D", 6, 1),
        (16, "A#", 5, 0.5), (16.5, "D", 6, 0.5), (17, "G", 6, 1), (18.5, "F", 6, 0.5), (19, "E", 6, 1),
    ]
    dur = len(prog) * compas

    def render(buf, t0):
        for i, ac in enumerate(prog):
            base = t0 + i * compas
            fs = [n(ac[0], 3), n(ac[1], 4 if NOTA[ac[1]] < NOTA[ac[0]] else 3), n(ac[2], 4 if NOTA[ac[2]] < NOTA[ac[0]] else 3)]
            poner(buf, pad(fs, compas + 0.3, 0.09), base)
            fb = n(bajos[i], 2)
            for k in range(8):  # bajo en corcheas
                poner(buf, bajo(fb * (2 if k in (3, 7) else 1), negra / 2 * 0.9, 0.22), base + k * negra / 2)
            for k in range(16):  # arpegio en semicorcheas
                f = fs[[0, 1, 2, 1, 2, 0, 1, 2][k % 8]] * 2
                poner(buf, pluck(f, 0.22, 0.07, 2600), base + k * negra / 4)
            for k in range(4):
                poner(buf, bombo(0.35 if k in (0, 2) else 0.2), base + k * negra)
            for k in range(8):
                poner(buf, hat(0.04, 0.05 if k % 2 else 0.03), base + k * negra / 2)
        for (tn, nota, oc, d) in motivo:
            poner(buf, campana(n(nota, oc), d * negra + 0.8, 0.10), t0 + tn * negra)
    guardar_ogg(OUT + "/musica/juego.ogg", bucle_sin_cortes(render, dur))


def jingle(nombre, notas, acorde_final, paso=0.16, vol_final=0.16):
    dur = len(notas) * paso + 3.0
    buf = np.zeros(int(dur * SR))
    for i, f in enumerate(notas):
        poner(buf, campana(f, 1.2, 0.22), i * paso)
        poner(buf, pluck(f / 2, 0.3, 0.08), i * paso)
    t_fin = len(notas) * paso
    poner(buf, pad(acorde_final, 2.6, vol_final * 1.6), t_fin)
    for f in acorde_final:
        poner(buf, campana(f * 2, 2.6, 0.12), t_fin)
    buf = reverb(buf, 0.3)
    buf *= env(dur, 0.001, 0.0, 1.0, 0.6)
    guardar_ogg(OUT + "/musica/" + nombre + ".ogg", buf)


# =====================================================================
#  EFECTOS
# =====================================================================
def fx_celda():
    buf = np.zeros(int(0.45 * SR))
    poner(buf, campana(n("E", 6), 0.4, 0.5), 0)
    poner(buf, campana(n("B", 6), 0.35, 0.45), 0.06)
    guardar_wav(OUT + "/efectos/celda.wav", reverb(buf, 0.15))


def fx_farol():
    dur = 1.1; t = t_arr(dur)
    ruido = lp(rng.standard_normal(len(t)), 900) * np.sin(np.pi * np.clip(t / 0.5, 0, 1)) * 0.5
    buf = ruido * (t < 0.5)
    for i, f in enumerate([n("D", 4), n("F#", 4), n("A", 4), n("D", 5)]):
        poner(buf, campana(f, 0.9, 0.3), 0.15 + i * 0.05)
    poner(buf, pad([n("D", 4), n("A", 4)], 0.9, 0.3), 0.15)
    guardar_wav(OUT + "/efectos/farol.wav", reverb(buf, 0.25))


def fx_golpe():
    dur = 0.6; t = t_arr(dur)
    f = 220 * np.exp(-t * 4) + 60
    x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.4 + np.sin(2 * np.pi * np.cumsum(f * 1.01) / SR)
    x = lp(x, 1200) * np.exp(-t * 5)
    buf = x.copy(); poner(buf, bombo(0.9), 0)
    poner(buf, lp(rng.standard_normal(int(0.15 * SR)), 2500) * np.exp(-t_arr(0.15) * 25) * 0.6, 0)
    guardar_wav(OUT + "/efectos/golpe.wav", buf)


def fx_sombra_disipa():
    dur = 0.9; t = t_arr(dur)
    ruido = rng.standard_normal(len(t))
    # barrido descendente de un filtro
    x = np.zeros_like(t)
    trozos = 30
    for k in range(trozos):
        a, b = k * len(t) // trozos, (k + 1) * len(t) // trozos
        fc = 3500 * (1 - k / trozos) + 300
        x[a:b] = lp(ruido, fc)[a:b]
    x *= np.sin(np.pi * t / dur) * 0.5
    tono = np.sin(2 * np.pi * np.cumsum(660 * np.exp(-t * 2)) / SR) * np.exp(-t * 3) * 0.25
    guardar_wav(OUT + "/efectos/sombra_disipa.wav", reverb(x + tono, 0.3), 0.7)


def fx_energia_baja():
    buf = np.zeros(int(0.5 * SR))
    for i in range(2):
        t = t_arr(0.12)
        poner(buf, 0.4 * np.sign(np.sin(2 * np.pi * 880 * t)) * env(0.12, 0.005, 0.02, 0.8, 0.03), i * 0.18)
    guardar_wav(OUT + "/efectos/energia_baja.wav", lp(buf, 3000), 0.6)


def fx_sin_energia():
    t = t_arr(0.25)
    x = 0.5 * np.sign(np.sin(2 * np.pi * 110 * t)) + 0.3 * np.sign(np.sin(2 * np.pi * 116 * t))
    guardar_wav(OUT + "/efectos/error.wav", lp(x, 900) * env(0.25, 0.005, 0.05, 0.7, 0.06), 0.6)


def fx_ronda():
    buf = np.zeros(int(1.6 * SR))
    for i, f in enumerate([n("D", 5), n("F#", 5), n("A", 5), n("D", 6)]):
        poner(buf, campana(f, 1.0, 0.35), i * 0.09)
    poner(buf, pad([n("D", 4), n("F#", 4), n("A", 4)], 1.2, 0.35), 0.36)
    guardar_wav(OUT + "/efectos/ronda.wav", reverb(buf, 0.3))


def fx_ui_click():
    t = t_arr(0.07)
    x = np.sin(2 * np.pi * 1250 * t) * np.exp(-t * 60) + 0.4 * np.sin(2 * np.pi * 2500 * t) * np.exp(-t * 90)
    guardar_wav(OUT + "/efectos/ui_click.wav", x, 0.5)


def fx_ui_hover():
    t = t_arr(0.05)
    guardar_wav(OUT + "/efectos/ui_hover.wav", np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 90), 0.25)


def fx_pausa():
    buf = np.zeros(int(0.35 * SR))
    poner(buf, campana(n("A", 5), 0.3, 0.4), 0)
    poner(buf, campana(n("E", 5), 0.3, 0.4), 0.08)
    guardar_wav(OUT + "/efectos/pausa.wav", buf, 0.55)


def fx_cuenta(nombre, f):
    t = t_arr(0.18)
    x = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t)) * env(0.18, 0.003, 0.03, 0.6, 0.08)
    guardar_wav(OUT + "/efectos/" + nombre + ".wav", x, 0.55)


def fx_alias_ok():
    buf = np.zeros(int(0.4 * SR))
    poner(buf, campana(n("C", 6), 0.3, 0.4), 0)
    poner(buf, campana(n("G", 6), 0.3, 0.4), 0.07)
    guardar_wav(OUT + "/efectos/confirmar.wav", buf, 0.55)


if __name__ == "__main__":
    musica_menu()
    musica_juego()
    jingle("victoria", [n(x, o) for x, o in [("D", 5), ("F#", 5), ("A", 5), ("D", 6), ("E", 6), ("F#", 6)]],
           [n("D", 4), n("F#", 4), n("A", 4), n("D", 5)])
    jingle("derrota", [n(x, o) for x, o in [("A", 5), ("F", 5), ("D", 5), ("C#", 5), ("A", 4)]],
           [n("D", 3), n("F", 3), n("A", 3)], paso=0.24)
    fx_celda(); fx_farol(); fx_golpe(); fx_sombra_disipa(); fx_energia_baja(); fx_sin_energia()
    fx_ronda(); fx_ui_click(); fx_ui_hover(); fx_pausa(); fx_alias_ok()
    fx_cuenta("cuenta", n("A", 5)); fx_cuenta("cuenta_ya", n("A", 6))
    print("listo")
