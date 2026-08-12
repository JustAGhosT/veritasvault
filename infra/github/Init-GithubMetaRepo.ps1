<#
Init-GithubMetaRepo.ps1
Creates the org-wide `.github` repo and pushes local templates.
#>

param(
  [string]$Org         = "phoenixvc",
  [string]$LocalRoot   = "$PSScriptRoot\templates", 
  [string]$RepoName    = ".github"
)

# 1. Create the repo if it doesn’t exist
if (-not (gh repo view "$Org/$RepoName" 2>$null)) {
  gh repo create "$Org/$RepoName" --public `
     --description "Org-wide community health files" `
     --disable-issues --clone
  Set-Location "$RepoName"
} else {
  gh repo clone "$Org/$RepoName"
  Set-Location "$RepoName"
}

# 2. Copy template contents
Copy-Item -Path "$LocalRoot\*" -Destination . -Recurse -Force

# 3. Ensure README
if (-not (Test-Path README.md)) {
  @"
# VeritasVault – Org-wide Community Files
(See docs in main README in template folder)
"@ | Out-File README.md -Encoding utf8
}

# 4. Commit & push
git add .
git commit -m "chore: bootstrap org-wide templates" | Out-Null
git push -u origin main

Write-Host "✅ .github repo bootstrapped & pushed."
