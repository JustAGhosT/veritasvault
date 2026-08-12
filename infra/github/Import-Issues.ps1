<#
Import Issues (with label + milestone creation)

CSV layout:
Title,Body,Repo,Label1,Label2,Sprint,Estimate,Assignee
#>

param(
    [string]$Csv = ".\roadmap-final.csv",
    [string]$Org = "phoenixvc",
    [string]$LogJson = ".\import-issue-log.json"
)

# ───────────────── 0.  Load & auto-pad CSV ─────────────────
$headers = 'Title', 'Body', 'Repo', 'Label1', 'Label2', 'Sprint', 'Estimate'
$fixed = @()

foreach ($line in Get-Content $Csv) {
    $cols = $line.Split(',', 8)
    if ($cols.Count -eq 7) { $cols = $cols[0..3] + @('') + $cols[4..6] }  # pad Label2
    $fixed += ($cols -join ',')
}

$rows = $fixed | ConvertFrom-Csv -Header $headers |
Where-Object { $_.Repo -and $_.Title }
$rows = $rows | Where-Object { $_.Title -ne 'Title' }

# ───────────────── 1.  Defaults & caches ──────────────────
$AssignMap = @{
    "vv-chain-services" = "mareeben"
    default             = "JustAGhosT"
}

$NewLabelSet = @{}   # repo => [HashSet] labels to create
$NewMilestoneSet = @{}   # repo => [HashSet] sprint names to create

# ───────────────── 2.  Scan rows for missing labels / sprints ──────────────
foreach ($r in $rows) {

    $repo = $r.Repo
    $labels = @($r.Label1, $r.Label2) | Where-Object { $_ }
    $sprint = $r.Sprint

    if (-not $NewLabelSet.ContainsKey($repo)) { $NewLabelSet[$repo] = [System.Collections.Generic.HashSet[string]]::new() }
    if (-not $NewMilestoneSet.ContainsKey($repo)) { $NewMilestoneSet[$repo] = [System.Collections.Generic.HashSet[string]]::new() }

    $labels | ForEach-Object { $NewLabelSet[$repo].Add($_) }
    if ($sprint) { $NewMilestoneSet[$repo].Add($sprint) }
    if ($r.Estimate) { $NewLabelSet[$repo].Add("estimate/$($r.Estimate)d") }
}

# ──────────────── 3.  Remove already-existing labels / milestones ──────────
foreach ($repo in $NewLabelSet.Keys) {
    $existing = gh api "repos/$Org/$repo/labels" --jq '.[].name'
    $existing | ForEach-Object { $null = $NewLabelSet[$repo].Remove($_) }
}
foreach ($repo in $NewMilestoneSet.Keys) {
    $existing = gh api "repos/$Org/$repo/milestones?state=all" --jq '.[].title'
    $existing | ForEach-Object { $null = $NewMilestoneSet[$repo].Remove($_) }
}

# ──────────────── 4.  PREVIEW #1  (labels) ─────────────────────────────────
Write-Host "`n=== Labels that will be CREATED ==="
foreach ($repo in $NewLabelSet.Keys) {
    if ($NewLabelSet[$repo].Count) {
        Write-Host "`n$($repo):" -ForegroundColor Cyan
        $NewLabelSet[$repo] | ForEach-Object { "  • $_" }
    }
}
if (-not ($NewLabelSet.Values | Where-Object Count)) {
    Write-Host "  (none)"
}

# ──────────────── 5.  PREVIEW #2  (milestones) ─────────────────────────────
Write-Host "`n=== Milestones that will be CREATED ==="
foreach ($repo in $NewMilestoneSet.Keys) {
    if ($NewMilestoneSet[$repo].Count) {
        Write-Host "`n$($repo):" -ForegroundColor Cyan
        $NewMilestoneSet[$repo] | ForEach-Object { "  • $_" }
    }
}
if (-not ($NewMilestoneSet.Values | Where-Object Count)) {
    Write-Host "  (none)"
}

# ───────── 6.  PREVIEW #3  (final issue list) ───────────
$preview = $rows | ForEach-Object {
    $repo = $_.Repo
    $assignee = $_.Assignee
    if (-not $assignee -or $assignee -match '^\d') {
        $assignee = $AssignMap[$repo] ?? $AssignMap.default
    }
    [pscustomobject]@{
        Repo     = $repo
        Title    = $_.Title
        Labels   = @($_.Label1, $_.Label2) -join ','
        Sprint   = $_.Sprint
        Estimate = $_.Estimate      
        Assignee = $assignee
    }
}

Write-Host "`n=== Preview of Issues to import ===`n"
$preview | Format-Table -AutoSize


Write-Host "`n=== Preview of Issues to import ===`n"
$preview | Format-Table -AutoSize

if ((Read-Host "`nProceed and execute ALL actions above? (y/N)") -notmatch '^[Yy]$') {
    Write-Warning "Aborted by user."
    return
}

# ──────────────── 7.  Create missing labels & milestones ───────────────────
foreach ($repo in $NewLabelSet.Keys) {
    foreach ($lbl in $NewLabelSet[$repo]) {
        gh api "repos/$Org/$repo/labels" -X POST -f name="$lbl"
        Write-Host "🏷️  created label '$lbl' in $repo"
    }
}
foreach ($repo in $NewMilestoneSet.Keys) {
    foreach ($ms in $NewMilestoneSet[$repo]) {
        gh api "repos/$Org/$repo/milestones" -X POST -f title="$ms"
        Write-Host "📅  created milestone '$ms' in $repo"
    }
}

# ──────────────── 8.  Import Issues ────────────────────────────────────────
$MilestoneIdCache = @{}
$issueLog = @()

foreach ($row in $rows) {

    $repo = $row.Repo
    $title = $row.Title
    $body = $row.Body
    $labelsArr = @($row.Label1, $row.Label2) | Where-Object { $_ }
    if ($row.Estimate -match '^\d+(\.\d+)?$') {
        $labelsArr += "estimate/$($row.Estimate)d"
    }   
    $assignee = $row.Assignee
    if (-not $assignee -or $assignee -match '^\d') {
        $assignee = $AssignMap[$repo] ?? $AssignMap.default
    }

    # resolve milestone number (from cache or fresh fetch)
    $milestoneNum = $null
    if ($row.Sprint) {
        if (-not $MilestoneIdCache.ContainsKey("$repo/$($row.Sprint)")) {
            $milestoneNum = gh api "repos/$Org/$repo/milestones?state=all" --jq "
         map(select(.title==\"$($row.Sprint)\"))[0].number" --silent
            $MilestoneIdCache["$repo/$($row.Sprint)"] = $milestoneNum
        }
        else {
            $milestoneNum = $MilestoneIdCache["$repo/$($row.Sprint)"]
        }
    }

    $api = @(
        "repos/$Org/$repo/issues", "-X", "POST",
        "-f", "title=$title",
        "-f", "body=$body`n`n(Imported from roadmap)"
    )
    foreach ($l in $labelsArr) { $api += @("-F", "labels[]=$l") }
    $api += @("-F", "assignees[]=$assignee")
    if ($milestoneNum) { $api += @("-F", "milestone=$milestoneNum") }

    $num = gh api @api --jq .number
    Write-Host "✅  #$num  $repo  $title"

    $issueLog += [pscustomobject]@{ Repo = "$repo"; Number = $num; Title = $title }
}

$issueLog | ConvertTo-Json -Depth 3 | Set-Content $LogJson
Write-Host "`n📝 Issue log written to $LogJson"
