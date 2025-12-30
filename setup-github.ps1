# 🚀 Quick Setup Script for TouchOne Auto-Update
# Run this script to initialize Git and push to GitHub

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  TouchOne - GitHub Setup Automation" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Get GitHub username
$username = Read-Host "Enter your GitHub username"

if ([string]::IsNullOrWhiteSpace($username)) {
    Write-Host "❌ GitHub username is required!" -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "📝 Using GitHub username: $username" -ForegroundColor Green
Write-Host ""

# Repository name
$repoName = "TouchOne"

Write-Host "📦 Repository name will be: $repoName" -ForegroundColor Yellow
Write-Host ""

# Confirm
$confirm = Read-Host "Continue with setup? (Y/N)"
if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Host "❌ Setup cancelled." -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "🔧 Starting setup..." -ForegroundColor Cyan
Write-Host ""

# Check if git is installed
try {
    git --version | Out-Null
    Write-Host "✅ Git is installed" -ForegroundColor Green
} catch {
    Write-Host "❌ Git is not installed. Please install from: https://git-scm.com/download/win" -ForegroundColor Red
    exit
}

# Configure git if needed
Write-Host ""
Write-Host "🔧 Configuring Git..." -ForegroundColor Cyan
$gitName = git config --global user.name
if ([string]::IsNullOrWhiteSpace($gitName)) {
    $name = Read-Host "Enter your name for Git commits"
    git config --global user.name "$name"
}

$gitEmail = git config --global user.email
if ([string]::IsNullOrWhiteSpace($gitEmail)) {
    $email = Read-Host "Enter your email for Git commits"
    git config --global user.email "$email"
}

Write-Host "✅ Git configured" -ForegroundColor Green

# Initialize git repository
Write-Host ""
Write-Host "📦 Initializing Git repository..." -ForegroundColor Cyan

if (Test-Path .git) {
    Write-Host "⚠️  Git already initialized" -ForegroundColor Yellow
} else {
    git init
    Write-Host "✅ Git initialized" -ForegroundColor Green
}

# Create/Update version.json with actual URLs
Write-Host ""
Write-Host "📝 Updating version.json..." -ForegroundColor Cyan

$versionJson = @{
    version = "1.0.0"
    download_url = "https://github.com/$username/$repoName/releases/download/v1.0.0/$repoName-v1.0.0.apk"
    changelog = "🎉 Initial Release`n`n✨ Features:`n• NFC data transfer`n• Transfer statistics`n• Received history`n• Copy & Share`n• Auto-update system"
} | ConvertTo-Json

$versionJson | Out-File -FilePath "version.json" -Encoding utf8
Write-Host "✅ version.json updated" -ForegroundColor Green

# Add remote
Write-Host ""
Write-Host "🔗 Adding GitHub remote..." -ForegroundColor Cyan

$remoteUrl = "https://github.com/$username/$repoName.git"

try {
    git remote add origin $remoteUrl 2>$null
    Write-Host "✅ Remote added: $remoteUrl" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Remote already exists, updating..." -ForegroundColor Yellow
    git remote set-url origin $remoteUrl
    Write-Host "✅ Remote updated" -ForegroundColor Green
}

# Add all files
Write-Host ""
Write-Host "📁 Adding files to Git..." -ForegroundColor Cyan
git add .
Write-Host "✅ Files added" -ForegroundColor Green

# Commit
Write-Host ""
Write-Host "💾 Creating commit..." -ForegroundColor Cyan
git commit -m "Initial commit - TouchOne NFC App with Auto-Update"
Write-Host "✅ Commit created" -ForegroundColor Green

# Create main branch if needed
Write-Host ""
Write-Host "🌿 Setting up main branch..." -ForegroundColor Cyan
git branch -M main
Write-Host "✅ Main branch ready" -ForegroundColor Green

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  📋 NEXT STEPS - IMPORTANT!" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1️⃣  Create repository on GitHub:" -ForegroundColor White
Write-Host "   Go to: https://github.com/new" -ForegroundColor Gray
Write-Host "   Repository name: $repoName" -ForegroundColor Gray
Write-Host "   Keep it PUBLIC (important!)" -ForegroundColor Gray
Write-Host "   Click 'Create repository'" -ForegroundColor Gray
Write-Host ""
Write-Host "2️⃣  After creating repository, run this command:" -ForegroundColor White
Write-Host "   git push -u origin main" -ForegroundColor Yellow
Write-Host ""
Write-Host "3️⃣  Update lib/main.dart (line ~148):" -ForegroundColor White
Write-Host "   Change:" -ForegroundColor Gray
Write-Host "   static const String versionUrl = '" -NoNewline -ForegroundColor Gray
Write-Host "https://raw.githubusercontent.com/$username/$repoName/main/version.json" -ForegroundColor Cyan
Write-Host "   ';" -ForegroundColor Gray
Write-Host ""
Write-Host "4️⃣  Build APK:" -ForegroundColor White
Write-Host "   flutter build apk --release" -ForegroundColor Yellow
Write-Host ""
Write-Host "5️⃣  Create first release on GitHub:" -ForegroundColor White
Write-Host "   https://github.com/$username/$repoName/releases/new" -ForegroundColor Cyan
Write-Host "   Tag: v1.0.0" -ForegroundColor Gray
Write-Host "   Upload APK from: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "✅ Local setup complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
