# Reformwell — import ComfyUI images into the website
# ---------------------------------------------------------------
# When you generate an exercise image, set the SaveImage node's
# "filename_prefix" to the exercise slug (the part before ".png" in
# the "Save as" filename, e.g.  glute-bridge ). ComfyUI then writes
# files like  glute-bridge_00001_.png  into its output folder.
#
# This script copies those into  ..\assets\exercises\<slug>.png  so
# the website shows them. It only copies files whose slug matches a
# real exercise (typos are skipped and listed), and if a slug was
# generated several times it keeps the NEWEST one.
#
# Usage (from this comfyui folder):
#   powershell -ExecutionPolicy Bypass -File import-images.ps1
#   powershell -ExecutionPolicy Bypass -File import-images.ps1 -ComfyOutput "C:\path\to\ComfyUI\output"
# ---------------------------------------------------------------
param(
  [string]$ComfyOutput = "",
  [string]$Dest = ""
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
if (-not $Dest) { $Dest = Join-Path $root "..\assets\exercises" }
$Dest = (Resolve-Path -LiteralPath $Dest -ErrorAction SilentlyContinue)
if (-not $Dest) {
  $Dest = Join-Path $root "..\assets\exercises"
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  $Dest = (Resolve-Path -LiteralPath $Dest)
}

# Try to find ComfyUI's output folder automatically if not given.
if (-not $ComfyOutput) {
  $guesses = @(
    "$env:USERPROFILE\ComfyUI\output",
    "$env:USERPROFILE\Desktop\ComfyUI\output",
    "$env:USERPROFILE\Downloads\ComfyUI_windows_portable\ComfyUI\output",
    "C:\ComfyUI\output",
    "$env:USERPROFILE\Documents\ComfyUI\output"
  )
  $ComfyOutput = $guesses | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $ComfyOutput -or -not (Test-Path $ComfyOutput)) {
  Write-Host "Could not find the ComfyUI output folder." -ForegroundColor Yellow
  Write-Host "Re-run with:  -ComfyOutput `"C:\path\to\ComfyUI\output`""
  exit 1
}

# Valid slugs from the prompt manifest.
$manifestPath = Join-Path $root "exercise-prompts.json"
$validSlugs = @{}
if (Test-Path $manifestPath) {
  (Get-Content $manifestPath -Raw | ConvertFrom-Json).exercises | ForEach-Object { $validSlugs[$_.slug] = $true }
}

Write-Host "Source : $ComfyOutput"
Write-Host "Target : $Dest"
Write-Host ""

$pngs = Get-ChildItem -LiteralPath $ComfyOutput -Filter *.png -Recurse | Sort-Object LastWriteTime
$copied = @{}; $skipped = New-Object System.Collections.ArrayList
foreach ($f in $pngs) {
  # strip ComfyUI's trailing _00001_ counter to recover the slug
  $slug = [regex]::Replace($f.BaseName, '_\d{2,}_?$', '')
  $slug = $slug.Trim('_').ToLower()
  if ($validSlugs.Count -and -not $validSlugs.ContainsKey($slug)) {
    [void]$skipped.Add($f.Name); continue
  }
  # newest wins (list is sorted oldest->newest, so just overwrite)
  Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $Dest "$slug.png") -Force
  $copied[$slug] = $true
}

Write-Host ("Imported {0} exercise image(s) into the site." -f $copied.Count) -ForegroundColor Green
if ($validSlugs.Count) {
  $have = $copied.Count; $total = $validSlugs.Count
  Write-Host ("Coverage: {0} of {1} exercises now have an image ({2}%)." -f $have, $total, [int](100*$have/$total))
}
if ($skipped.Count) {
  Write-Host ""
  Write-Host ("Skipped {0} file(s) whose name did not match a known exercise slug:" -f $skipped.Count) -ForegroundColor Yellow
  $skipped | Select-Object -Unique | ForEach-Object { Write-Host "  - $_" }
  Write-Host "  (Make sure the SaveImage 'filename_prefix' is set to the exact slug.)"
}
