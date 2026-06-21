# Generates a branded PDF for every program using headless Microsoft Edge.
# Run from the pt-studio folder:  powershell -ExecutionPolicy Bypass -File make-pdfs.ps1
#
# Edge cannot write --print-to-pdf to a path containing spaces, so we render to a
# no-space temp folder and then move each file into ./downloads.

$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) { $edge = "C:\Program Files\Microsoft\Edge\Application\msedge.exe" }
if (-not (Test-Path $edge)) { Write-Error "Microsoft Edge not found."; exit 1 }

$dir = $PSScriptRoot
$out = Join-Path $dir "downloads"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$tmp = Join-Path $env:TEMP "rw-pdfs"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$base = "file:///" + (($dir -replace '\\','/') -replace ' ','%20')
$udd  = Join-Path $env:TEMP "rw-edge-print"

$slugs = @('low-back-pain','neck-pain','shoulder','knee-pain','plantar-fasciitis','tennis-elbow','hip-glute','ankle-sprain')
$kinds = @(@{k='short'; label='relief-reset'}, @{k='long'; label='full-rehab'})

$made = 0
foreach ($slug in $slugs) {
  foreach ($kind in $kinds) {
    $name = "$slug-$($kind.label).pdf"
    $url  = "$base/print.html?slug=$slug&kind=$($kind.k)"
    $tpdf = Join-Path $tmp $name
    $a = @('--headless=new','--disable-gpu','--no-first-run','--no-pdf-header-footer',
           "--user-data-dir=$udd",'--virtual-time-budget=10000',"--print-to-pdf=$tpdf",$url)
    Start-Process $edge -ArgumentList $a -Wait -NoNewWindow -RedirectStandardError "$env:TEMP\rw-edge-err.txt"
    if (Test-Path $tpdf) {
      Move-Item -Force $tpdf (Join-Path $out $name)
      $kb = [math]::Round((Get-Item (Join-Path $out $name)).Length / 1KB, 1)
      Write-Host "OK   $name  ($kb KB)"
      $made++
    } else {
      Write-Host "FAIL $name"
    }
  }
}
Write-Host ""
Write-Host "Generated $made / $($slugs.Count * $kinds.Count) PDFs into: $out"
