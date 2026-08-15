# 阿里云账户余额查询（BSS QueryAccountBalance）
# 读取 D:\deepseek\scripts\aliyun-ak.conf（ACCESS_KEY_ID / ACCESS_KEY_SECRET）或环境变量
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$conf = 'D:\deepseek\scripts\aliyun-ak.conf'
$ak = $env:ALIBABA_CLOUD_ACCESS_KEY_ID
$sk = $env:ALIBABA_CLOUD_ACCESS_KEY_SECRET
if (-not $ak -and (Test-Path $conf)) {
  $c = Get-Content $conf -Raw
  $ak = ([regex]::Match($c, 'ACCESS_KEY_ID\s*=\s*([^\r\n]+)')).Groups[1].Value.Trim()
  $sk = ([regex]::Match($c, 'ACCESS_KEY_SECRET\s*=\s*([^\r\n]+)')).Groups[1].Value.Trim()
}
if (-not $ak -or -not $sk) {
  Write-Output 'ALIYUN: 未配置 AccessKey'
  exit 0
}
function Encode-URI($s) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($b in [System.Text.Encoding]::UTF8.GetBytes([string]$s)) {
    $ch = [char]$b
    if ($ch -match '[A-Za-z0-9\-_.~]') { [void]$sb.Append($ch) } else { [void]$sb.Append(('%{0:X2}' -f $b)) }
  }
  $sb.ToString()
}
$params = [ordered]@{
  AccessKeyId = $ak
  Action = 'QueryAccountBalance'
  Format = 'JSON'
  SignatureMethod = 'HMAC-SHA1'
  SignatureNonce = [guid]::NewGuid().ToString('N')
  SignatureVersion = '1.0'
  Timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
  Version = '2017-12-14'
}
$canon = ($params.GetEnumerator() | Sort-Object Name | ForEach-Object { (Encode-URI $_.Key) + '=' + (Encode-URI ([string]$_.Value)) }) -join '&'
$stringToSign = 'GET&%2F&' + (Encode-URI $canon)
$hmac = New-Object System.Security.Cryptography.HMACSHA1
$hmac.Key = [System.Text.Encoding]::UTF8.GetBytes([string]$sk + '&')
$sig = [Convert]::ToBase64String($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign)))
$url = 'https://business.aliyuncs.com/?' + $canon + '&Signature=' + (Encode-URI $sig)
$resp = curl.exe -s -m 20 $url
try {
  $j = $resp | ConvertFrom-Json
  if ($j.Data -and $j.Data.AvailableAmount) {
    $b = $j.Data
    Write-Output ("ALIYUN: 账户余额 ¥" + $b.AvailableAmount + "（现金 " + $b.AvailableCashAmount + " 信用 " + $b.CreditAmount + "）")
  } else {
    Write-Output ('ALIYUN: 查询失败 ' + ($j.Code) + ' ' + ($j.Message))
    exit 1
  }
} catch {
  Write-Output 'ALIYUN: 查询失败（接口不可达）'
  exit 1
}
