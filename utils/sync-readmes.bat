@echo off
setlocal enabledelayedexpansion

:: Copies README files listed in readme-paths.txt into the project root.
:: Each line should be: <source_path> <output_filename>
:: Overwrites existing files in the project root.
::
:: Usage: utils\sync-readmes.bat

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%.."
set "PATHS_FILE=%SCRIPT_DIR%readme-paths.txt"

if not exist "%PATHS_FILE%" (
    echo Error: %PATHS_FILE% not found.
    echo Create it with one entry per line: ^<source_path^> ^<output_filename^>
    echo   T:\projects\Dogcraft-Chat\README.md Dogcraft-Chat.md
    echo   T:\projects\Dogcraft-Economy\README.md Dogcraft-Economy.md
    exit /b 1
)

set copied=0
set skipped=0

for /f "usebackq eol=# tokens=1,* delims= " %%A in ("%PATHS_FILE%") do (
    set "src="
    set "output="

    :: Rebuild: everything except the last token is the source path
    set "full=%%A %%B"

    :: Find the last space-separated token as output name
    set "remaining=%%B"

    if "!remaining!"=="" (
        echo SKIP: bad format -^> %%A
        echo       Expected: ^<source_path^> ^<output_filename^>
        set /a skipped+=1
    ) else (
        :: Walk tokens to find the last one
        set "prev="
        set "output="
        for %%T in (!remaining!) do (
            if not "!output!"=="" (
                if "!prev!"=="" (
                    set "prev=%%A"
                ) else (
                    set "prev=!prev! !output!"
                )
            )
            set "output=%%T"
        )

        if "!prev!"=="" (
            set "src=%%A"
        ) else (
            set "src=!prev!"
        )

        if not exist "!src!" (
            echo SKIP: !src! ^(file not found^)
            set /a skipped+=1
        ) else (
            copy /y "!src!" "%PROJECT_DIR%\!output!" >nul
            echo   OK: !output! ^<- !src!
            set /a copied+=1
        )
    )
)

echo.
echo Done. Copied !copied! file(s), skipped !skipped!.
