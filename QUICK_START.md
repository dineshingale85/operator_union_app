# Quick Start Guide

## Before Running the App

1. **Add Your Logo**:
   - Place your app logo as `assets/logo.png`
   - Recommended size: 200x200 pixels
   - If no logo is provided, a fallback icon will be shown

2. **Run the App**:
   ```bash
   flutter pub get
   flutter run
   ```

## App Flow

1. **Splash Screen** (4 seconds): Shows logo and app name
2. **WebView**: Opens https://testdemo.co.in/login automatically
3. **Navigation**: Use back button to navigate or exit

## Development Notes

- Change URL: Edit the URL in `lib/main.dart` line 189
- Change splash duration: Edit `Duration(seconds: 4)` in line 60
- Customize theme: Modify the MaterialApp theme

## Troubleshooting

- If WebView doesn't load: Check internet connection
- If logo doesn't show: Ensure `assets/logo.png` exists
- Build errors: Run `flutter clean && flutter pub get`