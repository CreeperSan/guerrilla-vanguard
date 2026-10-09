"""生成商店的购买与余额不足提示音；单声道 PCM，游戏统一使用 SFX 总线。

上行三音代表成交，低沉下降双音代表余额不足；短淡入/淡出避免爆音。
没有第三方录音素材，重新运行会产生相同 WAV。
"""
from pathlib import Path
import math
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / "Assets/Audio/SFX/Shop"
RATE = 22050


def write_chime(name, notes, step, duration):
    """按时间顺序叠加带衰减包络的基频和轻微泛音，限幅为 16 位 PCM。"""
    values = []
    for index in range(int(duration * RATE)):
        t = index / RATE
        value = 0.0
        for note_index, frequency in enumerate(notes):
            elapsed = t - note_index * step
            if elapsed >= 0:
                envelope = min(1.0, elapsed / 0.003) * math.exp(-22 * elapsed)
                value += envelope * (0.35 * math.sin(2 * math.pi * frequency * elapsed)
                                     + 0.07 * math.sin(2 * math.pi * 2 * frequency * elapsed))
        value *= min(1.0, (duration - t) / 0.02)
        values.append(struct.pack("<h", int(max(-0.9, min(0.9, value)) * 32767)))
    with wave.open(str(ROOT / f"{name}.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(values))


def main():
    """输出可直接在场景中替换的两件短提示音。"""
    ROOT.mkdir(parents=True, exist_ok=True)
    write_chime("purchase", [880, 1174.66, 1567.98], 0.07, 0.32)
    write_chime("insufficient", [220, 164.81], 0.09, 0.27)


if __name__ == "__main__":
    main()
