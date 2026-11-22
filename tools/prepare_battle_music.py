"""Prepara as trilhas das fases e dos chefes para tocar em laço sem emenda e no mesmo volume.

As fontes variam de -5 a -17 dB RMS e quase nenhuma foi feita para laço. Para cada faixa da tabela TRACKS:

1. Decodifica com o ffmpeg para float 44,1 kHz estéreo.
2. Laço. Arquivos já feitos para laço ("-loop", "loopable") só perdem o silêncio digital das pontas. Nos outros,
   procura o par (a, b) em que os 8 s depois de b soam como os 8 s depois de a (bandas log do espectro, nível
   parecido): pular de b para a é então o que a própria música faria. A distância b - a sai múltipla de compasso
   (a repetição está no tempo da música); os dois pontos andam juntos até o ataque mais forte perto, e o ajuste
   fino é por correlação da onda, amostra a amostra. O arquivo final é x[a:b] com os primeiros CROSS s misturados
   com x[b:b + CROSS]: tocado em laço, o fim continua exatamente no começo. O laço vai de LOOP_MIN a LOOP_MAX s
   (o tamanho do AAB conta).
3. Loudness (ITU-R BS.1770, filtro ebur128 do ffmpeg): ganho para TARGET_LUFS integrado. Se o pico real passar de
   PEAK_DBTP, um limitador sobre o áudio superamostrado (4x) segura o pico; ele roda sobre [fim, laço] para chegar
   ao começo no mesmo estado em que sai do fim, e o laço continua sem emenda.
4. Grava Ogg Vorbis q5 44,1 kHz estéreo em D:\\src\\assets-downloaded\\atlantis-mix\\music\\<id>.ogg, de onde
   tools/sync_assets.py copia (manifestos tools/*_music_assets.json).

Requer numpy e o ffmpeg ($FFMPEG, D:\\.ai\\tools\\ffmpeg\\bin ou PATH). Não usa soundfile.
Uso: python tools/prepare_battle_music.py [--only=id1,id2] [--src DIR] [--out DIR]
"""
import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys

import numpy as np

SR = 44100
TARGET_LUFS = -14.0
PEAK_DBTP = -1.0
QUALITY = 5
WINDOW_S = 8.0
CROSS_S = 0.6
LOOP_MIN_S = 45.0
LOOP_MAX_S = 180.0
HOP = 1024
FRAME = 2048

# id final -> (arquivo em D:\src\assets-downloaded, já é laço)
TRACKS = {
    # Fases, uma por capítulo.
    "flow_tactical_combat": ("google_flow_music/Futuristic-tactical-combat/Tactical Combat Loop.mp3", False),
    "fardifferent_temples": ("itch/fardifferent-escape/Of Far Different Nature - Escape (CC-BY 4.0)/"
                             "Of Far Different Nature - Escape (CC-BY 4.0)/"
                             "Of Far Different Nature - Escape - 11 - Temples.mp3", False),
    "fardifferent_another_step_back": ("itch/fardifferent-another-step-back/"
                                       "Of Far Different Nature - Another Step Back (CC-BY 4.0)/"
                                       "Of Far Different Nature - Another Step Back (CC-BY 4.0)/"
                                       "Of Far Different Nature - Another Step Back - 03 - Another Step Back.mp3",
                                       False),
    "bogart_cyber_power": ("opengameart/cyber-power/cyber_power_0.mp3", False),
    # A versão "loopable" termina num decaimento de 2,4 s (-57 dB): o laço sai da busca, como nas outras.
    "bogart_neon_action": ("opengameart/neon-action/Neon Action (loopable)_0.mp3", False),
    "dancramp_cyber_side_scroller": ("itch/dancramp-void-music-pack/dancramp - Void/"
                                     "dancramp - Void - 05 Cyber Side Scroller.wav", False),
    "davidkbd_plasma_storm": ("itch/davidkbd-interstellar-edm-metal-music-pack/"
                              "DavidKBD - InterstellarPack - 02 - Plasma Storm.ogg", False),
    "davidkbd_orbital_assault": ("itch/davidkbd-interstellar-vol2-edm-metal-music-pack/"
                                 "DavidKBD - Interstellar vol2 09 - Orbital Assault.ogg", False),
    "davidkbd_binary_chaos": ("itch/davidkbd-code-injection-dark-techno-music-pack/"
                              "DavidKBD - Code injection Pack - 07 - Binary Chaos-loop.ogg", True),
    "fardifferent_ritual": ("itch/fardifferent-another-step-back/"
                            "Of Far Different Nature - Another Step Back (CC-BY 4.0)/"
                            "Of Far Different Nature - Another Step Back (CC-BY 4.0)/"
                            "Of Far Different Nature - Another Step Back - 04 - Ritual.mp3", False),
    # Chefes.
    "flow_apex_onslaught": ("google_flow_music/boss/Apex Onslaught.mp3", False),
    "flow_final_onslaught": ("google_flow_music/boss/Final Onslaught.mp3", False),
    "esiltir_calamity": ("opengameart/calamity-epic-orchestral-metal/Esiltir - Calamity_0.mp3", False),
    "aroldv_cyberpunk_boss": ("opengameart/cyberpunk-boss/cyberpunk_boss.flac", False),
    "mintodog_space_boss_battle": ("opengameart/space-boss-battle/space_boss_battle_bpm175_0.ogg", True),
}


