# obs-websocket v5 minimal client (PowerShell 5.1)
function Obs-Recv($ws) {
  $buf = New-Object byte[] 262144
  $ms = New-Object IO.MemoryStream
  do {
    $seg = New-Object System.ArraySegment[byte] -ArgumentList (,$buf)
    $r = $ws.ReceiveAsync($seg, [Threading.CancellationToken]::None).Result
    $ms.Write($buf, 0, $r.Count)
  } while (-not $r.EndOfMessage)
  $txt = [Text.Encoding]::UTF8.GetString($ms.ToArray())
  return ($txt | ConvertFrom-Json)
}
function Obs-Send($ws, $obj) {
  $json = $obj | ConvertTo-Json -Depth 8 -Compress
  $b = [Text.Encoding]::UTF8.GetBytes($json)
  $seg = New-Object System.ArraySegment[byte] -ArgumentList (,$b)
  $ws.SendAsync($seg, [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait()
}
function Obs-Connect([int]$port, [string]$password) {
  $ws = New-Object Net.WebSockets.ClientWebSocket
  $ws.ConnectAsync([Uri]"ws://127.0.0.1:$port", [Threading.CancellationToken]::None).Wait()
  $hello = Obs-Recv $ws
  $ident = @{ op = 1; d = @{ rpcVersion = 1; eventSubscriptions = 0 } }
  if ($hello.d.authentication) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $secret = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($password + $hello.d.authentication.salt)))
    $auth = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($secret + $hello.d.authentication.challenge)))
    $ident.d.authentication = $auth
  }
  Obs-Send $ws $ident
  $idd = Obs-Recv $ws
  if ($idd.op -ne 2) { throw "obs identify failed: $($idd | ConvertTo-Json -Compress)" }
  return $ws
}
$script:obsReqId = 0
function Obs-Request($ws, [string]$type, $data) {
  $script:obsReqId++
  $id = "r$($script:obsReqId)"
  $req = @{ op = 6; d = @{ requestType = $type; requestId = $id } }
  if ($data) { $req.d.requestData = $data }
  Obs-Send $ws $req
  for ($i = 0; $i -lt 50; $i++) {
    $m = Obs-Recv $ws
    if ($m.op -eq 7 -and $m.d.requestId -eq $id) { return $m.d }
  }
  throw "obs: no response for $type"
}
function Obs-Close($ws) { try { $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'bye', [Threading.CancellationToken]::None).Wait(3000) } catch {} }
