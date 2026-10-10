"""生成五名新首领的专用合成音效；固定种子、22.05 kHz 单声道 PCM，无外部录音。"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'Assets/Audio/SFX/Bosses'
RATE = 22050


def write(name, duration, frequency, noise, pulse):
    """将音调、噪声和脉冲包络混合，削峰并淡化两端，避免突变爆音。"""
    rng = random.Random(1040 + sum(map(ord, name)))
    samples = bytearray()
    for index in range(int(duration * RATE)):
        t = index / RATE
        envelope = min(1, t / .008, (duration - t) / .04)
        envelope *= .65 + .35 * math.cos(t * math.tau * pulse)
        value = (.35 * math.sin(math.tau * frequency * t) + noise * rng.uniform(-1, 1)) * envelope
        samples.extend(struct.pack('<h', int(max(-.9, min(.9, value)) * 32767)))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(samples)


def main():
    """为补员、盾冲、狙击锁定/枪声、点火、布雷/遥控和阶段切换提供声音辨识。"""
    ROOT.mkdir(parents=True, exist_ok=True)
    for args in [('rally', .55, 640, .05, 8), ('charge', .65, 90, .3, 4),
                 ('lock', .5, 1100, .01, 12), ('sniper', .22, 160, .6, 2),
                 ('flame', 1, 65, .4, 6), ('mine', .28, 410, .1, 16),
                 ('detonate', .7, 850, .02, 10), ('phase', .7, 220, .15, 5)]:
        write(*args)


if __name__ == '__main__':
    main()
