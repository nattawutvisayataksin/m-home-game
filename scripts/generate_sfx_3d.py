import math
import random
import struct
import wave
from pathlib import Path


# Deterministic procedural SFX for LAST LIGHT 3D — same synthesis style as the
# 2D build's generate_sfx.py, tuned for the tower-defense events:
# three distinct tower shots, combat hits, leak/breach, wave horn, economy UI.

RATE = 22050
OUTPUT = Path(__file__).resolve().parents[1] / "projects" / "last-light-3d" / "assets" / "audio" / "sfx"
MUSIC_OUTPUT = Path(__file__).resolve().parents[1] / "projects" / "last-light-3d" / "assets" / "audio" / "music"

NOISY = {"turret_shot", "resonator_pulse", "hit", "breach"}


def synthesize(name: str, duration: float, start_hz: float, end_hz: float, volume: float = 0.3) -> None:
	count = int(RATE * duration)
	rng = random.Random(name)
	samples = bytearray()
	for index in range(count):
		t = index / RATE
		phase = 2 * math.pi * (start_hz * t + (end_hz - start_hz) * t * t / (2 * duration))
		onset = min(1.0, t * 90.0)
		decay = max(0.0, (1.0 - t / duration) ** 2)
		envelope = onset * decay
		tone = math.sin(phase)
		if name in NOISY:
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
	# towers: distinct voices — turret cracks high, resonator thuds low+wide,
	# tangle chirps soft mid (fires rarely, so a bit longer reads fine)
	("turret_shot", 0.05, 820, 420, 0.20),
	("resonator_pulse", 0.26, 220, 88, 0.30),
	("tangle_cast", 0.22, 520, 240, 0.20),
	("hit", 0.1, 340, 120, 0.26),
	("leak", 0.34, 460, 180, 0.24),
	("breach", 0.4, 150, 40, 0.3),
	("wave_horn", 0.5, 140, 190, 0.26),
	("build", 0.3, 380, 760, 0.22),
	("upgrade", 0.42, 440, 1320, 0.24),
	("sell", 0.25, 700, 260, 0.2),
):
	synthesize(*spec)


def synthesize_ambient_loop() -> None:
	duration = 16.0
	count = int(RATE * duration)
	samples = bytearray()
	# Shelter-09 beacon drone: darker and slower than the 2D loop (night siege mood).
	for index in range(count):
		t = index / RATE
		swell = 0.55 + 0.45 * math.sin(2 * math.pi * t / duration - math.pi / 2)
		tone = (
			0.5 * math.sin(2 * math.pi * 48.0 * t)
			+ 0.22 * math.sin(2 * math.pi * 72.0 * t)
			+ 0.16 * math.sin(2 * math.pi * 96.0 * t)
			+ 0.08 * math.sin(2 * math.pi * 144.0 * t)
		)
		sample = int(max(-1.0, min(1.0, tone * swell * 0.10)) * 32767)
		samples.extend(struct.pack("<h", sample))

	MUSIC_OUTPUT.mkdir(parents=True, exist_ok=True)
	with wave.open(str(MUSIC_OUTPUT / "beacon_ambient_3d.wav"), "wb") as audio:
		audio.setnchannels(1)
		audio.setsampwidth(2)
		audio.setframerate(RATE)
		audio.writeframes(samples)


synthesize_ambient_loop()
print("LAST LIGHT 3D SFX + ambient generated.")
