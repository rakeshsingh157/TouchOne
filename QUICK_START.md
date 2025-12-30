# 🚀 TouchOne - Auto-Update Quick Start

## ⚡ Super Fast Setup (5 Minutes)

### Step 1: Run Setup Script

Open PowerShell in this folder and run:

```powershell
.\setup-github.ps1
```

This will:
- ✅ Initialize Git
- ✅ Configure GitHub remote
- ✅ Create version.json
- ✅ Prepare everything for push

### Step 2: Create GitHub Repository

1. Go to: https://github.com/new
2. Repository name: **TouchOne**
3. Make it **PUBLIC** ⚠️ (important!)
4. Click **Create repository**

### Step 3: Push Code

```powershell
git push -u origin main
```

### Step 4: Update Code

Open `lib/main.dart` and find line ~148.

Replace:
```dart
static const String versionUrl = 'https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/version.json';
```

With your actual GitHub username:
```dart
static const String versionUrl = 'https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/TouchOne/main/version.json';
```

### Step 5: Build and Release

```powershell
flutter build apk --release
```

APK will be at: `build\app\outputs\flutter-apk\app-release.apk`

### Step 6: Create First Release

1. Go to your repo → Releases → Create new release
2. Tag: `v1.0.0`
3. Title: `TouchOne v1.0.0`
4. Upload APK (rename to `TouchOne-v1.0.0.apk`)
5. Publish!

### Step 7: Final Push

```powershell
git add lib/main.dart
git commit -m "Update version URL"
git push
```

---

## ✅ Done! Your app now has auto-update!

Test by installing the APK from GitHub release.

---

## 🔄 For Future Updates

Just run:

```powershell
.\release-new-version.ps1
```

It will:
- Ask for new version number
- Update files automatically
- Build APK
- Guide you through creating GitHub release

---

## 📝 Quick Reference

| Action | Command |
|--------|---------|
| Setup GitHub | `.\setup-github.ps1` |
| New release | `.\release-new-version.ps1` |
| Build APK | `flutter build apk --release` |
| Check status | `git status` |
| Push changes | `git push` |

---

## 🆘 Troubleshooting

### "git is not recognized"
Install Git from: https://git-scm.com/download/win

### "Permission denied"
Run PowerShell as Administrator

### Update not showing in app
1. Check version.json URL in browser
2. Verify version number is higher
3. Check internet connection

---

## 📞 File Structure

```
nfc/
├── setup-github.ps1          ← Run this first
├── release-new-version.ps1   ← For updates
├── version.json              ← Auto-updated
├── SETUP_GITHUB.md          ← Detailed guide
├── UPDATE_SYSTEM_GUIDE.md   ← Technical docs
└── lib/main.dart            ← Update URL here
```

---

**That's it! You're ready to go! 🎉**
