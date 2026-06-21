# Reformwell — generate exercise images with a CONSISTENT 2-person cast,
# using the OpenAI gpt-image-1 IMAGE EDITS endpoint (feeds in a reference person).
# Key is NOT stored here; pass at runtime.
#
#   powershell -ExecutionPolicy Bypass -File generate-images-cast.ps1 -ApiKey "sk-..." -Scope short
#
# Even-indexed exercises use ref-woman.png, odd use ref-man.png (stable assignment).
# Existing images are skipped (safe to resume). Logs to _genlog_cast.txt.
param(
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [ValidateSet("short","all")][string]$Scope = "short",
  [int]$Max = 0,
  [string]$Quality = "medium"
)
$ErrorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Net.Http
$root = $PSScriptRoot
$destDir = Join-Path $root "..\assets\exercises"
if(-not (Test-Path $destDir)){ New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
$refW = Join-Path $root "refs\ref-woman.png"
$refM = Join-Path $root "refs\ref-man.png"
$log = Join-Path $root "_genlog_cast.txt"; $resultsPath = Join-Path $root "_genresults_cast.json"
function Note($m){ $l="{0}  {1}" -f (Get-Date -Format "HH:mm:ss"),$m; Add-Content $log $l; Write-Host $l }

$man = Get-Content (Join-Path $root "exercise-prompts.json") -Raw | ConvertFrom-Json
$bySlug=@{}; foreach($e in $man.exercises){ $bySlug[$e.slug]=$e }
if($Scope -eq "short"){ $targets = Get-Content (Join-Path $root "_short_slugs.json") -Raw | ConvertFrom-Json }
else { $targets = $man.exercises | ForEach-Object { $_.slug } }
if($Max -gt 0 -and $targets.Count -gt $Max){ $targets = $targets[0..($Max-1)] }

function Orient($t){
  $t=$t.ToLower()
  if($t -match 'lying|lie on|lies |supine|prone|face-up|face up|face-down|face down|on (his|her|their) back|on (his|her|their) side|side-lying|side lying|all fours|quadruped|hands and knees|plank'){ return "1536x1024" }
  elseif($t -match 'standing|stands|upright|stand '){ return "1024x1536" }
  else { return "1024x1024" }
}
$bytesW=[IO.File]::ReadAllBytes($refW); $bytesM=[IO.File]::ReadAllBytes($refM)
function EditCall($key,$prompt,$size,$quality,$refBytes,$dest){
  $client=New-Object System.Net.Http.HttpClient; $client.Timeout=[TimeSpan]::FromSeconds(220)
  $client.DefaultRequestHeaders.Authorization=New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer",$key)
  $form=New-Object System.Net.Http.MultipartFormDataContent
  $form.Add((New-Object System.Net.Http.StringContent("gpt-image-1")),"model")
  $form.Add((New-Object System.Net.Http.StringContent($prompt)),"prompt")
  $form.Add((New-Object System.Net.Http.StringContent($size)),"size")
  $form.Add((New-Object System.Net.Http.StringContent($quality)),"quality")
  $form.Add((New-Object System.Net.Http.StringContent("1")),"n")
  $ic=New-Object System.Net.Http.ByteArrayContent(,$refBytes)
  $ic.Headers.ContentType=[System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/png")
  $form.Add($ic,"image","ref.png")
  $resp=$client.PostAsync("https://api.openai.com/v1/images/edits",$form).Result
  $json=$resp.Content.ReadAsStringAsync().Result
  $client.Dispose()
  if(-not $resp.IsSuccessStatusCode){ throw ("HTTP $([int]$resp.StatusCode): " + $json.Substring(0,[Math]::Min(300,$json.Length))) }
  $obj=$json|ConvertFrom-Json
  [IO.File]::WriteAllBytes($dest,[Convert]::FromBase64String($obj.data[0].b64_json))
}

Note "=== cast run: scope=$Scope targets=$($targets.Count) quality=$Quality ==="
$i=-1;$done=0;$skip=0;$fail=0;$results=@()
foreach($slug in $targets){
  $i++
  $dest=Join-Path $destDir "$slug.png"
  if((Test-Path $dest) -and (Get-Item $dest).Length -gt 50000){ $skip++; Note "SKIP  $slug"; continue }
  $ex=$bySlug[$slug]; if(-not $ex){ $fail++; Note "MISS  $slug"; continue }
  $pose=$ex.prompt; $cut=$pose.IndexOf(", photorealistic studio photograph"); if($cut -gt 0){$pose=$pose.Substring(0,$cut)}
  $isW = ($i % 2 -eq 0)
  if($isW){ $who="the same woman from the reference image (same face, hair, black tank top and leggings)"; $refBytes=$bytesW; $tag="W" }
  else    { $who="the same man from the reference image (same face, hair, grey t-shirt and black shorts)"; $refBytes=$bytesM; $tag="M" }
  $prompt="Use the SAME person shown in the reference image. Keep $who. Show this exact same person performing the exercise correctly: $pose. Full body visible head to toe, correct exercise form, plain neutral light-grey studio background, soft even lighting, photorealistic. No text, no watermark."
  $size=Orient $ex.prompt
  try {
    EditCall $ApiKey $prompt $size $Quality $refBytes $dest
    $done++; Note ("OK    {0}  {1}  {2}  ({3}/{4})" -f $slug,$tag,$size,$done,$targets.Count)
    $results+=[pscustomobject]@{slug=$slug;status="ok";person=$tag}
  } catch {
    $fail++; Note "FAIL  $slug : $($_.Exception.Message)"
    $results+=[pscustomobject]@{slug=$slug;status="fail";error="$($_.Exception.Message)"}
  }
  Start-Sleep -Milliseconds 300
}
Note "=== done. ok=$done skip=$skip fail=$fail ==="
$results|ConvertTo-Json -Depth 4|Out-File $resultsPath -Encoding utf8
