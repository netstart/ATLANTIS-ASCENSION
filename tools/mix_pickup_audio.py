"""Mistura os sons de coleta (medalha, pérola, cápsula) e de dano em inimigo (1.14.3) a partir dos CC0 baixados.

Os sons antigos (pepSound do Kenney Digital Audio e um sino metálico no acerto) não soavam como moeda e
embolavam na rajada. Cada som novo junta duas camadas: um corpo que diz o que é e um transiente que dá o
"tchim" ou o "toc", recortados curtos para não se sobreporem na chuva de coletas e acertos.

Entrada (fora do repositório, em c:\\src\\downloads\\assets):
  opengameart/8-bit-sound-effect-pack-vol-001/Coin 3.wav     Deva (@Shades), CC0: moeda 8-bit de dois tons
  opengameart/10-8bit-coin-sounds/coin1.wav                   Luke.RUSTLTD, CC0: moeda 8-bit curta
  opengameart/100-cc0-sfx/plop_01.ogg                         rubberduck, CC0 (48 kHz): bolha
  kenney/casino-audio/Audio/chips-stack-2.ogg                 Kenney Casino Audio, CC0: fichas, o "tchim" real
  kenney/interface-sounds/Audio/glass_00{6,5,2}.ogg           Kenney Interface Sounds, CC0: cristal
  kenney/impact-sounds/Audio/impactGeneric_light_00{0..4}.ogg Kenney Impact Sounds, CC0: batida seca
  kenney/ui-audio/Audio/click4.ogg                            Kenney UI Audio, CC0: estalo agudo

Saída: atlantis-mix/pickups/*.ogg, que os manifestos tools/pickup_audio_*_assets.json copiam para assets/:
  - coin_medal.ogg: Coin 3 com passa-baixa de 7 kHz + fichas a -9 dB, 380 ms;
  - coin_pearl_1..3.ogg: um cristal por variante + bolha a -12 dB, 140 ms;
  - coin_capsule.ogg: coin1 com passa-baixa de 7 kHz, 300 ms (o jogo sobe o tom a cada cápsula do combo);
  - hit_1..5.ogg: uma batida por variante + estalo a -4 dB, corte duro em 90 ms.
Tudo mono a 44,1 kHz, sem silêncio no começo, pico em -1 dBFS. O jogo alterna as variantes (AudioManager).

Requer numpy e soundfile (python -m pip install numpy soundfile); rode com o Python que os tem:
  python tools/mix_pickup_audio.py [--src DIR]
"""
import argparse
import pathlib
import sys

import numpy as np
import soundfile as sf

SR = 44100
PEAK_DB = -1.0
# Começo do som: primeira amostra acima de -50 dB do pico, menos 0,5 ms para não cortar o ataque.
ONSET_DB = -50.0
ONSET_PAD = 22
# Fim: corta a cauda abaixo de -60 dB do pico antes do fade.
TAIL_DB = -60.0
LOWPASS_HZ = 7000.0


def load(path: pathlib.Path) -> np.ndarray:
    data, sr = sf.read(str(path), always_2d=True)
    mono = data.mean(axis=1)
    if sr != SR:
        # Reamostragem linear (só a bolha de 48 kHz passa por aqui; perda inaudível num som de 140 ms).
        t = np.arange(int(len(mono) * SR / sr)) * sr / SR
        mono = np.interp(t, np.arange(len(mono)), mono)
    level = np.abs(mono)
    start = int(np.nonzero(level > level.max() * 10 ** (ONSET_DB / 20.0))[0][0])
    return mono[max(0, start - ONSET_PAD):]


def db(x: float) -> float:
    return float(20.0 * np.log10(max(x, 1e-12)))


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """Passa-baixa de um polo (6 dB/oitava): só tira a aspereza da onda quadrada, sem abafar."""
    k = float(np.exp(-2.0 * np.pi * cutoff / SR))
    y = np.empty_like(x)
    state = 0.0
    for i, v in enumerate(x):
        state = (1.0 - k) * v + k * state
        y[i] = state
    return y


def mix(layers: list, max_ms: float, fade_ms: float) -> np.ndarray:
    """Soma camadas (sinal, ganho em dB sobre o pico próprio), corta em `max_ms` e normaliza o pico."""
    n = max(len(x) for x, _ in layers)
    y = np.zeros(n)
    for x, gain in layers:
        y[:len(x)] += x / max(np.abs(x).max(), 1e-12) * 10 ** (gain / 20.0)
    y = y[:int(max_ms * SR / 1000.0)]
    level = np.abs(y)
    y = y[:int(np.nonzero(level > level.max() * 10 ** (TAIL_DB / 20.0))[0][-1]) + 1]
    f = min(len(y), int(fade_ms * SR / 1000.0))
    y[-f:] *= np.linspace(1.0, 0.0, f)
    return y * (10 ** (PEAK_DB / 20.0) / max(np.abs(y).max(), 1e-12))


def write(path: pathlib.Path, x: np.ndarray) -> None:
    with sf.SoundFile(str(path), "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        data = x.astype(np.float32)
        for k in range(0, len(data), 4096):
            f.write(data[k:k + 4096])
    print(f"{path.name}: {len(x) * 1000 / SR:.0f} ms, pico {db(np.abs(x).max()):.1f} dBFS, "
          f"RMS {db(float(np.sqrt((x ** 2).mean()))):.1f} dBFS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", default=r"c:\src\downloads\assets")
    src = pathlib.Path(parser.parse_args().src)
    oga = src / "opengameart"
    kenney = src / "kenney"
    out = src / "atlantis-mix" / "pickups"
    out.mkdir(parents=True, exist_ok=True)

    coin = lowpass(load(oga / "8-bit-sound-effect-pack-vol-001" / "Coin 3.wav"), LOWPASS_HZ)
    chips = load(kenney / "casino-audio" / "Audio" / "chips-stack-2.ogg")
    write(out / "coin_medal.ogg", mix([(coin, 0.0), (chips, -9.0)], 380.0, 40.0))

    plop = load(oga / "100-cc0-sfx" / "plop_01.ogg")
    for k, glass in enumerate(("glass_006", "glass_005", "glass_002")):
        crystal = load(kenney / "interface-sounds" / "Audio" / f"{glass}.ogg")
        write(out / f"coin_pearl_{k + 1}.ogg", mix([(crystal, 0.0), (plop, -12.0)], 140.0, 15.0))

    capsule = lowpass(load(oga / "10-8bit-coin-sounds" / "coin1.wav"), LOWPASS_HZ)
    write(out / "coin_capsule.ogg", mix([(capsule, 0.0)], 300.0, 40.0))

    click = load(kenney / "ui-audio" / "Audio" / "click4.ogg")
    for k in range(5):
        thud = load(kenney / "impact-sounds" / "Audio" / f"impactGeneric_light_00{k}.ogg")
        write(out / f"hit_{k + 1}.ogg", mix([(thud, 0.0), (click, -4.0)], 90.0, 12.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
