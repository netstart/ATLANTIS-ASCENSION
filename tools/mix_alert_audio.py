"""Sintetiza os sons de alerta e de coleta que substituem os Kenney agudos, zumbidos ou de 8 bits (1.25.1).

O dono achou o aviso do feixe vermelho do chefe "terrivelmente irritante": era o computerNoise_000 do Kenney, um
zumbido tonal de 5 s em ~1 kHz (crista de 6,7 dB, quase sem dinâmica) que tocava inteiro a cada feixe; com 8,5
feixes por minuto ele soava em ~70% do tempo das lutas, vários por cima uns dos outros. Os outros trocados aqui
são os mais agudos ou "8 bits" que tocam na partida (medidas em tools/mix_alert_audio.py --measure):
  - fx_beam_warn  aviso do feixe: zumbido grave quente que sobe uma quinta (Sol2 a Ré3, com a oitava de baixo),
                  pulso suave no ritmo do pisca da faixa de aviso (7,5 Hz) e ruído abafado crescendo; 1,0 s, nada
                  acima de 2,5 kHz;
  - fx_beam_fire  o feixe acende (antes mudo): baque sub de 95 a 42 Hz, rugido de ruído que fecha de 1,8 kHz a
                  400 Hz e o Ré3 do fim do aviso, com a quinta, morrendo por baixo; 0,9 s;
  - fx_duel       início do duelo (era o laserLarge_000, zap retrô): sucção grave subindo e um baque com acorde
                  de Lá grave (Lá2, Mi3, Lá3) e cauda de sala; 1,4 s;
  - fx_sonar      aviso de objetivo (era o mesmo zumbido do feixe): ping de sonar em Ré5 com dois ecos abafados;
  - fx_horn       reforços inimigos (era o mesmo zumbido, mais grave): trompa grave Ré3 subindo a Fá3,
                  com a oitava de baixo, só harmônicos baixos (sem serra);
  - fx_alarm      chefe de meio de fase (era o rubberduck_alarm, 98% da energia acima de 4 kHz): sirene de dois
                  tons Mi4/Si3 em quatro pulsos, harmônicos até 2 kHz;
  - fx_orb        esfera, glifo e progresso de objetivo (era o powerUp1 do Kenney Digital Audio, 8 bits, 39% acima
                  de 4 kHz): bolha subindo uma oitava e um sino macio;
  - fx_power_up   melhora de arma, captura, clima dominado e as telas (era o powerUp10, 8 bits, centro em 3,6 kHz):
                  arpejo de sinos macios Sol-Si-Ré (o acorde do medidor) com um Sol grave por baixo;
  - fx_graze      raspão (era o highUp, quadrada 8 bits subindo): sopro de ar curto caindo de 1,6 kHz a 700 Hz.

Tudo é síntese do projeto (MIT, a mesma entrada atlantis_power_sfx do registro de licenças): usa os osciladores,
filtros, reverberação e limitador de tools/mix_power_audio.py, com sementes fixas (rodar de novo gera o mesmo som).
Mono, 44,1 kHz, sem silêncio no começo, pico em -1 dBFS, Ogg Vorbis q5 pelo ffmpeg (não precisa do soundfile).

Saída: D:\\src\\assets-downloaded\\atlantis-mix\\alerts\\fx_*.ogg, que tools/alert_audio_assets.json copia para
assets/audio/sfx/ (python -I tools/sync_assets.py). Requer numpy e o ffmpeg ($FFMPEG, D:\\.ai\\tools\\ffmpeg\\bin ou
o PATH):
  python tools/mix_alert_audio.py [--src DIR] [--only beam_warn,orb] [--measure ARQUIVO_OU_PASTA ...]

--measure imprime, para cada .ogg/.wav, duração, pico, RMS ativo, crista, centro espectral, energia acima de 4 kHz e
na faixa de 2 a 5 kHz (a mais incômoda ao ouvido), abaixo de 300 Hz, planura espectral de 1,5 a 8 kHz (perto de 0 é
tonal: zumbido ou quadrada) e um nível ponderado A aproximado.

Resultado (duração, pico, RMS ativo, centro espectral, acima de 4 kHz, nível ponderado A aproximado):
  fx_beam_warn    997 ms  -1.2  -11.6   176 Hz  0.0%  -24.7   (o antigo: 5000 ms, centro 1032 Hz, A -9.9)
  fx_beam_fire    896 ms  -1.0  -12.5    94 Hz  0.0%  -28.4
  fx_duel        1320 ms  -1.0  -11.3   114 Hz  0.0%  -25.8   (laserLarge_000: 14% acima de 4 kHz)
  fx_sonar        965 ms  -1.0  -16.2   860 Hz  0.0%  -19.1
  fx_horn        1145 ms  -1.1   -8.9   190 Hz  0.0%  -21.4
  fx_alarm       1144 ms  -1.0   -6.6   340 Hz  0.0%  -14.8   (alarm_02: centro 5337 Hz, 98% acima de 4 kHz)
  fx_orb          447 ms  -1.0  -14.0  1040 Hz  0.0%  -16.1   (powerUp1: centro 2518 Hz, 39% acima de 4 kHz)
  fx_power_up     823 ms  -1.1  -14.5   661 Hz  0.0%  -18.6   (powerUp10: centro 3564 Hz, 23% acima de 4 kHz)
  fx_graze        197 ms  -1.2  -16.7  1399 Hz  0.3%  -18.6   (highUp: quadrada, A -12.4)
"""
import argparse
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from mix_power_audio import (  # noqa: E402  (síntese compartilhada com os sons dos poderes)
    SR, PEAK_DB, bell, boom, bus, db, echo, env, fft_filter, glide, mix, n_of, noise, osc, reverb, svf, times,
)

