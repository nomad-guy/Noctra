param(
    [string]$Version = "1.0.6"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Noctra Release Dispatcher: v$Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check git status
$status = git status --porcelain
if ($status) {
    Write-Host "[1/4] Staging and committing changes..." -ForegroundColor Yellow
    git add .
    git commit -m "chore(release): v$Version"
} else {
    Write-Host "[1/4] Working tree is clean." -ForegroundColor Green
}

Write-Host "[2/4] Pushing commits to origin/main..." -ForegroundColor Yellow
git push origin main

$tagName = "v$Version"

# Delete local tag if exists
if (git tag -l $tagName) {
    Write-Host "Local tag $tagName exists. Updating..." -ForegroundColor DarkGray
    git tag -d $tagName
}

Write-Host "[3/4] Creating tag $tagName..." -ForegroundColor Yellow
git tag -a $tagName -m "Noctra Release $tagName"

Write-Host "[4/4] Pushing tag $tagName to GitHub..." -ForegroundColor Yellow
git push origin $tagName --force

Write-Host ""
Write-Host "Successfully triggered Release Workflow on GitHub!" -ForegroundColor Green
Write-Host "GitHub Release: https://github.com/nomad-guy/Noctra/releases/tag/$tagName" -ForegroundColor Cyan
