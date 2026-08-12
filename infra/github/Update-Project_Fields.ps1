# Update-ProjectFields.ps1
param(
    [string]$Org = "phoenixvc",
    [int]$Project = 5,
    [string]$Csv = "C:\Dev\roadmap-expanded.csv"
)

# map title -> field values from CSV
$map = @{}
Import-Csv $Csv | ForEach-Object {
    if ($_.Title) {
        $map[$_.Title] = $_
    }
}

# iterate project items
$items = gh projects item-list $Project --org $Org --format json | ConvertFrom-Json
foreach ($it in $items) {
    $title = $it.title
    if (-not $map.ContainsKey($title)) { continue }

    $row = $map[$title]
    $estimate = $row.'Estimate(d)'
    $assignee = $row.Assignee -replace '@', ''
    $sprint = $row.Milestone  # reuse Milestone column for Sprint label

    # set Estimate
    if ($estimate) {
        gh projects item-edit $Project --org $Org --id $it.id `
            --field "Estimate (d)" --value $estimate
    }

    # set Owner (User field)
    if ($assignee) {
        gh projects item-edit $Project --org $Org --id $it.id `
            --field "Owner" --value "$assignee"
    }

    # set Sprint (Iteration field)
    if ($sprint) {
        gh projects item-edit $Project --org $Org --id $it.id `
            --field "Sprint" --value "$sprint"
    }

    Write-Host "🔄 updated $title"
}
