# 그림을 8K 급으로 올린다 — Real-ESRGAN(ncnn-vulkan) 을 여러 번 통과시켜 긴 변이 Target(기본 7680) 이상이 되게 한다.
#
#   powershell -File tools\upscale-8k.ps1                                   # 캐릭터 폴더 전체(기본)
#   powershell -File tools\upscale-8k.ps1 -Src D:\new -Kind photo           # 사진·로고 글자는 photo(일반 모델)
#   powershell -File tools\upscale-8k.ps1 -Src D:\one -Include 'mascot*.png' -WorkWidth 640
#
# 통과 순서(320px 마스코트 기준): x4plus-anime ×4 → animevideov3-x3 ×3 → animevideov3-x2 ×2 = 7680.
#   첫 통과는 반드시 x4plus(-anime) — JPEG 잡음을 가장 잘 걷어 낸다. 뒤 통과는 가벼운 animevideov3 로 크기만 올린다.
#   남은 배수가 4 이상이면 ×4, 3 이면 ×3, 2 이하면 ×2 를 골라 Target 을 넘을 때까지 되풀이한다.
# 결과: <Out>\<이름>_8k.png (보관용, 장당 17~42 MB). 영상은 이것을 안 쓴다 — 매 프레임 줄여 그리면 4fps 가 된다(devlog 2026-09-22).
# 작업본: <Work>\<이름>.png — 1차 통과본을 WorkWidth(기본 640)로 줄인 것. 잡음은 빠지고 그리기엔 가볍다. 스크립트는 이것을 읽는다.
param(
  [string]$Src = 'C:\Users\info\Downloads\캐릭터',
  [string]$Out = "$PSScriptRoot\..\assets\hires",
  [string]$Work = "$PSScriptRoot\..\assets\work",
  [string[]]$Include = @('*.jpg', '*.jpeg', '*.png'),
  [ValidateSet('anime', 'photo')][string]$Kind = 'anime',   # anime: 마스코트·일러스트 / photo: 사진·로고 글자
  [int]$Target = 7680,
  [int]$WorkWidth = 640,
  [switch]$Force                                              # 이미 있는 8K 도 다시 만든다
)
$exe = "$PSScriptRoot\realesrgan\realesrgan-ncnn-vulkan.exe"
if (-not (Test-Path $exe)) { throw "Real-ESRGAN 이 없다 — tools\get-realesrgan.ps1 을 먼저 돌린다" }
New-Item -ItemType Directory -Force $Out, $Work | Out-Null
Add-Type -AssemblyName System.Drawing

function Up($in, $out, $model, $scale) {
  & $exe -i $in -o $out -n $model -s $scale 2>&1 | Out-Null
  if (-not (Test-Path $out)) { throw "실패: $in → $out ($model ×$scale)" }
}
function Dim($p) { $b = [System.Drawing.Image]::FromFile($p); $d = @($b.Width, $b.Height); $b.Dispose(); $d }
function Shrink($in, $out, $w) {
  $src = [System.Drawing.Image]::FromFile($in); if ($src.Width -le $w) { $src.Dispose(); Copy-Item $in $out -Force; return }
  $h = [int]($src.Height * $w / $src.Width); $b = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($b); $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'HighQuality'; $g.PixelOffsetMode = 'HighQuality'
  $g.DrawImage($src, 0, 0, $w, $h); $g.Dispose(); $b.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose(); $src.Dispose()
}
# 첫 통과 모델은 종류가 정한다. 뒤 통과는 배수를 미리 짠다 — {2,3,4} 를 최대 세 번 곱해 필요한 배수를 넘기되 가장 작게
# (320→1280 뒤 6배가 필요하면 ×3·×2 = 7680 딱 맞춤. ×4·×2 는 10240 으로 파일만 커진다).
$first = $(if ($Kind -eq 'anime') { 'realesrgan-x4plus-anime' } else { 'realesrgan-x4plus' })
function Model($s) { switch ($s) { 4 { if ($Kind -eq 'anime') { 'realesr-animevideov3-x4' } else { 'realesrgan-x4plus' } } 3 { 'realesr-animevideov3-x3' } default { 'realesr-animevideov3-x2' } } }
function Plan($longSide) {
  $need = $Target / $longSide; if ($need -le 1) { return @() }
  $best = $null
  foreach ($a in 2, 3, 4) { foreach ($b in 1, 2, 3, 4) { foreach ($c in 1, 2, 3, 4) {
    $p = $a * $b * $c; if ($p -lt $need) { continue }
    $seq = @($a, $b, $c) | Where-Object { $_ -gt 1 }
    if ($null -eq $best -or $p -lt $best.P -or ($p -eq $best.P -and $seq.Count -lt $best.Seq.Count)) { $best = @{ P = $p; Seq = $seq } } } } }
  if ($null -eq $best) { throw "세 번 통과로는 $Target 에 못 미친다(원본 긴 변 $longSide)" }
  $best.Seq
}

$tmp = "$env:TEMP\up8k"; New-Item -ItemType Directory -Force $tmp | Out-Null
$sw = [Diagnostics.Stopwatch]::StartNew(); $files = @(Get-ChildItem (Join-Path $Src '*') -File -Include $Include | Where-Object { $_.Name -notmatch '_8k\.png$' })   # -Include 는 경로 끝에 * 가 있어야 먹는다
if ($files.Count -eq 0) { "대상 없음: $Src ($($Include -join ', '))"; return }
foreach ($f in $files) {
  $n = $f.BaseName; $final = Join-Path $Out "${n}_8k.png"
  if ((Test-Path $final) -and -not $Force) { "[$([int]$sw.Elapsed.TotalSeconds)s] $n — 이미 있음(-Force 로 다시)"; continue }
  "[$([int]$sw.Elapsed.TotalSeconds)s] $n  $((Dim $f.FullName) -join 'x')"
  $cur = Join-Path $tmp "$n-1.png"; Up $f.FullName $cur $first 4
  Shrink $cur (Join-Path $Work "$n.png") $WorkWidth
  $k = 1; $d = Dim $cur; $seq = Plan ([Math]::Max($d[0], $d[1]))
  foreach ($s in $seq) { $k++; $next = Join-Path $tmp "$n-$k.png"; Up $cur $next (Model $s) $s; $cur = $next }
  Move-Item $cur $final -Force
  "  → $((Dim $final) -join 'x')  $([int]((Get-Item $final).Length/1MB)) MB  (×4 → $(($seq | % { "×$_" }) -join ' → '))  · 작업본 $((Dim (Join-Path $Work "$n.png")) -join 'x')"
}
Remove-Item $tmp -Recurse -Force -EA SilentlyContinue
"done $([int]$sw.Elapsed.TotalSeconds)s  → $Out"
