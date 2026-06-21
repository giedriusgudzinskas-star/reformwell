# Build contact-sheet montages of the generated exercise images for quick visual QC.
# Each tile is numbered; the index->slug legend is printed so failures can be mapped back.
param(
  [string]$Dir = (Join-Path $PSScriptRoot "..\assets\exercises"),
  [string]$OutDir = (Join-Path $PSScriptRoot "_qc"),
  [int]$Cols = 4,
  [int]$PerSheet = 20,
  [int]$Cell = 300
)
Add-Type -AssemblyName System.Drawing
if(-not (Test-Path $OutDir)){ New-Item -ItemType Directory -Force $OutDir | Out-Null }
Get-ChildItem "$OutDir\sheet_*.png" -ErrorAction SilentlyContinue | Remove-Item -Force
$imgs = Get-ChildItem "$Dir\*.png" | Sort-Object Name
$labelH = 26
$rows = [Math]::Ceiling($PerSheet/$Cols)
$sheetW = $Cols*$Cell
$sheetH = $rows*($Cell+$labelH)
$idxFont = New-Object System.Drawing.Font("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
$lblFont = New-Object System.Drawing.Font("Segoe UI",8)
$sf = New-Object System.Drawing.StringFormat; $sf.Alignment='Center'
$sheetIdx=0; $g0=0
"--- LEGEND (index : slug) ---"
for($s=0;$s -lt $imgs.Count;$s+=$PerSheet){
  $batch = $imgs[$s..([Math]::Min($s+$PerSheet,$imgs.Count)-1)]
  $bmp = New-Object System.Drawing.Bitmap $sheetW,$sheetH
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::White)
  $g.InterpolationMode='HighQualityBicubic'
  $c=0
  foreach($f in $batch){
    $col=$c % $Cols; $row=[Math]::Floor($c/$Cols)
    $x=$col*$Cell; $y=$row*($Cell+$labelH)
    try{
      $im=[System.Drawing.Image]::FromFile($f.FullName)
      $scale=[Math]::Min(($Cell-8)/$im.Width, ($Cell-8)/$im.Height)
      $w=[int]($im.Width*$scale); $h=[int]($im.Height*$scale)
      $g.DrawImage($im,[int]($x+($Cell-$w)/2),[int]($y+($Cell-$h)/2),$w,$h)
      $im.Dispose()
    }catch{}
    # index badge top-left
    $g.FillRectangle([System.Drawing.Brushes]::Black,$x,$y,38,24)
    $g.DrawString([string]$g0,$idxFont,[System.Drawing.Brushes]::White,($x+4),($y+1))
    # short label bottom
    $name=$f.BaseName; if($name.Length -gt 40){ $name=$name.Substring(0,40) }
    $rect=New-Object System.Drawing.RectangleF ([single]$x),([single]($y+$Cell-4)),([single]$Cell),([single]$labelH)
    $g.DrawString($name,$lblFont,[System.Drawing.Brushes]::Black,$rect,$sf)
    "{0,3} : {1}" -f $g0,$f.BaseName
    $c++; $g0++
  }
  $g.Dispose()
  $out=Join-Path $OutDir ("sheet_{0:D2}.png" -f $sheetIdx)
  $bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  $sheetIdx++
}
"--- wrote $sheetIdx sheet(s) to $OutDir ---"
