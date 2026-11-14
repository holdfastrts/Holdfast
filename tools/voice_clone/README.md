# Voice cloning on your PC (Chatterbox)

Speaks new lines in the King's voice (or any voice from a 10-20 s sample) with Chatterbox by Resemble AI (MIT licence:
free, commercial use allowed; its output carries an inaudible watermark). Runs on the owner's Windows PC (this
project's cloud machines cannot download the model). king_ref.wav = king_line_02, king_ref_b.wav = king_line_04
(the owner's ElevenLabs King), 24 kHz mono.

1. Install Python 3.11 from python.org; in the installer tick "Add python.exe to PATH".
2. Copy this folder to the PC; double-click install.bat (once; downloads a few GB).
3. Write the lines in lines.txt ("name | text"), double-click run.bat: the files appear in out/.
   Options (run from a command window: run.bat --lang pt): --ref king_ref_b.wav, --lang pt / es, --exaggeration 0.7.
