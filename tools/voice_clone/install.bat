@echo off
rem Run once, after installing Python 3.11 (python.org, tick "Add python.exe to PATH").
cd /d "%~dp0"
python -m venv venv
call venv\Scripts\activate
python -m pip install --upgrade pip
rem The graphics-card build of PyTorch (NVIDIA). Without an NVIDIA card this still works, on the processor.
pip install torch==2.6.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124
pip install chatterbox-tts
echo.
echo Installed. Now double-click run.bat
pause
