param(
    [string]$LogJson = "C:\Dev\phoenixvc\scripts\issue-log.json",
    [string]$Org = "phoenixvc",
    [int]   $Project = 5
)

$items = Get-Content $LogJson | ConvertFrom-Json
foreach ($it in $items) {
    $url = "https://github.com/$($it.Repo)/issues/$($it.Number)"
    gh projects item-add $Project --org $Org --url $url
    Write-Host "🔗 Added  $url"
}
Write-Host "🎉 All issues linked to project."
