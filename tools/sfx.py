"""Generate Velokity's original PCM sound effects and music."""

from array import array
from io import BytesIO
from math import copysign, exp, pi, sin, sqrt, tau
from pathlib import Path
import struct
import sys
import wave

RATE = 24_000
PEAK = 10 ** (-1 / 20)
MUSIC_RMS = 10 ** (-16 / 20)
LIMITER_KNEE = 0.65
OUTPUT = Path(__file__).resolve().parents[1] / "audio"

# Cue = start time, length, MIDI note, gain, and ending pitch shift in semitones.
EFFECTS = {
    "fill": [(0, .105, 72, .30, 4)],
    "cross": [(0, .095, 65, .24, -3)],
    "mistake": [(0, .19, 57, .26, -4), (.063, .15, 52, .13, -2)],
    "line": [(0, .15, 72, .24, 0), (.073, .19, 76, .23, 0)],
    "combo": [(0, .16, 69, .23, 0), (.07, .20, 73, .22, 0), (.14, .24, 81, .24, 0)],
    "win": [(0, .28, 69, .22, 0), (.09, .28, 74, .21, 0), (.19, .34, 78, .22, 0),
            (.28, .44, 81, .21, 0)],
    "coin": [(0, .135, 79, .18, 0), (.07, .21, 86, .19, 0)],
    "button": [(0, .085, 69, .19, -3)],
    "celebration": [(0, .28, 74, .22, 0), (.10, .31, 78, .19, 0),
                    (.21, .33, 81, .23, 0), (.31, .56, 85, .23, 0), (.43, .55, 90, .16, 0)],
}

# Four bars per loop. The melody includes soft pickups with tails into the next bar.
MUSIC = {
    "menu": {
        "bpm": 84,
        "chords": [(50, 57, 61, 66), (47, 54, 57, 62), (43, 50, 54, 59), (45, 52, 57, 59)],
        "motifs": [(66, 69, 73, 76), (74, 69, 66, 62), (67, 71, 74, 78), (76, 73, 69, 64)],
        "beats": (.35, 1.43, 2.45, 3.48),
    },
    "puzzle": {
        "bpm": 96,
        "chords": [(40, 47, 55, 62), (48, 55, 59, 64), (43, 50, 55, 64), (50, 57, 62, 69)],
        "motifs": [(67, 71, 76, 74), (72, 67, 64, 71), (69, 74, 76, 79), (76, 74, 69, 66)],
        "beats": (0, 1.5, 2.25, 3.55),
    },
}


def add_note(buffer, start, length, midi, gain, glide=0, *, pad=False):
    first_sample = round(start * RATE)
    samples = max(1, round(length * RATE))
    frequency = 440 * 2 ** ((midi - 69) / 12)
    frequency_change = frequency * (2 ** (glide / 12) - 1)
    attack = .22 if pad else .012
    release = length * (.58 if pad else .29)
    for index in range(samples):
        time = index / RATE
        fade_in = sin(min(time / attack, 1) * pi / 2) ** 2
        fade_out = sin(min((length - time) / release, 1) * pi / 2) ** 2
        phase = tau * time * (frequency + frequency_change * time / (2 * length))
        tone = .80 * sin(phase) + .15 * sin(phase * 2) + .05 * sin(phase * 3)
        decay = 1 if pad else exp(-2.7 * time / length)
        buffer[(first_sample + index) % len(buffer)] += gain * fade_in * fade_out * decay * tone


def render_effect(notes):
    duration = max(start + length for start, length, *_ in notes) + .02
    output = [0.0] * round(duration * RATE)
    for note in notes:
        add_note(output, *note)
    return output


def render_music(score):
    beat = 60 / score["bpm"]
    output = [0.0] * round(16 * beat * RATE)
    for bar, (chord, motif) in enumerate(zip(score["chords"], score["motifs"])):
        start = bar * 4
        for note in chord:
            add_note(output, (start + .05) * beat, 4.55 * beat, note, .049, pad=True)
        for offset, note, gain in zip(score["beats"], motif, (.095, .074, .083, .061)):
            add_note(output, (start + offset) * beat, 1.65 * beat, note, gain)
        add_note(output, (start + 2) * beat, 1.3 * beat, chord[0] + 12, .067)
    return output


def soft_limit(value):
    magnitude = abs(value)
    if magnitude <= LIMITER_KNEE:
        return value
    headroom = PEAK - LIMITER_KNEE
    limited = PEAK - headroom * exp(-(magnitude - LIMITER_KNEE) / headroom)
    return copysign(limited, value)


def rms(samples):
    return sqrt(sum(sample ** 2 for sample in samples) / len(samples))


def loud_music(samples):
    gain = MUSIC_RMS / rms(samples)
    for _ in range(6):
        limited = [soft_limit(sample * gain) for sample in samples]
        measured = rms(limited)
        if abs(measured - MUSIC_RMS) < 0.00001:
            return limited
        gain *= MUSIC_RMS / measured
    return limited


def wave_bytes(samples, loop=False):
    if loop:
        samples = loud_music(samples)
    else:
        gain = PEAK / max(map(abs, samples))
        samples = (sample * gain for sample in samples)
    ceiling = int(PEAK * 32767)
    pcm = array("h", (max(-ceiling, min(ceiling, round(value * 32767))) for value in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    stream = BytesIO()
    with wave.open(stream, "wb") as wav:
        wav.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        wav.writeframes(pcm.tobytes())
    content = stream.getvalue()
    if loop:
        # RIFF sampler chunk. One forward loop spans the PCM data.
        fields = struct.pack("<15I", 0, 0, round(1e9 / RATE), 60, 0, 0, 0, 1, 0,
                             0, 0, 0, len(pcm) - 1, 0, 0)
        body = content[8:36] + b"smpl" + struct.pack("<I", len(fields)) + fields + content[36:]
        content = b"RIFF" + struct.pack("<I", len(body)) + body
    return content


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, notes in EFFECTS.items():
        (OUTPUT / f"{name}.wav").write_bytes(wave_bytes(render_effect(notes)))
    for name, score in MUSIC.items():
        (OUTPUT / f"music_{name}.wav").write_bytes(wave_bytes(render_music(score), loop=True))
    size = sum(path.stat().st_size for path in OUTPUT.glob("*.wav"))
    print(f"Audio: {size:,} bytes ({len(EFFECTS)} effects and {len(MUSIC)} loops)")


if __name__ == "__main__":
    main()
