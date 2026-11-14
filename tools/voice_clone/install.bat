@echo off
rem Run once. Needs Python 3.11 (with the Python install manager: open a command window and type  py install 3.11 ).
cd /d "%~dp0"
py -V:3.11 -m venv venv 2>nul || py -3.11 -m venv venv 2>nul || python -m venv venv
call venv\Scripts\activate
python --version
python -m pip install --upgrade pip
rem PyTorch 2.6 built for NVIDIA graphics cards (Chatterbox needs exactly 2.6). Without an NVIDIA card it still works, on the processor.
pip install torch==2.6.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124
pip install chatterbox-tts
echo.
echo Installed. Now double-click run.bat
pause
