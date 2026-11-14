@echo off
rem Rebuilds the kit on Python 3.11 with the graphics-card PyTorch (Chatterbox needs PyTorch 2.6, which needs Python 3.11).
rem The voice model already downloaded is kept (it lives in your user folder, not here).
cd /d "%~dp0"
echo ---- Installing Python 3.11 (answer Y if it asks)
py install 3.11
echo ---- Removing the old setup (Python 3.15, no graphics card)
if exist venv rmdir /s /q venv
py -V:3.11 -m venv venv || py -3.11 -m venv venv
if not exist venv\Scripts\activate.bat (
  echo Python 3.11 was not found. Send Claude a screenshot of this window.
  pause
  exit /b 1
)
call venv\Scripts\activate
python --version
python -m pip install --upgrade pip
pip install torch==2.6.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124
pip install chatterbox-tts
echo ---- Check:
python -c "import torch; print('torch', torch.__version__, '| card found:', torch.cuda.is_available(), '|', torch.cuda.get_device_name(0) if torch.cuda.is_available() else '')"
echo.
echo If it says  card found: True  , double-click run.bat
pause
