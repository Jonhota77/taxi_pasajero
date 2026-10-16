@echo off
cd /d "%~dp0"
echo ==========================================
echo  Subiendo cambios a GitHub...
echo ==========================================
git add .
git commit -m "Backup %date% %time%"
git push
echo ==========================================
echo  Listo.
echo ==========================================
pause
