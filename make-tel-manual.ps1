<#
.SYNOPSIS
  Builds the TEL-Manual OBS scene collection from an export of TEL-Normal.

.DESCRIPTION
  Reads TELNormal.json (OBS: Scene Collection > Export), writes TELManual.json next to it, and
  leaves the export untouched. In the copy:
    - every Browser Source URL under thisevelife.space/overlay/ points at the TEL-Manual site
      (https://ceemaeve.github.io/tel-manual/) with ?src=manual added
    - the guest avatar sources (avatar.html) are removed from every scene
    - the Election and Month scenes are removed (not part of the backup)
    - the collection is renamed TEL-Manual
  Everything else (cameras, Countdown, Now Playing, alerts, audio, scene names) is copied as is.
  Run it by hand on the stream PC; it is not a scheduled task.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File make-tel-manual.ps1 -Export "$HOME\Downloads\TELNormal.json"
  Then OBS: Scene Collection > Import > TELManual.json
#>
param(
  [Parameter(Mandatory = $true)][string]$Export,
  [string]$ManualBase = 'https://ceemaeve.github.io/tel-manual/',
  [string[]]$DropScenes = @('Election', 'Month'),
  [string]$Out
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Export)) { throw "Export not found: $Export" }
if (-not $Out) { $Out = Join-Path (Split-Path -Parent (Resolve-Path $Export)) 'TELManual.json' }

$json = Get-Content -LiteralPath $Export -Raw -Encoding UTF8
$doc = $json | ConvertFrom-Json

# 1. Rewrite overlay URLs and find the avatar sources.
$rx = [regex]'^(?:https?://)?(?:www\.)?thisevelife\.space/overlay/([A-Za-z0-9_-]+\.html)(?:\?(.*))?$'
$dropSources = New-Object System.Collections.Generic.List[string]
$rewritten = 0
foreach ($s in $doc.sources) {
  if ($s.id -ne 'browser_source' -or -not $s.settings -or -not $s.settings.url) { continue }
  $m = $rx.Match($s.settings.url)
  if (-not $m.Success) { continue }
  $page = $m.Groups[1].Value
  if ($page -ieq 'avatar.html' -or $page -ieq 'election.html' -or $page -ieq 'month.html') { $dropSources.Add($s.name); continue }
  $q = 'src=manual'
  if ($m.Groups[2].Success -and $m.Groups[2].Value) { $q = 'src=manual&' + $m.Groups[2].Value }
  $s.settings.url = "$ManualBase$page`?$q"
  $rewritten++
}

# 2. Drop the chosen scenes and the avatar sources from every scene and group.
foreach ($s in $doc.sources) { if ($s.id -eq 'scene' -and ($DropScenes -contains $s.name)) { $dropSources.Add($s.name) } }
$doc.sources = @($doc.sources | Where-Object { $dropSources -notcontains $_.name })
function Prune($container) {
  if ($container.settings -and $container.settings.items) {
    $container.settings.items = @($container.settings.items | Where-Object { $dropSources -notcontains $_.name })
  }
}
foreach ($s in $doc.sources) { if ($s.id -eq 'scene' -or $s.id -eq 'group') { Prune $s } }
if ($doc.scene_order) { $doc.scene_order = @($doc.scene_order | Where-Object { $DropScenes -notcontains $_.name }) }
if ($doc.current_scene -and ($DropScenes -contains $doc.current_scene)) { $doc.current_scene = 'PreShow' }
if ($doc.current_program_scene -and ($DropScenes -contains $doc.current_program_scene)) { $doc.current_program_scene = 'PreShow' }

# 3. Rename and write.
$doc.name = 'TEL-Manual'
$doc | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $Out -Encoding UTF8

Write-Host "Wrote $Out"
Write-Host "  overlay URLs re-pointed: $rewritten"
Write-Host "  sources removed: $($dropSources -join ', ')"
Write-Host "Next: OBS > Scene Collection > Import > TELManual.json"
