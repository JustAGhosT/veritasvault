# -- params ----------------------------
$org = "phoenixvc"             # org/user
$projectNum = 5                       # project number
$csvPath = ".\roadmap-final.csv"
$estimateField = "Estimate (d)"       # exact custom-field name in your Project
# -------------------------------------

Import-Csv $csvPath | ForEach-Object {
    $title = $_.Title
    $body = $_.Body
    $labels = $_.Labels -replace '\s', ''
    $repo = $_.Repo
    $estimate = $_.'Estimate(d)'

    # 1) create draft item, capture nodeId
    $json = gh projects item-create $projectNum `
        --org $org `
        --title "$title" `
        --body "$body" `
        --format json | ConvertFrom-Json

    $itemId = $json.id

    # 2) assign labels & estimate
    if ($labels) {
        gh projects item-edit $projectNum --org $org --id $itemId --labels $labels
    }
    if ($estimate) {
        gh projects item-edit $projectNum --org $org --id $itemId --field "$estimateField" --value $estimate
    }

    # 3) optional GitHub Issue linkage
    if ($repo) {
        $issue = gh api "repos/$repo/issues" -X POST -f title="$title" -f body="$body`n`n(Imported from roadmap)" -F labels="$labels" --jq .number
        gh projects item-add $projectNum --org $org --url "https://github.com/$repo/issues/$issue"
    }

    Write-Host "✅ Added $title"
}
