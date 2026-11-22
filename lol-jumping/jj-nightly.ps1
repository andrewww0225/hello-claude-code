# 每晚 22:00 由「工作排程器」執行：英雄聯盟客戶端開著才跑 jj.ps1 -Push，結果寫進 jj.log
$log = Join-Path $PSScriptRoot 'jj.log'
function Write-Log($msg) { "$((Get-Date).ToString('yyyy-MM-dd HH:mm'))  $msg" | Out-File $log -Append -Encoding utf8 }

if (-not (Get-Process LeagueClientUx -ErrorAction SilentlyContinue)) { Write-Log '客戶端沒開，跳過。'; return }

try {
  $out = & (Join-Path $PSScriptRoot 'jj.ps1') -Push *>&1 | Out-String
  Write-Log ("執行 jj.ps1 -Push：`r`n" + $out.TrimEnd())
} catch {
  Write-Log "出錯：$($_.Exception.Message)"
}
