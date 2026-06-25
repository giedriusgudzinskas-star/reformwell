# Reformwell - add CUSTOM interpretive arrows to exercises whose movement a static
# photo cannot show (foot-intrinsic, isometric, dynamic). Each arrow is hand-written
# for that specific movement. Outputs to _regen2/. Key passed at runtime.
#
#   & '.\add-arrows-hard.ps1' -ApiKey "sk-..." [-Slugs @('toe-yoga-foot-doming')]
param(
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [string]$Quality = "medium",
  [string[]]$Slugs = @()
)
$ErrorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Net.Http
$root = $PSScriptRoot
$destDir = Join-Path $root "_regen2"
if(-not (Test-Path $destDir)){ New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
$refW = Join-Path $root "refs\ref-woman.png"; $refM = Join-Path $root "refs\ref-man.png"
$bytesW=[IO.File]::ReadAllBytes($refW); $bytesM=[IO.File]::ReadAllBytes($refM)
$man = Get-Content (Join-Path $root "exercise-prompts.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$bySlug=@{}; foreach($e in $man.exercises){ $bySlug[$e.slug]=$e }
function Note($m){ Write-Host ("{0}  {1}" -f (Get-Date -Format "HH:mm:ss"),$m) }

$STYLE = "Natural anatomically accurate form, plain neutral light-grey seamless studio background, soft even lighting, photorealistic. No text, no words, no numbers, no letters, no labels, no watermark."
$FOOT = "Frame this as a CLOSE-UP of the bare feet and lower legs on the floor (face need not be visible); the foot and toes must be large and clearly visible."

# Hand-written interpretive arrows per exercise.
$ITEMS = @(
  @{ slug="toe-yoga-foot-doming"; who="M"; size="1536x1024"; framing=$FOOT;
     arrow="Overlay ONE clean semi-transparent teal (#0E7C86) upward curved arrow under the arch of the foot, showing the arch lifting and doming upward while the toes and heel stay pressed on the floor." }
  @{ slug="seated-toe-and-foot-doming-short-foot"; who="W"; size="1536x1024"; framing=$FOOT;
     arrow="Overlay ONE clean teal (#0E7C86) upward arrow under the arch of the foot showing it doming upward (short foot), toes and heel staying down." }
  @{ slug="toe-yoga-big-toe-press"; who="M"; size="1536x1024"; framing=$FOOT;
     arrow="Overlay ONE clean teal (#0E7C86) downward arrow on the big toe showing it pressing down into the floor while the other four toes lift up." }
  @{ slug="toe-yoga-big-toe-lesser-toe-dissociation"; who="W"; size="1536x1024"; framing=$FOOT;
     arrow="Overlay TWO small clean teal (#0E7C86) arrows: a downward arrow on the big toe (pressing down) and an upward arrow on the other four toes (lifting up), showing opposite directions." }
  @{ slug="short-foot-and-toe-spreads"; who="M"; size="1536x1024"; framing=$FOOT;
     arrow="Overlay clean teal (#0E7C86) arrows at the toes fanning outward to show the toes spreading apart, plus a small upward arrow at the arch." }
  @{ slug="toe-spreads-and-short-foot-activation"; who="W"; size="1536x1024"; framing=$FOOT;
     arrow="Overlay clean teal (#0E7C86) outward-fanning arrows at the toes showing them spreading wide apart." }
  @{ slug="quadriceps-isometric-sets-quad-sets"; who="M"; size="1536x1024"; framing="Frame on the leg lying/seated straight on the mat, thigh and knee clearly visible.";
     arrow="Overlay ONE clean teal (#0E7C86) short downward arrow at the back of the knee showing it pressing down into the mat as the thigh muscle tightens." }
  @{ slug="isometric-neck-holds-all-directions"; who="W"; size="1024x1536"; framing="Upper body and head clearly visible, one hand placed against the side of the head.";
     arrow="Overlay ONE clean teal (#0E7C86) arrow showing the head gently pressing into the hand (the isometric push direction), head and hand staying still." }
  @{ slug="pogo-hops-low-amplitude-hopping"; who="M"; size="1024x1536"; framing="Full body visible, standing tall on the balls of the feet.";
     arrow="Overlay ONE clean teal (#0E7C86) vertical double-headed arrow at the feet showing quick small up-and-down hops with the feet just leaving the floor." }
  @{ slug="sport-specific-drills-and-graded-return"; who="W"; size="1024x1536"; framing="Full body in an athletic ready stance.";
     arrow="Overlay ONE clean teal (#0E7C86) forward/sideways arrow showing quick directional movement (jogging and pivoting)." }
)

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

if($Slugs.Count -gt 0){ $ITEMS = $ITEMS | Where-Object { $Slugs -contains $_.slug } }
Note "=== add-arrows-hard: $($ITEMS.Count) targets ==="
$done=0
foreach($it in $ITEMS){
  $dest=Join-Path $destDir "$($it.slug).png"
  if((Test-Path $dest) -and (Get-Item $dest).Length -gt 50000){ Note "SKIP  $($it.slug)"; continue }
  $ex=$bySlug[$it.slug]; if(-not $ex){ Note "MISS  $($it.slug)"; continue }
  $pose=$ex.prompt; $cut=$pose.IndexOf(", photorealistic"); if($cut -gt 0){$pose=$pose.Substring(0,$cut)}
  if($it.who -eq "W"){ $who="the same woman from the reference image (same face, hair, black tank top and leggings)"; $refBytes=$bytesW }
  else { $who="the same man from the reference image (same face, hair, grey t-shirt and black shorts)"; $refBytes=$bytesM }
  $prompt="Use the SAME person shown in the reference image: keep $who. Show this exact same person performing the exercise: $pose. $($it.framing) $STYLE $($it.arrow)"
  try { EditCall $ApiKey $prompt $it.size $Quality $refBytes $dest; $done++; Note ("OK    {0}" -f $it.slug) }
  catch { Note "FAIL  $($it.slug): $($_.Exception.Message)" }
  Start-Sleep -Milliseconds 350
}
Note "=== done. ok=$done -> $destDir ==="
