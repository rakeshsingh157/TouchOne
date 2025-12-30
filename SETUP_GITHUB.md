# 🚀 Complete GitHub Setup for TouchOne Auto-Update

## Step 1️⃣: Create GitHub Repository (1 minute)

### A. Go to GitHub
1. Open browser: https://github.com/new
2. Repository name: `TouchOne` (or any name you like)
3. Description: `NFC Data Transfer App with Auto-Update`
4. Keep it **Public** (important for raw file access)
5. ✅ Check "Add a README file"
6. Click **Create repository**

---

## Step 2️⃣: Push Your Code to GitHub (2 minutes)

### Open PowerShell in your project folder and run:

```powershell
# Navigate to project
cd "C:\Users\kumar\OneDrive\Desktop\nfc"

# Initialize git (if not already done)
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit - TouchOne NFC App with Auto-Update"

# Add your GitHub repository (REPLACE WITH YOUR USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/TouchOne.git

# Push to GitHub
git push -u origin main
```

**Note:** Replace `YOUR_USERNAME` with your actual GitHub username!

If you get an error about 'main' branch not existing, use:
```powershell
git branch -M main
git push -u origin main
```

---

## Step 3️⃣: Update the Code with Your GitHub URL

After pushing, update `lib/main.dart`:

1. Open `lib/main.dart`
2. Find line ~148 (in UpdateManager class)
3. Replace:
```dart
static const String versionUrl = 'https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/version.json';
```

**With your actual URL:**
```dart
static const String versionUrl = 'https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/TouchOne/main/version.json';
```

Example:
```dart
static const String versionUrl = 'https://raw.githubusercontent.com/kumarpatelrakesh/TouchOne/main/version.json';
```

---

## Step 4️⃣: Create Your First Release (3 minutes)

### A. Build the APK
```powershell
flutter build apk --release
```

### B. Create Release on GitHub
1. Go to: `https://github.com/YOUR_USERNAME/TouchOne/releases`
2. Click **"Create a new release"**
3. Fill in:
   - Tag version: `v1.0.0`
   - Release title: `TouchOne v1.0.0 - Initial Release`
   - Description: Copy-paste from below ⬇️

```markdown
## 🎉 TouchOne v1.0.0 - Initial Release

### ✨ Features
- 📱 NFC data transfer
- 📊 Transfer statistics
- 📜 Received data history
- 📋 Copy & Share functionality
- 🔄 Auto-update system

### 📦 Installation
Download and install the APK below.

### 🔒 Permissions Required
- NFC
- Internet (for updates)
- Contacts (for sharing contacts)
```

4. **Upload APK:**
   - Click "Attach binaries"
   - Select: `C:\Users\kumar\OneDrive\Desktop\nfc\build\app\outputs\flutter-apk\app-release.apk`
   - Rename to: `TouchOne-v1.0.0.apk`

5. Click **"Publish release"**

### C. Get the Download URL
After publishing, right-click on the APK file in the release and copy link address.

It should look like:
```
https://github.com/YOUR_USERNAME/TouchOne/releases/download/v1.0.0/TouchOne-v1.0.0.apk
```

---

## Step 5️⃣: Update version.json

1. Open `version.json` in your project
2. Update with your actual URLs:

```json
{
  "version": "1.0.0",
  "download_url": "https://github.com/YOUR_USERNAME/TouchOne/releases/download/v1.0.0/TouchOne-v1.0.0.apk",
  "changelog": "🎉 Initial Release\n\n✨ Features:\n• NFC data transfer\n• Transfer statistics\n• Received history\n• Copy & Share\n• Auto-update system"
}
```

3. Save and push:
```powershell
git add version.json
git commit -m "Add version.json for auto-update"
git push
```

---

## Step 6️⃣: Verify Setup

### A. Check version.json is accessible
Open in browser:
```
https://raw.githubusercontent.com/YOUR_USERNAME/TouchOne/main/version.json
```

You should see the JSON content!

### B. Test in app
1. Uninstall old app
2. Install the APK from GitHub release
3. Open app
4. No update dialog should appear (same version)

---

## 🔄 For Future Updates

### When you want to release v1.0.1:

1. **Update pubspec.yaml**
```yaml
version: 1.0.1+2
```

2. **Build new APK**
```powershell
flutter build apk --release
```

3. **Create new GitHub release**
   - Tag: `v1.0.1`
   - Upload new APK as `TouchOne-v1.0.1.apk`

4. **Update version.json**
```json
{
  "version": "1.0.1",
  "download_url": "https://github.com/YOUR_USERNAME/TouchOne/releases/download/v1.0.1/TouchOne-v1.0.1.apk",
  "changelog": "🎉 What's New:\n• New feature 1\n• Bug fixes"
}
```

5. **Push version.json**
```powershell
git add version.json
git commit -m "Update to v1.0.1"
git push
```

6. **Test**: Users with v1.0.0 will see update dialog!

---

## 📝 Quick Reference Commands

### Check git status
```powershell
git status
```

### Add and commit changes
```powershell
git add .
git commit -m "Your message here"
git push
```

### Build APK
```powershell
flutter build apk --release
```

### APK Location
```
C:\Users\kumar\OneDrive\Desktop\nfc\build\app\outputs\flutter-apk\app-release.apk
```

---

## ✅ Checklist

- [ ] GitHub repository created
- [ ] Code pushed to GitHub
- [ ] Updated versionUrl in main.dart
- [ ] First release created (v1.0.0)
- [ ] APK uploaded to release
- [ ] version.json updated with correct URL
- [ ] version.json pushed to GitHub
- [ ] Verified version.json URL in browser
- [ ] Tested app installation

---

## 🆘 Need Help?

### If you don't have Git installed:
Download from: https://git-scm.com/download/win

### If you're not logged into GitHub:
```powershell
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### If push is rejected:
```powershell
git pull origin main --rebase
git push
```

---

**You're all set! 🎉**

After completing these steps, your app will automatically check for updates from GitHub!
