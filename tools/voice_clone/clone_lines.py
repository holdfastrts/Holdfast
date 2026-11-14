"""Speak new lines in a cloned voice with Chatterbox (Resemble AI, MIT licence), on your own PC.

  python clone_lines.py                          the King, lines.txt -> out/
  python clone_lines.py --ref king_ref_b.wav     the other King sample as the voice
  python clone_lines.py --lang pt                Portuguese (also es, fr, it, de...: the multilingual model)
  python clone_lines.py --exaggeration 0.7       more emotion (0.4 here: a calm old king; up to about 1.0)
  python clone_lines.py --cfg 0.2                 slower, more deliberate (0.3 here; 0.5 is Chatterbox's brisk default)
  python clone_lines.py --pitch -1.5              lower the voice 1.5 semitones after generating (0 = off)

lines.txt: one line each, "name | text", e.g.  king_06 | Rome did not fall in a day.
Each line becomes out/<name>.wav. The first run downloads the model (a few GB), later runs reuse it.
It uses the NVIDIA graphics card if there is one (fast), otherwise the processor (slow: about a minute a line)."""
import argparse
import os
import sys

import torch
import torchaudio as ta

HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument("--lines", default=os.path.join(HERE, "lines.txt"))
ap.add_argument("--ref", default=os.path.join(HERE, "king_ref.wav"))
ap.add_argument("--out", default=os.path.join(HERE, "out"))
ap.add_argument("--lang", default="en")
ap.add_argument("--exaggeration", type=float, default=0.4)
ap.add_argument("--cfg", type=float, default=0.3, help="pace/adherence (lower = slower, more deliberate)")
ap.add_argument("--pitch", type=float, default=0.0, help="semitones after generating (e.g. -1.5 = deeper)")
a = ap.parse_args()

device = "cuda" if torch.cuda.is_available() else "cpu"
print("Using", "the graphics card" if device == "cuda" else "the processor (slow)")
if a.lang == "en":
    from chatterbox.tts import ChatterboxTTS
    model = ChatterboxTTS.from_pretrained(device=device)
else:
    from chatterbox.mtl_tts import ChatterboxMultilingualTTS
    model = ChatterboxMultilingualTTS.from_pretrained(device=device)
ref = a.ref if os.path.isabs(a.ref) else os.path.join(HERE, a.ref)
os.makedirs(a.out, exist_ok=True)
lines = []
for raw in open(a.lines, encoding="utf-8"):
    raw = raw.strip()
    if raw and not raw.startswith("#") and "|" in raw:
        name, text = raw.split("|", 1)
        lines.append((name.strip(), text.strip()))
if not lines:
    sys.exit("lines.txt has no lines like:  king_06 | Your text here.")
for i, (name, text) in enumerate(lines, 1):
    print("[%d/%d] %s: %s" % (i, len(lines), name, text))
    kw = {"audio_prompt_path": ref, "exaggeration": a.exaggeration, "cfg_weight": a.cfg}
    if a.lang != "en":
        kw["language_id"] = a.lang
    wav = model.generate(text, **kw)
    if a.pitch != 0.0:
        import librosa
        y = librosa.effects.pitch_shift(wav.squeeze(0).cpu().numpy(), sr=model.sr, n_steps=a.pitch)
        wav = torch.from_numpy(y).unsqueeze(0)
    wav = wav / max(float(wav.abs().max()), 1e-6) * 0.89     # (levelled just under the ceiling: no clipping)
    ta.save(os.path.join(a.out, name + ".wav"), wav, model.sr)
print("Done: the files are in", a.out)
