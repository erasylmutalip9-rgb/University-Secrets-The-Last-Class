@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
echo University Secrets: The Last Class - GitHub source uploader
echo Repository: https://github.com/erasylmutalip9-rgb/University-Secrets-The-Last-Class
where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: Install Git for Windows first from https://git-scm.com/downloads/win
  pause
  exit /b 1
)
if not exist project.godot (
  echo ERROR: project.godot not found. Extract the entire ZIP first.
  pause
  exit /b 1
)
if not exist .git (
  git init -b main
  if errorlevel 1 goto failed
  git remote add origin https://github.com/erasylmutalip9-rgb/University-Secrets-The-Last-Class.git
  if errorlevel 1 goto failed
)
git remote -v
echo If the origin URL is not YOUR expected GitHub repository, press Ctrl+C now.
git add .
if errorlevel 1 goto failed
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "Initial source release: Godot 20-level campaign and offline AI modules"
  if errorlevel 1 (
    echo ERROR: Commit failed. Configure Git author identity using git config --global user.name and user.email.
    goto failed
  )
)
git push -u origin main
if errorlevel 1 (
  echo ERROR: GitHub push failed. Sign into Git Credential Manager, or open this folder in GitHub Desktop.
  echo Your local commit is safe. Do not delete the folder.
  goto failed
)
echo SUCCESS: Source files uploaded to GitHub.
pause
exit /b 0
:failed
echo Upload not completed; no force push was attempted.
pause
exit /b 1
