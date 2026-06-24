# Reformwell - generate 5 IMPROVED example images for review before redoing all.
# Improvements: (1) natural anatomy / better poses, (2) a single clean teal motion
# arrow showing the movement direction where the static photo is unclear.
# Outputs to comfyui/_examples/ so originals in assets/exercises/ stay untouched.
#
#   powershell -ExecutionPolicy Bypass -File generate-examples.ps1 -ApiKey "sk-..."
param(
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [string]$Quality = "medium",
  [string[]]$Slugs = @()   # if set, only generate these slugs
)
$ErrorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Net.Http
$root = $PSScriptRoot
$destDir = Join-Path $root "_examples"
if(-not (Test-Path $destDir)){ New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
$refW = Join-Path $root "refs\ref-woman.png"
$refM = Join-Path $root "refs\ref-man.png"
$bytesW=[IO.File]::ReadAllBytes($refW); $bytesM=[IO.File]::ReadAllBytes($refM)

# Shared style + arrow rules appended to every pose.
$STYLE = "Full body visible head to toe, correct and natural anatomically accurate exercise form, the foot and ankle in a natural realistic position (never twisted unnaturally), plain neutral light-grey seamless studio background, soft even lighting, photorealistic. No text, no words, no numbers, no letters, no labels, no legend, no watermark."
$ARROW = "Overlay exactly ONE clean, smooth, semi-transparent teal (color #0E7C86) motion arrow directly on the photo to show the direction the movement goes. The arrow must be simple and modern with a single arrowhead, no text near it."

# size: lying/seated-on-floor = landscape, standing/kneeling = portrait
$EXAMPLES = @(
  @{ slug="resistance-band-ankle-inversion-eversion"; who="M"; size="1536x1024";
     pose="the same person seated upright on an exercise mat, one leg extended straight forward resting on the mat, a light resistance band looped around the ball of that foot with both hands holding the band ends, the foot rotating the sole inward against the band while the knee and lower leg stay still and naturally aligned";
     arrow="The teal arrow should be a short curved double-headed arrow beside the foot showing it turning side to side (inward and outward)." }

  @{ slug="ankle-pumps"; who="W"; size="1536x1024";
     pose="the same person seated upright on an exercise mat with one leg extended straight forward, the foot pointing the toes away from the body, lower leg still";
     arrow="The teal arrow should be a curved double-headed arrow at the foot showing the up-and-down pumping motion of the foot at the ankle." }

  @{ slug="ankle-alphabet"; who="M"; size="1024x1536";
     pose="the same person seated upright on a sturdy plain chair, one leg lifted with the foot off the floor, knee bent about ninety degrees, lower leg held still while the foot moves at the ankle";
     arrow="The teal arrow should be a small looping curved arrow in the air near the toes showing the foot tracing shapes." }

  @{ slug="ankle-dorsiflexion-mobilization-knee-to-wall"; who="W"; size="1024x1536";
     pose="the same person in a half-kneeling lunge facing a plain wall, front foot flat with the heel firmly down, both hands on the wall, driving the front knee forward over the toes toward the wall, back knee resting on the mat";
     arrow="The teal arrow must be placed right at the front knee and point FORWARD and slightly down toward the wall (in the direction the knee travels over the toes). Do not point the arrow backward toward the hip." }

  @{ slug="towel-band-calf-raise-eccentric-focus-seated-or-supported"; who="M"; size="1024x1536";
     pose="the same person standing tall with one hand resting on a counter for balance, clearly and obviously risen high onto the balls of both feet with BOTH HEELS LIFTED WELL OFF THE FLOOR, calf muscles visibly engaged, body tall on tiptoes, torso upright";
     arrow="The teal arrow must be a vertical double-headed arrow placed at the raised heels showing the heels rising up and lowering down." }
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
  $json=$resp.Content.ReadAsStringAsync().Result
  $client.Dispose()
  if(-not $resp.IsSuccessStatusCode){ throw ("HTTP $([int]$resp.StatusCode): " + $json.Substring(0,[Math]::Min(400,$json.Length))) }
  $obj=$json|ConvertFrom-Json
  [IO.File]::WriteAllBytes($dest,[Convert]::FromBase64String($obj.data[0].b64_json))
}

if($Slugs.Count -gt 0){ $EXAMPLES = $EXAMPLES | Where-Object { $Slugs -contains $_.slug } }
Write-Host "`n=== Generating $($EXAMPLES.Count) example image(s) (quality=$Quality) ===" -ForegroundColor Cyan
$done=0
foreach($ex in $EXAMPLES){
  if($ex.who -eq "W"){ $whoDesc="the same woman from the reference image (same face, hair, black tank top and leggings)"; $refBytes=$bytesW }
  else { $whoDesc="the same man from the reference image (same face, hair, grey t-shirt and black shorts)"; $refBytes=$bytesM }
  $prompt="Use the SAME person shown in the reference image: keep $whoDesc. Show this exact same person performing the exercise: $($ex.pose). $STYLE $ARROW $($ex.arrow)"
  $dest=Join-Path $destDir "$($ex.slug).png"
  try {
    EditCall $ApiKey $prompt $ex.size $Quality $refBytes $dest
    $done++; Write-Host ("OK   {0}  [{1}]  ({2}/5)" -f $ex.slug,$ex.who,$done) -ForegroundColor Green
  } catch {
    Write-Host ("FAIL {0}: {1}" -f $ex.slug,$_.Exception.Message) -ForegroundColor Red
  }
  Start-Sleep -Milliseconds 400
}
Write-Host "`nDone. $done/5 saved to: $destDir" -ForegroundColor Cyan
Write-Host "Perziurek nuotraukas tame aplanke." -ForegroundColor Yellow
