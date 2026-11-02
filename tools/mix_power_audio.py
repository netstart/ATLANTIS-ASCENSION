"""Mistura os sons dos poderes das 12 naves e do medidor de poder a partir dos CC0 baixados e de camadas sintetizadas.

Cada nave tem uma assinatura sonora própria, repetida nos três níveis do poder para o jogador reconhecer a nave
pelo ouvido no meio da rajada:
  - Falcão: metal e metais solares (brass);       - Manta: cristal, grave profundo e sonar;
  - Hidra: lançamentos de míssil sibilantes;      - Tempestade: vento e eletricidade;
  - Tridente: água, ondas e bolhas;               - Atlas: escudos pesados e metal ressonante;
  - Aríete: artilharia, baques;                   - Enxame: zumbido de drones, inseto-tecnológico;
  - Eclipse: escuro, abafado, invertido;          - Nova: estelar e brilhante, "ping" de crítico;
  - Titã: explosões sísmicas;                     - Ascensão: coro e brilho de coral, todas as cores.
O nível I é curto e seco (0,3 a 0,8 s); o II tem corpo (0,9 a 1,6 s); o supremo (III) é o maior, com sub-grave e
cauda de reverberação (2,0 a 2,5 s). Poderes que duram mais que o som (o raio de 4 s da Manta, a barragem de 5 s da
Hidra, a Ascensão de 6 s) usam o som como abertura; o jogo segura o resto com os laços que já tem.

Camadas sintetizadas aqui (obra própria do projeto, MIT): varreduras de ruído (whoosh, vento, onda), sub-graves com
queda de tom, risers, sinos de cristal e de metal por parciais, metais (brass) e coro por formantes, zumbido de
enxame, estalos elétricos, bolhas (Minnaert), reverberação por convolução com ruído decaindo e limitador.
O ruído usa sementes fixas: rodar de novo gera arquivos iguais amostra a amostra.

Entrada (fora do repositório, em c:\\src\\downloads\\assets):
  kenney/sci-fi-sounds/Audio/forceField_00{1,2,3}.ogg             Kenney Sci-fi Sounds, CC0: campo de força
  kenney/sci-fi-sounds/Audio/laserLarge_00{0,2}.ogg               Kenney Sci-fi Sounds, CC0: raio grosso
  kenney/sci-fi-sounds/Audio/laserSmall_002.ogg                   Kenney Sci-fi Sounds, CC0: raio fino
  kenney/sci-fi-sounds/Audio/laserRetro_00{1,2,3}.ogg             Kenney Sci-fi Sounds, CC0: tiro estelar
  kenney/sci-fi-sounds/Audio/lowFrequency_explosion_000.ogg       Kenney Sci-fi Sounds, CC0: explosão grave
  kenney/sci-fi-sounds/Audio/explosionCrunch_00{0..4}.ogg         Kenney Sci-fi Sounds, CC0: explosão com estalo
  kenney/sci-fi-sounds/Audio/thrusterFire_002.ogg                 Kenney Sci-fi Sounds, CC0: propulsor
  kenney/impact-sounds/Audio/impactMetal_heavy_00{0,1,2}.ogg      Kenney Impact Sounds, CC0: metal pesado
  kenney/impact-sounds/Audio/impactPlate_heavy_000.ogg            Kenney Impact Sounds, CC0: chapa blindada
  kenney/impact-sounds/Audio/impactSoft_heavy_001.ogg             Kenney Impact Sounds, CC0: baque abafado
  kenney/impact-sounds/Audio/impactMining_000.ogg                 Kenney Impact Sounds, CC0: rocha
  kenney/digital-audio/Audio/{zap1,zapTwoTone,zapThreeToneUp}.ogg Kenney Digital Audio, CC0: zap eletrônico
  kenney/interface-sounds/Audio/glass_00{2,3,4,5,6}.ogg           Kenney Interface Sounds, CC0: cristal
  kenney/interface-sounds/Audio/{tick_001,select_001}.ogg         Kenney Interface Sounds, CC0: tique
  kenney/rpg-audio/Audio/{drawKnife1,knifeSlice2}.ogg             Kenney RPG Audio, CC0: lâmina
  opengameart/512-sfx-8bit/<pasta do pacote>/...                  Juhani Junkala (SubspaceAudio), CC0:
      Weapons/Grenade Whistles/sfx_wpn_missilelaunch.wav            lançamento de míssil
      Weapons/Cannon/sfx_wpn_cannon{1,2,4,5}.wav                    canhão
      Explosions/Long/sfx_exp_long{1,2,3,4,6}.wav                   explosão longa
      Explosions/Short/sfx_exp_short_hard{1..6}.wav                 explosão curta
      Explosions/Shortest/sfx_exp_shortest_hard{1..8}.wav           estouro curtíssimo
      Movement/Portals and Transitions/sfx_movement_portal5.wav     portal (invertido no Eclipse)
  opengameart/100-cc0-sfx/{splash_0{1,2},plop_01,gong_0{1,2}}.ogg rubberduck, CC0 (48 kHz): água, bolha, gongo
  opengameart/100-cc0-sfx-2/sfx100v2_air_0{1,3}.ogg               rubberduck, CC0 (48 kHz): vento
  opengameart/100-cc0-sfx-2/sfx100v2_thunder_01.ogg               rubberduck, CC0 (48 kHz): trovão
  opengameart/100-cc0-sfx-2/sfx100v2_loop_water_0{2,3}.ogg        rubberduck, CC0 (48 kHz): água corrente
  opengameart/80-cc0-creature-sfx/x1/{bug_03,scream_01}.ogg       rubberduck, CC0 (48 kHz): inseto, grito
  opengameart/80-cc0-creature-sfx/x2/roar_05.ogg                  rubberduck, CC0: rugido
  opengameart/electricity-sound-pack/charge.wav                   faxcorp, CC0: carga elétrica

Saída: atlantis-mix/powers/power_<nave>_<nível>.ogg (36 arquivos), power_charge_{1,2,3}.ogg (segmento do medidor
cheio: cristal em Dó, Mi e Sol, o terceiro com brilho) e power_empty.ogg (recusa suave). Tudo mono a 44,1 kHz, sem
silêncio no começo, pico em -1 dBFS depois de um limitador com antevisão.

Requer numpy e soundfile (python -m pip install numpy soundfile); rode com o Python que os tem:
  python tools/mix_power_audio.py [--src DIR] [--only falcon_1,nova_3]

Resultado (duração, pico, RMS; nenhum arquivo com amostra cortada nem silêncio no começo):
  arquivo                    ms  pico    RMS  camadas
  power_falcon_1.ogg        420  -1.1  -16.1  whoosh 0,7-6,5 kHz + drawKnife1 + anel de metal + brass curto
  power_falcon_2.ogg       1040  -1.2  -15.6  knifeSlice2 + 12 penas (zap + chiado) em leque + acorde brass Ré maior
  power_falcon_3.ogg       2450  -1.1  -12.7  sino + brass, riser, assobio de mergulho, sub 140-32 Hz +
                                              explosionCrunch_004 + exp_long3 + brass + reverb
  power_manta_1.ogg         434  -1.1  -17.7  zap 3,6-1,5 kHz + laserSmall_002 + glass_006 + ping de sonar
  power_manta_2.ogg        1600  -1.1  -10.7  laserLarge_002 + 3 feixes 660/880/1109 Hz + glass_005..003 + sonar + 55
                                              Hz
  power_manta_3.ogg        2500  -1.1  -11.9  carga (charge.wav + tom subindo + brilho), sub + laserLarge_000 + rugido
                                              de serras + sonar grave
  power_hydra_1.ogg         585  -1.1  -12.7  missilelaunch x1,5 + 8 x (chiado + baque + chirp)
  power_hydra_2.ogg        1300  -1.1  -11.6  3 x (missilelaunch x0,85 + sub 95 Hz + chiado + bolhas)
  power_hydra_3.ogg        2448  -1.1  -14.3  roar_05 x0,8 + sibilo de serpente + 21 lançamentos + ronco grave
  power_tempest_1.ogg       400  -1.1  -12.9  whoosh 1,2-9 kHz + zap1 + estalos + air_03
  power_tempest_2.ogg      1600  -1.0  -13.2  acorde caindo 2 oitavas (para-fita) + vento + air_01 + sub + tique
                                              desacelerando
  power_tempest_3.ogg      2400  -1.0  -15.5  estalo + arco + sub, thunder_01 + estalos + charge.wav + vento + 9 arcos
  power_trident_1.ogg       989  -1.1  -16.2  plop_01 + onda subindo + splash_01 + baque + bolhas
  power_trident_2.ogg      1399  -1.1  -13.3  redemoinho (passa-faixa girando 2-9 Hz) + tom de vórtice + loop_water_02
                                              + bolhas
  power_trident_3.ogg      2500  -1.1  -13.8  loop_water_03 + 3 x (onda + splash + sub 60 Hz + bolhas) + reverb
  power_atlas_1.ogg         700  -1.1  -11.9  forceField_001 + impactMetal_heavy_002 + anel de metal com tremolo +
                                              subida
  power_atlas_2.ogg        1600  -1.1  -12.2  forceField_003 + 3 x (sino de cristal + zumbido orbitando)
  power_atlas_3.ogg        2500  -1.1  -11.8  impactMetal_heavy_000 x0,7 + gong_01 + sub + drone + coro 'u' + brilho +
                                              arpejo de reparo
  power_ram_1.ogg          1000  -1.1   -9.9  5 x (sub 130-45 Hz + cannon4 x1,2)
  power_ram_2.ogg          1000  -1.3  -11.1  motor subindo + thrusterFire_002, impactPlate_heavy_000 +
                                              impactMetal_heavy_001 + sub + explosionCrunch_000
  power_ram_3.ogg          2500  -1.3  -12.9  ronco + 10 x (cannon1/2/5 + sub) + exp_long2 + reverb
  power_swarm_1.ogg         900  -1.0  -14.3  14 zumbidos chegando + bug_03 + select_001
  power_swarm_2.ogg        1399  -1.1  -11.0  zumbido + rede de senos 220/330/440 Hz + zapTwoTone + zapThreeToneUp +
                                              estalos
  power_swarm_3.ogg        2450  -1.0  -14.4  scream_01 com anel 110 Hz + chirp + 24 zumbidos em doppler + 8
                                              exp_shortest_hard + sub
  power_eclipse_1.ogg      1050  -1.2  -14.6  impactSoft abafado, forceField_002 e gong_02 invertidos + sub crescendo
                                              + impactSoft_heavy_001
  power_eclipse_2.ogg      1000  -1.1  -11.5  wub 70 Hz + anel de ruído varrendo + plasma 110 Hz + portal5 invertido,
                                              passa-baixa 3,5 kHz
  power_eclipse_3.ogg      2500  -1.0   -9.9  queda sub 130-26 Hz + acorde menor, sucção invertida + gong_02
                                              invertido, vácuo, sub + explosionCrunch_003 + acorde
  power_nova_1.ogg          400  -1.1  -15.9  bipe duplo de mira + sino 3,1 kHz + glass_002 + brilho
  power_nova_2.ogg          861  -1.3  -16.0  3 x (zap estelar + laserRetro_001..003 + sino + brilho)
  power_nova_3.ogg         2500  -1.2  -11.2  ping, sucção subindo + reverb e exp_long1 invertidos, exp_long4 +
                                              lowFrequency_explosion_000 + sub + brilho
  power_titan_1.ogg         900  -1.1  -10.3  explosionCrunch_002 + sub 75-28 Hz + ronco + impactMining_000
  power_titan_2.ogg        1281  -1.0  -14.9  6 x (chiado de pavio + exp_short_hard1..6) + sub final
  power_titan_3.ogg        2500  -1.1  -12.0  ronco sísmico + 6 x (explosionCrunch_001..004 + sub crescente) +
                                              exp_long6
  power_ascension_1.ogg     790  -1.1  -17.3  sinos Mi/Si + eco triplo + glass_003 + coro curto
  power_ascension_2.ogg    1577  -1.0  -14.2  coro 'a' Dó maior + 12 lanças (sino + zap) pentatônicas + brilho
  power_ascension_3.ogg    2500  -1.2  -13.5  sinos, coro 'o' subindo uma quarta + riser + brilho, acorde final de
                                              coro + brass + sinos + sub
  power_charge_1.ogg        500  -1.0  -16.4  sino de cristal Dó6 + glass_004 + chirp
  power_charge_2.ogg        500  -1.0  -16.6  sino de cristal Mi6 + glass_005 + chirp
  power_charge_3.ogg        700  -1.2  -16.7  sino de cristal Sol6 + oitava + glass_006 + chirp + brilho
  power_empty.ogg           300  -1.1  -13.9  dois triângulos 392/294 Hz abafados
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
JUNKALA = "512-sfx-8bit/The Essential Retro Video Game Sound Effects Collection [512 sounds] By Juhani Junkala"

# Razões de parciais: barra de metal (anel do Falcão e do Atlas) e taça de cristal (Manta, Nova, Ascensão, medidor).
METAL = (1.0, 1.48, 2.21, 2.95, 3.63, 4.84)
CRYSTAL = (1.0, 2.32, 4.25, 6.63)
# Formantes (Hz, largura, ganho) das vogais do coro.
VOWELS = {
    "a": ((800, 160, 1.0), (1150, 180, 0.6), (2900, 240, 0.25), (3900, 260, 0.1)),
    "o": ((450, 140, 1.0), (800, 160, 0.5), (2830, 200, 0.12)),
    "u": ((325, 100, 1.0), (700, 120, 0.3), (2530, 340, 0.05)),
}


# ---------------------------------------------------------------- arquivos

def load(path: pathlib.Path) -> np.ndarray:
    data, sr = sf.read(str(path), always_2d=True)
    mono = data.mean(axis=1)
    if sr != SR:
        # Reamostragem linear (só os arquivos de 48 kHz passam por aqui; perda inaudível nestas camadas).
        t = np.arange(int(len(mono) * SR / sr)) * sr / SR
        mono = np.interp(t, np.arange(len(mono)), mono)
    level = np.abs(mono)
    start = int(np.nonzero(level > level.max() * 10 ** (ONSET_DB / 20.0))[0][0])
    return mono[max(0, start - ONSET_PAD):]


class Library:
    """Carrega cada arquivo de entrada uma vez só, por caminho relativo a --src."""

    def __init__(self, src: pathlib.Path) -> None:
        self.src = src
        self.cache: dict = {}

    def __call__(self, rel: str) -> np.ndarray:
        if rel not in self.cache:
            self.cache[rel] = load(self.src / rel)
        return self.cache[rel].copy()


def db(x: float) -> float:
    return float(20.0 * np.log10(max(x, 1e-12)))


def write(path: pathlib.Path, x: np.ndarray) -> dict:
    # O Vorbis desloca o pico em até 1,5 dB nos transientes: confere o arquivo decodificado e regrava até ele
    # ficar entre -1,25 e -1,0 dBFS.
    target = 10 ** (PEAK_DB / 20.0)
    best = None
    for _ in range(10):
        with sf.SoundFile(str(path), "w", SR, 1, format="OGG", subtype="VORBIS") as f:
            data = x.astype(np.float32)
            for k in range(0, len(data), 4096):
                f.write(data[k:k + 4096])
        back, _ = sf.read(str(path))
        decoded = float(np.abs(back).max())
        if decoded <= target * 1.001 and (best is None or decoded > best[0]):
            best = (decoded, x)
        if target * 0.985 <= decoded <= target * 1.001:
            break
        x = x * (target / decoded) * 0.996
    else:
        if best is not None:  # não convergiu: regrava a melhor tentativa abaixo do teto
            with sf.SoundFile(str(path), "w", SR, 1, format="OGG", subtype="VORBIS") as f:
                data = best[1].astype(np.float32)
                for k in range(0, len(data), 4096):
                    f.write(data[k:k + 4096])
            back, _ = sf.read(str(path))
    level = np.abs(back)
    stats = {
        "ms": len(back) * 1000.0 / SR,
        "peak": db(float(level.max())),
        "rms": db(float(np.sqrt((back ** 2).mean()))),
        "clip": int((level >= 0.999).sum()),
        "onset_ms": float(np.nonzero(level > level.max() * 0.01)[0][0]) * 1000.0 / SR,
    }
    print(f"{path.name}: {stats['ms']:.0f} ms, pico {stats['peak']:.1f} dBFS, RMS {stats['rms']:.1f} dBFS, "
          f"cortes {stats['clip']}, ataque em {stats['onset_ms']:.1f} ms")
    return stats


# ---------------------------------------------------------------- utilitários de sinal

def n_of(seconds: float) -> int:
    return max(1, int(round(seconds * SR)))


def times(seconds: float) -> np.ndarray:
    return np.arange(n_of(seconds)) / SR


def glide(f0: float, f1: float, seconds: float, power: float = 1.0) -> np.ndarray:
    """Frequência que vai de f0 a f1 em escala exponencial; power > 1 acelera no fim, < 1 no começo."""
    u = (times(seconds) / seconds) ** power
    return f0 * (f1 / f0) ** u


def as_freq(freq, seconds: float) -> np.ndarray:
    n = n_of(seconds)
    f = np.asarray(freq, dtype=float)
    return np.full(n, float(f)) if f.ndim == 0 else np.resize(f, n)


def osc(freq, seconds: float, shape: str = "sine", phase: float = 0.0) -> np.ndarray:
    """Oscilador com frequência variável; serra e quadrada com polyBLEP para não espelhar agudos."""
    f = as_freq(freq, seconds)
    cycles = np.cumsum(f) / SR + phase
    if shape == "sine":
        return np.sin(2.0 * np.pi * cycles)
    if shape == "tri":
        return 2.0 * np.abs(2.0 * (cycles % 1.0) - 1.0) - 1.0
    dt = np.clip(f / SR, 1e-6, 0.5)

    def saw(c: np.ndarray) -> np.ndarray:
        t = c % 1.0
        y = 2.0 * t - 1.0
        lo = t < dt
        x = t[lo] / dt[lo]
        y[lo] -= x + x - x * x - 1.0
        hi = t > 1.0 - dt
        x = (t[hi] - 1.0) / dt[hi]
        y[hi] -= x * x + x + x + 1.0
        return y

    if shape == "saw":
        return saw(cycles)
    return 0.5 * (saw(cycles) - saw(cycles + 0.5))  # quadrada


def noise(seconds: float, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1.0, 1.0, n_of(seconds))


def env(seconds: float, attack: float, tau: float, hold: float = 0.0) -> np.ndarray:
    """Ataque linear, platô e queda exponencial com constante `tau`."""
    t = times(seconds)
    e = np.minimum(1.0, t / max(attack, 1e-4))
    rel = np.maximum(0.0, t - attack - hold)
    return e * np.exp(-rel / tau)


def swell(seconds: float, power: float = 2.0) -> np.ndarray:
    """Subida de 0 (-40 dB) a 1 no fim: crescendo de riser e de som invertido."""
    u = times(seconds) / seconds
    return 0.01 + 0.99 * u ** power


def fade_out(x: np.ndarray, seconds: float) -> np.ndarray:
    f = min(len(x), n_of(seconds))
    x = x.copy()
    x[-f:] *= np.linspace(1.0, 0.0, f) ** 1.5
    return x


def seg(x: np.ndarray, a: float, b: float) -> np.ndarray:
    """Trecho de a a b (s) com exatamente n_of(b - a) amostras, completando com silêncio se o arquivo acabar."""
    k = int(round(a * SR))
    part = x[k:k + n_of(b - a)]
    return np.concatenate([part, np.zeros(n_of(b - a) - len(part))])


def resample(x: np.ndarray, ratio: float) -> np.ndarray:
    """Muda tom e duração juntos (ratio 2 = uma oitava acima, metade do tempo)."""
    t = np.arange(0.0, len(x) - 1, ratio)
    return np.interp(t, np.arange(len(x)), x)


def fft_filter(x: np.ndarray, lo: float = 0.0, hi: float = 0.0) -> np.ndarray:
    """Passa-faixa estático de fase zero, com bordas suaves de meia oitava (lo/hi = 0 desliga o lado)."""
    n = 1 << int(np.ceil(np.log2(len(x) + 1)))
    spec = np.fft.rfft(x, n)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    mask = np.ones_like(f)
    oct_ = np.log2(np.maximum(f, 1.0))
    if lo > 0:
        mask *= np.clip((oct_ - np.log2(lo)) / 0.5 + 0.5, 0.0, 1.0)
    if hi > 0:
        mask *= np.clip((np.log2(hi) - oct_) / 0.5 + 0.5, 0.0, 1.0)
    return np.fft.irfft(spec * mask, n)[:len(x)]


def formant(x: np.ndarray, vowel: str) -> np.ndarray:
    n = 1 << int(np.ceil(np.log2(len(x) + 1)))
    spec = np.fft.rfft(x, n)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    mask = np.full_like(f, 0.02)
    for fc, bw, gain in VOWELS[vowel]:
        mask += gain * np.exp(-0.5 * ((f - fc) / bw) ** 2)
    return np.fft.irfft(spec * mask, n)[:len(x)]


def svf(x: np.ndarray, cutoff, q: float = 0.707, mode: str = "low") -> np.ndarray:
    """Filtro de estado variável (topologia TPT) com corte variável no tempo: varreduras de whoosh, vento e brass."""
    fc = np.clip(np.resize(np.asarray(cutoff, dtype=float), len(x)), 20.0, SR * 0.45)
    g = np.tan(np.pi * fc / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    out = np.empty_like(x)
    ic1 = ic2 = 0.0
    sel = {"low": 0, "band": 1, "high": 2}[mode]
    for i in range(len(x)):
        v0 = x[i]
        v3 = v0 - ic2
        v1 = a1[i] * ic1 + a2[i] * v3
        v2 = ic2 + a2[i] * ic1 + a3[i] * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        out[i] = v2 if sel == 0 else (v1 if sel == 1 else v0 - k * v1 - v2)
    return out


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    n = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    return np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[:len(x) + len(ir) - 1]


def reverb(x: np.ndarray, t60: float, wet: float, seed: int, damp: float = 6000.0) -> np.ndarray:
    """Sala sintética: ruído decaindo 60 dB em `t60`, abafado acima de `damp`, com 12 ms de pré-atraso."""
    t = times(t60)
    ir = noise(t60, seed) * np.exp(-6.9 * t / t60)
    ir = fft_filter(ir, lo=120.0, hi=damp)
    ir = np.concatenate([np.zeros(n_of(0.012)), ir / np.sqrt((ir ** 2).sum())])
    tail = convolve(x, ir)
    tail *= np.sqrt((x ** 2).sum() / max((tail ** 2).sum(), 1e-12))
    y = np.zeros(len(tail))
    y[:len(x)] += x
    return y + wet * tail


def echo(x: np.ndarray, delay: float, feedback: float, taps: int, lowpass: float = 0.0) -> np.ndarray:
    d = n_of(delay)
    y = np.zeros(len(x) + d * taps)
    tap = x.copy()
    for k in range(taps + 1):
        y[k * d:k * d + len(tap)] += tap * feedback ** k
        if lowpass:
            tap = fft_filter(tap, hi=lowpass)
    return y


def sat(x: np.ndarray, drive: float) -> np.ndarray:
    return np.tanh(x * drive) / np.tanh(drive)


def limit(x: np.ndarray, ceiling: float, release_ms: float = 80.0, block: int = 64) -> np.ndarray:
    """Limitador por blocos com antevisão de um bloco e joelho macio de segurança no teto."""
    nb = -(-len(x) // block)
    xp = np.concatenate([x, np.zeros(nb * block - len(x))])
    peaks = np.abs(xp).reshape(nb, block).max(axis=1)
    g = np.minimum(1.0, ceiling / np.maximum(peaks, 1e-12))
    g = np.minimum(g, np.concatenate([g[1:], [1.0]]))
    r = float(np.exp(-block / (release_ms * SR / 1000.0)))
    smooth = np.empty_like(g)
    s = 1.0
    for i, v in enumerate(g):
        s = v if v < s else r * s + (1.0 - r) * v
        smooth[i] = s
    gain = np.interp(np.arange(len(xp)), np.arange(nb) * block + block / 2.0, smooth)
    y = (xp * gain)[:len(x)]
    knee = 0.85 * ceiling
    over = np.abs(y) > knee
    y[over] = np.sign(y[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(y[over]) - knee) / (ceiling - knee)))
    return y


# ---------------------------------------------------------------- mistura

def bus(layers: list) -> np.ndarray:
    """Soma camadas (sinal, ganho em dB sobre o pico próprio[, início em s]) sem normalizar a soma."""
    n = max(int(round((item[2] if len(item) > 2 else 0.0) * SR)) + len(item[0]) for item in layers)
    y = np.zeros(n)
    for item in layers:
        x, gain = item[0], item[1]
        k = int(round((item[2] if len(item) > 2 else 0.0) * SR))
        y[k:k + len(x)] += x / max(np.abs(x).max(), 1e-12) * 10 ** (gain / 20.0)
    return y


def mix(layers: list, max_ms: float, fade_ms: float, push_db: float = 4.0) -> np.ndarray:
    """Soma as camadas, corta em `max_ms`, tira o silêncio do começo, empurra `push_db` no limitador e normaliza."""
    y = bus(layers)[:int(max_ms * SR / 1000.0)]
    level = np.abs(y)
    start = int(np.nonzero(level > level.max() * 10 ** (ONSET_DB / 20.0))[0][0])
    y = y[max(0, start - ONSET_PAD):]
    level = np.abs(y)
    y = y[:int(np.nonzero(level > level.max() * 10 ** (TAIL_DB / 20.0))[0][-1]) + 1]
    f = min(len(y), int(fade_ms * SR / 1000.0))
    y[-f:] *= np.linspace(1.0, 0.0, f)
    ceiling = 10 ** (PEAK_DB / 20.0)
    y = limit(y / np.abs(y).max() * ceiling * 10 ** (push_db / 20.0), ceiling)
    return y * (ceiling / max(np.abs(y).max(), 1e-12))


# ---------------------------------------------------------------- camadas sintetizadas

def boom(seconds: float, f0: float, f1: float, tau: float = 0.25, seed: int = 0) -> np.ndarray:
    """Sub-grave: seno que cai de f0 a f1 em 120 ms, com estalo de ataque e saturação para soar no celular."""
    drop = np.minimum(times(seconds) / 0.12, 1.0)
    body = osc(f0 * (f1 / f0) ** drop, seconds) * env(seconds, 0.002, tau)
    body += 0.35 * osc(2.0 * f0 * (f1 / f0) ** drop, seconds) * env(seconds, 0.002, tau * 0.4)
    click = fft_filter(noise(0.012, seed + 1), hi=3500.0) * np.linspace(1.0, 0.0, n_of(0.012))
    body[:len(click)] += 0.6 * click
    return sat(body, 2.2)


def whoosh(seconds: float, f0: float, f1: float, q: float, peak: float, seed: int) -> np.ndarray:
    """Ruído num passa-faixa que varre de f0 a f1, crescendo até `peak` (s) e sumindo depois."""
    t = times(seconds)
    shape = np.where(t < peak, (t / peak) ** 2, np.exp(-(t - peak) / max((seconds - peak) / 3.0, 1e-3)))
    return svf(noise(seconds, seed), glide(f0, f1, seconds), q, "band") * (0.01 + shape)


def bell(f: float, seconds: float, ratios=CRYSTAL, tau: float = 0.3, attack: float = 0.002) -> np.ndarray:
    """Sino por parciais: cada parcial mais aguda decai mais rápido."""
    y = np.zeros(n_of(seconds))
    for i, r in enumerate(ratios):
        if f * r < SR * 0.45:
            y += osc(f * r, seconds, phase=0.1 * i) * env(seconds, attack, tau / (1.0 + 0.6 * i)) / (1.0 + i) ** 0.7
    return y


def brass(freqs, seconds: float, attack: float = 0.04, open_hz: float = 3500.0, tau: float = 0.4,
          seed: int = 0) -> np.ndarray:
    """Metais solares: serras desafinadas em ±7 cents com o filtro abrindo no ataque e fechando na queda."""
    rng = np.random.default_rng(seed)
    y = np.zeros(n_of(seconds))
    for f in freqs:
        for cents in (-7.0, 0.0, 7.0):
            y += osc(f * 2 ** (cents / 1200.0), seconds, "saw", rng.uniform())
    e = env(seconds, attack, tau, hold=attack)
    return svf(y, 250.0 + open_hz * e, 0.9) * e


def choir(freqs, seconds: float, vowel: str = "a", attack: float = 0.25, pitch=None, seed: int = 0) -> np.ndarray:
    """Coro: cinco vozes por nota com vibrato e desafinação, sopro e filtro de formantes da vogal."""
    rng = np.random.default_rng(seed)
    t = times(seconds)
    bend = np.ones(len(t)) if pitch is None else np.resize(np.asarray(pitch, dtype=float), len(t))
    y = np.zeros(len(t))
    for f in freqs:
        for _ in range(5):
            vib = 1.0 + 0.004 * np.sin(2 * np.pi * rng.uniform(4.8, 6.2) * t + rng.uniform(0, 6.3))
            y += osc(f * 2 ** (rng.uniform(-12, 12) / 1200.0) * vib * bend, seconds, "saw", rng.uniform())
    y = formant(y + 0.15 * noise(seconds, seed + 7) * len(freqs), vowel)
    a = np.minimum(1.0, t / attack) ** 1.5
    return y * a


def zap(f0: float, f1: float, seconds: float, shape: str = "square", tau: float = 0.05) -> np.ndarray:
    return osc(glide(f0, f1, seconds, 0.6), seconds, shape) * env(seconds, 0.001, tau)


def crackle(seconds: float, rate: float, seed: int) -> np.ndarray:
    """Estalos elétricos: impulsos de Poisson de 1 a 4 ms com amplitudes aleatórias, só os agudos."""
    rng = np.random.default_rng(seed)
    y = np.zeros(n_of(seconds) + n_of(0.005))
    count = rng.poisson(rate * seconds)
    for at in rng.uniform(0.0, seconds, count):
        burst = n_of(rng.uniform(0.001, 0.004))
        k = int(at * SR)
        y[k:k + burst] += rng.uniform(-1, 1, burst) * rng.uniform(0.2, 1.0) * np.exp(-np.arange(burst) / (burst / 3))
    return fft_filter(y[:n_of(seconds)], lo=1800.0)


def arc(seconds: float, seed: int) -> np.ndarray:
    """Arco de raio: zap que cai de tom com modulação em anel áspera."""
    rng = np.random.default_rng(seed)
    t = times(seconds)
    z = zap(rng.uniform(2200, 4200), rng.uniform(250, 500), seconds, "saw", seconds / 3)
    return z * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * rng.uniform(70, 130) * t)))


def buzz(seconds: float, voices: int, f_lo: float, f_hi: float, seed: int, doppler: float = 0.0) -> np.ndarray:
    """Zumbido de enxame: serras com batida de asa (AM de 35 a 70 Hz), tom subindo `doppler` no fim."""
    rng = np.random.default_rng(seed)
    t = times(seconds)
    rise = 1.0 + doppler * (t / seconds) ** 2
    y = np.zeros(len(t))
    for _ in range(voices):
        f = rng.uniform(f_lo, f_hi) * (1.0 + 0.02 * np.sin(2 * np.pi * rng.uniform(0.5, 3.0) * t)) * rise
        wing = 0.55 + 0.45 * np.sin(2 * np.pi * rng.uniform(35, 70) * t + rng.uniform(0, 6.3))
        y += osc(f, seconds, "saw", rng.uniform()) * wing
    return fft_filter(y, lo=180.0, hi=4500.0)


def bubbles(seconds: float, count: int, seed: int, f_lo: float = 350.0, f_hi: float = 1400.0) -> np.ndarray:
    """Bolhas de Minnaert: seno curto cujo tom sobe enquanto decai."""
    rng = np.random.default_rng(seed)
    y = np.zeros(n_of(seconds) + n_of(0.08))
    for _ in range(count):
        d = rng.uniform(0.03, 0.07)
        f = rng.uniform(f_lo, f_hi)
        b = osc(f * (1.0 + 2.5 * times(d)), d) * env(d, 0.001, d / 3)
        k = int(rng.uniform(0, seconds) * SR)
        y[k:k + len(b)] += b * rng.uniform(0.3, 1.0)
    return y[:n_of(seconds)]


def shimmer(seconds: float, count: int, seed: int, f_lo: float = 2500.0, f_hi: float = 8000.0,
            power: float = 1.0) -> np.ndarray:
    """Brilho: pequenos sinos agudos espalhados (power > 1 junta mais no fim, < 1 no começo)."""
    rng = np.random.default_rng(seed)
    y = np.zeros(n_of(seconds) + n_of(0.25))
    for _ in range(count):
        d = rng.uniform(0.08, 0.25)
        b = bell(rng.uniform(f_lo, f_hi), d, CRYSTAL, d / 3)
        k = int(seconds * rng.uniform() ** (1.0 / power) * SR)
        y[k:k + len(b)] += b * rng.uniform(0.3, 1.0)
    return y


def wind(seconds: float, seed: int, center: float = 700.0) -> np.ndarray:
    """Vento: ruído num passa-faixa de Q alto cujo centro sobe e desce em rajadas."""
    t = times(seconds)
    gust = center * 2 ** (0.8 * np.sin(2 * np.pi * 0.9 * t) + 0.4 * np.sin(2 * np.pi * 2.3 * t + 1.0))
    return svf(noise(seconds, seed), gust, 2.5, "band")


def hiss(seconds: float, seed: int, f0: float = 2500.0, f1: float = 7000.0) -> np.ndarray:
    """Chiado de míssil: ruído agudo varrendo para cima, decaindo."""
    return svf(noise(seconds, seed), glide(f0, f1, seconds), 0.8, "band") * env(seconds, 0.004, seconds / 3)


def ending_at(x: np.ndarray, end: float) -> float:
    """Posição de início para um som invertido terminar exatamente em `end` (s)."""
    return max(0.0, end - len(x) / SR)


# ---------------------------------------------------------------- Falcão: metal e metais solares

def falcon_1(L) -> np.ndarray:
    return mix([
        (whoosh(0.34, 700.0, 6500.0, 1.2, 0.12, 11), 0.0),
        (L("kenney/rpg-audio/Audio/drawKnife1.ogg"), -3.0, 0.02),
        (bell(1975.0, 0.35, METAL, 0.12), -10.0, 0.05),
        (brass([523.25, 783.99], 0.2, 0.008, 5000.0, 0.08), -11.0),
    ], 480.0, 60.0)


def falcon_2(L) -> np.ndarray:
    layers = [(L("kenney/rpg-audio/Audio/knifeSlice2.ogg"), -3.0),
              (brass([293.66, 369.99, 440.0], 1.0, 0.08, 3500.0, 0.35, 21), -7.0, 0.04)]
    for i in range(12):
        f = 1700.0 + 95.0 * i
        feather = zap(f, f * 1.7, 0.06, "sine", 0.025) + 0.4 * hiss(0.06, 200 + i, 3000.0, 8000.0)
        layers.append((feather, -4.0 - (i % 3), 0.035 * i))
    layers.append((bell(2349.3, 0.5, METAL, 0.2), -12.0, 0.4))
    return mix(layers, 1150.0, 220.0)


def falcon_3(L) -> np.ndarray:
    riser = (osc(glide(150.0, 900.0, 0.8, 1.5), 0.8, "saw") * 0.5
             + whoosh(0.8, 400.0, 6000.0, 1.5, 0.79, 31)) * swell(0.8, 2.0)
    dive = osc(glide(3000.0, 260.0, 0.32, 0.7), 0.32) * env(0.32, 0.01, 0.2)
    impact = bus([
        (boom(1.4, 140.0, 32.0, 0.45, 32), 0.0),
        (L("kenney/sci-fi-sounds/Audio/explosionCrunch_004.ogg"), -3.0),
        (L(f"opengameart/{JUNKALA}/Explosions/Long/sfx_exp_long3.wav"), -6.0),
        (brass([146.83, 220.0, 293.66, 440.0], 1.2, 0.02, 4500.0, 0.45, 33), -3.0),
        (whoosh(0.7, 5000.0, 300.0, 1.0, 0.04, 34), -6.0),
        (bell(1174.7, 1.0, METAL, 0.5), -11.0),
    ])
    return mix([
        # Resposta imediata ao botão antes do riser.
        (bell(1568.0, 0.5, METAL, 0.2) + brass([392.0, 587.33], 0.5, 0.005, 4000.0, 0.12, 36), -8.0),
        (riser, -6.0),
        (dive, -8.0, 0.8),
        (reverb(impact, 1.4, 0.3, 35), 0.0, 1.1),
    ], 2450.0, 450.0, 5.0)


# ---------------------------------------------------------------- Manta: cristal, grave, sonar

def manta_1(L) -> np.ndarray:
    beam = zap(3600.0, 1500.0, 0.14, "sine", 0.06) + 0.25 * zap(1800.0, 750.0, 0.14, "square", 0.04)
    dry = bus([
        (beam, 0.0),
        (L("kenney/sci-fi-sounds/Audio/laserSmall_002.ogg"), -5.0),
        (L("kenney/interface-sounds/Audio/glass_006.ogg"), -8.0),
        (osc(1318.5, 0.35) * env(0.35, 0.003, 0.09), -14.0, 0.03),
    ])
    return mix([(reverb(dry, 0.4, 0.2, 41), 0.0)], 450.0, 80.0, 8.0)


def manta_2(L) -> np.ndarray:
    layers = [(L("kenney/sci-fi-sounds/Audio/laserLarge_002.ogg"), -4.0),
              (osc(1046.5, 1.3) * env(1.3, 0.002, 0.35), -8.0),
              (osc(55.0, 1.5) * env(1.5, 0.05, 0.5, 0.6), -9.0)]
    for i, (f, at) in enumerate(((660.0, 0.0), (880.0, 0.09), (1108.7, 0.18))):
        d = 1.45 - at
        t = times(d)
        sweep = f * (1.0 + 0.05 * np.sin(2 * np.pi * 0.7 * t + 2.1 * i))
        tone = osc(sweep, d) + 0.3 * osc(sweep / 2.0, d, "saw")
        e = env(d, 0.015, 0.25, hold=1.0 - at)
        layers.append((svf(tone, 3000.0, 0.8) * e, -5.0, at))
        layers.append((L(f"kenney/interface-sounds/Audio/glass_00{5 - i}.ogg"), -10.0, at))
    return mix([(reverb(bus(layers), 0.9, 0.25, 42), 0.0)], 1600.0, 300.0)


def manta_3(L) -> np.ndarray:
    t = times(0.75)
    charge_tone = osc(glide(220.0, 880.0, 0.75, 1.6), 0.75) * (0.6 + 0.4 * np.sin(2 * np.pi * (6 + 30 * t) * t))
    charge = bus([
        (seg(L("opengameart/electricity-sound-pack/charge.wav"), 0.0, 0.75) * swell(0.75, 1.5), -4.0),
        (charge_tone * swell(0.75, 1.5), -3.0),
        (shimmer(0.75, 14, 43, 2000.0, 6000.0, 2.0), -12.0),
    ])
    d = 1.75
    tr = times(d)
    throb = 0.75 + 0.25 * np.sin(2 * np.pi * 6.0 * tr)
    saws = osc(55.0, d, "saw") + osc(82.4, d, "saw") + osc(110.3, d, "saw")
    roar = svf(saws, 600.0 + 1200.0 * env(d, 0.05, 0.6), 1.2)
    roar += 0.6 * svf(noise(d, 44), 700.0, 1.0, "band")
    whine = osc(1760.0, d) + osc(1764.0, d)
    release = bus([
        (boom(1.2, 110.0, 38.0, 0.4, 45), 0.0),
        (L("kenney/sci-fi-sounds/Audio/laserLarge_000.ogg"), -3.0),
        (roar * throb * env(d, 0.03, 1.0, 0.5), -2.0),
        (whine * env(d, 0.05, 0.8, 0.6), -14.0),
        (bell(523.25, 1.6, (1.0, 2.0, 3.01), 0.6), -7.0),
    ])
    return mix([(charge, 0.0), (reverb(release, 1.8, 0.3, 46), 0.0, 0.75)], 2500.0, 500.0, 5.0)


# ---------------------------------------------------------------- Hidra: mísseis sibilantes

def hydra_1(L) -> np.ndarray:
    layers = [(resample(L(f"opengameart/{JUNKALA}/Weapons/Grenade Whistles/sfx_wpn_missilelaunch.wav"), 1.5), -6.0)]
    for i in range(8):
        at = 0.055 * i
        layers.append((hiss(0.2, 300 + i), -2.0 - (i % 2) * 2, at))
        layers.append((boom(0.12, 180.0, 80.0, 0.04, 310 + i), -9.0, at))
        layers.append((zap(900.0 + 60 * i, 1800.0 + 120 * i, 0.08, "sine", 0.03), -15.0, at))
    return mix(layers, 800.0, 150.0)


def hydra_2(L) -> np.ndarray:
    launch = resample(L(f"opengameart/{JUNKALA}/Weapons/Grenade Whistles/sfx_wpn_missilelaunch.wav"), 0.85)
    layers = []
    for i, at in enumerate((0.0, 0.26, 0.52)):
        lift = -1.0 if i == 2 else 0.0
        layers += [(launch, -2.0 + lift, at),
                   (boom(0.4, 95.0, 40.0, 0.12, 320 + i), -3.0 + lift, at),
                   (hiss(0.45, 330 + i, 1800.0, 5000.0), -5.0 + lift, at),
                   (bubbles(0.4, 8, 340 + i), -15.0, at + 0.05)]
    return mix(layers, 1300.0, 250.0)


def hydra_3(L) -> np.ndarray:
    t = times(1.0)
    serpents = svf(noise(1.0, 350), 4500.0, 2.0, "band") * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t))
    serpents *= env(1.0, 0.1, 0.3, 0.4)
    layers = [(fft_filter(resample(L("opengameart/80-cc0-creature-sfx/x2/roar_05.ogg"), 0.8), hi=3500.0), -1.0),
              (serpents, -8.0),
              (L(f"opengameart/{JUNKALA}/Weapons/Grenade Whistles/sfx_wpn_missilelaunch.wav"), -4.0, 0.45),
              (fft_filter(noise(2.1, 351), hi=160.0) * swell(2.1, 0.7), -6.0, 0.4)]
    rng = np.random.default_rng(352)
    at, k = 0.45, 0
    while at < 2.25:
        layers.append((hiss(0.13, 360 + k, 3000.0, 8000.0), rng.uniform(-8.0, -4.0), at))
        layers.append((boom(0.1, 160.0, 70.0, 0.03, 400 + k), rng.uniform(-12.0, -8.0), at))
        at += 0.085
        k += 1
    return mix(layers, 2450.0, 300.0)


# ---------------------------------------------------------------- Tempestade: vento e eletricidade

def tempest_1(L) -> np.ndarray:
    return mix([
        (whoosh(0.3, 1200.0, 9000.0, 1.5, 0.08, 51), 0.0),
        (L("kenney/digital-audio/Audio/zap1.ogg"), -6.0),
        (crackle(0.2, 140.0, 52), -9.0, 0.02),
        (L("opengameart/100-cc0-sfx-2/sfx100v2_air_03.ogg"), -6.0),
    ], 400.0, 80.0)


def tempest_2(L) -> np.ndarray:
    d = 1.6
    t = times(d)
    drop = 2 ** (-2.0 * np.minimum(t / 1.1, 1.0) ** 1.5)  # cai duas oitavas: o tempo freia
    chord = sum(osc(f * drop, d, "saw") for f in (440.0, 554.4, 659.3)) + osc(880.0 * drop, d)
    chord = svf(chord, 6000.0 * drop ** 1.3, 0.9) * env(d, 0.01, 0.3, 0.8)
    layers = [(chord, -4.0),
              (wind(d, 61) * env(d, 0.4, 0.5, 0.6), -5.0),
              (seg(L("opengameart/100-cc0-sfx-2/sfx100v2_air_01.ogg"), 0.0, 1.6), -8.0),
              (boom(0.7, 90.0, 30.0, 0.25, 62), -6.0)]
    at, gap = 0.0, 0.08
    tick = L("kenney/interface-sounds/Audio/tick_001.ogg")
    while at < 1.4:  # tique-taque que desacelera
        layers.append((tick, -12.0, at))
        at += gap
        gap *= 1.35
    return mix(layers, 1600.0, 350.0)


def tempest_3(L) -> np.ndarray:
    crack = crackle(0.3, 900.0, 71)
    crack[:n_of(0.06)] += 0.8 * fft_filter(noise(0.06, 70), lo=1500.0) * env(0.06, 0.001, 0.015)
    layers = [(crack, -5.0),
              (arc(0.22, 76), 0.0),
              (boom(0.6, 120.0, 40.0, 0.2, 77), -3.0),
              (seg(L("opengameart/100-cc0-sfx-2/sfx100v2_thunder_01.ogg"), 0.0, 2.4), 0.0, 0.05),
              (crackle(2.2, 160.0, 72), -6.0, 0.1),
              (seg(L("opengameart/electricity-sound-pack/charge.wav"), 1.0, 3.0), -5.0, 0.2),
              (wind(2.4, 73, 900.0) * env(2.4, 0.3, 0.8, 1.0), -7.0)]
    rng = np.random.default_rng(74)
    for k, at in enumerate(np.sort(rng.uniform(0.1, 1.9, 9))):
        layers.append((arc(rng.uniform(0.08, 0.18), 75 + k), rng.uniform(-7.0, -3.0), float(at)))
    return mix(layers, 2400.0, 450.0, 5.0)


# ---------------------------------------------------------------- Tridente: água, ondas, bolhas

def wave(seconds: float, seed: int) -> np.ndarray:
    """Onda subindo: ruído com passa-baixa abrindo de 250 Hz a 3,5 kHz enquanto cresce."""
    return svf(noise(seconds, seed), glide(250.0, 3500.0, seconds, 1.3), 0.9) * swell(seconds, 1.6)


def trident_1(L) -> np.ndarray:
    dry = bus([
        (L("opengameart/100-cc0-sfx/plop_01.ogg"), -9.0),  # resposta imediata antes da onda crescer
        (wave(0.42, 81), -3.0),
        (L("opengameart/100-cc0-sfx/splash_01.ogg"), -1.0, 0.38),
        (boom(0.5, 70.0, 40.0, 0.15, 82), -8.0, 0.38),
        (bubbles(0.55, 14, 83), -10.0, 0.42),
    ])
    return mix([(reverb(dry, 0.8, 0.2, 84), 0.0)], 1000.0, 200.0)


def trident_2(L) -> np.ndarray:
    d = 1.4
    t = times(d)
    rate = glide(2.0, 9.0, d)
    spin = 2 * np.pi * np.cumsum(rate) / SR
    swirl = svf(noise(d, 91), 900.0 * 2 ** (0.9 * np.sin(spin)), 3.0, "band")
    vortex = osc(glide(110.0, 260.0, d) * (1.0 + 0.03 * np.sin(spin)), d) * (0.7 + 0.3 * np.sin(spin + 1.0))
    e = env(d, 0.15, 0.25, 0.9)
    return mix([
        (swirl * e, -2.0),
        (vortex * e, -8.0),
        (seg(L("opengameart/100-cc0-sfx-2/sfx100v2_loop_water_02.ogg"), 0.0, d) * e, -7.0),
        (bubbles(1.2, 22, 92, 250.0, 900.0), -12.0, 0.1),
        (osc(60.0, d) * (0.5 + 0.5 * np.sin(2 * np.pi * 7.0 * t)) * e, -12.0),
    ], 1400.0, 300.0)


def trident_3(L) -> np.ndarray:
    splash1 = L("opengameart/100-cc0-sfx/splash_01.ogg")
    splashes = (splash1, L("opengameart/100-cc0-sfx/splash_02.ogg"), resample(splash1, 0.8))
    layers = [(seg(L("opengameart/100-cc0-sfx-2/sfx100v2_loop_water_03.ogg"), 0.0, 2.5), -10.0)]
    for i, at in enumerate((0.0, 0.62, 1.24)):
        grow = 2.0 * i
        layers += [(wave(0.45, 100 + i), -6.0 + grow, at),
                   (splashes[i], -4.0 + grow, at + 0.4),
                   (boom(0.7, 60.0, 30.0, 0.22, 110 + i), -6.0 + grow, at + 0.4),
                   (bubbles(0.6, 18, 120 + i), -12.0, at + 0.45)]
    return mix([(reverb(bus(layers), 1.5, 0.25, 125), 0.0)], 2500.0, 450.0, 5.0)


# ---------------------------------------------------------------- Atlas: escudos pesados, metal ressonante

def atlas_1(L) -> np.ndarray:
    t = times(0.6)
    ring = bell(880.0, 0.6, METAL, 0.25) * (0.75 + 0.25 * np.sin(2 * np.pi * 18.0 * t))
    return mix([
        (L("kenney/sci-fi-sounds/Audio/forceField_001.ogg"), -3.0),
        (L("kenney/impact-sounds/Audio/impactMetal_heavy_002.ogg"), -3.0),
        (ring, -2.0, 0.02),
        (bell(1760.0, 0.4, METAL, 0.15), -9.0, 0.02),
        (zap(300.0, 1200.0, 0.12, "sine", 0.06), -10.0),
    ], 700.0, 150.0)


def atlas_2(L) -> np.ndarray:
    d = 1.6
    layers = [(L("kenney/sci-fi-sounds/Audio/forceField_003.ogg"), -9.0)]
    for i, (f, hum) in enumerate(((523.25, 110.0), (783.99, 165.0), (1046.5, 220.0))):
        at = 0.14 * i
        dd = d - at
        t = times(dd)
        orbit = 0.5 + 0.5 * np.sin(2 * np.pi * 2.5 * t + i * 2 * np.pi / 3)
        tone = (osc(hum, dd) + 0.3 * osc(2 * hum, dd)) * orbit * env(dd, 0.05, 0.3, 1.0 - at)
        layers += [(bell(f, 0.9, CRYSTAL, 0.35), -4.0, at), (tone, -8.0, at)]
    return mix([(reverb(bus(layers), 1.0, 0.2, 131), 0.0)], 1600.0, 300.0)


def atlas_3(L) -> np.ndarray:
    d = 2.4
    drone = svf(osc(65.41, d, "saw") + osc(98.0, d, "saw"), 900.0, 0.8) * env(d, 0.05, 0.6, 1.2)
    layers = [(resample(L("kenney/impact-sounds/Audio/impactMetal_heavy_000.ogg"), 0.7), -1.0),
              (L("opengameart/100-cc0-sfx/gong_01.ogg"), -4.0),
              (boom(1.0, 80.0, 35.0, 0.35, 141), -3.0),
              (drone, -8.0),
              (choir([261.63, 329.63, 392.0, 523.25], d, "u", 0.6, seed=142) * env(d, 0.6, 0.5, 1.0), -6.0),
              (shimmer(2.0, 24, 143, 3000.0, 7000.0), -13.0, 0.2)]
    for i, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):  # reparo: arpejo de Dó maior
        layers.append((bell(f, 0.8, CRYSTAL, 0.3), -5.0, 1.45 + 0.09 * i))
    return mix([(reverb(bus(layers), 2.0, 0.3, 144), 0.0)], 2500.0, 500.0, 5.0)


# ---------------------------------------------------------------- Aríete: artilharia, baques

def ram_1(L) -> np.ndarray:
    cannon = resample(L(f"opengameart/{JUNKALA}/Weapons/Cannon/sfx_wpn_cannon4.wav"), 1.2)
    layers = []
    for i in range(5):
        lift = 2.0 if i == 4 else 0.0
        at = 0.13 * i
        layers += [(boom(0.3, 130.0, 45.0, 0.08, 150 + i), -1.0 + lift, at), (cannon, -6.0 + lift, at)]
    return mix(layers, 1000.0, 200.0)


def ram_2(L) -> np.ndarray:
    d = 0.38
    rev = svf(osc(glide(55.0, 110.0, d), d, "saw") + 0.5 * noise(d, 160), glide(300.0, 2000.0, d), 1.0) * swell(d, 1.2)
    return mix([
        (rev, -4.0),
        (seg(L("kenney/sci-fi-sounds/Audio/thrusterFire_002.ogg"), 0.0, d) * swell(d, 1.0), -5.0),
        (L("kenney/impact-sounds/Audio/impactPlate_heavy_000.ogg"), -1.0, d),
        (L("kenney/impact-sounds/Audio/impactMetal_heavy_001.ogg"), -3.0, d),
        (boom(0.55, 120.0, 38.0, 0.18, 161), -1.0, d),
        (L("kenney/sci-fi-sounds/Audio/explosionCrunch_000.ogg"), -6.0, d),
    ], 1000.0, 200.0)


def ram_3(L) -> np.ndarray:
    rng = np.random.default_rng(170)
    cannons = [L(f"opengameart/{JUNKALA}/Weapons/Cannon/sfx_wpn_cannon{k}.wav") for k in (1, 2, 5)]
    layers = [(fft_filter(noise(2.5, 171), hi=120.0) * env(2.5, 0.6, 0.5, 0.9), -4.0),
              (L(f"opengameart/{JUNKALA}/Explosions/Long/sfx_exp_long2.wav"), -6.0, 1.6)]
    for k, at in enumerate(np.sort(np.concatenate([[0.0], rng.uniform(0.1, 1.8, 9)]))):
        c = resample(cannons[k % 3], rng.uniform(0.9, 1.1))
        layers += [(c, rng.uniform(-8.0, -2.0), float(at)),
                   (boom(0.5, rng.uniform(100.0, 140.0), 35.0, 0.15, 180 + k), rng.uniform(-5.0, -1.0), float(at))]
    return mix([(reverb(bus(layers), 1.5, 0.2, 172), 0.0)], 2500.0, 450.0, 5.0)


# ---------------------------------------------------------------- Enxame: drones, inseto-tecnológico

def swarm_1(L) -> np.ndarray:
    d = 0.9
    t = times(d)
    arrive = np.where(t < 0.5, 0.1 + 0.9 * (t / 0.5) ** 1.5, np.exp(-(t - 0.5) / 0.15))
    return mix([
        (buzz(d, 14, 170.0, 330.0, 190, 0.06) * arrive, 0.0),
        (L("opengameart/80-cc0-creature-sfx/x1/bug_03.ogg"), -8.0, 0.05),
        (L("kenney/interface-sounds/Audio/select_001.ogg"), -14.0, 0.45),
    ], 900.0, 120.0)


def swarm_2(L) -> np.ndarray:
    d = 1.4
    t = times(d - 0.2)
    net = (osc(220.0, d - 0.2) + osc(330.0, d - 0.2) + osc(440.0, d - 0.2)
           + 0.5 * svf(osc(110.0, d - 0.2, "saw"), 1200.0)) * (0.65 + 0.35 * np.sin(2 * np.pi * 7.0 * t))
    layers = [(buzz(d, 10, 150.0, 260.0, 200) * env(d, 0.1, 0.4, 0.6), -10.0),
              (net * env(d - 0.2, 0.08, 0.35, 0.6), -4.0, 0.2),
              (L("kenney/digital-audio/Audio/zapTwoTone.ogg"), -6.0),
              (L("kenney/digital-audio/Audio/zapThreeToneUp.ogg"), -7.0, 0.12),
              (crackle(0.9, 50.0, 201), -16.0, 0.3)]
    for i, at in enumerate((0.05, 0.15, 0.25)):
        layers.append((zap(2400.0 + 300 * i, 3600.0 + 300 * i, 0.06, "square", 0.025), -13.0, at))
    return mix(layers, 1400.0, 300.0)


def swarm_3(L) -> np.ndarray:
    scream = resample(L("opengameart/80-cc0-creature-sfx/x1/scream_01.ogg"), 0.9)
    tech = scream * (0.5 + 0.5 * np.sin(2 * np.pi * 110.0 * np.arange(len(scream)) / SR))
    layers = [(tech, -1.0),
              (osc(glide(1800.0, 2600.0, 0.4), 0.4, "saw") * env(0.4, 0.02, 0.12, 0.1), -12.0),
              (buzz(1.9, 24, 200.0, 420.0, 210, 0.3) * swell(1.9, 0.8), -3.0, 0.5),
              (boom(0.6, 90.0, 32.0, 0.2, 211), -4.0, 2.0)]
    rng = np.random.default_rng(212)
    for k, at in enumerate(np.sort(rng.uniform(1.2, 2.3, 8))):
        pop = L(f"opengameart/{JUNKALA}/Explosions/Shortest/sfx_exp_shortest_hard{k + 1}.wav")
        layers.append((pop, rng.uniform(-8.0, -4.0), float(at)))
    return mix(layers, 2450.0, 350.0)


# ---------------------------------------------------------------- Eclipse: escuro, abafado, invertido

def eclipse_1(L) -> np.ndarray:
    field = fft_filter(L("kenney/sci-fi-sounds/Audio/forceField_002.ogg")[::-1], hi=1500.0)
    gong = fft_filter(L("opengameart/100-cc0-sfx/gong_02.ogg")[::-1], hi=1200.0)[-n_of(0.75):]
    end = 0.75
    return mix([
        (fft_filter(L("kenney/impact-sounds/Audio/impactSoft_heavy_001.ogg"), hi=900.0), -12.0),  # toque abafado
        (field, -2.0, ending_at(field, end)),
        (gong * swell(len(gong) / SR, 1.0), -4.0, ending_at(gong, end)),
        (osc(50.0, end) * swell(end, 2.0), -10.0),
        (L("kenney/impact-sounds/Audio/impactSoft_heavy_001.ogg"), -4.0, end - 0.03),
    ], 1050.0, 220.0)


def eclipse_2(L) -> np.ndarray:
    d = 1.0
    t = times(d)
    f = 70.0 * (1.0 + 0.6 * np.exp(-t / 0.05))
    wub = (osc(f, d) + 0.4 * osc(2 * f, d)) * env(d, 0.003, 0.3)
    ring_fc = 300.0 * 2 ** (2.9 * (1.0 - np.abs(2.0 * t / d - 1.0)) ** 1.5)
    ring = svf(noise(d, 220), ring_fc, 4.0, "band") * env(d, 0.02, 0.3, 0.2)
    plasma = svf(osc(110.0, d, "saw"), 900.0) * (0.6 + 0.4 * np.sin(2 * np.pi * 22.0 * t)) * env(d, 0.01, 0.35)
    portal = fft_filter(L(f"opengameart/{JUNKALA}/Movement/Portals and Transitions/sfx_movement_portal5.wav")[::-1],
                        hi=2500.0)
    dark = fft_filter(bus([(wub, 0.0), (ring, -4.0), (plasma, -8.0), (portal, -10.0, ending_at(portal, 0.25))]),
                      hi=3500.0)
    return mix([(reverb(dark, 0.9, 0.25, 221, 2500.0), 0.0)], 1000.0, 220.0)


def eclipse_3(L) -> np.ndarray:
    drop = sat(osc(glide(130.0, 26.0, 0.6, 0.6), 0.6) * env(0.6, 0.003, 0.3, 0.1), 2.5)
    minor = (55.0, 65.41, 82.41)
    stab = svf(sum(osc(f, 0.6, "saw") for f in minor), 500.0) * env(0.6, 0.005, 0.2)
    suck_src = reverb(fft_filter(noise(0.3, 230), hi=2000.0) * env(0.3, 0.001, 0.08), 0.8, 1.0, 231, 3000.0)
    suck = suck_src[::-1][-n_of(0.85):]
    gong = fft_filter(L("opengameart/100-cc0-sfx/gong_02.ogg")[::-1], hi=900.0)[-n_of(0.85):]
    release = bus([
        (boom(1.0, 90.0, 30.0, 0.35, 232), 0.0),
        (fft_filter(L("kenney/sci-fi-sounds/Audio/explosionCrunch_003.ogg"), hi=2500.0), -4.0),
        (whoosh(0.7, 3000.0, 200.0, 1.0, 0.03, 233), -6.0),
        (svf(sum(osc(f * 2, 0.95, "saw") for f in minor), 900.0) * env(0.95, 0.01, 0.4, 0.2), -6.0),
    ])
    return mix([
        (drop, 0.0),
        (stab, -6.0),
        (suck, -4.0, 1.45 - len(suck) / SR),
        (gong * swell(len(gong) / SR, 1.5), -8.0, 1.45 - len(gong) / SR),
        (reverb(release, 1.6, 0.3, 234, 3000.0), 0.0, 1.55),  # 100 ms de vácuo antes de soltar
    ], 2500.0, 450.0, 5.0)


# ---------------------------------------------------------------- Nova: estelar, "ping" de crítico

def nova_1(L) -> np.ndarray:
    lock = fft_filter(np.concatenate([zap(1760.0, 1760.0, 0.035, "square", 0.02), np.zeros(n_of(0.025)),
                                      zap(2637.0, 2637.0, 0.05, "square", 0.025)]), hi=6000.0)
    return mix([
        (lock, -6.0),
        (bell(3136.0, 0.35, CRYSTAL, 0.18), 0.0, 0.06),
        (L("kenney/interface-sounds/Audio/glass_002.ogg"), -8.0, 0.06),
        (shimmer(0.25, 6, 241, 4000.0, 8500.0), -14.0, 0.07),
    ], 400.0, 80.0)


def nova_2(L) -> np.ndarray:
    layers = []
    for i, at in enumerate((0.0, 0.14, 0.28)):
        p = (1.0, 1.12, 1.26)[i]
        star = zap(4200.0 * p, 1400.0 * p, 0.09, "sine", 0.04) + 0.3 * zap(2100.0 * p, 700.0 * p, 0.09, "square", 0.03)
        layers += [(star, -1.0, at),
                   (L(f"kenney/sci-fi-sounds/Audio/laserRetro_00{i + 1}.ogg"), -6.0, at),
                   (bell(2093.0 * p, 0.3, CRYSTAL, 0.12), -10.0, at + 0.01),
                   (shimmer(0.3, 6, 250 + i, 3500.0, 8500.0, 0.5), -14.0, at + 0.02)]
    return mix([(reverb(bus(layers), 0.6, 0.2, 253), 0.0)], 1000.0, 250.0)


def nova_3(L) -> np.ndarray:
    pull = osc(glide(150.0, 2400.0, 0.98, 2.2), 0.98) * swell(0.98, 2.0)
    implode_src = reverb(np.concatenate([noise(0.05, 260) * env(0.05, 0.001, 0.015), np.zeros(n_of(0.05))])
                         + np.pad(bell(1568.0, 0.1, CRYSTAL, 0.05), (0, 0)), 0.9, 1.0, 261)
    implode = implode_src[::-1][-n_of(0.95):]
    rev_exp = fft_filter(L(f"opengameart/{JUNKALA}/Explosions/Long/sfx_exp_long1.wav")[::-1], hi=4000.0)[-n_of(0.95):]
    blast = bus([
        (L(f"opengameart/{JUNKALA}/Explosions/Long/sfx_exp_long4.wav"), -1.0),
        (L("kenney/sci-fi-sounds/Audio/lowFrequency_explosion_000.ogg"), -2.0),
        (boom(1.3, 120.0, 30.0, 0.45, 262), -1.0),
        (shimmer(0.6, 30, 263, 2000.0, 9000.0, 0.5), -8.0),
        (fft_filter(noise(0.08, 264), lo=3000.0) * env(0.08, 0.001, 0.02), -8.0),
    ])
    return mix([
        (bell(3136.0, 0.4, CRYSTAL, 0.15), -8.0),  # resposta imediata: o "ping" estelar da Nova
        (pull, -6.0),
        (implode, -4.0, 0.98 - len(implode) / SR),
        (rev_exp, -6.0, 0.98 - len(rev_exp) / SR),
        (reverb(blast, 1.6, 0.3, 265), 0.0, 1.0),
    ], 2500.0, 450.0, 5.0)


# ---------------------------------------------------------------- Titã: explosões sísmicas

def titan_1(L) -> np.ndarray:
    return mix([
        (L("kenney/sci-fi-sounds/Audio/explosionCrunch_002.ogg"), 0.0),
        (boom(0.9, 75.0, 28.0, 0.35, 270), -1.0),
        (fft_filter(noise(0.9, 271), hi=90.0) * env(0.9, 0.02, 0.3), -6.0),
        (L("kenney/impact-sounds/Audio/impactMining_000.ogg"), -8.0, 0.03),
    ], 900.0, 200.0, 5.0)


def titan_2(L) -> np.ndarray:
    layers = []
    for k, at in enumerate((0.0, 0.14, 0.25, 0.34, 0.41, 0.47)):
        ex = resample(L(f"opengameart/{JUNKALA}/Explosions/Short/sfx_exp_short_hard{k + 1}.wav"), 1.0 + 0.06 * k)
        layers += [(fft_filter(noise(0.05, 280 + k), lo=3000.0) * swell(0.05, 1.0), -12.0, max(0.0, at - 0.05)),
                   (ex, -5.0 + 0.8 * k, at)]
    layers.append((boom(0.6, 100.0, 32.0, 0.2, 290), -2.0, 0.47))
    return mix([(reverb(bus(layers), 0.8, 0.2, 291), 0.0)], 1300.0, 300.0)


def titan_3(L) -> np.ndarray:
    crunch = [L(f"kenney/sci-fi-sounds/Audio/explosionCrunch_00{k}.ogg") for k in (1, 2, 3, 4)]
    layers = [(fft_filter(noise(2.5, 300), hi=70.0) * env(2.5, 0.3, 0.6, 1.2), -3.0),
              (L(f"opengameart/{JUNKALA}/Explosions/Long/sfx_exp_long6.wav"), -6.0, 1.22)]
    for k, at in enumerate((0.0, 0.3, 0.56, 0.8, 1.02, 1.22)):
        size = k / 5.0
        layers += [(resample(crunch[k % 4], 0.8 + 0.06 * k), -8.0 + 8.0 * size, at),
                   (boom(0.6 + 0.6 * size, 90.0 + 10 * k, 30.0, 0.15 + 0.25 * size, 310 + k), -6.0 + 5.0 * size, at)]
    return mix([(reverb(bus(layers), 1.8, 0.25, 320), 0.0)], 2500.0, 500.0, 5.0)


# ---------------------------------------------------------------- Ascensão: coro, coral, todas as cores

def ascension_1(L) -> np.ndarray:
    chime = bell(1318.5, 0.4, CRYSTAL, 0.2) + bell(1975.5, 0.4, CRYSTAL, 0.16)
    return mix([
        (echo(chime, 0.13, 0.5, 3, 5000.0), 0.0),
        (L("kenney/interface-sounds/Audio/glass_003.ogg"), -10.0),
        (choir([659.25, 987.77], 0.6, "a", 0.08, seed=330) * env(0.6, 0.08, 0.15), -14.0),
    ], 900.0, 200.0)


def ascension_2(L) -> np.ndarray:
    d = 1.6
    lances = (523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0, 2349.3)
    layers = [(choir([261.63, 329.63, 392.0, 523.25], d, "a", 0.12, seed=340) * env(d, 0.12, 0.4, 0.7), -2.0),
              (shimmer(1.2, 20, 341, 3000.0, 9000.0), -12.0, 0.1)]
    for i, f in enumerate(lances):
        at = 0.05 + 0.055 * i
        layers += [(bell(f, 0.4, CRYSTAL, 0.15), -6.0, at), (zap(f * 3, f * 2, 0.03, "sine", 0.01), -14.0, at)]
    return mix([(reverb(bus(layers), 1.4, 0.35, 342), 0.0)], 1600.0, 300.0)


def ascension_3(L) -> np.ndarray:
    d = 1.8
    t = times(d)
    rise = 2 ** ((5.0 / 12.0) * (t / d) ** 1.5)  # o coro sobe uma quarta até o acorde final
    riser = whoosh(d, 300.0, 9000.0, 1.2, d - 0.01, 350)
    climb = bus([
        (choir([261.63, 329.63, 392.0], d, "o", 0.5, rise, 351), -3.0),
        (riser * swell(d, 1.5), -9.0),
        (shimmer(d, 40, 352, 2000.0, 9000.0, 2.0), -10.0),
    ])
    hit = 1.75
    triumph = bus([
        (choir([130.81, 196.0, 261.63, 329.63, 392.0, 523.25, 659.25], 0.75, "a", 0.02, seed=353), 0.0),
        (brass([130.81, 196.0, 261.63, 392.0], 0.75, 0.01, 4000.0, 0.4, 354), -5.0),
        (bell(1046.5, 0.75, CRYSTAL, 0.4) + bell(1568.0, 0.75, CRYSTAL, 0.35), -6.0),
        (boom(0.75, 100.0, 33.0, 0.3, 355), -4.0),
        (shimmer(0.6, 30, 356, 1500.0, 10000.0, 0.5), -9.0),
    ])
    return mix([
        (bell(1318.5, 0.5, CRYSTAL, 0.2) + bell(1975.5, 0.5, CRYSTAL, 0.16), -7.0),  # o eco de Atlântida abre
        (climb, 0.0),
        (reverb(triumph, 2.2, 0.35, 357), 1.0, hit),
    ], 2500.0, 450.0, 4.0)


# ---------------------------------------------------------------- medidor de poder

def charge(L, k: int) -> np.ndarray:
    f = (1046.5, 1318.5, 1568.0)[k]  # Dó, Mi, Sol
    layers = [(bell(f, 0.5, CRYSTAL, 0.18), 0.0),
              (L(f"kenney/interface-sounds/Audio/glass_00{(4, 5, 6)[k]}.ogg"), -10.0),
              (zap(f / 2, f, 0.05, "sine", 0.03), -14.0)]
    if k == 2:  # o terceiro enche a barra: oitava acima e brilho
        layers += [(bell(2 * f, 0.6, CRYSTAL, 0.22), -6.0, 0.02), (shimmer(0.45, 10, 360, 4000.0, 9000.0), -12.0, 0.03)]
    return mix([(reverb(bus(layers), 0.5, 0.15, 361 + k), 0.0)], 700.0 if k == 2 else 500.0, 120.0)


def empty(L) -> np.ndarray:
    blip = lambda f: osc(f, 0.09, "tri") * env(0.09, 0.004, 0.035)
    soft = fft_filter(np.concatenate([blip(392.0), np.zeros(n_of(0.02)), blip(293.66)]), hi=2500.0)
    return mix([(reverb(soft, 0.3, 0.12, 370), 0.0)], 300.0, 60.0, 1.0)


# ---------------------------------------------------------------- principal

SOUNDS = {
    "falcon_1": falcon_1, "falcon_2": falcon_2, "falcon_3": falcon_3,
    "manta_1": manta_1, "manta_2": manta_2, "manta_3": manta_3,
    "hydra_1": hydra_1, "hydra_2": hydra_2, "hydra_3": hydra_3,
    "tempest_1": tempest_1, "tempest_2": tempest_2, "tempest_3": tempest_3,
    "trident_1": trident_1, "trident_2": trident_2, "trident_3": trident_3,
    "atlas_1": atlas_1, "atlas_2": atlas_2, "atlas_3": atlas_3,
    "ram_1": ram_1, "ram_2": ram_2, "ram_3": ram_3,
    "swarm_1": swarm_1, "swarm_2": swarm_2, "swarm_3": swarm_3,
    "eclipse_1": eclipse_1, "eclipse_2": eclipse_2, "eclipse_3": eclipse_3,
    "nova_1": nova_1, "nova_2": nova_2, "nova_3": nova_3,
    "titan_1": titan_1, "titan_2": titan_2, "titan_3": titan_3,
    "ascension_1": ascension_1, "ascension_2": ascension_2, "ascension_3": ascension_3,
    "charge_1": lambda L: charge(L, 0), "charge_2": lambda L: charge(L, 1), "charge_3": lambda L: charge(L, 2),
    "empty": empty,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", default=r"c:\src\downloads\assets")
    parser.add_argument("--only", default="", help="lista separada por vírgula, ex.: falcon_1,nova_3")
    args = parser.parse_args()
    src = pathlib.Path(args.src)
    out = src / "atlantis-mix" / "powers"
    out.mkdir(parents=True, exist_ok=True)
    lib = Library(src)
    wanted = [w for w in args.only.split(",") if w] or list(SOUNDS)
    failed = 0
    for name in wanted:
        stats = write(out / f"power_{name}.ogg", SOUNDS[name](lib))
        if stats["clip"] or stats["onset_ms"] > 5.0 or stats["peak"] > -0.5 or not 250.0 <= stats["ms"] <= 2600.0:
            print(f"  ERRO: power_{name}.ogg fora do padrão")
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
