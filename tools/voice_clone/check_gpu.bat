@echo off
cd /d "%~dp0"
call venv\Scripts\activate
echo ---- Python:
python --version
echo ---- PyTorch and the graphics card:
python -c "import torch; print('torch', torch.__version__, '| CUDA build:', torch.version.cuda, '| card found:', torch.cuda.is_available()); print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'no card seen by PyTorch')"
echo ---- NVIDIA driver:
nvidia-smi
pause
