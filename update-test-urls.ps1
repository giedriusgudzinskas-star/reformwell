# update-test-urls.ps1
# Atnaujina esamų TEST payment links success URL'us į download.html.
# Naudok tai, kad galėtum išbandyti visą srautą test režime.
#
# Paleidimas:
#   powershell -ExecutionPolicy Bypass -File update-test-urls.ps1 -Key "sk_test_..."

param(
  [Parameter(Mandatory=$true)][string]$Key
)

$ErrorActionPreference = "Stop"
$base = "https://api.stripe.com/v1"
$site = "https://reformwell.lt"

function Stripe($method, $path, $body="") {
  $cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Key + ":"))
  $h = @{ Authorization = "Basic $cred" }
  if ($method -eq "POST") {
    Invoke-RestMethod -Uri "$base$path" -Method POST -Headers $h -ContentType "application/x-www-form-urlencoded" -Body $body
  } else {
    Invoke-RestMethod -Uri "$base$path$body" -Method GET -Headers $h
  }
}

function Enc($v) { [Uri]::EscapeDataString([string]$v) }

# Esami test payment links iš main.js
$KNOWN = @{
  "https://buy.stripe.com/test_cNi3co3rYcTL0Pm0Eie7m00" = "low-back-pain__short"
  "https://buy.stripe.com/test_14AaEQ3rY7zr55CaeSe7m01" = "low-back-pain__long"
  "https://buy.stripe.com/test_6oU3co5A6g5X0Pm4Uye7m02" = "neck-pain__short"
  "https://buy.stripe.com/test_5kQbIU9Qm8Dv8hO9aOe7m03" = "neck-pain__long"
  "https://buy.stripe.com/test_eVqcMY6Ea2f79lScn0e7m04" = "shoulder__short"
  "https://buy.stripe.com/test_5kQcMY8Mi2f77dK4Uye7m05" = "shoulder__long"
  "https://buy.stripe.com/test_dRm9AM3rY4nfgOkdr4e7m06" = "knee-pain__short"
  "https://buy.stripe.com/test_7sY7sE3rY1b341y2Mqe7m07" = "knee-pain__long"
  "https://buy.stripe.com/test_4gM00ce6Cf1T1Tq1Ime7m08" = "plantar-fasciitis__short"
  "https://buy.stripe.com/test_28EfZae6C9Hz2XuaeSe7m09" = "plantar-fasciitis__long"
  "https://buy.stripe.com/test_7sY28kaUq6vn1Tq2Mqe7m0a" = "tennis-elbow__short"
  "https://buy.stripe.com/test_7sY28kbYubPH1Tq3Que7m0b" = "tennis-elbow__long"
  "https://buy.stripe.com/test_4gMcMYfaG6vn1Tq1Ime7m0c" = "hip-glute__short"
  "https://buy.stripe.com/test_aFa28k5A63jbdC8fzce7m0d" = "hip-glute__long"
  "https://buy.stripe.com/test_cNifZa1jQaLD8hOfzce7m0e" = "ankle-sprain__short"
  "https://buy.stripe.com/test_aFa3co4w23jbbu086Ke7m0f" = "ankle-sprain__long"
  "https://buy.stripe.com/test_eVq28kfaG1b3dC81Ime7m0g" = "all-access"
}

Write-Host "`n=== Atnaujinami test payment links ===" -ForegroundColor Cyan

# Gauti visų payment links sąrašą
$page = Stripe GET "/payment_links" "?limit=100"
$links = $page.data

Write-Host "Rasta $($links.Count) payment links Stripe paskyroje.`n"

$updated = 0
$skipped = 0

foreach ($pl in $links) {
  $url = "https://buy.stripe.com/" + $pl.id.Replace("plink_", "")
  # Ieškoti pagal URL (Stripe grąžina url lauką)
  $plUrl = $pl.url

  $sku = $null
  foreach ($k in $KNOWN.Keys) {
    # Stripe URL gali neatitikti tiksliai - palygink pagal payment link ID
    if ($pl.url -eq $k) { $sku = $KNOWN[$k]; break }
  }

  if (-not $sku) {
    # Bandyti pagal ID
    foreach ($k in $KNOWN.Keys) {
      $shortCode = ($k -split "/")[-1]
      if ($pl.url -match [regex]::Escape($shortCode.Substring(0, [Math]::Min(8, $shortCode.Length)))) {
        $sku = $KNOWN[$k]; break
      }
    }
  }

  if (-not $sku) { $skipped++; continue }

  $successUrl = "$site/download.html?sku=$(Enc $sku)"
  try {
    $body = "after_completion[type]=redirect&after_completion[redirect][url]=$(Enc $successUrl)"
    Stripe POST "/payment_links/$($pl.id)" $body | Out-Null
    Write-Host ("OK  {0}  ->  {1}" -f $sku, $successUrl) -ForegroundColor Green
    $updated++
  } catch {
    Write-Host ("ERR {0}: {1}" -f $sku, $_.Exception.Message) -ForegroundColor Red
  }
}

Write-Host "`nAtnaujinta: $updated  |  Praleista (nerasta): $skipped" -ForegroundColor Yellow
if ($updated -gt 0) {
  Write-Host "Dabar galite išbandyti srautą: pirkimas (test kortele 4242...) -> download.html" -ForegroundColor Cyan
}
