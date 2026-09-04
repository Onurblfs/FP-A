@echo off
chcp 65001 >nul
setlocal EnableExtensions
title Adicionar SEGMENTO ao Consolidado.csv
cd /d "%~dp0"

set "PYTHON="
set "CONDA_ACT="
if exist "C:\ProgramData\anaconda3\python.exe" (
  set "PYTHON=C:\ProgramData\anaconda3\python.exe"
  set "CONDA_ACT=C:\ProgramData\anaconda3\Scripts\activate.bat"
)
if not defined PYTHON if exist "%USERPROFILE%\anaconda3\python.exe" (
  set "PYTHON=%USERPROFILE%\anaconda3\python.exe"
  set "CONDA_ACT=%USERPROFILE%\anaconda3\Scripts\activate.bat"
)
if not defined PYTHON if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not defined PYTHON if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
if not defined PYTHON where python >nul 2>&1 && set "PYTHON=python"

if not defined PYTHON (
  echo [ERRO] Python 3.8 ou superior nao encontrado.
  pause
  exit /b 1
)

if defined CONDA_ACT if exist "%CONDA_ACT%" (
  echo Ativando o ambiente Anaconda...
  call "%CONDA_ACT%"
)

echo Python: %PYTHON%
"%PYTHON%" -c "import ssl" >nul 2>&1
if errorlevel 1 (
  echo.
  echo [ERRO] O Python encontrado nao consegue carregar o modulo SSL.
  echo Repare ou reinstale o Anaconda. O pip nao pode acessar a internet sem SSL.
  echo Python selecionado: %PYTHON%
  pause
  exit /b 1
)

if not exist ".env" (
  copy /y ".env.example" ".env" >nul
  echo.
  echo O arquivo .env foi criado. Confira os caminhos e dados do Oracle.
  start /wait notepad ".env"
)

"%PYTHON%" -c "import importlib.util as u, pandas, openpyxl, sys; sys.exit(0 if (u.find_spec('oracledb') or u.find_spec('cx_Oracle')) else 1)" >nul 2>&1
if errorlevel 1 (
  echo Instalando as bibliotecas necessarias...
  if defined CONDA_ACT (
    call conda install -y pandas openpyxl python-oracledb
  ) else (
    "%PYTHON%" -m pip install -r requirements.txt
  )
  if errorlevel 1 (
    echo [ERRO] Nao foi possivel instalar as bibliotecas.
    echo No Anaconda Prompt, execute:
    echo   conda install pandas openpyxl python-oracledb
    pause
    exit /b 1
  )
)

"%PYTHON%" -c "import importlib.util as u, pandas, openpyxl, sys; sys.exit(0 if (u.find_spec('oracledb') or u.find_spec('cx_Oracle')) else 1)" >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Ainda faltam pandas, openpyxl ou o driver Oracle.
  pause
  exit /b 1
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
