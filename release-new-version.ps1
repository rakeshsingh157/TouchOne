# 🔄 Release New Version Script
# Use this when you want to release a new update

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  TouchOne - New Release Helper" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Get version
$currentVersion = (Get-Content pubspec.yaml | Select-String "^version:").ToString().Split(":")[1].Trim().Split("+")[0]
Write-Host "📌 Current version in pubspec.yaml: $currentVersion" -ForegroundColor Yellow
Write-Host ""

$newVersion = Read-Host "Enter new version (e.g., 1.0.1)"

if ([string]::IsNullOrWhiteSpace($newVersion)) {
    Write-Host "❌ Version is required!" -ForegroundColor Red
    exit
}

Write-Host ""
$changelog = Read-Host "Enter changelog (brief description)"

if ([string]::IsNullOrWhiteSpace($changelog)) {
    $changelog = "Bug fixes and improvements"
}

Write-Host ""
Write-Host "📋 Summary:" -ForegroundColor Cyan
Write-Host "  New version: $newVersion" -ForegroundColor White
Write-Host "  Changelog: $changelog" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "Continue? (Y/N)"
if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Host "❌ Cancelled." -ForegroundColor Red
    exit
}

# Get GitHub username from git remote
Write-Host ""
Write-Host "🔍 Detecting GitHub info..." -ForegroundColor Cyan

try {
    $remoteUrl = git config --get remote.origin.url
    if ($remoteUrl -match "github\.com[:/](.+?)/(.+?)\.git") {
        $username = $matches[1]
        $repoName = $matches[2]
        Write-Host "✅ Detected: $username/$repoName" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Could not detect GitHub info from remote" -ForegroundColor Yellow
        $username = Read-Host "Enter GitHub username"
        $repoName = Read-Host "Enter repository name"
    }
} catch {
    $username = Read-Host "Enter GitHub username"
    $repoName = Read-Host "Enter repository name"
}

# Update pubspec.yaml version
Write-Host ""
Write-Host "📝 Updating pubspec.yaml..." -ForegroundColor Cyan

$pubspecContent = Get-Content pubspec.yaml -Raw
$buildNumber = [int]($currentVersion.Split("+")[1]) + 1
$pubspecContent = $pubspecContent -replace "version: $currentVersion", "version: $newVersion+$buildNumber"
$pubspecContent | Out-File -FilePath pubspec.yaml -Encoding utf8 -NoNewline
Write-Host "✅ Updated to $newVersion+$buildNumber" -ForegroundColor Green

# Update version.json
Write-Host ""
Write-Host "📝 Updating version.json..." -ForegroundColor Cyan

$versionJson = @{
    version = $newVersion
    download_url = "https://github.com/$username/$repoName/releases/download/v$newVersion/$repoName-v$newVersion.apk"
    changelog = $changelog
} | ConvertTo-Json

$versionJson | Out-File -FilePath "version.json" -Encoding utf8
Write-Host "✅ version.json updated" -ForegroundColor Green

# Build APK
Write-Host ""
Write-Host "🔨 Building APK..." -ForegroundColor Cyan
Write-Host ""

flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ APK built successfully!" -ForegroundColor Green
    
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    $apkSize = (Get-Item $apkPath).Length / 1MB
    Write-Host "   Location: $apkPath" -ForegroundColor Gray
    Write-Host "   Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit
}

# Commit changes
Write-Host ""
Write-Host "💾 Committing changes..." -ForegroundColor Cyan

git add pubspec.yaml version.json
git commit -m "Release v$newVersion - $changelog"
Write-Host "✅ Changes committed" -ForegroundColor Green

# Push
Write-Host ""
$pushNow = Read-Host "Push to GitHub now? (Y/N)"

if ($pushNow -eq 'Y' -or $pushNow -eq 'y') {
    Write-Host ""
    Write-Host "⬆️  Pushing to GitHub..." -ForegroundColor Cyan
    git push
    Write-Host "✅ Pushed successfully" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  📋 NEXT STEPS" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1️⃣  Create GitHub Release:" -ForegroundColor White
Write-Host "   Go to: https://github.com/$username/$repoName/releases/new" -ForegroundColor Cyan
Write-Host ""
Write-Host "2️⃣  Fill in release details:" -ForegroundColor White
Write-Host "   Tag: v$newVersion" -ForegroundColor Gray
Write-Host "   Title: TouchOne v$newVersion" -ForegroundColor Gray
Write-Host "   Description: $changelog" -ForegroundColor Gray
Write-Host ""
Write-Host "3️⃣  Upload APK:" -ForegroundColor White
Write-Host "   File: $apkPath" -ForegroundColor Gray
Write-Host "   Rename to: $repoName-v$newVersion.apk" -ForegroundColor Gray
Write-Host ""
Write-Host "4️⃣  Publish the release" -ForegroundColor White
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "✅ Release preparation complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Open GitHub releases page
$openGithub = Read-Host "Open GitHub releases page in browser? (Y/N)"
if ($openGithub -eq 'Y' -or $openGithub -eq 'y') {
    Start-Process "https://github.com/$username/$repoName/releases/new"
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
