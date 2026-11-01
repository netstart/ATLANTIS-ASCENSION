"""Prepara o áudio do clima (1.13 "Céu e Mar Vivos") a partir dos arquivos CC0 baixados.

Entrada (fora do repositório, em c:\\src\\downloads\\assets\\opengameart):
  rain-and-thunders/Dark_Rainy_Night(ambience).ogg   kindland, CC0: chuva forte com trovões
  underwater-ambient-pad/Underwater-Ambient-Pad-isaiah658_0.ogg   isaiah658, CC0
  30-cc0-sfx-loops/x/{rain,noise_01,water_flowing}.ogg   rubberduck, CC0

Saída: opengameart/weather-cuts/*.ogg, que o manifesto tools/weather_audio_assets.json copia para assets/.
  - três trovões recortados da gravação (início no ataque, cauda de 1,5 s), pico em -1 dBFS;
  - um trecho de 24 s da mesma gravação sem trovão, com emenda cruzada: a base da tempestade em laço;
  - os laços curtos (chuva fina, vento, água correndo, pad submerso) com o mesmo nível RMS.
Tudo mono a 44,1 kHz. Os trovões são achados pela energia, não por tempo fixo: o script imprime onde.

Requer numpy e soundfile (python -m pip install numpy soundfile); rode com o Python que os tem:
  python tools/cut_weather_audio.py [--src DIR]
"""
import argparse
import pathlib
import sys

import numpy as np
import soundfile as sf

SR = 44100
PEAK_DB = -1.5
# Nível dos laços (RMS em dBFS): o volume fino de cada camada fica no jogo (WeatherAudio).
LOOP_RMS_DB = -22.0
# Trovões: perto de cada instante (s) procura o pico de energia numa janela de -2 a +3 s.
THUNDERS = (34.0, 90.0, 146.0)
THUNDER_PRE = 0.25
THUNDER_LEN = 6.5
THUNDER_TAIL = 1.5
# Trecho sem trovão para a base da tempestade, e a emenda cruzada do laço.
STORM_BED = (60.0, 84.0)
LOOP_XFADE = 1.5


def load(path: pathlib.Path) -> np.ndarray:
    data, sr = sf.read(str(path), always_2d=True)
    mono = data.mean(axis=1)
    if sr != SR:
        # Reamostragem linear: só os laços curtos de 48 kHz passam por aqui (ruído de banda larga).
        t = np.arange(int(len(mono) * SR / sr)) * sr / SR
        mono = np.interp(t, np.arange(len(mono)), mono)
    return mono


def db(x: float) -> float:
    return float(20.0 * np.log10(max(x, 1e-12)))


def peak_to(x: np.ndarray, target_db: float) -> np.ndarray:
    return x * (10 ** (target_db / 20.0) / max(np.abs(x).max(), 1e-12))


def rms_to(x: np.ndarray, target_db: float) -> np.ndarray:
    rms = float(np.sqrt((x ** 2).mean()))
    y = x * (10 ** (target_db / 20.0) / max(rms, 1e-12))
    # Nunca passa do pico máximo (ruído forte cortaria).
    if np.abs(y).max() > 10 ** (PEAK_DB / 20.0):
        y = peak_to(y, PEAK_DB)
    return y


def fade(x: np.ndarray, fade_in: float, fade_out: float) -> np.ndarray:
    y = x.copy()
    a = int(fade_in * SR)
    b = int(fade_out * SR)
    if a > 0:
        y[:a] *= np.linspace(0.0, 1.0, a)
    if b > 0:
        y[-b:] *= np.linspace(1.0, 0.0, b) ** 2
    return y


def seamless(x: np.ndarray, xfade: float) -> np.ndarray:
    """Laço sem emenda: o fim entra no começo com ganho de potência constante."""
    n = int(xfade * SR)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    t = np.linspace(0.0, np.pi / 2.0, n)
    mixed = tail * np.cos(t) + head * np.sin(t)
    return np.concatenate([mixed, body])


def onset(x: np.ndarray, around: float) -> float:
    """Instante (s) do maior salto de energia perto de `around`: o estalo do trovão."""
    win = int(0.05 * SR)
    lo = int((around - 2.0) * SR)
    hi = int((around + 3.0) * SR)
    seg = x[lo:hi]
    n = len(seg) // win
    energy = np.sqrt((seg[:n * win].reshape(n, win) ** 2).mean(axis=1))
    rise = np.diff(energy, prepend=energy[0])
    return (lo + int(np.argmax(rise)) * win) / SR


def write(path: pathlib.Path, x: np.ndarray) -> None:
    # Em blocos: o codificador Vorbis do libsndfile estoura a pilha no Windows com um bloco grande.
    with sf.SoundFile(str(path), "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        data = x.astype(np.float32)
        for k in range(0, len(data), 4096):
            f.write(data[k:k + 4096])
    print(f"{path.name}: {len(x) / SR:.1f} s, pico {db(np.abs(x).max()):.1f} dBFS, "
          f"RMS {db(float(np.sqrt((x ** 2).mean()))):.1f} dBFS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", default=r"c:\src\downloads\assets\opengameart")
    src = pathlib.Path(parser.parse_args().src)
    out = src / "weather-cuts"
    out.mkdir(parents=True, exist_ok=True)
    night = load(src / "rain-and-thunders" / "Dark_Rainy_Night(ambience).ogg")
    for k, around in enumerate(THUNDERS):
        at = onset(night, around)
        start = int((at - THUNDER_PRE) * SR)
        clip = night[start:start + int(THUNDER_LEN * SR)]
        print(f"trovão {k + 1}: ataque em {at:.2f} s")
        write(out / f"thunder_{k + 1}.ogg", peak_to(fade(clip, 0.03, THUNDER_TAIL), PEAK_DB))
    bed = night[int(STORM_BED[0] * SR):int(STORM_BED[1] * SR)]
    write(out / "storm_bed.ogg", rms_to(seamless(bed, LOOP_XFADE), LOOP_RMS_DB))
    loops = {
        "rain_light.ogg": src / "30-cc0-sfx-loops" / "x" / "rain.ogg",
        "wind.ogg": src / "30-cc0-sfx-loops" / "x" / "noise_01.ogg",
        "water_flow.ogg": src / "30-cc0-sfx-loops" / "x" / "water_flowing.ogg",
        "underwater_pad.ogg": src / "underwater-ambient-pad" / "Underwater-Ambient-Pad-isaiah658_0.ogg",
    }
    for name, path in loops.items():
        write(out / name, rms_to(load(path), LOOP_RMS_DB))
    return 0


if __name__ == "__main__":
    sys.exit(main())
