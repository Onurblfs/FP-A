@echo off
chcp 65001 >nul
setlocal EnableExtensions
title Adicionar SEGMENTO ao Consolidado.csv
cd /d "%~dp0"

set "PYTHON="
if exist "C:\ProgramData\anaconda3\python.exe" set "PYTHON=C:\ProgramData\anaconda3\python.exe"
if not defined PYTHON if exist "%USERPROFILE%\anaconda3\python.exe" set "PYTHON=%USERPROFILE%\anaconda3\python.exe"
if not defined PYTHON if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not defined PYTHON if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
if not defined PYTHON where python >nul 2>&1 && set "PYTHON=python"

if not defined PYTHON (
  echo [ERRO] Python 3.11 ou superior nao encontrado.
  pause
  exit /b 1
)

if not exist ".env" (
  copy /y ".env.example" ".env" >nul
  echo.
  echo O arquivo .env foi criado. Confira os caminhos e dados do Oracle.
  start /wait notepad ".env"
)

"%PYTHON%" -c "import pandas, openpyxl, oracledb" >nul 2>&1
if errorlevel 1 (
  echo Instalando as bibliotecas necessarias...
  "%PYTHON%" -m pip install -r requirements.txt
  if errorlevel 1 (
    echo [ERRO] Nao foi possivel instalar as bibliotecas.
    pause
    exit /b 1
  )
)

echo.
echo Consultando o DWH e adicionando SEGMENTO ao Consolidado.csv...
"%PYTHON%" adicionar_segmento.py
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo Arquivo atualizado com sucesso.
) else (
  echo Atualizacao finalizada com erro. Consulte as mensagens acima.
)
pause
exit /b %RC%
