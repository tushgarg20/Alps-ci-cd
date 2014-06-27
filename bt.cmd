@echo off

rem Unset any python related environment variables for the duration of this command
setlocal
set PYTHONHOME=
set PYTHONPATH=
set PYTHONSTARTUP=

rem Set python location
set PYDIR=%~dp0tools\python
set CURDIR=%CD%
pushd "%~dp0"

rem Parameter validation
if [%1]==[] goto Usage
rem If the script file doesn't exist, but script.py does, use that.

rem First try %dp0\<script>.py
set SCRIPT="%~dp0%1.py"
if exist %SCRIPT% goto Invoke

rem Next, try %CURDIR%\<script>.py
set SCRIPT="%CURDIR%\%1.py"
if exist %SCRIPT% goto Invoke

rem Next, try %CURDIR%\<script>
set SCRIPT="%CURDIR%\%1"
if exist %SCRIPT% goto Invoke

rem Next, just the arg as passed in
set SCRIPT="%1"
if exist %SCRIPT% goto Invoke

rem Finally, <script>.py as passed in
set SCRIPT="%1.py"
if exist %SCRIPT% goto Invoke

echo Error: Neither %1 nor %1.py exist, exiting. 
goto Usage

:Invoke
rem Funky for loop to put all args after script name (without stripping out ',' and ';') into %%j
rem Need to pass the string into a temp file to deal with " characters correctly.  It seems
rem that the "usebackq" option in the for loop irrevocably treats = characters as delimiters. Ugh.

rem First, Generate random file name until we find one that doesn't exist
:Again
set TmpName=.bt.%Random%.tmp
if EXIST %TmpName% goto Again

rem Populate tmp file with all args
echo %* > %TmpName%

rem Parse args from file
for /f "tokens=1,*" %%i in (%TmpName%) do set FULL_CMD="%PYDIR%\python" %SCRIPT% %%j

rem Remove tmp file
del %TmpName% > nul

rem Execute command
rem echo %FULL_CMD%
%FULL_CMD%
if ERRORLEVEL 1 (popd & exit /B %ERRORLEVEL%)
goto End

:Usage
echo Usage:
echo   %~n0 script [script_args]

:End
popd
