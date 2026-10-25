@echo off
rem Double-click to start the GILT Level Builder and open it in the browser.
title GILT Level Builder
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\level_builder.ps1" %*
if errorlevel 1 pause
