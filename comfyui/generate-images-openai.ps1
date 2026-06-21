# Reformwell — generate exercise images via the OpenAI Images API (gpt-image-1).
# The API key is NOT stored here; pass it at runtime.
#
#   powershell -ExecutionPolicy Bypass -File generate-images-openai.ps1 -ApiKey "sk-..." -Scope short
#
# -Scope short -> 87 short-program exercises (_short_slugs.json);  -Scope all -> all 257.
# Existing images in ..\assets\exercises\ are skipped, so it is safe to re-run / resume.
param(
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [ValidateSet("short","all")][string]$Scope = "short",
  [int]$Max = 0,
  [string]$Model = "gpt-image-1",
  [string]$Quality = "medium"
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$root = $PSScriptRoot
$url  = "https://api.openai.com/v1/images/generations"
$h = @{ Authorization = "Bearer $ApiKey" }
$destDir = Join-Path $root "..\assets\exercises"
if(-not (Test-Path $destDir)){ New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
$log = Join-Path $root "_genlog_openai.txt"
$resultsPath = Join-Path $root "_genresults_openai.json"
function Note($m){ $line="{0}  {1}" -f (Get-Date -Format "HH:mm:ss"),$m; Add-Content $log $line; Write-Host $line }

$man = Get-Content (Join-Path $root "exercise-prompts.json") -Raw | ConvertFrom-Json
$bySlug=@{}; foreach($e in $man.exercises){ $bySlug[$e.slug]=$e }
if($Scope -eq "short"){ $targets = Get-Content (Join-Path $root "_short_slugs.json") -Raw | ConvertFrom-Json }
else { $targets = $man.exercises | ForEach-Object { $_.slug } }
if($Max -gt 0 -and $targets.Count -gt $Max){ $targets = $targets[0..($Max-1)] }

function Orient($t){
  $t=$t.ToLower()
  if($t -match 'lying|lie on|lies |supine|prone|face-up|face up|face-down|face down|on (his|her|their) back|on (his|her|their) side|side-lying|side lying|all fours|quadruped|hands and knees|plank'){ return "land" }
  elseif($t -match 'standing|stands|upright|stand '){ return "port" }
  else { return "sq" }
}
function SizeFor($o,$m){
  if($m -eq "dall-e-3"){ if($o -eq "land"){return "1792x1024"} elseif($o -eq "port"){return "1024x1792"} else {return "1024x1024"} }
  if($o -eq "land"){return "1536x1024"} elseif($o -eq "port"){return "1024x1536"} else {return "1024x1024"}
}

Note "=== run start: scope=$Scope targets=$($targets.Count) model=$Model quality=$Quality ==="
$done=0;$skip=0;$fail=0;$results=@()
foreach($slug in $targets){
  $dest = Join-Path $destDir "$slug.png"
  if((Test-Path $dest) -and (Get-Item $dest).Length -gt 50000){ $skip++; Note "SKIP  $slug (exists)"; continue }
  $ex=$bySlug[$slug]; if(-not $ex){ $fail++; Note "MISS  $slug"; continue }
  $pose=$ex.prompt; $cut=$pose.IndexOf(", photorealistic studio photograph"); if($cut -gt 0){ $pose=$pose.Substring(0,$cut) }
  $prompt="A photorealistic studio photograph showing the exercise performed correctly: $pose. Single person, full body visible head to toe with correct exercise form, plain neutral light-grey studio background, soft even lighting. No text, no labels, no watermark, no arrows."
  $o = Orient $ex.prompt
  try {
    $body = @{ model=$Model; prompt=$prompt; size=(SizeFor $o $Model); quality=$Quality; n=1 } | ConvertTo-Json -Depth 4
    $r = Invoke-RestMethod -Uri $url -Headers $h -Method Post -Body $body -ContentType "application/json" -TimeoutSec 200
    if($r.data[0].b64_json){ [IO.File]::WriteAllBytes($dest,[Convert]::FromBase64String($r.data[0].b64_json)) }
    elseif($r.data[0].url){ Invoke-WebRequest $r.data[0].url -OutFile $dest -TimeoutSec 120 }
    else { throw "no image in response" }
    $done++; Note ("OK    {0}  {1}  {2:N0}B  ({3}/{4})" -f $slug,$o,(Get-Item $dest).Length,$done,$targets.Count)
    $results += [pscustomobject]@{ slug=$slug; status="ok"; orient=$o }
  } catch {
    $m=$_.ErrorDetails.Message; if(-not $m){$m=$_.Exception.Message}
    $fail++; Note "FAIL  $slug : $m"
    $results += [pscustomobject]@{ slug=$slug; status="fail"; error="$m" }
  }
  Start-Sleep -Milliseconds 300
}
Note "=== done. ok=$done skipped=$skip failed=$fail ==="
$results | ConvertTo-Json -Depth 4 | Out-File $resultsPath -Encoding utf8
