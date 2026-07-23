#!/usr/bin/env python3
"""Generate the six game sound effects as 16-bit mono WAVs using only the
Python stdlib. All sounds are tiny procedural blips — original audio.

Run from the repo root:  python tools/make_sfx.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
random.seed(20260723)


def save(name: str, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for smp in samples:
            v = max(-1.0, min(1.0, smp))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(frames))
    print(f"wrote {path} ({len(samples)} samples)")


def t_range(seconds: float):
    n = int(RATE * seconds)
    return [i / RATE for i in range(n)]


def place():
    dur = 0.07
    out = []
    for t in t_range(dur):
        v = 0.55 * math.sin(2 * math.pi * 190 * t) * math.exp(-t * 42)
        if t < 0.006:
            v += 0.25 * (random.random() * 2 - 1) * (1 - t / 0.006)
        out.append(v)
    return out


def stack():
    out = []
    for t in t_range(0.055):
        out.append(0.5 * math.sin(2 * math.pi * 330 * t) * math.exp(-t * 55))
    for t in t_range(0.075):
        out.append(0.5 * math.sin(2 * math.pi * 449 * t) * math.exp(-t * 45))
    return out


def complete():
    notes = [523.25, 659.25, 783.99]
    out = [0.0] * int(RATE * 0.30)
    for i, f in enumerate(notes):
        start = int(RATE * 0.075 * i)
        for j, t in enumerate(t_range(0.16)):
            k = start + j
            if k < len(out):
                out[k] += 0.34 * math.sin(2 * math.pi * f * t) * math.exp(-t * 16)
    return out


def coin():
    out = []
    for t in t_range(0.15):
        v = 0.3 * math.sin(2 * math.pi * 1318.5 * t)
        v += 0.3 * math.sin(2 * math.pi * 1760.0 * t)
        out.append(v * math.exp(-t * 20) * min(1.0, t / 0.004))
    return out


def pack():
    dur = 0.24
    out = []
    for t in t_range(dur):
        p = t / dur
        env = math.sin(math.pi * p) ** 2
        noise = (random.random() * 2 - 1) * 0.28
        sweep = 0.3 * math.sin(2 * math.pi * (250 + 700 * p * p) * t)
        out.append(env * (noise + sweep))
    return out


def death():
    dur = 0.5
    out = []
    for t in t_range(dur):
        p = t / dur
        f = 320 * math.exp(-p * 1.1)
        trem = 1.0 + 0.25 * math.sin(2 * math.pi * 9 * t)
        out.append(0.45 * math.sin(2 * math.pi * f * t) * trem * math.exp(-t * 5))
    return out


def main():
    save("place", place())
    save("stack", stack())
    save("complete", complete())
    save("coin", coin())
    save("pack", pack())
    save("death", death())


if __name__ == "__main__":
    main()
