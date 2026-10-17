@echo off
chcp 65001 > nul
echo ===================================================
echo     KHOI DONG HE THONG NHAN DANG CAY TRONG (AI)
echo ===================================================
echo.

cd /d "%~dp0"

if not exist "venv\Scripts\python.exe" (
    echo [LOI] Chua tim thay moi truong venv!
    echo Vui long kiem tra thu muc venv.
    pause
    exit /b 1
)

echo Dang khoi dong Web App Streamlit...
echo Neu trinh duyet khong tu dong mo, vui long truy cap: http://localhost:8501
echo.

.\venv\Scripts\python.exe -m streamlit run app.py

pause
