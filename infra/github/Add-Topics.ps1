<#
Adds GitHub topics to the VeritasVault repos.
• If a topic already exists it’s skipped (GitHub is idempotent).
• Extend the $Topics map to taste; any repo missing from the map gets only “veritasvault”.
#>

param(
  [string] $Org = "phoenixvc"
)

# ───────────────────────────────────────────────────────────
# Per-repo topic map  (space- or comma-separated list)
# ───────────────────────────────────────────────────────────
$Topics = @{
  "vv-landing"        = "nextjs react tailwind frontend website";
  "vv-game-suite"     = "typescript phaser webgl game defi breakout";
  "vv-docs"           = "docusaurus documentation mdx";
  "vv-chain-services" = "nodejs fastify postgres tezos ethereum api";
  "vv-iac"            = "terraform aws eks iac devops";
}

# ───────────────────────────────────────────────────────────
foreach ($repoName in $Topics.Keys) {

  $topicList = ("veritasvault " + $Topics[$repoName]) -split '\s+' | Where-Object {$_}

  Write-Host "🏷  $repoName  →  $($topicList -join ', ')"

  foreach ($t in $topicList) {
    gh repo edit "$Org/$repoName" --add-topic $t 1>$null
  }
}

Write-Host "✅ Topics applied (safe to re-run)."
