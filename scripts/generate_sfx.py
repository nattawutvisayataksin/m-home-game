import math
import random
import struct
import wave
from pathlib import Path


RATE = 22050
OUTPUT = Path(__file__).resolve().parents[1] / "projects" / "last-light" / "assets" / "audio" / "sfx"
MUSIC_OUTPUT = Path(__file__).resolve().parents[1] / "projects" / "last-light" / "assets" / "audio" / "music"


def synthesize(name: str, duration: float, start_hz: float, end_hz: float, volume: float = 0.35) -> None:
    count = int(RATE * duration)
    rng = random.Random(name)
    samples = bytearray()
    for index in range(count):
        t = index / RATE
        phase = 2 * math.pi * (start_hz * t + (end_hz - start_hz) * t * t / (2 * duration))
        envelope = min(1.0, t * 90.0) * max(0.0, (1.0 - t / duration) ** 2)
        tone = math.sin(phase)
        if name in {"shot", "hit", "breach"}:
            tone = tone * 0.6 + (rng.random() * 2 - 1) * 0.4
        sample = int(max(-1.0, min(1.0, tone * envelope * volume)) * 32767)
        samples.extend(struct.pack("<h", sample))

    OUTPUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(samples)


for spec in (
    ("shot", 0.045, 760, 340, 0.22),
    ("hit", 0.11, 360, 110, 0.28),
    ("charge", 0.32, 300, 920, 0.24),
    ("upgrade", 0.42, 440, 1320, 0.25),
    ("pulse", 0.55, 180, 55, 0.32),
    ("warning", 0.48, 620, 250, 0.22),
    ("breach", 0.28, 180, 48, 0.3),
    ("death", 0.18, 260, 80, 0.26),
    ("boss", 0.5, 140, 60, 0.3),
):
    synthesize(*spec)


def synthesize_ambient_loop() -> None:
    duration = 16.0
    count = int(RATE * duration)
    samples = bytearray()
    for index in range(count):
        t = index / RATE
        swell = 0.55 + 0.45 * math.sin(2 * math.pi * t / duration - math.pi / 2)
        tone = (
            0.48 * math.sin(2 * math.pi * 55.0 * t)
            + 0.26 * math.sin(2 * math.pi * 82.5 * t)
            + 0.18 * math.sin(2 * math.pi * 110.0 * t)
            + 0.08 * math.sin(2 * math.pi * 165.0 * t)
        )
        sample = int(max(-1.0, min(1.0, tone * swell * 0.10)) * 32767)
        samples.extend(struct.pack("<h", sample))

    MUSIC_OUTPUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(MUSIC_OUTPUT / "beacon_ambient.wav"), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(samples)


synthesize_ambient_loop()
