# Bulk-Create-ProjectItems.ps1  (fixed for 2025-05 gh CLI)

param(
  [string]$Csv = ".\roadmap-final.csv",
  [string]$Org = "phoenixvc", # use --User if personal
  [int]   $Project = 5,
  [string]$EstimateField = "Estimate (d)"
)

Import-Csv $Csv | ForEach-Object {

  $title = $_.Title
  if (-not $title) { return }                    # skip separator rows
  $body = $_.Body
  $labels = ($_.Labels -replace '\s', '') -split ',' | Where-Object { $_ }
  $repo = $_.Repo
  $estimate = $_.'Estimate(d)'

  # 1) CREATE DRAFT ITEM
  $json = gh projects item-create $Project `
    --org $Org `
    --title "$title" `
    --body "$body" `
    --format json | ConvertFrom-Json
  $itemId = $json.id

  # 2) SET LABELS & ESTIMATE
  if ($labels.Count) {
    gh projects item-edit  $Project --org $Org --id $itemId --labels $labels
  }
  if ($estimate) {
    gh projects item-edit  $Project --org $Org --id $itemId `
      --field "$EstimateField" --value "$estimate"
  }

  # 3) OPTIONAL ISSUE + LINK
  if ($repo) {
    $issueNum = gh api "repos/$repo/issues" -X POST `
      -F title="$title" `
      -F body="$body`n`n(Imported from roadmap)" `
      -F labels="$($labels -join ',')" `
      --jq .number
    gh projects item-add $Project --org $Org `
      --url "https://github.com/$repo/issues/$issueNum"
  }

  Write-Host "✅ Added $title"
}
