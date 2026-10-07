"""生成原创的八首循环配乐：每首 16 小节、独立旋律/和声/节奏与音色。

乐器采用带包络的加法合成，所有事件与延迟都按完整乐句环绕写入，
尾部释放会延续到循环开头，没有硬切尾音或额外静音间隔。
依赖 numpy；仅生成 Assets/Audio/Music 下的指定文件，不修改音效或其他资源。
"""
from pathlib import Path
import json
import math
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Assets/Audio/Music"
RATE = 22050
BEATS = 64

# 曲名、速度、和弦、主旋律音级、音色与节奏风格均独立配置，方便以后替换正式配乐。
TRACKS = [
    ("menu_command", "首页 / 集结号", 92, [(43, 0), (39, 1), (46, 1), (41, 1)], [0, 7, 10, 12, 7, 3, 5, 0], "warm", "light"),
    ("level_fortress", "要塞 / 突破防线", 112, [(45, 0), (41, 1), (48, 1), (43, 1)], [0, 3, 7, 12, 10, 7, 5, 3], "brass", "march"),
    ("level_jungle", "丛林 / 绿色潜行", 124, [(40, 0), (43, 1), (38, 1), (45, 0)], [0, 7, 10, 12, 7, 5, 3, 7], "pluck", "sync"),
    ("level_village", "村庄 / 黎明巡行", 96, [(38, 1), (43, 1), (45, 1), (38, 1)], [0, 4, 7, 9, 7, 4, 2, 0], "bell", "light"),
    ("level_valley", "山谷 / 风之回声", 88, [(38, 0), (34, 1), (41, 1), (36, 1)], [0, 7, 12, 10, 7, 5, 3, 0], "airy", "sparse"),
    ("level_metropolis", "都市 / 霓虹追击", 128, [(36, 0), (32, 1), (39, 1), (34, 1)], [0, 7, 3, 10, 12, 7, 5, 3], "chip", "drive"),
    ("level_underground_fortress", "地下要塞 / 铁幕核心", 108, [(35, 0), (31, 1), (28, 0), (30, 1)], [0, 2, 3, 7, 6, 3, 2, 0], "dark", "heavy"),
    ("level_mine_shaft", "矿井 / 深层脉冲", 104, [(33, 0), (36, 1), (38, 0), (40, 1)], [0, 7, 12, 7, 3, 5, 10, 7], "metal", "sync"),
]


def frequency(midi):
    """按十二平均律从 MIDI 音高计算基频。"""
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def voice(midi, duration, timbre, amplitude):
    """用有限谐波和软起止包络合成音符，避免混叠和点击声。"""
    count = max(2, round(duration * RATE))
    t = np.arange(count, dtype=np.float64) / RATE
    f = frequency(midi)
    phase = math.tau * f * t
    if timbre in ("pad", "airy", "warm"):
        signal = np.sin(phase) + 0.22 * np.sin(phase * 2) + 0.08 * np.sin(phase * 3)
        attack, release = min(0.22, duration * 0.25), min(0.55, duration * 0.4)
        decay = np.ones_like(t)
    elif timbre in ("pluck", "bell", "metal"):
        signal = np.sin(phase) + 0.32 * np.sin(phase * 2) + 0.11 * np.sin(phase * (3.97 if timbre == "metal" else 3))
        attack, release = 0.008, min(0.14, duration * 0.4)
        decay = np.exp(-t * (5.0 if timbre == "pluck" else 3.0))
    else:
        signal = np.sin(phase) + 0.28 * np.sin(phase * 2) + 0.14 * np.sin(phase * 3) + 0.065 * np.sin(phase * 4)
        attack, release = 0.018, min(0.2, duration * 0.4)
        decay = np.exp(-t * 1.8)
    envelope = np.minimum(1.0, t / attack) * np.minimum(1.0, (duration - t) / release)
    return signal * np.maximum(envelope, 0.0) * decay * amplitude


def add_event(mix, signal, beat, seconds_per_beat, pan=0.0):
    """事件跨乐句尾端时环绕到开头，保留尾音自然释放的连续性。"""
    start = round(beat * seconds_per_beat * RATE)
    indices = (start + np.arange(len(signal))) % len(mix)
    left = math.sqrt((1.0 - pan) * 0.5)
    right = math.sqrt((1.0 + pan) * 0.5)
    np.add.at(mix[:, 0], indices, signal * left)
    np.add.at(mix[:, 1], indices, signal * right)


