from math import log10, sqrt
import struct
import unittest
import wave

from sfx import EFFECTS, MUSIC, OUTPUT, RATE


class AudioAssetsTest(unittest.TestCase):
    def test_pcm_cues_and_budget(self):
        names = set(EFFECTS) | {f"music_{name}" for name in MUSIC}
        files = {path.stem: path for path in OUTPUT.glob("*.wav")}
        self.assertEqual(set(files), names)
        self.assertLess(sum(path.stat().st_size for path in files.values()), 3_000_000)
        for name, path in files.items():
            with self.subTest(cue=name), wave.open(str(path), "rb") as wav:
                self.assertEqual((wav.getnchannels(), wav.getsampwidth(), wav.getframerate()), (1, 2, RATE))
                frames = wav.getnframes()
                pcm = struct.unpack(f"<{frames}h", wav.readframes(frames))
                peak = max(map(abs, pcm))
                peak_db = 20 * log10(peak / 32767)
                self.assertLessEqual(peak_db, -1.0)
                if name in EFFECTS:
                    self.assertAlmostEqual(peak_db, -1.0, delta=0.01)
                    self.assertLessEqual(frames, RATE)
                    self.assertEqual((pcm[0], pcm[-1]), (0, 0))
                else:
                    rms = sqrt(sum(sample ** 2 for sample in pcm) / frames)
                    self.assertAlmostEqual(20 * log10(rms / 32767), -16.0, delta=0.1)

    def test_music_seams_and_sampler_loops(self):
        for name in MUSIC:
            path = OUTPUT / f"music_{name}.wav"
            content = path.read_bytes()
            position = content.index(b"smpl")
            fields = struct.unpack_from("<15I", content, position + 8)
            with self.subTest(track=name), wave.open(str(path), "rb") as wav:
                frames = wav.getnframes()
                self.assertEqual((fields[7], fields[10], fields[11], fields[12]), (1, 0, 0, frames - 1))
                pcm = struct.unpack(f"<{frames}h", wav.readframes(frames))
                # The seam should be no steeper than the nearby waveform.
                steps = [abs(pcm[i] - pcm[i - 1]) for i in [*range(1, 49), *range(frames - 48, frames)]]
                self.assertLessEqual(abs(pcm[0] - pcm[-1]), max(steps))
