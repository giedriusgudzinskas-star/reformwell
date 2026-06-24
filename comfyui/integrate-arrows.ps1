# Reformwell - convert _staging PNGs to web JPGs (half size, ~q80) and copy into
# assets/exercises, backing up the originals first. Run AFTER generation finishes.
#
#   & '.\integrate-arrows.ps1'
param([int]$Quality = 80, [string]$Source = "_staging")
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = $PSScriptRoot
$stage = Join-Path $root $Source
$assets = Join-Path $root "..\assets\exercises"
$backup = Join-Path $root "_backup-pre-arrows"
if(-not (Test-Path $backup)){ New-Item -ItemType Directory -Force -Path $backup | Out-Null }

# JPEG encoder at $Quality
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)

$pngs = Get-ChildItem (Join-Path $stage "*.png")
Write-Host "Converting $($pngs.Count) staged images..."
$n = 0
foreach($png in $pngs){
  $slug = [IO.Path]::GetFileNameWithoutExtension($png.Name)
  $src = [System.Drawing.Image]::FromFile($png.FullName)
  $w = [int]([math]::Round($src.Width/2)); $h = [int]([math]::Round($src.Height/2))
  $bmp = New-Object System.Drawing.Bitmap($w,$h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($src, 0, 0, $w, $h)
  $g.Dispose(); $src.Dispose()

  $destJpg = Join-Path $assets "$slug.jpg"
  if(Test-Path $destJpg){ Copy-Item $destJpg (Join-Path $backup "$slug.jpg") -Force }
  $bmp.Save($destJpg, $enc, $ep)
  $bmp.Dispose()
  $kb = [math]::Round((Get-Item $destJpg).Length/1KB,1)
  $n++; Write-Host ("  {0}  {1}x{2}  {3} KB" -f $slug,$w,$h,$kb)
}
Write-Host "`nDone. $n images integrated. Originals backed up to: $backup"
