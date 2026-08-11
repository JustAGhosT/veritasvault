param(
    [string]$Org = "phoenixvc",
    [string[]]$Repos = @(
        "vv-landing",
        "vv-game-suite",
        "vv-docs",
        "vv-chain-services",
        "vv-iac"
    ),
    [string]$Team = "dev"           # set to team slug or leave empty
)

foreach ($r in $Repos) {

    # Skip if repo already exists (re-run safe)
    if (gh repo view "$Org/$r" 2>$null) {
        Write-Host "🔁 $r already exists – skipping"
        continue
    }

    Write-Host "📦 Creating $Org/$r …"

    $createArgs = @(
        "repo", "create", "$Org/$r",
        "--public",
        "--description", "VeritasVault.ai $r",
        "--add-readme",
        "--license", "MIT"
        #"--disable-issues",            # remove if you want issues (they inherit templates anyway)
        #"--confirm"                    # no interactive prompt
    )
    if ($Team) { $createArgs += @("--team", $Team) }

    gh @createArgs

    # ─ add topics ─
    gh repo edit "$Org/$r" --enable-branch-protection

    # ─ protect main ─
    gh api "repos/$Org/$r/branches/main/protection" -X PUT --silent `
    -F required_pull_request_reviews.required_approving_review_count:=1 `
    -F required_status_checks:=null `
    -F enforce_admins:=true

    Write-Host "✅ $r ready"
}
