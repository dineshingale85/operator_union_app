# Operator Union Flutter App

A Flutter application with splash screen that automatically navigates to a WebView after 4 seconds.

## Features

- **Splash Screen**: Displays app logo for exactly 4 seconds
- **WebView Integration**: Opens https://testdemo.co.in/login in full-screen WebView
- **Navigation Controls**: Back button support with WebView history
- **Smooth Transitions**: Fade animation between splash and WebView
- **Cross-Platform**: Supports Android and iOS

## Setup Instructions

### 1. Add Logo Image
Place your app logo as `assets/logo.png` (200x200 pixels recommended).

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run the App
```bash
flutter run
```

## Dependencies

- `webview_flutter: ^4.8.0` - WebView support
- `cupertino_icons: ^1.0.8` - iOS-style icons

## App Behavior

1. **Splash Screen (4 seconds)**:
   - Shows centered logo on white background
   - Displays "Operator Union" title and "Loading..." text
   - Automatically navigates after exactly 4 seconds

2. **WebView Screen**:
   - Loads https://testdemo.co.in/login
   - JavaScript enabled
   - Back button navigates WebView history
   - Device back button: WebView back or exit app
   - Refresh button available
   - Loading indicator during page loads

## Platform Configuration

### Android
- Internet permissions added to AndroidManifest.xml
- Hardware acceleration enabled

### iOS
- Network security configuration for web content
- Optional permissions for camera, microphone, photo library (for WebView features)

## File Structure

```
lib/
├── main.dart                 # Main app with splash screen and WebView
assets/
├── logo.png                  # App logo (you need to add this)
├── README.md                 # Asset information
android/
├── app/src/main/AndroidManifest.xml  # Android permissions
ios/
├── Runner/Info.plist         # iOS configuration
```

## Customization

- Change splash duration: Modify `Duration(seconds: 4)` in SplashScreen
- Change WebView URL: Update URL in WebViewScreen
- Modify app theme: Update MaterialApp theme in OperatorUnionApp
- Add loading animations: Customize loading indicators in WebViewScreen

## Notes

- The app is designed to feel like a native app wrapper for the PWA
- WebView includes error handling and loading states
- Graceful fallback if logo image doesn't exist
- Exit confirmation dialog when at first page