FFMPEG_DEFAULT = r"D:\.ai\tools\ffmpeg\bin\ffmpeg.exe"
## Harmônicos macios (1/n^1,5): timbre de trompa ou órgão, sem o zumbido da serra e da quadrada.
SOFT = (1.0, 0.35, 0.19, 0.125, 0.09, 0.068)


def ffmpeg() -> str:
    for cand in (os.environ.get("FFMPEG", ""), FFMPEG_DEFAULT, shutil.which("ffmpeg") or ""):
        if cand and pathlib.Path(cand).is_file():
            return cand
    raise SystemExit("ffmpeg não encontrado: defina $FFMPEG")


def decode(path: pathlib.Path) -> np.ndarray:
    raw = subprocess.run([ffmpeg(), "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(float)


def encode(path: pathlib.Path, x: np.ndarray) -> None:
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).round().astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        src = pathlib.Path(tmp) / "in.wav"
        with wave.open(str(src), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run([ffmpeg(), "-v", "error", "-y", "-i", str(src), "-c:a", "libvorbis", "-q:a", "5",
                        "-map_metadata", "-1", "-fflags", "+bitexact", str(path)], check=True)


def write(path: pathlib.Path, x: np.ndarray) -> dict:
    """Grava e confere o decodificado: o Vorbis mexe no pico, então regrava até ficar entre -1,25 e -1 dBFS."""
    target = 10 ** (PEAK_DB / 20.0)
    for _ in range(8):
        encode(path, x)
        back = decode(path)
        peak = float(np.abs(back).max())
        if target * 0.97 <= peak <= target * 1.001:
            break
        x = x * (target / peak) * 0.996
    m = measure(back)
    print(f"{path.name}: {m['ms']:.0f} ms, pico {m['peak']:.1f} dBFS, RMS ativo {m['arms']:.1f} dBFS, "
          f"centro {m['cent']:.0f} Hz, acima de 4 kHz {m['hi4']:.1f}%")
    return m


def measure(x: np.ndarray) -> dict:
    n = len(x)
    peak = float(np.abs(x).max())
    frame = 1024
    rms = np.array([np.sqrt((x[i:i + frame] ** 2).mean()) for i in range(0, max(1, n - frame), frame // 2)]) \
        if n > frame else np.array([np.sqrt((x ** 2).mean())])
    active = rms[rms > rms.max() * 10 ** (-30 / 20)]
    arms = float(np.sqrt((active ** 2).mean()))
    size = 1 << int(np.ceil(np.log2(n)))
    power = np.abs(np.fft.rfft(x * np.hanning(n), size)) ** 2
    f = np.fft.rfftfreq(size, 1.0 / SR)
    total = power.sum() + 1e-20
    band = power[(f > 1500) & (f < 8000)] + 1e-20
    f2 = f ** 2
    a_w = (12194 ** 2 * f2 ** 2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2))
                                    * (f2 + 12194 ** 2))  # curva de ponderação A (IEC 61672)
    return {
        "ms": n * 1000.0 / SR, "peak": db(peak), "arms": db(arms), "crest": db(peak) - db(arms),
        "cent": float((power * f).sum() / total),
        "hi4": 100.0 * float(power[f > 4000].sum() / total),
        "pres": 100.0 * float(power[(f > 2000) & (f < 5000)].sum() / total),
        "low": 100.0 * float(power[f < 300].sum() / total),
        "flat": float(np.exp(np.log(band).mean()) / band.mean()),
        "a": db(float(np.sqrt((power * a_w ** 2).sum() / total)) * arms),
    }


# ---------------------------------------------------------------- camadas

def tone(freq, seconds: float, partials=SOFT) -> np.ndarray:
    """Soma de harmônicos macios sobre uma frequência (fixa ou variável)."""
    f = np.resize(np.asarray(freq, dtype=float), n_of(seconds))
    y = np.zeros(n_of(seconds))
    for k, a in enumerate(partials, start=1):
        y += a * osc(f * k, seconds, phase=0.13 * k) * (f * k < SR * 0.45)
    return y


def soft_bell(f: float, seconds: float, tau: float) -> np.ndarray:
    """Sino macio: fundamental forte e só parciais 2 e 3 fracas (sem as parciais de cristal que furam)."""
    return bell(f, seconds, (1.0, 2.0, 3.0), tau, attack=0.004)


# ---------------------------------------------------------------- sons

def beam_warn() -> np.ndarray:
    total = 1.0
    t = times(total)
    rise = glide(98.0, 146.8, total, 0.8)  # Sol2 a Ré3: a quinta sobe enquanto o feixe carrega
    hum = tone(rise, total) + 0.55 * tone(rise * 0.5, total)  # e a oitava de baixo, que pesa nos fones
    # Pulso suave no ritmo do pisca da faixa (4 quadros aceso, 4 apagado = 7,5 Hz), sem degrau: cosseno elevado.
    pulse = 0.65 + 0.35 * np.cos(2.0 * np.pi * 7.5 * t)
    charge = tone(rise * 2.0, total, (1.0, 0.25, 0.08)) * pulse
    air = svf(noise(total, 811), glide(300.0, 1800.0, total, 1.6), 0.9)
    grow = 0.25 + 0.75 * np.minimum(t / 0.85, 1.0) ** 1.6
    shape = np.minimum(t / 0.06, 1.0) * np.where(t < 0.85, 1.0, np.exp(-(t - 0.85) / 0.05)) * grow
    y = bus([(hum * shape, 0.0), (charge * shape, -5.0), (air * shape * grow, -8.0)])
    return mix([(fft_filter(y, hi=2500.0), 0.0)], total * 1000.0, 40.0, 2.0)


def beam_fire() -> np.ndarray:
    total = 0.9
    t = times(total)
    roar = svf(noise(total, 821), glide(1800.0, 400.0, total, 0.7), 0.8) * env(total, 0.012, 0.32)
    # O Ré3 em que o aviso parou, com a quinta, morrendo: o feixe "é" a carga que acabou de subir.
    hum = (tone(146.8, total) + 0.5 * tone(220.0, total)) * env(total, 0.02, 0.4)
    y = bus([(boom(total, 95.0, 42.0, 0.3, 822), -3.0), (roar, 0.0), (hum, -3.0)])
    y = fft_filter(y * (1.0 - (t / total) ** 4), hi=3000.0)
    return mix([(reverb(y, 0.5, 0.12, 823, 2500.0), 0.0)], total * 1000.0, 120.0, 3.0)


def duel() -> np.ndarray:
    pre = 0.5
    suck = svf(noise(pre, 831), glide(300.0, 2200.0, pre, 2.0), 1.2) * (times(pre) / pre) ** 2.5
    chord = sum(tone(f, 1.0) for f in (110.0, 164.8, 220.0)) * env(1.0, 0.006, 0.35)
    hit = bus([(boom(1.0, 85.0, 35.0, 0.35, 832), -3.0), (chord, -1.0)])
    y = bus([(suck, -4.0), (hit, 0.0, pre)])
    y = fft_filter(y, hi=2500.0)
    return mix([(reverb(y, 0.9, 0.2, 833, 2000.0), 0.0)], 1400.0, 250.0, 3.0)


def sonar() -> np.ndarray:
    ping = soft_bell(587.3, 0.35, 0.22) + 0.3 * osc(293.7, 0.35) * env(0.35, 0.01, 0.2)
    y = echo(ping, 0.2, 0.42, 2, lowpass=1800.0)
    return mix([(reverb(fft_filter(y, hi=2500.0), 0.6, 0.15, 841, 2000.0), 0.0)], 1000.0, 200.0, 1.0)


def horn() -> np.ndarray:
    def note(f: float, seconds: float, bend: float) -> np.ndarray:
        t = times(seconds)
        pitch = f * (1.0 + bend * np.minimum(t / 0.2, 1.0))
        e = np.minimum(t / 0.18, 1.0) ** 1.5 * np.exp(-np.maximum(0.0, t - seconds * 0.6) / 0.12)
        return (tone(pitch * 2.0, seconds) + 0.5 * tone(pitch, seconds)) * e

    y = bus([(note(73.4, 0.6, 0.015), 0.0), (note(87.3, 0.7, 0.01), 0.0, 0.45)])
    y = fft_filter(y, hi=1500.0)
    return mix([(reverb(y, 0.7, 0.15, 851, 1500.0), 0.0)], 1150.0, 150.0, 2.0)


def alarm() -> np.ndarray:
    def pulse(f: float) -> np.ndarray:
        d = 0.2
        t = times(d)
        return tone(f, d) * np.minimum(t / 0.015, 1.0) * np.exp(-np.maximum(0.0, t - 0.12) / 0.04)

    layers = [(pulse(329.6 if k % 2 == 0 else 246.9), 0.0, 0.2 * k) for k in range(4)]
    y = fft_filter(bus(layers), hi=2000.0)
    return mix([(reverb(y, 0.5, 0.15, 861, 2000.0), 0.0)], 1250.0, 200.0, 2.0)


def orb() -> np.ndarray:
    d = 0.09
    bubble = osc(glide(440.0, 880.0, d, 0.7), d) * env(d, 0.002, 0.05)
    y = bus([(bubble, -2.0), (soft_bell(880.0, 0.4, 0.15), -4.0, 0.05)])
    return mix([(fft_filter(y, hi=3000.0), 0.0)], 450.0, 100.0, 1.0)


def power_up() -> np.ndarray:
    notes = (392.0, 493.9, 587.3)
    layers = [(soft_bell(f, 0.6 if k == 2 else 0.3, 0.25 if k == 2 else 0.12), -3.0 if k else 0.0, 0.07 * k)
              for k, f in enumerate(notes)]
    layers.append((osc(196.0, 0.5) * env(0.5, 0.02, 0.2), -9.0))
    y = fft_filter(bus(layers), hi=3500.0)
    return mix([(reverb(y, 0.5, 0.15, 871, 3000.0), 0.0)], 800.0, 150.0, 1.0)


def graze() -> np.ndarray:
    total = 0.2
    t = times(total)
    air = svf(noise(total, 881), glide(1600.0, 700.0, total), 1.2, "band")
    shape = np.minimum(t / 0.015, 1.0) * np.exp(-np.maximum(0.0, t - 0.015) / 0.05)
    y = bus([(air * shape, 0.0), (osc(glide(660.0, 520.0, total), total) * shape, -14.0)])
    return mix([(fft_filter(y, hi=4000.0), 0.0)], total * 1000.0, 40.0, 1.0)


SOUNDS = {
    "beam_warn": beam_warn, "beam_fire": beam_fire, "duel": duel, "sonar": sonar, "horn": horn, "alarm": alarm,
    "orb": orb, "power_up": power_up, "graze": graze,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", default=r"D:\src\assets-downloaded")
    parser.add_argument("--only", default="", help="lista separada por vírgula, ex.: beam_warn,orb")
    parser.add_argument("--measure", nargs="*", default=None, help="só mede os arquivos ou pastas dados")
    args = parser.parse_args()
    if args.measure is not None:
        for item in args.measure:
            p = pathlib.Path(item)
            for f in sorted(p.glob("*")) if p.is_dir() else [p]:
                if f.suffix in (".ogg", ".wav"):
                    m = measure(decode(f))
                    print(f"{f.stem:26s} {m['ms']:6.0f} ms  pico {m['peak']:5.1f}  RMS {m['arms']:5.1f}  "
                          f"crista {m['crest']:4.1f}  centro {m['cent']:5.0f} Hz  >4k {m['hi4']:4.1f}%  "
                          f"2-5k {m['pres']:4.1f}%  <300 {m['low']:4.1f}%  planura {m['flat']:.3f}  A {m['a']:5.1f}")
        return 0
    out = pathlib.Path(args.src) / "atlantis-mix" / "alerts"
    out.mkdir(parents=True, exist_ok=True)
    failed = 0
    for name in [w for w in args.only.split(",") if w] or list(SOUNDS):
        m = write(out / f"fx_{name}.ogg", SOUNDS[name]())
        if m["peak"] > -0.9 or m["hi4"] > 5.0 or not 150.0 <= m["ms"] <= 1500.0:
            print(f"  ERRO: fx_{name}.ogg fora do padrão")
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
