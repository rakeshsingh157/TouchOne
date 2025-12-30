# 🚀 TouchOne Auto-Update System - Setup Guide

## 📌 Overview
Your app can now check for updates, download new APK, and prompt users to install - all automatically!

---

## 🔧 STEP 1: Setup GitHub Repository

### Option A: GitHub Releases (Recommended)

1. **Create GitHub Repository**
   ```bash
   # If not already done
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/YOUR_USERNAME/TouchOne.git
   git push -u origin main
   ```

2. **Upload version.json to your repo**
   - Copy `version.json` to your repository root
   - Commit and push:
   ```bash
   git add version.json
   git commit -m "Add version.json for auto-update"
   git push
   ```

3. **Create a Release**
   - Go to: `https://github.com/YOUR_USERNAME/YOUR_REPO/releases`
   - Click "Create a new release"
   - Tag version: `v1.0.1`
   - Upload your APK file: `app-release.apk`
   - Rename it to: `TouchOne-v1.0.1.apk`
   - Publish release

4. **Update version.json**
   ```json
   {
     "version": "1.0.1",
     "download_url": "https://github.com/YOUR_USERNAME/TouchOne/releases/download/v1.0.1/TouchOne-v1.0.1.apk",
     "changelog": "Your update notes here"
   }
   ```

5. **Get Raw URL for version.json**
   - URL format: `https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/version.json`

---

### Option B: Use Your Own Server

1. **Host Files on Server**
   - Upload `version.json` to your server
   - Upload APK file to your server

2. **Update URLs**
   ```json
   {
     "version": "1.0.1",
     "download_url": "https://yourserver.com/downloads/TouchOne-v1.0.1.apk",
     "changelog": "Your updates"
   }
   ```

---

## 🔧 STEP 2: Update Code with Your URLs

Open `lib/main.dart` and find `UpdateManager` class:

```dart
// Line ~148
static const String versionUrl = 'YOUR_VERSION_JSON_URL_HERE';
```

**Replace with your actual URL:**
```dart
// For GitHub:
static const String versionUrl = 'https://raw.githubusercontent.com/kumarpatelrakesh/TouchOne/main/version.json';

// For custom server:
static const String versionUrl = 'https://yourserver.com/version.json';
```

---

## 🔧 STEP 3: Update App Version

In `pubspec.yaml`:
```yaml
version: 1.0.0+1  # Change this when you release updates
```

Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`
- Example: `1.0.1+2` (version 1.0.1, build 2)

---

## 🔧 STEP 4: Build & Release Process

### For New Updates:

1. **Update version in pubspec.yaml**
   ```yaml
   version: 1.0.1+2
   ```

2. **Build new APK**
   ```bash
   flutter build apk --release
   ```

3. **Upload to GitHub Release**
   - Create new release with tag `v1.0.1`
   - Upload APK from: `build/app/outputs/flutter-apk/app-release.apk`
   - Rename to: `TouchOne-v1.0.1.apk`

4. **Update version.json**
   ```json
   {
     "version": "1.0.1",
     "download_url": "https://github.com/YOUR_USERNAME/TouchOne/releases/download/v1.0.1/TouchOne-v1.0.1.apk",
     "changelog": "✨ New features\n🐛 Bug fixes"
   }
   ```

5. **Push version.json to repo**
   ```bash
   git add version.json
   git commit -m "Update to v1.0.1"
   git push
   ```

---

## 📱 How It Works

1. **App Startup**: Automatically checks for updates after 2 seconds
2. **Version Check**: Compares current version with `version.json`
3. **Update Dialog**: Shows beautiful dialog if update available
4. **Download**: Downloads APK with progress bar
5. **Install**: Opens Android installer for user to install

---

## ⚙️ Customization

### Change Update Check Timing

In `lib/main.dart`, `_NfcHomePageState.initState()`:
```dart
Future<void> _checkForUpdates() async {
  await Future.delayed(const Duration(seconds: 2)); // Change this
  // ...
}
```

### Make Updates Mandatory

In `_showUpdateDialog()`:
```dart
showDialog(
  context: context,
  barrierDismissible: false, // Keep this false
  builder: (context) => UpdateDialog(updateInfo: updateInfo),
);
```

Then remove "LATER" button from UpdateDialog.

### Custom Changelog Format

Update `version.json`:
```json
{
  "version": "1.0.1",
  "download_url": "...",
  "changelog": "🎉 NEW:\n• Feature 1\n• Feature 2\n\n🐛 FIXED:\n• Bug 1\n• Bug 2"
}
```

---

## 🔒 Permissions Explained

Already added in AndroidManifest.xml:
- `INTERNET` - Download APK
- `WRITE_EXTERNAL_STORAGE` - Save APK file
- `REQUEST_INSTALL_PACKAGES` - Install APK

---

## 🧪 Testing

1. **Change version in version.json to higher version**
   ```json
   {
     "version": "2.0.0",
     "download_url": "...",
     "changelog": "Test update"
   }
   ```

2. **Restart app** - Update dialog should appear

3. **Click "UPDATE NOW"** - Should download and prompt install

---

## ❗ Troubleshooting

### Update Dialog Not Showing
- ✅ Check version.json URL is correct
- ✅ Verify version.json is publicly accessible
- ✅ Check internet connection
- ✅ Look at debug console for errors

### Download Fails
- ✅ Verify APK URL is direct download link
- ✅ Check file exists at URL
- ✅ Ensure HTTPS (not HTTP)

### Install Doesn't Open
- ✅ Check `REQUEST_INSTALL_PACKAGES` permission in manifest
- ✅ Verify APK file downloaded successfully
- ✅ Try manual install from Downloads folder

---

## 📝 version.json Template

```json
{
  "version": "1.0.1",
  "download_url": "https://github.com/USERNAME/REPO/releases/download/v1.0.1/TouchOne-v1.0.1.apk",
  "changelog": "🎉 What's New:\n• Amazing new features\n• Better performance\n\n🐛 Bug Fixes:\n• Fixed crash issues\n• Improved stability"
}
```

---

## 🎯 Quick Start Checklist

- [ ] Create GitHub repository
- [ ] Upload version.json to repo
- [ ] Create release with APK
- [ ] Update versionUrl in main.dart
- [ ] Build and test
- [ ] Push changes

---

## 📞 Support

For issues, check:
1. Console logs in app
2. Network requests in browser DevTools
3. GitHub release settings

**Your auto-update system is ready! 🚀**
