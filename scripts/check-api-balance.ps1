# 各 API 余额/可用性检查（全矩阵，含充值链接）
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File check-api-balance.ps1 [-Threshold 5] [-Popup]
param([double]$Threshold = 5, [switch]$Popup)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$logFile = Join-Path $PSScriptRoot 'balance-watch.log'
$stateFile = Join-Path $PSScriptRoot 'balance-state.json'
$report = @()
function Get-EnvVal($file, $name) {
  $raw = Get-Content $file -Raw
  $m = [regex]::Match($raw, $name + '\s*=\s*([^\r\n]+)')
  if ($m.Success) { return $m.Groups[1].Value.Trim() }
  return ''
}
function Add-Report($api, $text, $level, $url) {
  $script:report += [pscustomobject]@{ api = $api; text = $text; level = $level; url = $url }
  Write-Output $text
}
function Alert($msg) {
  Add-Content $logFile ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $msg)
  if ($Popup) { try { msg.exe $env:USERNAME $msg 2>$null } catch {} }
}
# 充值链接
$URL_DS = 'https://platform.deepseek.com/top_up'
$URL_BAILIAN = 'https://expense.console.aliyun.com/'
$URL_SHEAPI = 'https://www.sheapi.top/'
$URL_FEIXUE = 'https://feixueapi.xyz/'
$URL_TRIPO = 'https://platform.tripo3d.ai/'
# ---------- 1. DeepSeek 官方 ----------
$dsKey = Get-EnvVal 'D:\deepseek\.env' 'DEEPSEEK_API_KEY'
if ($dsKey) {
  $resp = curl.exe -s -m 20 'https://api.deepseek.com/user/balance' -H ("Authorization: Bearer " + $dsKey) 2>$null
  try {
    $j = $resp | ConvertFrom-Json
    if ($j.balance_infos -and $j.balance_infos.Count -gt 0) {
      $bal = [double]$j.balance_infos[0].total_balance
      $lv = 'ok'
      if ($bal -lt $Threshold) { $lv = 'warn'; Alert ("DeepSeek API 余额 ¥" + $bal.ToString('0.00') + "，已低于 ¥" + $Threshold + "，请及时充值！") }
      Add-Report 'DeepSeek' ("DeepSeek 余额: ¥" + $bal.ToString('0.00')) $lv $URL_DS
    } else { Add-Report 'DeepSeek' 'DeepSeek: 查询失败（响应异常）' 'bad' $URL_DS }
  } catch { Add-Report 'DeepSeek' 'DeepSeek: 查询失败（接口不可达/Key 失效）' 'bad' $URL_DS }
} else { Add-Report 'DeepSeek' 'DeepSeek: 未找到 Key' 'bad' $URL_DS }
# ---------- 2. 阿里百炼 DashScope（视觉） ----------
$seeKey = Get-EnvVal 'C:\Users\刘健鹏\.config\see\config.env' 'SEE_API_KEY'
if ($seeKey) {
  $r = curl.exe -s -m 15 -X POST 'https://dashscope.aliyuncs.com/api/v1/tokens' -H ("Authorization: Bearer " + $seeKey) -H 'Content-Type: application/json' -d '{}' 2>$null
  if ($r -match '"token"') { Add-Report '阿里百炼' '阿里百炼(视觉): Key 有效' 'ok' $URL_BAILIAN }
  else { Add-Report '阿里百炼' '阿里百炼(视觉): Key 失效' 'bad' $URL_BAILIAN; Alert '阿里百炼 DashScope 视觉 Key 失效，请检查 ~/.config/see/config.env' }
} else { Add-Report '阿里百炼' '阿里百炼(视觉): 未找到 Key' 'bad' $URL_BAILIAN }
# ---------- 3. sheapi.top（Codex 中转，需代理） ----------
$oaKey = ''
try { $oaKey = (Get-Content 'C:\Users\刘健鹏\.codex\auth.json' -Raw | ConvertFrom-Json).OPENAI_API_KEY } catch {}
if ($oaKey) {
  $code = curl.exe -s -o NUL -w '%{http_code}' -m 15 -x 'http://127.0.0.1:7897' 'https://www.sheapi.top/v1/dashboard/billing/credit_grants' -H ("Authorization: Bearer " + $oaKey) 2>$null
  if ($code -eq '000') { Add-Report 'sheapi.top' 'sheapi.top(Codex): 不可达' 'bad' $URL_SHEAPI; Alert 'sheapi.top 中转连不上了（Codex 可能无法使用），检查 Clash 代理与服务状态' }
  elseif ($code -eq '401' -or $code -eq '403') { Add-Report 'sheapi.top' 'sheapi.top(Codex): Key 失效' 'bad' $URL_SHEAPI; Alert 'sheapi.top 的 Key 失效（401/403），请更新 ~/.codex/auth.json' }
  else { Add-Report 'sheapi.top' ("sheapi.top(Codex): 可达 HTTP " + $code) 'ok' $URL_SHEAPI }
} else { Add-Report 'sheapi.top' 'sheapi.top(Codex): 未找到 Key' 'bad' $URL_SHEAPI }
# ---------- 4. feixueapi.xyz（Claude 中转） ----------
$code = curl.exe -s -o NUL -w '%{http_code}' -m 15 'https://feixueapi.xyz/v1/models' 2>$null
if ($code -eq '000') { Add-Report '飞雪' 'feixueapi.xyz(飞雪): 站点不可达' 'bad' $URL_FEIXUE; Alert '飞雪 feixueapi.xyz 站点连不上了' }
elseif ($code -eq '401' -or $code -eq '403') { Add-Report '飞雪' 'feixueapi.xyz(飞雪): 站点可达，Key 未存本机' 'warn' $URL_FEIXUE }
else { Add-Report '飞雪' ("feixueapi.xyz(飞雪): 可达 HTTP " + $code) 'ok' $URL_FEIXUE }
# ---------- 5. Tripo（3D） ----------
$tripKey = Get-EnvVal 'C:\Users\刘健鹏\.codex\.env' 'TRIPO_API_KEY'
if ($tripKey) {
  $code = curl.exe -s -o NUL -w '%{http_code}' -m 15 'https://platform.tripo3d.ai/v1/tasks?limit=1' -H ("Authorization: Bearer " + $tripKey) 2>$null
  if ($code -eq '200') { Add-Report 'Tripo' 'Tripo(3D): Key 有效' 'ok' $URL_TRIPO }
  elseif ($code -eq '401' -or $code -eq '403') { Add-Report 'Tripo' 'Tripo(3D): Key 失效' 'bad' $URL_TRIPO; Alert 'Tripo 3D 的 Key 失效，请检查 ~/.codex/.env' }
  else { Add-Report 'Tripo' ("Tripo(3D): 探测异常 HTTP " + $code) 'warn' $URL_TRIPO }
} else { Add-Report 'Tripo' 'Tripo(3D): 未找到 Key' 'bad' $URL_TRIPO }
# ---------- 状态文件（悬浮窗数据源） ----------
$state = [pscustomobject]@{
  updated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  threshold = $Threshold
  items = $report
}
$state | ConvertTo-Json -Depth 3 | Set-Content $stateFile -Encoding UTF8
