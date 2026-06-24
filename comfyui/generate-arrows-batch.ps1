# Reformwell - batch-regenerate the exercises that need a motion arrow.
# Reads _needs-arrow.txt, builds an improved natural-anatomy prompt plus a
# category-specific teal motion arrow, outputs PNGs to _staging/.
# Originals in assets/exercises stay untouched until you approve.
#
#   & '.\generate-arrows-batch.ps1' -ApiKey "sk-..."           # all in _needs-arrow.txt
#   & '.\generate-arrows-batch.ps1' -ApiKey "sk-..." -Slugs @('ankle-pumps','clamshell-side-lying')
param(
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [string]$Quality = "medium",
  [string[]]$Slugs = @()
)
$ErrorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Net.Http
$root = $PSScriptRoot
$destDir = Join-Path $root "_staging"
if(-not (Test-Path $destDir)){ New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
$refW = Join-Path $root "refs\ref-woman.png"; $refM = Join-Path $root "refs\ref-man.png"
$bytesW=[IO.File]::ReadAllBytes($refW); $bytesM=[IO.File]::ReadAllBytes($refM)
$log = Join-Path $root "_genlog_arrows.txt"
function Note($m){ $l="{0}  {1}" -f (Get-Date -Format "HH:mm:ss"),$m; Add-Content $log $l; Write-Host $l }

$man = Get-Content (Join-Path $root "exercise-prompts.json") -Raw | ConvertFrom-Json
$bySlug=@{}; foreach($e in $man.exercises){ $bySlug[$e.slug]=$e }

$STYLE = "Full body visible head to toe, correct and natural anatomically accurate exercise form, the foot ankle and joints in a natural realistic position (never twisted unnaturally), plain neutral light-grey seamless studio background, soft even lighting, photorealistic. No text, no words, no numbers, no letters, no labels, no legend, no watermark."
$ARROWBASE = "Overlay exactly ONE clean, smooth, semi-transparent teal (color #0E7C86) motion arrow directly on the photo, simple and modern, no text near it."

# Map exercise wording to the right arrow shape/direction.
function ArrowHint($name,$pose){
  $t = ($name + " " + $pose).ToLower()
  if($t -match 'inversion|eversion|side to side|in/out|in and out'){ return "$ARROWBASE The arrow is a short curved double-headed arrow beside the foot showing it turning inward and outward (side to side)." }
  if($t -match 'pump'){ return "$ARROWBASE The arrow is a curved double-headed arrow at the foot showing it moving up and down at the ankle." }
  if($t -match 'alphabet|trace|ankle.*circle|circles'){ return "$ARROWBASE The arrow is a small looping curved arrow near the foot showing a circular tracing motion." }
  if($t -match 'pronation|supination'){ return "$ARROWBASE The arrow is a curved arrow at the hand/forearm showing it rotating between palm-up and palm-down." }
  if($t -match 'wrist'){ return "$ARROWBASE The arrow is a curved double-headed arrow at the hand showing the wrist bending up and down." }
  if($t -match 'calf raise|heel raise|heel lift|onto the balls|rise onto|rising onto|tiptoe'){ return "$ARROWBASE The arrow is a vertical double-headed arrow at the heel showing the heel rising up and lowering down." }
  if($t -match 'clamshell'){ return "$ARROWBASE The arrow is a curved arrow at the top knee showing it opening upward like a clamshell while the feet stay together." }
  if($t -match 'bridge|hip thrust'){ return "$ARROWBASE The arrow is an upward arrow at the hips showing them lifting up." }
  if($t -match 'pendulum|swing'){ return "$ARROWBASE The arrow is a curved double-headed arrow below the hanging arm showing it swinging gently." }
  if($t -match 'wall slide'){ return "$ARROWBASE The arrow is a vertical arrow showing the arms sliding up the wall." }
  if($t -match 'pull-apart|pull apart|face pull|band.*row|banded row|rows'){ return "$ARROWBASE The arrow shows the hands/band being pulled apart and back toward the body." }
  if($t -match 'pallof|anti-rotation|press'){ return "$ARROWBASE The arrow is a horizontal arrow showing the hands pressing straight out away from the chest." }
  if($t -match 'external rotation|internal rotation|rotation|rotat|windshield'){ return "$ARROWBASE The arrow is a curved arrow showing the rotation direction of the limb." }
  if($t -match 'y-t-w|y and t|y raise|t raise|w raise|scaption|scapula|setting|squeeze|retract'){ return "$ARROWBASE The arrow shows the arms/shoulder blades lifting and drawing together." }
  if($t -match 'abduction|leg raise|straight leg raise'){ return "$ARROWBASE The arrow shows the leg lifting in the working direction." }
  if($t -match 'knee extension|leg curl|leg extension'){ return "$ARROWBASE The arrow is a curved arrow at the lower leg showing it extending and bending at the knee." }
  if($t -match 'hop|bound|pogo|jump|plyometric|skip|skater|agility|change of direction'){ return "$ARROWBASE The arrow is an upward arrow showing the hopping/jumping direction." }
  if($t -match 'step-up|step up|step-down|step down'){ return "$ARROWBASE The arrow is a vertical double-headed arrow showing stepping up and down." }
  if($t -match 'squat|sit-to-stand|sit to stand|wall sit'){ return "$ARROWBASE The arrow is a vertical double-headed arrow showing lowering down and standing back up." }
  if($t -match '4-way|four-way'){ return "$ARROWBASE The arrow is a curved double-headed arrow at the foot showing the ankle moving through its range." }
  if($t -match 'isometric|hold'){ return "$ARROWBASE The arrow is a short straight arrow showing the direction of the muscle effort (the push or pull held still)." }
  return "$ARROWBASE The arrow shows the main direction of movement for this exercise."
}

function Orient($t){
  $t=$t.ToLower()
  if($t -match 'lying|lie on|lies |supine|prone|face-up|face up|face-down|face down|on (his|her|their) back|on (his|her|their) side|side-lying|side lying|all fours|quadruped|hands and knees|plank|seated on (an )?(exercise )?mat|sitting on'){ return "1536x1024" }
  elseif($t -match 'standing|stands|upright|stand |half-kneeling|kneeling|step'){ return "1024x1536" }
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
  ($json|ConvertFrom-Json) | ForEach-Object { [IO.File]::WriteAllBytes($dest,[Convert]::FromBase64String($_.data[0].b64_json)) }
}

$targets = if($Slugs.Count -gt 0){ $Slugs } else { Get-Content (Join-Path $root "_needs-arrow.txt") | Where-Object { $_ } }
Note "=== arrows batch: $($targets.Count) targets, quality=$Quality ==="
$i=-1; $done=0; $fail=0
foreach($slug in $targets){
  $i++
  $dest=Join-Path $destDir "$slug.png"
  if((Test-Path $dest) -and (Get-Item $dest).Length -gt 50000){ Note "SKIP  $slug"; continue }
  $ex=$bySlug[$slug]; if(-not $ex){ $fail++; Note "MISS  $slug"; continue }
  $pose=$ex.prompt; $cut=$pose.IndexOf(", photorealistic"); if($cut -gt 0){$pose=$pose.Substring(0,$cut)}
  $isW = ($i % 2 -eq 0)
  if($isW){ $whoDesc="the same woman from the reference image (same face, hair, black tank top and leggings)"; $refBytes=$bytesW; $tag="W" }
  else    { $whoDesc="the same man from the reference image (same face, hair, grey t-shirt and black shorts)"; $refBytes=$bytesM; $tag="M" }
  $arrow = ArrowHint $ex.name $pose
  $prompt="Use the SAME person shown in the reference image: keep $whoDesc. Show this exact same person performing the exercise: $pose. $STYLE $arrow"
  $size = Orient $pose
  try {
    EditCall $ApiKey $prompt $size $Quality $refBytes $dest
    $done++; Note ("OK    {0}  {1}  {2}  ({3}/{4})" -f $slug,$tag,$size,$done,$targets.Count)
  } catch {
    $fail++; Note "FAIL  $slug : $($_.Exception.Message)"
  }
  Start-Sleep -Milliseconds 350
}
Note "=== done. ok=$done fail=$fail -> $destDir ==="