def percussion(kind, rng, amplitude):
    """自制鼓组：低鼓、滤波军鼓与短踩镲，不引用外部采样。"""
    duration = {"kick": 0.2, "snare": 0.14, "hat": 0.045}[kind]
    t = np.arange(round(duration * RATE)) / RATE
    if kind == "kick":
        signal = np.sin(math.tau * (47 * t + 8 * (1 - np.exp(-t * 35)))) * np.exp(-t * 24)
    else:
        noise = rng.uniform(-1, 1, len(t))
        signal = noise - np.convolve(noise, np.ones(8) / 8, mode="same")
        signal *= np.exp(-t * (36 if kind == "snare" else 110))
    edge = np.minimum(1.0, t / 0.002) * np.minimum(1.0, (duration - t) / 0.012)
    return signal * np.maximum(edge, 0) * amplitude


def compose(spec, seed):
    """四段和声构成完整 16 小节，A/B 旋律呼应并在末小节回到开头主题。"""
    name, title, bpm, chords, motif, timbre, rhythm = spec
    beat_seconds = 60.0 / bpm
    mix = np.zeros((round(BEATS * beat_seconds * RATE), 2), dtype=np.float64)
    rng = np.random.default_rng(seed)
    opening_root = chords[0][0]
    for bar in range(16):
        root, major = chords[(bar // 2) % 4]
        third = 4 if major else 3
        for degree, pan in [(0, -0.45), (third, 0.0), (7, 0.45)]:
            add_event(mix, voice(root + 12 + degree, beat_seconds * 4.8, "pad", 0.055), bar * 4, beat_seconds, pan)
        for beat in range(4):
            bass_note = root - 12 + (7 if beat == 2 and rhythm in ("drive", "sync") else 0)
            add_event(mix, voice(bass_note, beat_seconds * 0.85, "dark", 0.1), bar * 4 + beat, beat_seconds)
            if rhythm != "sparse" or beat == 0:
                add_event(mix, percussion("kick", rng, 0.095 if rhythm == "heavy" else 0.055), bar * 4 + beat, beat_seconds)
            if beat in (1, 3) and rhythm not in ("sparse", "light"):
                add_event(mix, percussion("snare", rng, 0.045), bar * 4 + beat, beat_seconds, -0.15)
            for half in (0.0, 0.5):
                if rhythm == "sparse" and (beat + half) != 2.5:
                    continue
                add_event(mix, percussion("hat", rng, 0.012 if rhythm not in ("light", "sparse") else 0.005), bar * 4 + beat + half, beat_seconds, 0.4)
        # 每两小节组成问答短句，末小节下降回主音，下一轮自然呼应。
        offsets = [0.5, 1.25, 2.0, 3.0] if rhythm != "sync" else [0.5, 1.5, 2.25, 3.25]
        for step, offset in enumerate(offsets):
            degree = motif[(bar % 2) * 4 + step]
            melodic_root = root + 24
            if bar == 15:
                melodic_root = opening_root + 24
                degree = [7, 5, 2, 0][step]
            if timbre == "airy" and step in (1, 3):
                continue
            add_event(mix, voice(melodic_root + degree, beat_seconds * (1.8 if timbre == "airy" else 1.05), timbre, 0.095), bar * 4 + offset, beat_seconds, 0.12 if bar % 2 == 0 else -0.12)
        if rhythm in ("drive", "sync"):
            for step in range(8):
                degree = [0, third, 7, 12][step % 4]
                add_event(mix, voice(root + 24 + degree, beat_seconds * 0.55, "pluck", 0.025), bar * 4 + step * 0.5, beat_seconds, -0.4)
    # 环形延迟让末尾回声进入开头，不在文件末尾添加静音或硬截掉混响。
    dry = mix.copy()
    mix[:, 0] += np.roll(dry[:, 1], round(beat_seconds * RATE * 0.75)) * 0.19
    mix[:, 1] += np.roll(dry[:, 0], round(beat_seconds * RATE * 1.25)) * 0.19
    mix -= np.mean(mix, axis=0)
    rms = float(np.sqrt(np.mean(mix * mix)))
    mix *= 0.12 / max(rms, 0.001)
    mix = np.tanh(mix * 1.1) / 1.1
    peak = float(np.max(np.abs(mix)))
    if peak > 0.85:
        mix *= 0.85 / peak
    pcm = np.rint(mix * 32767).astype("<i2")
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())
    return {"file": f"{name}.wav", "title": title, "bpm": bpm, "bars": 16, "seconds": round(len(mix) / RATE, 3), "loop": "whole phrase; circular release and delay", "seed": seed}


def main():
    """批量导出配乐与对应元数据，供主题资源和音频总线直接使用。"""
    OUTPUT.mkdir(parents=True, exist_ok=True)
    metadata = []
    for index, spec in enumerate(TRACKS):
        track = compose(spec, 20261007 + index)
        metadata.append(track)
        print(f'{track["file"]}: {track["seconds"]}s / {track["bpm"]} BPM / 16 bars', flush=True)
    (OUTPUT / "tracks.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
