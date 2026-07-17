#!/usr/bin/env python3
"""마작한판 효과음 합성 스크립트 (표준 라이브러리만 사용).

아기자기한 파스텔 톤 게임에 어울리는 부드러운 사인파 기반 효과음을
assets/sfx/*.wav 로 생성한다.
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples
        )
        w.writeframes(frames)
    print(f"wrote {path} ({len(samples)/SR:.2f}s)")


def silence(dur):
    return [0.0] * int(SR * dur)


def tone(freq, dur, vol=0.5, attack=0.005, decay=None, harmonics=(1.0, 0.25)):
    """부드러운 종소리 느낌: 기본파 + 약한 배음, 지수 감쇠."""
    n = int(SR * dur)
    decay = decay if decay is not None else dur
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / attack) * math.exp(-3.5 * t / decay)
        s = 0.0
        for h, amp in enumerate(harmonics, start=1):
            s += amp * math.sin(2 * math.pi * freq * h * t)
        out.append(vol * env * s)
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, s in enumerate(l):
            out[i] += s
    peak = max(1.0, max(abs(s) for s in out))
    return [s / peak * 0.9 for s in out]


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


# 1) tap — 패 버리기: 짧은 나무 '톡' (노이즈 + 저음 펄스)
random.seed(7)
n = int(SR * 0.07)
tap = []
for i in range(n):
    t = i / SR
    env = math.exp(-60 * t)
    noise = (random.random() * 2 - 1) * 0.5
    thump = math.sin(2 * math.pi * 220 * t) * 0.9
    tap.append(0.55 * env * (noise + thump))
write_wav("tap", tap)

# 2) draw — 패 뽑기: 짧고 귀여운 상승 블립
n = int(SR * 0.10)
draw = []
for i in range(n):
    t = i / SR
    env = min(1.0, t / 0.005) * math.exp(-25 * t)
    f = 520 + 420 * (t / 0.10)  # 520 → 940Hz 스윕
    draw.append(0.4 * env * math.sin(2 * math.pi * f * t))
write_wav("draw", draw)

# 3) claim — 뺏어오기: 뾰롱 (두 음 상승)
write_wav("claim", mix(seq(
    tone(659.3, 0.09, vol=0.5, decay=0.12),   # E5
    tone(987.8, 0.22, vol=0.5, decay=0.22),   # B5
)))

# 4) ding — 영수증 항목 체크: 맑은 종 '딩'
write_wav("ding", tone(1568.0, 0.28, vol=0.45, decay=0.25,
                       harmonics=(1.0, 0.35, 0.12)))  # G6

# 5) total — 총점 발표: 짧은 상승 3연타 + 마무리 음
write_wav("total", mix(seq(
    tone(1046.5, 0.09, vol=0.42, decay=0.10),  # C6
    tone(1318.5, 0.09, vol=0.42, decay=0.10),  # E6
    tone(1568.0, 0.09, vol=0.42, decay=0.10),  # G6
    tone(2093.0, 0.42, vol=0.5, decay=0.40, harmonics=(1.0, 0.3, 0.1)),  # C7
)))

# 6) win — 승리 팡파레: 밝은 아르페지오
write_wav("win", mix(
    seq(
        tone(523.3, 0.13, vol=0.45, decay=0.16),  # C5
        tone(659.3, 0.13, vol=0.45, decay=0.16),  # E5
        tone(784.0, 0.13, vol=0.45, decay=0.16),  # G5
        tone(1046.5, 0.55, vol=0.5, decay=0.5, harmonics=(1.0, 0.3, 0.1)),  # C6
    ),
    seq(silence(0.39), tone(523.3, 0.55, vol=0.22, decay=0.5)),  # 낮은 C 화음 보강
))

# 7) lose — 아쉬움: 부드러운 하강 두 음 (짧고 순하게)
write_wav("lose", mix(seq(
    tone(392.0, 0.18, vol=0.32, decay=0.22),  # G4
    tone(311.1, 0.40, vol=0.32, decay=0.38),  # Eb4
)))
