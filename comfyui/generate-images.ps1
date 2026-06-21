# Reformwell — generate exercise images via the Comfy Cloud API.
# The API key is NOT stored here; pass it at runtime.
#
#   powershell -ExecutionPolicy Bypass -File generate-images.ps1 -ApiKey "comfyui-..." -Scope short
#
# -Scope short  -> the 87 short-program exercises (reads _short_slugs.json)
# -Scope all    -> all 257 (reads exercise-prompts.json order)
# Existing images in ..\assets\exercises\ are skipped, so it is safe to re-run / resume.
param(
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [ValidateSet("short","all")][string]$Scope = "short",
  [int]$Max = 0,
  [string]$Ckpt = "realvisxlV50_v50Bakedvae.safetensors",
  [int]$Steps = 30,
  [double]$Cfg = 6.0
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$root = $PSScriptRoot
$base = "https://cloud.comfy.org"
$h = @{ "X-API-Key" = $ApiKey }
$destDir = Join-Path $root "..\assets\exercises"
if(-not (Test-Path $destDir)){ New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
$log = Join-Path $root "_genlog.txt"
$resultsPath = Join-Path $root "_genresults.json"

function Note($m){ $line = "{0}  {1}" -f (Get-Date -Format "HH:mm:ss"), $m; Add-Content -Path $log -Value $line; Write-Host $line }

$man = Get-Content (Join-Path $root "exercise-prompts.json") -Raw | ConvertFrom-Json
$bySlug = @{}; foreach($e in $man.exercises){ $bySlug[$e.slug] = $e }
$neg = $man.negative

if($Scope -eq "short"){ $targets = Get-Content (Join-Path $root "_short_slugs.json") -Raw | ConvertFrom-Json }
else { $targets = $man.exercises | ForEach-Object { $_.slug } }
if($Max -gt 0 -and $targets.Count -gt $Max){ $targets = $targets[0..($Max-1)] }

function Orient($text){
  $t = $text.ToLower()
  if($t -match 'lying|lie on|lies |supine|prone|face-up|face up|face-down|face down|on (his|her|their) back|on (his|her|their) side|side-lying|side lying|all fours|quadruped|hands and knees|plank'){ return @(1216,832) }
  elseif($t -match 'standing|stands|upright|stand '){ return @(832,1216) }
  else { return @(1024,1024) }
}

Note "=== run start: scope=$Scope targets=$($targets.Count) ckpt=$Ckpt steps=$Steps cfg=$Cfg ==="
$done=0; $skip=0; $fail=0; $results=@()
foreach($slug in $targets){
  $dest = Join-Path $destDir "$slug.png"
  if((Test-Path $dest) -and (Get-Item $dest).Length -gt 50000){ $skip++; Note "SKIP  $slug (exists)"; continue }
  $ex = $bySlug[$slug]
  if(-not $ex){ $fail++; Note "MISS  $slug (not in manifest)"; continue }
  try {
    $wh = Orient $ex.prompt
    $pos = $ex.prompt + ", full body head to toe, entire body in frame, nothing cropped"
    $seed = Get-Random -Minimum 1 -Maximum 2147480000
    $graph = @{
      "3" = @{ class_type="CheckpointLoaderSimple"; inputs=@{ ckpt_name=$Ckpt } }
      "4" = @{ class_type="CLIPTextEncode"; inputs=@{ text=$pos; clip=@("3",1) } }
      "5" = @{ class_type="CLIPTextEncode"; inputs=@{ text=$neg; clip=@("3",1) } }
      "6" = @{ class_type="EmptyLatentImage"; inputs=@{ width=$wh[0]; height=$wh[1]; batch_size=1 } }
      "7" = @{ class_type="KSampler"; inputs=@{ seed=$seed; steps=$Steps; cfg=$Cfg; sampler_name="dpmpp_2m"; scheduler="karras"; denoise=1.0; model=@("3",0); positive=@("4",0); negative=@("5",0); latent_image=@("6",0) } }
      "8" = @{ class_type="VAEDecode"; inputs=@{ samples=@("7",0); vae=@("3",2) } }
      "9" = @{ class_type="SaveImage"; inputs=@{ filename_prefix=$slug; images=@("8",0) } }
    }
    $body = @{ prompt=$graph } | ConvertTo-Json -Depth 12
    $sub = Invoke-RestMethod -Uri "$base/api/prompt" -Headers $h -Method Post -Body $body -ContentType "application/json" -TimeoutSec 60
    if($sub -is [string]){ $sub = $sub | ConvertFrom-Json }
    $jid = $sub.prompt_id
    if(-not $jid){ throw "no prompt_id ($($sub | ConvertTo-Json -Compress))" }

    $status=""; $t=0
    while($t -lt 80){
      $t++
      try { $s = Invoke-RestMethod -Uri "$base/api/job/$jid/status" -Headers $h -TimeoutSec 20; if($s -is [string]){ $s=$s|ConvertFrom-Json }; $status="$($s.status)" } catch { $status="poll-err" }
      if($status -match 'success|completed|failed|cancelled|error'){ break }
      Start-Sleep -Seconds 3
    }
    if($status -notmatch 'success|completed'){ throw "status=$status" }

    $job = Invoke-RestMethod -Uri "$base/api/jobs/$jid" -Headers $h -TimeoutSec 30
    if($job -is [string]){ $job = $job | ConvertFrom-Json }
    $img=$null; foreach($n in $job.outputs.PSObject.Properties){ if($n.Value.images){ $img=$n.Value.images[0]; break } }
    if(-not $img){ throw "no image output" }
    $f=[uri]::EscapeDataString($img.filename); $sf=[uri]::EscapeDataString("$($img.subfolder)"); $ty="$($img.type)"
    Invoke-WebRequest -Uri "$base/api/view?filename=$f&subfolder=$sf&type=$ty" -Headers $h -OutFile $dest -TimeoutSec 120
    $sz = (Get-Item $dest).Length
    $done++; Note ("OK    {0}  {1}x{2}  {3:N0}B  ({4}/{5})" -f $slug,$wh[0],$wh[1],$sz,$done,$targets.Count)
    $results += [pscustomobject]@{ slug=$slug; status="ok"; w=$wh[0]; h=$wh[1]; bytes=$sz; seed=$seed }
  } catch {
    $fail++; Note "FAIL  $slug : $($_.Exception.Message)"
    $results += [pscustomobject]@{ slug=$slug; status="fail"; error="$($_.Exception.Message)" }
  }
  Start-Sleep -Milliseconds 400
}
Note "=== done. ok=$done skipped=$skip failed=$fail ==="
$results | ConvertTo-Json -Depth 4 | Out-File $resultsPath -Encoding utf8
