@echo off
cd /d "%~dp0"
call venv\Scripts\activate
python clone_lines.py %*
pause
