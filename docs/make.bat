@ECHO OFF
REM Convenience launcher for the dart-yse documentation on Windows.
REM
REM Usage:
REM   make.bat html       full build: generate API RST + sphinx HTML
REM   make.bat api        only regenerate API RSTs
REM   make.bat sphinx     only rebuild Sphinx HTML
REM   make.bat serve      python http server on http://localhost:8000
REM   make.bat clean      delete build\ and source\api\_generated\

pushd %~dp0

if "%SPHINXBUILD%" == "" (
    set SPHINXBUILD=sphinx-build
)
if "%DART%" == "" (
    set DART=dart
)
set SOURCEDIR=source
set BUILDDIR=build

if "%1" == "" goto help
if "%1" == "help" goto help
if "%1" == "api" goto api
if "%1" == "sphinx" goto sphinx
if "%1" == "html" goto html
if "%1" == "serve" goto serve
if "%1" == "clean" goto clean
goto help

:api
pushd ..
%DART% run tool\emit_api_rst.dart --out docs\source\api\_generated
popd
goto end

:sphinx
%SPHINXBUILD% -b html "%SOURCEDIR%" "%BUILDDIR%\html"
goto end

:html
pushd ..
%DART% run tool\emit_api_rst.dart --out docs\source\api\_generated
popd
if errorlevel 1 goto end
%SPHINXBUILD% -b html "%SOURCEDIR%" "%BUILDDIR%\html"
goto end

:serve
echo Serving on http://localhost:8000 (Ctrl-C to stop)
pushd "%BUILDDIR%\html"
python -m http.server 8000
popd
goto end

:clean
if exist "%BUILDDIR%" rmdir /s /q "%BUILDDIR%"
if exist "%SOURCEDIR%\api\_generated" rmdir /s /q "%SOURCEDIR%\api\_generated"
if exist "%SOURCEDIR%\api\patcher_objects.rst" del /q "%SOURCEDIR%\api\patcher_objects.rst"
goto end

:help
echo Targets: html, api, sphinx, serve, clean
goto end

:end
popd
