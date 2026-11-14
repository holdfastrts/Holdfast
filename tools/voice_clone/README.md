# Voice cloning on your PC (Chatterbox)

Speaks new lines in the King's voice (or any voice from a 10-20 s sample) with Chatterbox by Resemble AI (MIT licence:
free, commercial use allowed; its output carries an inaudible watermark). Runs on the owner's Windows PC (this
project's cloud machines cannot download the model). king_ref.wav = king_line_02, king_ref_b.wav = king_line_04
(the owner's ElevenLabs King), 24 kHz mono.

1. Install Python 3.11: with the Python install manager (python-manager MSIX), open a command window and type  py install 3.11 .
2. Copy this folder to the PC; double-click install.bat (once; downloads a few GB).
3. Write the lines in lines.txt ("name | text"), double-click run.bat: the files appear in out/.
   Options (run from a command window: run.bat --lang pt): --ref king_ref_b.wav, --lang pt / es, --exaggeration 0.7.

## The campaign characters (refs/)

refs/ holds a Chatterbox reference (about 20 s, 24 kHz mono) for each new campaign character, spoken by a voice the
owner DESIGNED in ElevenLabs (Voice Design, 2026-11-14; no real person's voice). refs/README.txt says who is who:

| Reference | Character |
|---|---|
| refs/hollweg_ref.wav | Meister Hollweg, the clockmaker (Clockwork narrator) |
| refs/explorer_ref.wav | the Catholic explorer (Brood storyline) |
| refs/varenne_ref.wav | Etienne Varenne, rebel leader of the Free Assembly |
| refs/fairleigh_ref.wav | Lord Edmund Fairleigh, Governor of Virginia |
| refs/ruggieri_ref.wav | Captain Matteo Ruggieri, the guns |

Two ways to use one:

- One character for the whole file: `run.bat --ref refs/hollweg_ref.wav` (or `python clone_lines.py --ref
  refs/hollweg_ref.wav`); every line in lines.txt is spoken in that voice.
- Several characters in one run: in lines.txt a line `[ref refs/varenne_ref.wav]` switches the voice for the lines
  after it, until the next `[ref ...]` (before the first one the voice is `--ref`, the King). lines.txt has one
  section per character with a PLACEHOLDER line to try the voice; replace them with the real dialogue (or put `#` in
  front of the lines you do not want this time).

The other options work the same (`--lang pt`, `--exaggeration 0.7` for the fiery Varenne or the loud Ruggieri,
`--pitch`). The references are not game files: refs/ has a .gdignore so Godot does not import them.
