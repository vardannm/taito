"""Generate small original arcade cues; no third-party recordings."""
import math
import struct
import wave
from pathlib import Path

root = Path(__file__).resolve().parent.parent / 'assets' / 'audio'
root.mkdir(parents=True, exist_ok=True)
for name, notes in {'target': [659.25, 987.77], 'miss': [196, 146.83], 'complete': [523.25, 659.25, 783.99, 1046.5]}.items():
    duration = len(notes) * .12 + .3
    frames = []
    for i in range(int(44100 * duration)):
        t = i / 44100
        value = 0
        for j, frequency in enumerate(notes):
            age = t - j * .12
            if age >= 0:
                envelope = min(1, age / .008) * math.exp(-age * 10)
                value += .22 * envelope * (math.sin(2 * math.pi * frequency * age) + .15 * math.sin(2 * math.pi * frequency * 2 * age))
        frames.append(struct.pack('<h', int(max(-1, min(1, value)) * 32767)))
    with wave.open(str(root / f'{name}.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(44100)
        f.writeframes(b''.join(frames))
