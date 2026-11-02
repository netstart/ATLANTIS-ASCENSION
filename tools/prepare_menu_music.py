"""Prepara a trilha do menu (1.16.0) gerada no Google Flow Music para tocar em laço sem emenda.

A faixa "Atlantis Ascension - Main Theme (Alt Take)" foi gerada pelo mantenedor no Google Flow Music (Lyria) em
2026-11-01 e baixada em WAV 48 kHz estéreo. Ela começa calma (-26 dB RMS), cresce até o tema heroico e volta à calma
no fim (-25 dB), então o fim casa com o começo.

O laço: os últimos FADE segundos da faixa são misturados por igual potência sobre os primeiros FADE segundos, e a
faixa é cortada ali. Tocada em laço, a última amostra continua exatamente na primeira (o começo já contém a cauda),
sem clique e sem silêncio. Depois normaliza para -16 LUFS aproximado (RMS) com pico máximo em -1 dBFS.

Entrada:  c:\\src\\downloads\\assets\\flow-music\\menu\\main_theme_alt.wav
Saída:    c:\\src\\downloads\\assets\\flow-music\\menu\\flow_tide_rising.ogg (Vorbis q6, 48 kHz estéreo)

Requer numpy e soundfile: python tools/prepare_menu_music.py [--src DIR]
"""
import argparse
import pathlib
import sys

import numpy as np
import soundfile as sf

FADE = 4.0
TARGET_RMS_DB = -16.0
PEAK_DB = -1.0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=r"c:\src\downloads\assets\flow-music\menu")
    args = ap.parse_args()
    src = pathlib.Path(args.src)
    x, sr = sf.read(src / "main_theme_alt.wav", always_2d=True)
    # Corta o silêncio do fim (abaixo de -60 dB do pico), se houver.
    mono = np.abs(x).max(axis=1)
    thr = mono.max() * 10 ** (-60 / 20)
    end = int(np.nonzero(mono > thr)[0][-1]) + 1
    x = x[:end]
    c = int(FADE * sr)
    loop_len = len(x) - c
    t = np.linspace(0.0, np.pi / 2, c)[:, None]
    y = x[:loop_len].copy()
    y[:c] = x[:c] * np.sin(t) + x[loop_len:] * np.cos(t)
    rms = np.sqrt((y ** 2).mean())
    gain = 10 ** (TARGET_RMS_DB / 20) / rms
    peak = np.abs(y).max() * gain
    limit = 10 ** (PEAK_DB / 20)
    if peak > limit:
        gain *= limit / peak
    y *= gain
    out = src / "flow_tide_rising.ogg"
    # Em blocos: o libsndfile 1.2 derruba o Python ao gravar Vorbis longo de uma vez.
    with sf.SoundFile(out, "w", sr, y.shape[1], format="OGG", subtype="VORBIS", compression_level=0.4) as f:
        for i in range(0, len(y), sr):
            f.write(y[i:i + sr])
    print(f"{out}: {loop_len / sr:.1f} s, ganho {20 * np.log10(gain):+.1f} dB, pico {20 * np.log10(np.abs(y).max()):.1f} dBFS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
