@echo off
setlocal EnableExtensions
rem ======================================================================
rem DARTY launcher. Double-click the Korean-named .cmd files next to this.
rem This file is ASCII only on purpose: cmd.exe reads batch files in the
rem system code page, so Korean text inside a .cmd file can break.
rem
rem Usage: darty_launch.cmd showcase ^| flow ^| game ^| editor ^| where
rem   showcase = art showcase  (art/showcase/showcase.tscn, Astra design)
rem   flow     = flow preview  (game/flow_preview/flow_preview.tscn, cards)
rem   game     = main game F5  (app/main.tscn, developer mode + 3 bots)
rem   editor   = open the project in the Godot editor
rem   where    = print which Godot and project folder will be used
rem Godot path: set the GODOT environment variable to override the search.
rem ======================================================================
set "TARGET=%~1"
if not defined TARGET set "TARGET=showcase"

rem --- 1. Godot project folder = the sub folder that contains project.godot
set "PROJECT_DIR="
for /d %%D in ("%~dp0*") do if exist "%%~fD\project.godot" set "PROJECT_DIR=%%~fD"
if not defined PROJECT_DIR goto :no_project

rem --- 2. Godot 4.6.3 executable
set "GODOT_EXE="
if defined GODOT if exist "%GODOT%" set "GODOT_EXE=%GODOT%"
for %%G in (
  "%USERPROFILE%\Desktop\Godot_v4.6.3-stable_win64.exe"
  "%USERPROFILE%\Desktop\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe"
  "%USERPROFILE%\Downloads\Godot_v4.6.3-stable_win64.exe"
  "%USERPROFILE%\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe"
  "%USERPROFILE%\OneDrive\Desktop\Godot_v4.6.3-stable_win64.exe"
  "C:\Users\Public\godot46\Godot_v4.6.3-stable_win64.exe"
) do if not defined GODOT_EXE if exist "%%~G" if not exist "%%~G\" set "GODOT_EXE=%%~G"
if not defined GODOT_EXE for /f "delims=" %%G in ('where Godot_v4.6.3-stable_win64.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%G"
if not defined GODOT_EXE goto :no_godot

rem --- 3. What to open
set "SCENE="
if /i "%TARGET%"=="showcase" set "SCENE=res://art/showcase/showcase.tscn"
if /i "%TARGET%"=="flow" set "SCENE=res://game/flow_preview/flow_preview.tscn"
if /i "%TARGET%"=="where" goto :where
if /i not "%TARGET%"=="showcase" if /i not "%TARGET%"=="flow" if /i not "%TARGET%"=="game" if /i not "%TARGET%"=="editor" goto :bad_target

pushd "%PROJECT_DIR%"
rem First run after cloning: import once so scripts and scenes resolve.
if not exist ".godot\uid_cache.bin" (
  echo [DARTY] First run: importing project files. Please wait...
  start "" /wait "%GODOT_EXE%" --headless --path . --import
)
if /i "%TARGET%"=="editor" (
  start "" "%GODOT_EXE%" --path . --editor
) else (
  start "" "%GODOT_EXE%" --path . %SCENE%
)
popd
exit /b 0

:where
echo Godot  : %GODOT_EXE%
echo Project: %PROJECT_DIR%
exit /b 0

:no_project
echo [DARTY] project.godot was not found in a folder next to this file.
pause
exit /b 1

:no_godot
echo [DARTY] Godot 4.6.3 was not found.
echo         Put Godot_v4.6.3-stable_win64.exe on your Desktop,
echo         or set the GODOT environment variable to its full path.
pause
exit /b 1

:bad_target
echo [DARTY] Unknown target "%TARGET%". Use: showcase, flow, game, editor, where
pause
exit /b 1
