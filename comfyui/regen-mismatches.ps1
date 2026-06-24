# Reformwell - regenerate the images GPT-4o flagged as mismatch, feeding each
# image the specific correction GPT suggested. Outputs to _regen/.
# Key passed at runtime. Reads _qc-results.json + exercise-prompts.json.
#
#   & '.\regen-mismatches.ps1' -ApiKey "sk-..."            # all mismatches
#   & '.\regen-mismatches.ps1' -ApiKey "sk-..." -Slugs @('side-plank-full')
param(
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [string]$Quality = "medium",
  [string[]]$Slugs = @()
)
$ErrorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Net.Http
$root = $PSScriptRoot
$destDir = Join-Path $root "_regen"
if(-not (Test-Path $destDir)){ New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
$refW = Join-Path $root "refs\ref-woman.png"; $refM = Join-Path $root "refs\ref-man.png"
$bytesW=[IO.File]::ReadAllBytes($refW); $bytesM=[IO.File]::ReadAllBytes($refM)
$log = Join-Path $root "_genlog_regen.txt"
function Note($m){ $l="{0}  {1}" -f (Get-Date -Format "HH:mm:ss"),$m; Add-Content $log $l; Write-Host $l }

$man = Get-Content (Join-Path $root "exercise-prompts.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$bySlug=@{}; foreach($e in $man.exercises){ $bySlug[$e.slug]=$e }
$qc = Get-Content (Join-Path $root "_qc-results.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$needArrow = @{}; if(Test-Path (Join-Path $root "_needs-arrow.txt")){ Get-Content (Join-Path $root "_needs-arrow.txt") | ForEach-Object { if($_){ $needArrow[$_.Trim()]=$true } } }

$STYLE = "Correct and natural anatomically accurate exercise form, joints in natural realistic positions (never twisted unnaturally), plain neutral light-grey seamless studio background, soft even lighting, photorealistic. No text, no words, no numbers, no letters, no labels, no watermark."

function IsFoot($s){ return ($s -match 'toe-yoga|short-foot|doming|toe-spread|toe-and-foot') }
function ArrowHint($name,$pose){
  $t=($name+" "+$pose).ToLower()
  $b="Overlay exactly ONE clean semi-transparent teal (#0E7C86) motion arrow on the photo, simple, single arrowhead, no text."
  if($t -match 'inversion|eversion|side to side'){ return "$b Short curved double-headed arrow at the foot showing it turning inward and outward." }
  if($t -match 'pump|circle'){ return "$b Curved double-headed arrow at the foot showing the ankle moving." }
  if($t -match 'calf raise|heel raise|onto the balls|rise onto'){ return "$b Vertical double-headed arrow at the heel showing it rising and lowering." }
  if($t -match 'rotation|rotat'){ return "$b Curved arrow showing the rotation direction." }
  if($t -match 'pull|row|face pull|y-t-w|raise|scaption|scapula'){ return "$b Arrow showing the pulling/lifting direction." }
  if($t -match 'abduction|clamshell|leg raise'){ return "$b Arrow showing the leg lifting in the working direction." }
  if($t -match 'press'){ return "$b Arrow showing the press direction." }
  if($t -match 'hop|bound|skip|jump|plyometric'){ return "$b Upward arrow showing the hop/jump direction." }
  if($t -match 'step-down|step down|step-up|step up|squat'){ return "$b Vertical double-headed arrow showing the up and down movement." }
  return "$b Arrow showing the main direction of movement."
}
function Orient($pose,$foot){
  if($foot){ return "1536x1024" }
  $t=$pose.ToLower()
  if($t -match 'lying|supine|prone|side-lying|all fours|quadruped|hands and knees|plank|seated on (an )?(exercise )?mat|sitting on'){ return "1536x1024" }
  elseif($t -match 'standing|stands|upright|half-kneeling|kneeling|step'){ return "1024x1536" }
  else { return "1024x1024" }
}
function EditCall($key,$prompt,$size,$quality,$refBytes,$dest){
  $client=New-Object System.Net.Http.HttpClient; $client.Timeout=[TimeSpan]::FromSeconds(300)
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
  $json=$resp.Content.ReadAsStringAsync().Result; $client.Dispose()
  if(-not $resp.IsSuccessStatusCode){ throw ("HTTP $([int]$resp.StatusCode): " + $json.Substring(0,[Math]::Min(300,$json.Length))) }
  ($json|ConvertFrom-Json)|ForEach-Object{ [IO.File]::WriteAllBytes($dest,[Convert]::FromBase64String($_.data[0].b64_json)) }
}

# build target list = mismatches (or provided slugs)
$targets=@()
if($Slugs.Count -gt 0){ $targets=$Slugs }
else { foreach($p in $qc.PSObject.Properties){ if($p.Value.verdict -eq 'mismatch'){ $targets += $p.Name } } }
Note "=== regen mismatches: $($targets.Count) targets ==="

$i=-1;$done=0;$fail=0
foreach($slug in $targets){
  $i++
  $dest=Join-Path $destDir "$slug.png"
  if((Test-Path $dest) -and (Get-Item $dest).Length -gt 50000){ Note "SKIP  $slug"; continue }
  $ex=$bySlug[$slug]; if(-not $ex){ $fail++; Note "MISS  $slug"; continue }
  $pose=$ex.prompt; $cut=$pose.IndexOf(", photorealistic"); if($cut -gt 0){$pose=$pose.Substring(0,$cut)}
  $q=$qc.$slug; $problem=$q.problem; $fix=$q.fix
  $isW = ($i % 2 -eq 0)
  if($isW){ $who="the same woman from the reference image (same face, hair, black tank top and leggings)"; $refBytes=$bytesW; $tag="W" }
  else    { $who="the same man from the reference image (same face, hair, grey t-shirt and black shorts)"; $refBytes=$bytesM; $tag="M" }
  $foot = IsFoot $slug
  if($foot){ $framing="Frame this as a CLOSE-UP on the bare feet and lower legs on the floor (the face need not be visible); the foot and toe action must be clearly and prominently visible." }
  else { $framing="Full body visible head to toe." }
  $correction="The previous image was WRONG: $problem. You MUST correct it: $fix. Depict the exercise exactly and unambiguously."
  $arrow=""; if($needArrow[$slug]){ $arrow = ArrowHint $ex.name $pose }
  $prompt="Use the SAME person shown in the reference image: keep $who. Show this exact same person performing the exercise: $pose. $correction $framing $STYLE $arrow"
  $size = Orient $pose $foot
  try {
    EditCall $ApiKey $prompt $size $Quality $refBytes $dest
    $done++; Note ("OK    {0}  {1}  {2}  ({3}/{4})" -f $slug,$tag,$size,$done,$targets.Count)
  } catch { $fail++; Note "FAIL  $slug : $($_.Exception.Message)" }
  Start-Sleep -Milliseconds 350
}
Note "=== done. ok=$done fail=$fail -> $destDir ==="
