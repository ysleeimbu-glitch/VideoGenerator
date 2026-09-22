# Real-ESRGAN(ncnn-vulkan) 휴대판을 받아 tools\realesrgan\ 에 푼다 — 43 MB, 설치 없음, GPU(Vulkan)로 돈다.
# 저장소에는 넣지 않는다(이진 51 MB). upscale-8k.ps1 이 이 폴더를 본다.
$url = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip'
$zip = "$env:TEMP\realesrgan.zip"; [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath "$PSScriptRoot\realesrgan" -Force
"ok: $PSScriptRoot\realesrgan\realesrgan-ncnn-vulkan.exe"
