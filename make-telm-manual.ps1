<#
.SYNOPSIS
  Builds the TELM-Manual OBS scene collection (the server-free backup of TELM-Auto) from a TELM-Auto export.

.DESCRIPTION
  Reads TELM-Auto.json (OBS: Scene Collection > Export), writes TELM-Manual.json next to it, and
  leaves the export untouched (an export already called TELM-Manual.json gives TELM-Manual.rebuilt.json). In the copy:
    - every Browser Source URL under thisevelife.space/overlay-metallic/ (or /overlay/) points at the TELM-Manual site
      (https://ceemaeve.github.io/tel-manual/) with ?src=manual added; this includes the guest
      avatar sources (avatar.html), which then read guests from manual.json and portraits from CCP
    - the Election and Month scenes are removed (not part of the backup)
    - the collection is renamed TELM-Manual
  Everything else (cameras, Countdown, the Now Playing music player, StreamElements alerts, stinger, audio, scene names,
  Stream Deck keys) is copied as is.
  Run it by hand on the stream PC; it is not a scheduled task.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File make-telm-manual.ps1 -Export "$HOME\Downloads\TELM-Auto.json"
  Then OBS: Scene Collection > Import > TELM-Manual.json
#>
param(
  [Parameter(Mandatory = $true)][string]$Export,
  [string]$ManualBase = 'https://ceemaeve.github.io/tel-manual/',
  [string[]]$DropScenes = @('Election', 'Month'),
  [string]$Out
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Export)) { throw "Export not found: $Export" }
if (-not $Out) {
  $dir = Split-Path -Parent (Resolve-Path $Export)
  $Out = Join-Path $dir 'TELM-Manual.json'
  if ((Resolve-Path $Export).Path -ieq $Out) { $Out = Join-Path $dir 'TELM-Manual.rebuilt.json' }
}
if ((Test-Path -LiteralPath $Out) -and (Resolve-Path $Out).Path -ieq (Resolve-Path $Export).Path) { throw "-Out is the export itself: $Out" }

$json = Get-Content -LiteralPath $Export -Raw -Encoding UTF8
$doc = $json | ConvertFrom-Json

# 1. Rewrite overlay URLs (avatar.html included) and find the Month source.
$rx = [regex]'^(?:https?://)?(?:www\.)?thisevelife\.space/overlay(?:-metallic)?/([A-Za-z0-9_-]+\.html)(?:\?(.*))?$'
$dropSources = New-Object System.Collections.Generic.List[string]
$rewritten = 0
foreach ($s in $doc.sources) {
  if ($s.id -ne 'browser_source' -or -not $s.settings -or -not $s.settings.url) { continue }
  $m = $rx.Match($s.settings.url)
  if (-not $m.Success) { continue }
  $page = $m.Groups[1].Value
  if ($page -ieq 'month.html') { $dropSources.Add($s.name); continue }
  $q = 'src=manual'
  if ($m.Groups[2].Success -and $m.Groups[2].Value) { $q = 'src=manual&' + $m.Groups[2].Value }
  $s.settings.url = "$ManualBase$page`?$q"
  $rewritten++
}

# 2. Drop the chosen scenes and their page sources from every scene and group.
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
$doc.name = 'TELM-Manual'
$doc | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $Out -Encoding UTF8

Write-Host "Wrote $Out"
Write-Host "  overlay URLs re-pointed: $rewritten"
Write-Host "  sources removed: $($dropSources -join ', ')"
Write-Host "Next: OBS > Scene Collection > Import > $(Split-Path -Leaf $Out)"
