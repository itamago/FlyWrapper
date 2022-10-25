@rem ---------------------------------------------------------------------------------
@rem  Copyright (C)Nintendo All rights reserved.
@rem  
@rem  These coded instructions, statements, and computer programs contain proprietary
@rem  information of Nintendo and/or its licensed developers and are protected by
@rem  national and international copyright laws. They may not be disclosed to third
@rem  parties or copied or duplicated in any form, in whole or in part, without the
@rem  prior written consent of Nintendo.
@rem  
@rem  The content herein is highly confidential and should be handled accordingly.
@rem ---------------------------------------------------------------------------------


@rem Helper batch script that generates a Visual Studio solution.
@rem Two operation modes are available: interactive or automated.
@rem To use the automated mode, simply pass as command line arguments the
@rem Visual Studio version and platform to target. such as "GenSolution.cmd VS2010 Cafe".

@echo off
setlocal EnableDelayedExpansion

:: List of the supported VS versions
set "VS_YEAR_LIST=2019 2022"

:: Fully qualified path to the folder this batch file is in
set "HERE=%~dp0"
set "HERE=%HERE:~0,-1%"

:: Path to the folder containing the root CMakeLists.txt file
set "SOURCE_DIR=%HERE%"

:: Folders for generated files
set "BUILD_DIR=%HERE%\build"
set "LIB_DIR=%HERE%\lib"
set "EXE_DIR=%HERE%\bin"
set "DLL_DIR=%HERE%\bin"

:: Find CMake
if exist "%HERE%\external\CMake\bin\cmake.exe" (
	set "CMAKE=%HERE%\external\CMake\bin\cmake.exe"
) else (
	set CMAKE=cmake
)

:: Init variables
set CMAKE_OPTIONS=
set ASKPAUSE=0
set AUTOMATED=0

:: Just in case we run on a 32-bit Windows
if not exist "%ProgramFiles(x86)%" set "%ProgramFiles(x86)%=%ProgramFiles%"


:: ============================================================================
:: Parse arguments

if "%~1"=="--help" (
	echo Usage:
	echo   %~n0 version platform [--build:config] [--target:target]
	echo.
	echo Where:
	echo   version     The Visual Studio version: VS2019 or VS2022.
	echo   platform    The platform to target: Win64.
	echo   config      The configuration to build ^(typically, Debug or Release^).
	exit /b 0
)

if not "%~1"=="" (
	if not "%~2"=="" (
		set AUTOMATED=1
		set VERSION=%~1
		set PLATFORM=%~2
		shift
		shift
	) else (
		echo Two arguments expected, got only one >&2
		exit /b 1
	)
)

set BUILD_CONFIG=
set BUILD_TARGET=
:ParseOptions
set ARG=%~1
set ARG8=%ARG:~0,8%
set ARG9=%ARG:~0,9%
if "%ARG8%"=="--build:" (
	set BUILD_CONFIG=%ARG:--build:=%
) else if "%ARG9%"=="--target:" (
	set BUILD_TARGET=--target %ARG:--target:=%
) else if "%ARG%"=="--cpp11" (
	set CORE_ENABLE_CPP11=1
) else if not "%ARG%"=="" (
	set CMAKE_OPTIONS=%CMAKE_OPTIONS% "%ARG%"
) else (
	goto DoneParsingOptions
)
shift
goto ParseOptions
:DoneParsingOptions


:: ============================================================================
:: Choose VS version

:ChooseVersion
set HAVE_WIN32=1
set HAVE_WIN64=1
set HAVE_WINRT=0

if not %AUTOMATED%==0 goto %VERSION%

:: Ask which version
set NUM=1
for %%y in (%VS_YEAR_LIST%) do (
	set VS%%y_NUM=!NUM!
	set /a NUM=!NUM!+1
)
:AskVersion
echo Which version of Visual Studio do you want to generate a solution for?
for %%y in (%VS_YEAR_LIST%) do (
	echo !VS%%y_NUM! - Visual Studio %%y
)
set /p VERSION=
for %%y in (%VS_YEAR_LIST%) do (
	if %VERSION% equ !VS%%y_NUM! (
		goto VS%%y
	)
)
echo.
goto AskVersion

:: Handle the different versions

:VS2019
call :CheckVsYear 2019 || goto Error
set VS_YEAR=2019
set VS_VERSION=16
set HAVE_WINRT=1
goto Generate

:VS2022
call :CheckVsYear 2022 || goto Error
set VS_YEAR=2022
set VS_VERSION=17
set HAVE_WINRT=1
goto Generate



:: ============================================================================
:: Generate solution

:: Check if a solution already exists
:Generate
set GENERATOR=Visual Studio %VS_VERSION% %VS_YEAR%
set FOLDER=windows-x64-msvc%VS_YEAR%-vs%VS_YEAR%

if not %AUTOMATED%==0               goto CallCMake
if not exist "%BUILD_DIR%\%FOLDER%" goto CallCMake
:AskDelete
echo.
echo A solution already exists, do you want to delete it? (y/n^)
set /p SUPPRESS=
if "%SUPPRESS%"=="y" (rmdir /s /q "%BUILD_DIR%\%FOLDER%" && goto CallCMake)
if "%SUPPRESS%"=="n" goto CallCMake
echo.
goto AskDelete

:: Actually generate the solution (and optionally build it)
:CallCMake
echo.
if not exist "%BUILD_DIR%\%FOLDER%" mkdir "%BUILD_DIR%\%FOLDER%"
pushd "%BUILD_DIR%\%FOLDER%"
set CMAKE_CMD_LINE="%CMAKE%" -G "%GENERATOR%" "-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY=%LIB_DIR%\%FOLDER%" "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY=%EXE_DIR%\%FOLDER%" "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=%DLL_DIR%\%FOLDER%"  "-DCMAKE_INSTALL_PREFIX=%HERE%\deliverables" %CMAKE_OPTIONS% "%SOURCE_DIR%"
echo Calling CMake as follows:
echo %CMAKE_CMD_LINE%
echo.
%CMAKE_CMD_LINE% || goto Error
popd
:AskOpen
if %AUTOMATED%==0 (
	echo.
	echo The Solution has been generated in "%BUILD_DIR%\%FOLDER%"
	echo Do you want to open it?
	set /p OPEN=
	if "!OPEN!"=="n" exit /b 0
	if "!OPEN!"=="y" (
		for %%f in ("%BUILD_DIR%\%FOLDER%\*.sln") do (
			start "" "%%~ff"
			exit /b 0
		)
	)
	goto AskOpen
)
:Build
if "%BUILD_CONFIG%"=="" goto End
set PLATFORM=
set CMAKE_CMD_LINE="%CMAKE%" --build "%BUILD_DIR%\%FOLDER%" --config %BUILD_CONFIG% %BUILD_TARGET% --clean-first --use-stderr || goto Error
echo.
echo.
echo Calling CMake as follows:
echo %CMAKE_CMD_LINE%
%CMAKE_CMD_LINE%

:End
exit /b 0

:Error
popd
if %AUTOMATED%==0 (
	echo.
	pause
)
exit /b 1

:CheckVsYear
for %%y in (%VS_YEAR_LIST%) do (
	if "%1"=="%%y" (
		exit /b 0
	)
)
echo Unsupported VS version: %1 >&2
exit /b 1

