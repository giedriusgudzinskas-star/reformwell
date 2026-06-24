# setup-live-stripe.ps1
# Sukuria 17 Stripe LIVE produktų + payment links su atsisiuntimo URL'ais.
#
# Paleidimas:
#   powershell -ExecutionPolicy Bypass -File setup-live-stripe.ps1 -Key "sk_live_..."
#
# Po paleidimo: nukopijuok išvestį į main.js PAYMENT_LINKS objektą.

param(
  [Parameter(Mandatory=$true)][string]$Key
)

$ErrorActionPreference = "Stop"
$base = "https://api.stripe.com/v1"
$site = "https://reformwell.lt"

function Stripe($method, $path, $body) {
  $cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Key + ":"))
  $h = @{ Authorization = "Basic $cred" }
  if ($method -eq "POST") {
    Invoke-RestMethod -Uri "$base$path" -Method POST -Headers $h -ContentType "application/x-www-form-urlencoded" -Body $body
  } else {
    Invoke-RestMethod -Uri "$base$path" -Method GET -Headers $h
  }
}

function Enc($v) { [Uri]::EscapeDataString([string]$v) }

$SKUS = @(
  @{ sku="low-back-pain__short";      name="Juosmens skausmas — Palengvinimo ir atstatymo planas";      price=3900 }
  @{ sku="low-back-pain__long";       name="Juosmens skausmas — Reabilitacijos ir atsparumo programa";  price=8900 }
  @{ sku="neck-pain__short";          name="Kaklo skausmas — Palengvinimo ir atstatymo planas";          price=3900 }
  @{ sku="neck-pain__long";           name="Kaklo skausmas — Reabilitacijos ir atsparumo programa";      price=8900 }
  @{ sku="shoulder__short";           name="Peties skausmas — Palengvinimo ir atstatymo planas";         price=3900 }
  @{ sku="shoulder__long";            name="Peties skausmas — Reabilitacijos ir atsparumo programa";     price=8900 }
  @{ sku="knee-pain__short";          name="Kelio skausmas — Palengvinimo ir atstatymo planas";          price=3900 }
  @{ sku="knee-pain__long";           name="Kelio skausmas — Reabilitacijos ir atsparumo programa";      price=8900 }
  @{ sku="plantar-fasciitis__short";  name="Plantarinis fascitas — Palengvinimo ir atstatymo planas";    price=3900 }
  @{ sku="plantar-fasciitis__long";   name="Plantarinis fascitas — Reabilitacijos ir atsparumo programa";price=8900 }
  @{ sku="tennis-elbow__short";       name="Teniso alkūnė — Palengvinimo ir atstatymo planas";           price=3900 }
  @{ sku="tennis-elbow__long";        name="Teniso alkūnė — Reabilitacijos ir atsparumo programa";       price=8900 }
  @{ sku="hip-glute__short";          name="Klubo skausmas — Palengvinimo ir atstatymo planas";          price=3900 }
  @{ sku="hip-glute__long";           name="Klubo skausmas — Reabilitacijos ir atsparumo programa";      price=8900 }
  @{ sku="ankle-sprain__short";       name="Čiurnos patempimas — Palengvinimo ir atstatymo planas";      price=3900 }
  @{ sku="ankle-sprain__long";        name="Čiurnos patempimas — Reabilitacijos ir atsparumo programa";  price=8900 }
  @{ sku="all-access";                name="Reformwell — Visa biblioteka (16 programų)";                  price=14900 }
)

Write-Host "`n=== Reformwell LIVE Stripe setup ===" -ForegroundColor Cyan
Write-Host "Kuriama $($SKUS.Count) produktų...`n"

$results = @()

foreach ($item in $SKUS) {
  $sku  = $item.sku
  $name = $item.name
  $cents = $item.price
  $successUrl = "$site/download.html?sku=$(Enc $sku)"

  try {
    # 1. Produktas
    $prodBody = "name=$(Enc $name)&metadata[sku]=$(Enc $sku)"
    $prod = Stripe POST "/products" $prodBody
    $prodId = $prod.id

    # 2. Kaina
    $priceBody = "unit_amount=$cents&currency=eur&product=$(Enc $prodId)"
    $price = Stripe POST "/prices" $priceBody
    $priceId = $price.id

    # 3. Payment link
    $plBody = "line_items[0][price]=$(Enc $priceId)&line_items[0][quantity]=1" +
              "&after_completion[type]=redirect" +
              "&after_completion[redirect][url]=$(Enc $successUrl)" +
              "&payment_method_types[0]=card"
    $pl = Stripe POST "/payment_links" $plBody
    $url = $pl.url

    $results += [pscustomobject]@{ SKU=$sku; URL=$url; OK=$true }
    Write-Host ("OK  {0}" -f $sku) -ForegroundColor Green
  } catch {
    $results += [pscustomobject]@{ SKU=$sku; URL=""; OK=$false; Err=$_.Exception.Message }
    Write-Host ("ERR {0}: {1}" -f $sku, $_.Exception.Message) -ForegroundColor Red
  }
}

Write-Host "`n=== Nukopijuok į main.js PAYMENT_LINKS ===" -ForegroundColor Yellow
Write-Host "  var PAYMENT_LINKS = {"
foreach ($r in $results) {
  if ($r.OK) {
    Write-Host ('    "{0}": "{1}",' -f $r.SKU, $r.URL)
  } else {
    Write-Host ('    // KLAIDA: {0}' -f $r.SKU) -ForegroundColor Red
  }
}
Write-Host "  };"

$failed = $results | Where-Object { -not $_.OK }
if ($failed.Count -eq 0) {
  Write-Host "`nVisi $($SKUS.Count) produktai sukurti. Paleisk is naujo jei buvo klaidu." -ForegroundColor Green
} else {
  Write-Host "`n$($failed.Count) klaidos. Patikrink auksciau ir paleisk dar karta." -ForegroundColor Red
}
