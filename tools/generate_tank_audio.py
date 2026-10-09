"""生成坦克专用合成音效，固定种子保证可复现，无第三方录音素材依赖。

主炮为低频冲击和空气爆音，机枪为短金属脉冲，履带为可循环发动机与滚轮节奏。
输出单声道 22.05 kHz PCM WAV，游戏内播放统一交由 SFX 总线与距离衰减处理。
"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'Assets/Audio/SFX/Tank'
RATE = 22050


def write(name, duration, sample, fade=True):
    """削去尖峰并淡化一次性尾端；循环履带保持周期性载波。"""
    rng = random.Random(381 + sum(map(ord, name)))
    values = []
    for i in range(int(duration * RATE)):
        t = i / RATE
        value = sample(t, rng.uniform(-1, 1))
        if fade:
            value *= min(1.0, t / 0.002, (duration - t) / 0.025)
        values.append(struct.pack('<h', int(max(-0.95, min(0.95, value)) * 32767)))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b''.join(values))


def main():
    """分别创建炮声、机枪、装填、热警报、出舱和履带六种可替换 WAV。"""
    ROOT.mkdir(parents=True, exist_ok=True)
    write('cannon', 0.7, lambda t, n: 0.68 * math.sin(2 * math.pi * (82 * t - 34 * t * t)) * math.exp(-7 * t) + 0.3 * n * math.exp(-18 * t))
    write('machine', 0.13, lambda t, n: (0.46 * n + 0.35 * math.sin(2 * math.pi * (900 * t - 1600 * t * t))) * math.exp(-35 * t))
    write('reload', 0.9, lambda t, n: sum((0.2 * n + 0.25 * math.sin(2 * math.pi * 470 * t)) * math.exp(-55 * (t - start)) if t >= start else 0 for start in [0, 0.22, 0.65]))
    write('overload', 1.2, lambda t, n: 0.24 * math.sin(2 * math.pi * (210 * t + 115 * t * t)) * (0.5 + 0.5 * math.sin(2 * math.pi * 7 * t)) + 0.1 * n * math.exp(-2 * t))
    write('eject', 0.8, lambda t, n: 0.5 * n * math.exp(-9 * t) + 0.28 * math.sin(2 * math.pi * (125 * t - 45 * t * t)) * math.exp(-5 * t))
    write('tracks', 0.8, lambda t, n: 0.22 * math.sin(2 * math.pi * 45 * t) + 0.1 * math.sin(2 * math.pi * 90 * t) + 0.08 * math.sin(2 * math.pi * 300 * t) * max(0, math.cos(2 * math.pi * 6.25 * t)) ** 10, fade=False)


if __name__ == '__main__':
    main()
