"""生成佣兵原创音效：拔销投掷、手雷爆炸、近战挥击和重甲受击。

固定随机种子的程序合成，44.1 kHz / 16 位单声道 PCM；不依赖外部录音。
音量统一归一化并加首尾淡化，便于 Godot 通过空间音源混音。
"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'Assets/Audio/SFX/Mercenary'
RATE = 44100


def synthesize(name, duration, seed):
    """用噪声、频率扫描和衰减包络区分布料投掷、低频爆炸与金属碰撞。"""
    rng = random.Random(seed)
    values = []
    low = 0.0
    for index in range(int(duration * RATE)):
        t = index / RATE
        noise = rng.uniform(-1.0, 1.0)
        low = low * 0.92 + noise * 0.08
        if name == 'grenadier_throw':
            value = math.sin(2 * math.pi * 2300 * t) * math.exp(-t * 95) * 0.4
            value += noise * math.exp(-((t - 0.12) / 0.06) ** 2) * 0.24
        elif name == 'grenadier_explosion':
            value = low * math.exp(-t * 5) * 2.3 + noise * math.exp(-t * 34) * 0.4
            value += math.sin(2 * math.pi * (95 * t - 28 * t * t)) * math.exp(-t * 7) * 0.5
        elif name == 'fearless_strike':
            value = noise * math.exp(-((t - 0.045) / 0.025) ** 2) * 0.22
            value += low * math.exp(-max(t - 0.085, 0) * 27) * (0.9 if t >= 0.085 else 0)
            value += math.sin(2 * math.pi * 145 * t) * math.exp(-((t - 0.1) / 0.05) ** 2) * 0.35
        else:
            value = sum(math.sin(2 * math.pi * f * t) * math.exp(-t * decay) * amp
                        for f, decay, amp in [(660, 23, 0.25), (1135, 18, 0.16), (1840, 35, 0.1)])
            value += noise * math.exp(-t * 80) * 0.28
        value *= min(1.0, t / 0.003) * min(1.0, (duration - t) / 0.025)
        values.append(value)
    peak = max(abs(value) for value in values) or 1.0
    data = b''.join(struct.pack('<h', round(value / peak * 0.7 * 32767)) for value in values)
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(data)


def main():
    """只生成本次新增兵种的四种音效，不覆盖已有武器或爆炸声音。"""
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, duration, seed in [('grenadier_throw', 0.3, 401), ('grenadier_explosion', 0.8, 402),
                                 ('fearless_strike', 0.3, 403), ('fearless_armor', 0.35, 404)]:
        synthesize(name, duration, seed)


if __name__ == '__main__':
    main()
