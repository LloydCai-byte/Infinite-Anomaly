"""Original, deterministic low-volume electric-piano loop and timer chime."""
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "continuity" / "audio"
RATE = 22050
rng = np.random.default_rng(927)
duration = 48.0
mix = np.zeros((int(duration * RATE), 2), dtype=np.float64)

def note(start, midi, length, gain, pan=0.0):
    t = np.arange(int(length * RATE)) / RATE
    f = 440 * 2 ** ((midi - 69) / 12)
    env = (1 - np.exp(-t * 70)) * np.exp(-t * 1.6)
    env *= np.minimum(1, (length - t) * 15)
    signal = (np.sin(2 * np.pi * f * t) + .22 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 3)) * env * gain
    for delay, level in [(0, 1), (.19, .15), (.37, .07)]:
        index = (np.arange(len(t)) + int((start + delay) * RATE)) % len(mix)
        mix[index, 0] += signal * level * (1 - pan * .3)
        mix[index, 1] += signal * level * (1 + pan * .3)

chords = [(48, 55, 59, 62), (45, 52, 55, 59), (41, 48, 52, 57), (43, 50, 53, 57)]
melodies = [(72, 71, 67), (71, 67, 64), (69, 67, 64), (65, 67, 62)]
for bar in range(16):
    start = bar * 3.0
    chord = chords[bar % 4]
    for i, n in enumerate(chord):
        note(start + i * .032, n, 3.2, .11 if i == 0 else .055, (i - 1.5) / 2)
    for beat, n in zip([.75, 1.875, 2.625], melodies[bar % 4]):
        note(start + beat, n, 1.3, .057, .35)
    for beat in [0, .75, 1.5, 2.25]:
        t = np.arange(int(.12 * RATE)) / RATE
        brush = rng.standard_normal(len(t)) * np.exp(-t * 65) * .008
        idx = (np.arange(len(t)) + int((start + beat) * RATE)) % len(mix)
        mix[idx] += brush[:, None]

def save(path, samples):
    samples = np.clip(samples, -1, 1)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(samples.shape[1])
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes((samples * 32767).astype("<i2").tobytes())

OUT.mkdir(parents=True, exist_ok=True)
save(OUT / "quiet-room.wav", mix * (.6 / max(.6, np.abs(mix).max())))
t = np.arange(int(1.8 * RATE)) / RATE
bell = (np.sin(2 * np.pi * 660 * t) + .35 * np.sin(2 * np.pi * 880 * t)) * (1 - np.exp(-t * 180)) * np.exp(-t * 3.6) * .3
save(OUT / "bell.wav", np.column_stack([bell, bell]))
print(f"STAGE2_AUDIO 48s loop; peak={np.abs(mix).max():.3f}; original synthesis")
