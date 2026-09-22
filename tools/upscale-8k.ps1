# 자료 그림을 8K 급으로 올린다 — Real-ESRGAN(ncnn-vulkan) 세 번 통과: ×4 (x4plus-anime) → ×3 (animevideov3-x3) → ×2 (animevideov3-x2)
# 320px 마스코트 → 1280 → 3840 → 7680.  배지(554px)는 글자라 일반 모델 x4plus 두 번 → 8864.
# 영상용 작업본은 1차 통과본(1280)을 640 으로 줄인 PNG — JPEG 잡음은 빠지고, 매 프레임 그리기엔 가볍다.
param(
  [string]$Src = 'C:\Users\info\Downloads\캐릭터',
  [string]$Out = "$PSScriptRoot\..\assets\hires",
  [string]$Work = "$PSScriptRoot\..\assets\work"
)
$exe = "$PSScriptRoot\realesrgan\realesrgan-ncnn-vulkan.exe"
New-Item -ItemType Directory -Force $Out, $Work | Out-Null
Add-Type -AssemblyName System.Drawing
function Up($in, $out, $model, $scale) { & $exe -i $in -o $out -n $model -s $scale 2>&1 | Out-Null; if (-not (Test-Path $out)) { throw "실패: $in → $out ($model)" } }
function Size($p) { $b = [System.Drawing.Image]::FromFile($p); $s = "$($b.Width)x$($b.Height)"; $b.Dispose(); $s }
function Shrink($in, $out, $w) { $src = [System.Drawing.Image]::FromFile($in); $h = [int]($src.Height * $w / $src.Width); $b = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($b); $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'HighQuality'; $g.PixelOffsetMode = 'HighQuality'; $g.DrawImage($src, 0, 0, $w, $h); $g.Dispose(); $b.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose(); $src.Dispose() }
$tmp = "$env:TEMP\up8k"; New-Item -ItemType Directory -Force $tmp | Out-Null
$sw = [Diagnostics.Stopwatch]::StartNew()
foreach ($f in (Get-ChildItem "$Src\다운로드*.jpg")) {
  $n = $f.BaseName; "[$([int]$sw.Elapsed.TotalSeconds)s] $n"
  Up $f.FullName "$tmp\$n-1.png" realesrgan-x4plus-anime 4
  Shrink "$tmp\$n-1.png" "$Work\$n.png" 640
  Up "$tmp\$n-1.png" "$tmp\$n-2.png" realesr-animevideov3-x3 3
  Up "$tmp\$n-2.png" "$Out\${n}_8k.png" realesr-animevideov3-x2 2
  "  → $(Size "$Out\${n}_8k.png")  $([int]((Get-Item "$Out\${n}_8k.png").Length/1MB)) MB  · 작업본 $(Size "$Work\$n.png")"
}
$badge = "$Src\autodesk gold partner logo.png"
if (Test-Path $badge) { "[$([int]$sw.Elapsed.TotalSeconds)s] gold partner"
  Up $badge "$tmp\badge-1.png" realesrgan-x4plus 4
  Shrink "$tmp\badge-1.png" "$Work\autodesk gold partner logo.png" 1108
  Up "$tmp\badge-1.png" "$Out\autodesk_gold_partner_8k.png" realesrgan-x4plus 4
  "  → $(Size "$Out\autodesk_gold_partner_8k.png")  $([int]((Get-Item "$Out\autodesk_gold_partner_8k.png").Length/1MB)) MB" }
"done $([int]$sw.Elapsed.TotalSeconds)s"
