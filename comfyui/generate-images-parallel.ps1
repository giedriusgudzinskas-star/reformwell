# Reformwell — PARALLEL exercise-image generator (gpt-image-1 edits, consistent 2-person cast).
# Runs several requests at once via a runspace pool for a big wall-clock speedup.
# Key NOT stored here; pass at runtime. Resumable (skips existing).
#
#   powershell -ExecutionPolicy Bypass -File generate-images-parallel.ps1 -ApiKey "sk-..." -Scope all -Throttle 5
param(
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [ValidateSet("short","all")][string]$Scope = "all",
  [int]$Throttle = 5,
  [string]$Quality = "medium"
)
$ErrorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"
$root = $PSScriptRoot
$destDir = (Resolve-Path (Join-Path $root "..\assets\exercises")).Path
$refW = (Join-Path $root "refs\ref-woman.png")
$refM = (Join-Path $root "refs\ref-man.png")
$log  = Join-Path $root "_genlog_par.txt"
function Note($m){ $l="{0}  {1}" -f (Get-Date -Format "HH:mm:ss"),$m; Add-Content $log $l; Write-Host $l }

$man = Get-Content (Join-Path $root "exercise-prompts.json") -Raw | ConvertFrom-Json
$bySlug=@{}; foreach($e in $man.exercises){ $bySlug[$e.slug]=$e }
if($Scope -eq "short"){ $targets = Get-Content (Join-Path $root "_short_slugs.json") -Raw | ConvertFrom-Json }
else { $targets = $man.exercises | ForEach-Object { $_.slug } }
function Orient($t){
  $t=$t.ToLower()
  if($t -match 'lying|lie on|lies |supine|prone|face-up|face up|face-down|face down|on (his|her|their) back|on (his|her|their) side|side-lying|side lying|all fours|quadruped|hands and knees|plank'){ return "1536x1024" }
  elseif($t -match 'standing|stands|upright|stand '){ return "1024x1536" }
  else { return "1024x1024" }
}

# Precompute the work list (skip existing). Person assignment by global index keeps the cast stable.
$work = New-Object System.Collections.ArrayList
$i=-1
foreach($slug in $targets){
  $i++
  $dest = Join-Path $destDir "$slug.png"
  if((Test-Path $dest) -and (Get-Item $dest).Length -gt 50000){ continue }
  $ex=$bySlug[$slug]; if(-not $ex){ continue }
  $pose=$ex.prompt; $cut=$pose.IndexOf(", photorealistic studio photograph"); if($cut -gt 0){ $pose=$pose.Substring(0,$cut) }
  $isW = ($i % 2 -eq 0)
  if($isW){ $who="the same woman from the reference image (same face, hair, black tank top and leggings)"; $ref=$refW; $tag="W" }
  else    { $who="the same man from the reference image (same face, hair, grey t-shirt and black shorts)"; $ref=$refM; $tag="M" }
  $prompt="Use the SAME person shown in the reference image. Keep $who. Show this exact same person performing the exercise correctly: $pose. Full body visible head to toe, correct exercise form, plain neutral light-grey studio background, soft even lighting, photorealistic. No text, no watermark."
  [void]$work.Add([pscustomobject]@{ slug=$slug; dest=$dest; prompt=$prompt; size=(Orient $ex.prompt); ref=$ref; tag=$tag })
}

$sb = {
  param($item,$key,$quality)
  Add-Type -AssemblyName System.Net.Http
  $refBytes=[IO.File]::ReadAllBytes($item.ref)
  for($attempt=1; $attempt -le 4; $attempt++){
    try {
      $client=New-Object System.Net.Http.HttpClient; $client.Timeout=[TimeSpan]::FromSeconds(240)
      $client.DefaultRequestHeaders.Authorization=New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer",$key)
      $form=New-Object System.Net.Http.MultipartFormDataContent
      $form.Add((New-Object System.Net.Http.StringContent("gpt-image-1")),"model")
      $form.Add((New-Object System.Net.Http.StringContent($item.prompt)),"prompt")
      $form.Add((New-Object System.Net.Http.StringContent($item.size)),"size")
      $form.Add((New-Object System.Net.Http.StringContent($quality)),"quality")
      $form.Add((New-Object System.Net.Http.StringContent("1")),"n")
      $ic=New-Object System.Net.Http.ByteArrayContent(,$refBytes)
      $ic.Headers.ContentType=[System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/png")
      $form.Add($ic,"image","ref.png")
      $resp=$client.PostAsync("https://api.openai.com/v1/images/edits",$form).Result
      $json=$resp.Content.ReadAsStringAsync().Result
      $code=[int]$resp.StatusCode; $client.Dispose()
      if($code -eq 429 -or $code -ge 500){ Start-Sleep -Seconds (6*$attempt); continue }
      if($code -lt 200 -or $code -ge 300){ return "FAIL $($item.slug): HTTP $code $($json.Substring(0,[Math]::Min(160,$json.Length)))" }
      $obj=$json|ConvertFrom-Json
      [IO.File]::WriteAllBytes($item.dest,[Convert]::FromBase64String($obj.data[0].b64_json))
      return "OK   $($item.slug) $($item.tag)"
    } catch { if($attempt -ge 4){ return "FAIL $($item.slug): $($_.Exception.Message)" }; Start-Sleep -Seconds (6*$attempt) }
  }
  return "FAIL $($item.slug): retries exhausted"
}

Note "=== PARALLEL run: to-generate=$($work.Count) throttle=$Throttle quality=$Quality ==="
$pool=[runspacefactory]::CreateRunspacePool(1,$Throttle); $pool.Open()
$jobs=New-Object System.Collections.ArrayList
foreach($w in $work){
  $ps=[powershell]::Create(); $ps.RunspacePool=$pool
  [void]$ps.AddScript($sb).AddArgument($w).AddArgument($ApiKey).AddArgument($Quality)
  [void]$jobs.Add([pscustomobject]@{ ps=$ps; handle=$ps.BeginInvoke() })
}
$n=0; $ok=0; $fail=0
foreach($j in $jobs){
  try { $res = $j.ps.EndInvoke($j.handle) } catch { $res = @("FAIL endinvoke: $($_.Exception.Message)") }
  try { $j.ps.Dispose() } catch {}
  $n++
  $line = ($res | Out-String).Trim()
  if($line -like 'OK*'){ $ok++ } else { $fail++ }
  Note ("[{0}/{1}] {2}" -f $n,$jobs.Count,$line)
}
$pool.Close()
Note "=== done. ok=$ok fail=$fail ==="
