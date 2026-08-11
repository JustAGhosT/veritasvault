# HISTORICAL — DO NOT RUN. Kept as the estate's origin record.
#
# This script created the original five VeritasVault repos in May 2025. Its
# $Org default ("phoenixvc") and its branch-protection block record the
# *intended* design, none of which survived: the repos were created under the
# personal JustAGhosT account with no branch protection, and eight more repos
# accreted outside this list.
#
# The consolidation target is now the neuralliquid org, not phoenixvc.
# See docs/planning/estate-consolidation-spike.md §8.

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
