"""合成三种武器的原创射击音效：狙击爆音与金属尾声、RPG 低频冲击、火焰噪声。

只使用 Python 标准库；固定随机种子、16 位单声道 PCM，无第三方录音依赖。
喷火每发的 110 ms 噪声尾巴在连射时平滑衔接，松开扳机后自然结束。
"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'Assets/Audio/SFX/Weapons'
RATE = 22050


def generate(name, duration, seed):
    """使用衰减包络、低通噪声和频率扫描合成声音，并限制峰值避免削波。"""
    rng = random.Random(seed)
    low = 0.0
    samples = []
    for index in range(int(RATE * duration)):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        low = low * 0.82 + noise * 0.18
        if name == 'sniper':
            value = noise * math.exp(-t * 65) * 0.7 + low * math.exp(-t * 12) * 0.7
            value += math.sin(2 * math.pi * 125 * t) * math.exp(-t * 20) * 0.3
            value += math.sin(2 * math.pi * 1700 * t) * math.exp(-((t - 0.12) / 0.025) ** 2) * 0.08
        elif name == 'rpg':
            value = low * math.exp(-t * 7) * 1.4 + noise * math.exp(-t * 25) * 0.25
            value += math.sin(2 * math.pi * (85 * t - 35 * t * t)) * math.exp(-t * 8) * 0.45
        else:
            value = (low * 1.2 + noise * 0.18) * (0.7 + 0.3 * math.sin(2 * math.pi * 45 * t))
        value *= min(1.0, t / 0.003) * min(1.0, (duration - t) / 0.025)
        samples.append(struct.pack('<h', int(max(-0.9, min(0.9, value)) * 32767)))
    with wave.open(str(ROOT / f'{name}_fire.wav'), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b''.join(samples))


def main():
    """生成可直接导入 Godot 并通过现有开火音源播放的 WAV 文件。"""
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, duration, seed in [('sniper', 0.5, 101), ('rpg', 0.65, 102), ('flamethrower', 0.11, 103)]:
        generate(name, duration, seed)


if __name__ == '__main__':
    main()