def ffmpeg_bin() -> str:
    for cand in (os.environ.get("FFMPEG", ""), r"D:\.ai\tools\ffmpeg\bin\ffmpeg.exe", shutil.which("ffmpeg") or ""):
        if cand and pathlib.Path(cand).is_file():
            return cand
    sys.exit("ffmpeg não encontrado: defina $FFMPEG")


FF = ffmpeg_bin()
RAW = ["-f", "f32le", "-ar", str(SR), "-ac", "2"]


def decode(path: pathlib.Path) -> np.ndarray:
    out = subprocess.run([FF, "-v", "error", "-i", str(path), *RAW, "-"], capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def run_filter(x: np.ndarray, af: str) -> tuple[np.ndarray | None, str]:
    """Passa x pelo filtro do ffmpeg; devolve o áudio (ou None com -f null) e o stderr."""
    null = af.startswith("ebur128")
    cmd = [FF, "-hide_banner", "-nostats", *RAW, "-i", "-", "-af", af]
    cmd += ["-f", "null", "-"] if null else [*RAW, "-"]
    p = subprocess.run(cmd, input=x.astype(np.float32).tobytes(), capture_output=True, check=True)
    y = None if null else np.frombuffer(p.stdout, dtype=np.float32).reshape(-1, 2).astype(np.float64)
    return y, p.stderr.decode("utf-8", "replace")


def loudness(x: np.ndarray) -> tuple[float, float]:
    """(LUFS integrado, pico real em dBTP) pelo ebur128 do ffmpeg."""
    _, err = run_filter(x, "ebur128=peak=true:framelog=quiet")
    summary = err[err.rfind("Summary:"):]
    lufs = float(re.search(r"I:\s+(-?[\d.]+|-inf) LUFS", summary).group(1))
    peak = float(re.search(r"True peak:\s+Peak:\s+(-?[\d.]+|-inf) dBFS", summary).group(1))
    return lufs, peak


def trim_silence(x: np.ndarray) -> np.ndarray:
    mono = np.abs(x).max(axis=1)
    idx = np.nonzero(mono > 10 ** (-60 / 20))[0]
    return x[idx[0]:idx[-1] + 1]


def band_features(mono: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Bandas log do espectro (centradas e normalizadas por quadro) e nível em dB por quadro."""
    frames = np.lib.stride_tricks.sliding_window_view(mono, FRAME)[::HOP] * np.hanning(FRAME)
    spec = np.abs(np.fft.rfft(frames, axis=1)) ** 2
    freqs = np.fft.rfftfreq(FRAME, 1 / SR)
    edges = np.geomspace(40, 16000, 41)
    bands = np.stack([spec[:, (freqs >= lo) & (freqs < hi)].sum(axis=1) for lo, hi in zip(edges[:-1], edges[1:])], 1)
    logb = np.log(bands + 1e-9)
    level = 10 * np.log10(spec.sum(axis=1) + 1e-12)
    f = logb - logb.mean(axis=0)
    f /= np.linalg.norm(f, axis=1, keepdims=True) + 1e-9
    return f.astype(np.float32), level


def onset_strength(mono: np.ndarray) -> np.ndarray:
    frames = np.lib.stride_tricks.sliding_window_view(mono, FRAME)[::HOP] * np.hanning(FRAME)
    mag = np.log1p(np.abs(np.fft.rfft(frames, axis=1)))
    flux = np.maximum(np.diff(mag, axis=0), 0).sum(axis=1)
    return np.concatenate([[0.0], flux])


def beat_period(onset: np.ndarray) -> float:
    """Período do tempo em quadros (autocorrelação do ataque, 70 a 190 BPM)."""
    o = onset - onset.mean()
    ac = np.correlate(o, o, "full")[len(o) - 1:]
    fps = SR / HOP
    lags = np.arange(len(ac))
    ok = (lags >= fps * 60 / 185) & (lags <= fps * 60 / 85)
    lag = int(lags[ok][np.argmax(ac[ok])])
    # Refina pelo pico de 8 tempos (8x mais preciso), com interpolação parabólica.
    lo, hi = 8 * lag - 6, min(8 * lag + 7, len(ac) - 1)
    k = lo + int(np.argmax(ac[lo:hi]))
    den = ac[k - 1] - 2 * ac[k] + ac[k + 1]
    frac = 0.5 * (ac[k - 1] - ac[k + 1]) / den if den else 0.0
    return (k + frac) / 8


def find_loop(x: np.ndarray) -> dict:
    mono = x.mean(axis=1)
    feats, level = band_features(mono)
    onset = onset_strength(mono)
    n = len(feats)
    fps = SR / HOP
    w = int(WINDOW_S * fps)
    dur = len(x) / SR
    a_max = int(min(dur * 0.35, 60.0) * fps)
    lmin = int(max(LOOP_MIN_S, dur * 0.45) * fps)
    lmax = int(LOOP_MAX_S * fps)
    b_min = lmin
    b_max = n - w - int((CROSS_S + 0.5) * fps)
    if b_max <= b_min:
        sys.exit(f"faixa curta demais para o laço ({dur:.1f} s)")
    # Similaridade das janelas de w quadros que começam em a e em b (soma acumulada ao longo das diagonais).
    m = feats[:a_max + w] @ feats[b_min:b_max + w].T
    c = np.zeros((m.shape[0] + 1, m.shape[1] + 1), dtype=np.float64)
    for i in range(m.shape[0]):
        c[i + 1, 1:] = c[i, :-1] + m[i]
    sim = (c[w:a_max + w, w:] - c[:a_max, :-w])[:, :b_max - b_min] / w      # sim[a, b - b_min]
    lev = np.convolve(level, np.ones(w) / w, "valid")
    dlev = np.abs(lev[:a_max, None] - lev[None, b_min:b_max])
    a_idx = np.arange(a_max)[:, None]
    b_idx = np.arange(b_min, b_max)[None, :]
    length = b_idx - a_idx
    # O laço fecha em compassos inteiros de 4 tempos: mais de 0,15 compasso fora da grade (o erro da estimativa do tempo cresce com o laço) está fora; menos custa pontos.
    period = beat_period(onset)
    bars_f = length / (4 * period)
    grid = np.abs(bars_f - np.round(bars_f))
    score = (sim - 0.02 * dlev - 0.3 * grid - 0.06 * a_idx / max(a_max, 1)
             + 0.08 * np.minimum(length, lmax) / lmax)
    score[(length < lmin) | (length > lmax) | (grid > 0.15)] = -np.inf
    # Timbre parecido não basta: entre os 300 melhores pares, vale também o ritmo (correlação dos ataques nas
    # duas janelas). Fora do tempo, os ataques não batem.
    on = onset - np.convolve(onset, np.ones(43) / 43, "same")
    flat = np.argsort(score, axis=None)[::-1][:300]
    best, pick = -np.inf, (0, b_min, 0.0, 0.0)
    for ai, bj in zip(*np.unravel_index(flat, score.shape)):
        a, b = int(ai), int(bj + b_min)
        u, v = on[a:a + w], on[b:b + w]
        rhythm = float(u @ v / (np.linalg.norm(u) * np.linalg.norm(v) + 1e-12))
        total = score[ai, bj] + 0.5 * rhythm
        if total > best:
            best, pick = total, (a, b, float(sim[ai, bj]), rhythm)
    a, b, best_sim, rhythm = pick
    # Os dois pontos andam juntos (até meio compasso) até o ataque mais forte: a junção cai no tempo forte.
    half_bar = int(2 * period)
    shifts = [d for d in range(-half_bar, half_bar + 1) if a + d >= 0 and b + d + w < n]
    d = max(shifts, key=lambda k: onset[a + k] + onset[b + k])
    a, b = a + d, b + d
    # Ajuste fino, amostra a amostra, até um quadro para cada lado: correlação da onda logo depois dos dois
    # pontos. Se a onda pouco se parece (outra voz, outra variação), alinha pelos ataques (envoltória).
    a_s, b_s = a * HOP, b * HOP
    seg = int(1.5 * SR)
    lo = max(b_s - HOP, 0)

    def best_lag(sig: np.ndarray) -> tuple[int, float]:
        ref = sig[a_s:a_s + seg]
        hay = sig[lo:b_s + HOP + seg]
        corr = np.correlate(hay, ref, "valid")
        norm = np.sqrt(np.convolve(hay ** 2, np.ones(seg), "valid")) * np.linalg.norm(ref) + 1e-12
        k = int(np.argmax(corr / norm))
        return k, float(corr[k] / norm[k])

    k, r = best_lag(mono)
    if r < 0.5:
        env = np.convolve(np.abs(np.diff(mono, prepend=0.0)), np.ones(88) / 88, "same")
        k, _ = best_lag(env - env.mean())
        ref = mono[a_s:a_s + seg]
        cand = mono[lo + k:lo + k + seg]
        r = float(ref @ cand / (np.linalg.norm(ref) * np.linalg.norm(cand) + 1e-12))
    b_s = lo + k
    # Compassos de 4 tempos no laço; o BPM informado é o que fecha esse número inteiro no tamanho exato.
    loop_s = (b_s - a_s) / SR
    bars = max(1, round(loop_s / (4 * period / fps)))
    return {"a": a_s, "b": b_s, "sim": best_sim, "rhythm": rhythm, "corr": r, "bpm": 240 * bars / loop_s, "bars": bars,
            "bar_err": loop_s / (4 * period / fps) - bars}


def make_loop(x: np.ndarray, info: dict) -> np.ndarray:
    a, b = info["a"], info["b"]
    c = int(CROSS_S * SR)
    y = x[a:b].copy()
    t = np.linspace(0.0, 1.0, c)[:, None]
    if info["corr"] > 0.5:   # trechos parecidos: soma de amplitudes constante
        fade_in = 0.5 - 0.5 * np.cos(np.pi * t)
        fade_out = 1.0 - fade_in
    else:                    # pouco correlacionados: soma de potências constante
        fade_in, fade_out = np.sin(t * np.pi / 2), np.cos(t * np.pi / 2)
    y[:c] = x[a:a + c] * fade_in + x[b:b + c] * fade_out
    return y


def limit_loop(y: np.ndarray, ceiling_db: float) -> np.ndarray:
    """Limitador sobre o áudio superamostrado 4x. Roda sobre [fim, laço] para o começo herdar o estado do fim."""
    pre = min(len(y), 4 * SR)
    z = np.concatenate([y[-pre:], y])
    af = (f"aresample={4 * SR},alimiter=limit={10 ** (ceiling_db / 20):.4f}:level=disabled:attack=1:release=60:"
          f"asc=1,aresample={SR}")
    z, _ = run_filter(z, af)
    # A ida e volta da reamostragem pode mudar o total em poucas amostras: mantém o tamanho do laço.
    z = z[pre:pre + len(y)]
    return np.concatenate([z, np.zeros((len(y) - len(z), 2))]) if len(z) < len(y) else z


def render(y: np.ndarray, out: pathlib.Path) -> tuple[float, float, float, str]:
    """Normaliza, grava e mede o OGG. Se o pico real do arquivo passar do teto, limita mais baixo e regrava."""
    lufs, _ = loudness(y)
    gain_db = TARGET_LUFS - lufs
    base = y * 10 ** (gain_db / 20)
    _, peak = loudness(base)
    z, note = base, ""
    for ceiling in (PEAK_DBTP - 0.5, PEAK_DBTP - 1.0, PEAK_DBTP - 1.5, PEAK_DBTP - 2.0):
        encode(z, out)
        lufs, peak = loudness(decode(out))
        if peak <= PEAK_DBTP:
            break
        # Compensa o que o limitador tira do loudness (até 2 dB), sem passar do teto.
        z = limit_loop(base, ceiling)
        extra = min(2.0, max(0.0, TARGET_LUFS - loudness(z)[0]))
        if extra > 0.2:
            z = limit_loop(base * 10 ** (extra / 20), ceiling)
        note = f", limitador em {ceiling:.1f} dBTP"
    return lufs, peak, gain_db, note


def encode(y: np.ndarray, out: pathlib.Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([FF, "-v", "error", "-y", *RAW, "-i", "-", "-c:a", "libvorbis", "-q:a", str(QUALITY), str(out)],
                   input=y.astype(np.float32).tobytes(), check=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=r"D:\src\assets-downloaded")
    ap.add_argument("--out", default=r"D:\src\assets-downloaded\atlantis-mix\music")
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    only = {s for s in args.only.split(",") if s}
    src, out_dir = pathlib.Path(args.src), pathlib.Path(args.out)
    print(f"{'id':32} {'LUFS':>6} {'dBTP':>6} {'dur s':>7}  laço")
    for tid, (rel, is_loop) in TRACKS.items():
        if only and tid not in only:
            continue
        x = decode(src / rel)
        if is_loop:
            y = trim_silence(x)
            loop_txt = "arquivo já em laço (0 até o fim)"
        else:
            info = find_loop(x)
            y = make_loop(x, info)
            loop_txt = (f"{info['a'] / SR:.2f}-{info['b'] / SR:.2f} s, {info['bars']} compassos a "
                        f"{info['bpm']:.1f} BPM (erro {info['bar_err']:+.2f}), timbre {info['sim']:.2f}, ritmo {info['rhythm']:.2f}, onda {info['corr']:.2f}")
        out = out_dir / f"{tid}.ogg"
        lufs, peak, gain_db, note = render(y, out)
        print(f"{tid:32} {lufs:6.1f} {peak:6.1f} {len(y) / SR:7.1f}  {loop_txt}; ganho {gain_db:+.1f} dB{note}; "
              f"{out.stat().st_size / 1e6:.2f} MB", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
