@echo off
echo Cleaning up old files...
del /Q "build\windows\x64\firebase_cpp_sdk_windows_13.5.0.zip" 2>nul
rmdir /S /Q "build\windows\x64\extracted" 2>nul
mkdir "build\windows\x64\extracted"

echo Downloading Firebase C++ SDK...
curl -Lo "build\windows\x64\firebase_cpp_sdk_windows_13.5.0.zip" "https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_windows_13.5.0.zip"
if %errorlevel% neq 0 (
    echo Download failed!
    exit /b %errorlevel%
)

echo Extracting Firebase C++ SDK...
tar -xf "build\windows\x64\firebase_cpp_sdk_windows_13.5.0.zip" -C "build\windows\x64\extracted"
if %errorlevel% neq 0 (
    echo Extraction failed!
    exit /b %errorlevel%
)

echo Done!
