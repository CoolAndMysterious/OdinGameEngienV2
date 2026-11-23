
@echo off
setlocal

:: Find the engine root directory.
set "ROOT=%~dp0"

:: Shader source and output directories.
set "SHADER_DIR=%ROOT%Shared\Shaders"
set "OUTPUT_DIR=%ROOT%Shared\Shaders\Compiled"

:: Create output directory if it doesn't exist.
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: Check that glslc is installed.
where glslc >nul 2>&1

if errorlevel 1 (
    echo ERROR: glslc was not found.
    exit /b 1
)

echo.
echo Compiling GLSL shaders...
echo.

:: Compile vertex, fragment and compute shaders.
for %%E in (vert frag comp) do (
    for %%S in ("%SHADER_DIR%\*.%%E") do (
        if exist "%%~fS" (
            echo Compiling: %%~nxS

            glslc --target-env=vulkan1.3 ^
                "%%~fS" ^
                -o "%OUTPUT_DIR%\%%~nxS.spv"

            if errorlevel 1 (
                echo ERROR: Failed to compile %%~nxS
                exit /b 1
            )
        )
    )
)

echo.
echo All shaders compiled successfully!

exit /b 0
