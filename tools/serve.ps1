# 폴더 하나를 http://127.0.0.1:8765/ 로 내놓는다(Range 지원) — 브라우저에서 MP4 를 돌려 보며 프레임을 확인할 때 쓴다. Ctrl+C 로 끝낸다.
param([string]$Root = "$env:USERPROFILE\Videos", [int]$Port = 8765)
$l = New-Object Net.HttpListener; $l.Prefixes.Add("http://127.0.0.1:$Port/"); $l.Start(); "serving $Root on http://127.0.0.1:$Port/"
while ($l.IsListening) {
  $c = $l.GetContext(); $req = $c.Request; $res = $c.Response
  try {
    $rel = [Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/')); $path = Join-Path $Root $rel
    if ($rel -eq '' -or -not (Test-Path $path -PathType Leaf)) { $res.StatusCode = 404; $res.Close(); continue }
    $fi = Get-Item $path; $len = $fi.Length; $start = 0; $end = $len - 1
    $res.ContentType = $(if ($fi.Extension -eq '.mp4') { 'video/mp4' } elseif ($fi.Extension -eq '.html') { 'text/html; charset=utf-8' } else { 'application/octet-stream' })
    $res.Headers['Accept-Ranges'] = 'bytes'
    $range = $req.Headers['Range']
    if ($range -and $range -match 'bytes=(\d*)-(\d*)') { if ($Matches[1]) { $start = [long]$Matches[1] }; if ($Matches[2]) { $end = [long]$Matches[2] }; if ($end -ge $len) { $end = $len - 1 }; $res.StatusCode = 206; $res.Headers['Content-Range'] = "bytes $start-$end/$len" }
    $count = $end - $start + 1; $res.ContentLength64 = $count
    $fs = [IO.File]::OpenRead($path); $fs.Position = $start; $buf = New-Object byte[] 65536; $left = $count
    while ($left -gt 0) { $n = $fs.Read($buf, 0, [Math]::Min($buf.Length, $left)); if ($n -le 0) { break }; $res.OutputStream.Write($buf, 0, $n); $left -= $n }
    $fs.Close(); $res.Close()
  } catch { try { $res.Close() } catch {} }
}
