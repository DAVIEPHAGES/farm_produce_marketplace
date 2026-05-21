@echo off
echo Building APK...
flutter build apk --debug
echo.
echo Checking if APK was created...
if exist "android\app\build\outputs\flutter-apk\app-debug.apk" (
    echo ✅ APK found! Installing on phone...
    adb -s R58N70MALSK install -r android\app\build\outputs\flutter-apk\app-debug.apk
    echo ✅ Done! App updated.
) else (
    echo ❌ ERROR: APK not found! Build may have failed.
    echo Check the error messages above.
)
echo.
pause