@echo off

:: This project needs Python 3.10 specifically because it ships a prebuilt DeepSpeed
:: wheel for Windows (wheels\deepspeed-0.16.1+unknown-cp310-cp310-win_amd64.whl).
:: The "cp310" in that filename means it ONLY installs on Python 3.10 - any other
:: version (3.9, 3.11, 3.12, ...) will fail later with a cryptic
:: "... is not a supported wheel on this platform." error from pip.
:: Rather than let that happen mid-install, we check for the "py" launcher and
:: Python 3.10 up front and bail out early with a clear message if it's missing.

setlocal enabledelayedexpansion

where py >nul 2>nul
if errorlevel 1 (
    echo ERROR: The Python launcher "py" was not found on PATH.
    echo This installer requires Python 3.10 ^(needed for the bundled DeepSpeed wheel^).
    echo Install Python 3.10 from https://www.python.org/downloads/release/python-31011/
    echo ^(tick "Add python.exe to PATH" and "py launcher" during install^), then re-run this script.
    exit /b 1
)

py -3.10 --version >nul 2>nul
if errorlevel 1 (
    echo ERROR: Python 3.10 was not found via the "py" launcher.
    echo This installer requires Python 3.10 specifically ^(needed for the bundled DeepSpeed wheel:
    echo wheels\deepspeed-0.16.1+unknown-cp310-cp310-win_amd64.whl - the "cp310" tag means it only
    echo installs on Python 3.10^).
    echo.
    echo Install Python 3.10 from https://www.python.org/downloads/release/python-31011/
    echo then re-run this script. Alternatively, run PyInst.ps1 in PowerShell, which will
    echo download and install Python 3.10 for you automatically.
    exit /b 1
)

set PYTHON_EXE=py -3.10

:: Set current directory
cd /d %~dp0

echo Starting installation process...

:: Create and activate virtual environment
echo Creating and activating virtual environment with Python 3.10...
%PYTHON_EXE% -m venv venv
call venv\Scripts\activate.bat

:: Sanity check: confirm the venv actually landed on 3.10 (belt and suspenders)
python -c "import sys; assert sys.version_info[:2] == (3, 10), f'venv is Python {sys.version_info[0]}.{sys.version_info[1]}, expected 3.10'"
if errorlevel 1 (
    echo ERROR: The virtual environment did not end up on Python 3.10. Aborting before
    echo installing torch/DeepSpeed to avoid a broken environment. Check your "py" launcher
    echo installation and try again.
    exit /b 1
)

:: Upgrade pip
echo Upgrading pip...
python -m pip install --upgrade pip

echo Installing torch (CUDA 12.1 build - adjust if your GPU/driver needs a different CUDA version)...
pip install torch==2.5.1+cu121 torchaudio==2.5.1+cu121 torchvision==0.20.1 --index-url https://download.pytorch.org/whl/cu121

echo Installing bundled DeepSpeed wheel (Python 3.10 / Windows / CUDA 12.1 build)...
pip install "%~dp0wheels\deepspeed-0.16.1+unknown-cp310-cp310-win_amd64.whl"
if errorlevel 1 (
    echo ERROR: DeepSpeed wheel install failed. Double check the active Python is 3.10 ^(run:
    echo   python --version
    echo ^) and that you are on 64-bit Windows.
    exit /b 1
)

echo Installing requirements...
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: pip install -r requirements.txt failed. See the pip output above for the
    echo specific package/version conflict.
    exit /b 1
)

:: Pin ctranslate2 to a version known compatible with faster-whisper/RealtimeSTT on this stack
:: (mirrors the same pin applied in the Dockerfile build).
echo Pinning ctranslate2 to a known-compatible version...
pip install "ctranslate2<4.5.0"

echo.
echo Installation complete. Python version in use:
python --version
echo To start the app: cd code ^&^& python server.py
cmd
