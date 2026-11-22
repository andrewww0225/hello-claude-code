# 開合跳帳本：英雄聯盟輸一局 = 10 下開合跳
# 用法（英雄聯盟客戶端要開著）：
#   .\jj.ps1          同步最近 20 場，記下新的輸場，更新網站用的 fitness\jj.json（不推送）
#   .\jj.ps1 -Push    同上，再把 jj.json 單獨 commit 並推到 GitHub，彈力帶 app 就看得到
#   .\jj.ps1 status   只看本機帳本，不連客戶端
# 做了幾下開合跳在彈力帶 app 裡記，這裡只算「應做幾下」。
# lockfile 密碼只在記憶體使用，不印出、不存檔。每場的英雄和 KDA 只存在本機 games.csv，
# 推上公開 repo 的 jj.json 只有累計數字。
param([string]$Cmd = 'sync', [switch]$Push,
      [string]$Data = $PSScriptRoot,
      [string]$Site = 'D:\學校\專題\查證工具\evidence-mirror',
      [string]$Dir  = 'D:\Riot Games\League of Legends')

$PerLoss = 10
$MinSec  = 480   # 未滿 8 分鐘的場次不算
$ledger = Join-Path $Data 'games.csv'   # 每場一列；Counted=0 表示起算前的場次

function Get-Losses {
  if (-not (Test-Path $ledger)) { return 0 }
  @(Import-Csv $ledger -Encoding UTF8 | Where-Object { $_.Counted -eq '1' -and $_.Result -eq 'L' }).Count
}

if ($Cmd -eq 'status') { $l = Get-Losses; "計入的輸場：$l 場 → 應做 $($l * $PerLoss) 下（做了幾下看彈力帶 app）"; return }

# ---- 同步 ----
if (-not (Test-Path "$Dir\lockfile")) { "找不到 lockfile：英雄聯盟客戶端沒開？"; return }
$fs = [IO.File]::Open("$Dir\lockfile", 'Open', 'Read', 'ReadWrite')
$sr = New-Object IO.StreamReader($fs); $parts = $sr.ReadToEnd().Split(':'); $sr.Close()
$port = $parts[2]; $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("riot:$($parts[3])"))
$parts = $null

if (-not ('LcuTrust' -as [type])) {
Add-Type @"
using System.Net; using System.Security.Cryptography.X509Certificates;
public class LcuTrust : ICertificatePolicy { public bool CheckValidationResult(ServicePoint a, X509Certificate b, WebRequest c, int d) { return true; } }
"@ }
[Net.ServicePointManager]::CertificatePolicy = New-Object LcuTrust   # 只連 127.0.0.1 的客戶端自簽憑證
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$h = @{ Authorization = "Basic $auth" }
function Get-Lcu($path) {
  $r = Invoke-WebRequest -UseBasicParsing -Uri "https://127.0.0.1:$port$path" -Headers $h
  [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
}

$champ = @{}; (Get-Lcu '/lol-game-data/assets/v1/champion-summary.json') | ForEach-Object { $champ[[int]$_.id] = $_.name }
$r = Get-Lcu '/lol-match-history/v1/products/lol/current-summoner/matches?begIndex=0&endIndex=19'
$fetched = @(@($r.games.games) | Where-Object { $_ -and $_.gameId }) | Sort-Object gameCreation
if (-not $fetched.Count) { "客戶端沒有回傳任何場次，這次不更新。"; return }

$first = -not (Test-Path $ledger)
$known = @{}; if (-not $first) { Import-Csv $ledger -Encoding UTF8 | ForEach-Object { $known[$_.GameId] = 1 } }

# 帳本有資料、但抓到的 20 場全是新的：上次同步後可能打了超過 20 場
if (-not $first -and $fetched.Count -ge 20 -and -not ($fetched | Where-Object { $known["$($_.gameId)"] })) {
  "⚠ 抓到的 20 場都沒在帳本裡：上次同步後可能打了超過 20 場，更早的輸場會漏算。"
}

$new = @(foreach ($g in $fetched) {
  if ($known["$($g.gameId)"]) { continue }
  $p = $g.participants[0]; $s = $p.stats
  [pscustomobject]@{
    GameId  = "$($g.gameId)"
    Date    = ([DateTimeOffset]::FromUnixTimeMilliseconds($g.gameCreation)).ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd HH:mm')
    Champ   = $champ[[int]$p.championId]
    Result  = if ($s.win) { 'W' } else { 'L' }
    KDA     = "$($s.kills)/$($s.deaths)/$($s.assists)"
    Min     = [math]::Floor($g.gameDuration / 60)
    # 起算前的場次、未滿 8 分鐘的場次（重開局等）都不算
    Counted = if ($first -or $g.gameDuration -lt $MinSec) { '0' } else { '1' }
  }
})
if ($new.Count) { $new | Export-Csv $ledger -Append -NoTypeInformation -Encoding UTF8 }

if ($first) { "第一次執行：記下現有 $($new.Count) 場當起點（不計入），之後的新場次才算。" }
elseif ($new.Count -eq 0) { "沒有新場次。" }
else {
  "新場次 $($new.Count) 場："
  $new | ForEach-Object { "  $($_.Date)  $($_.Champ)  $($_.Result)  $($_.KDA)  $($_.Min) 分" +
    $(if ($_.Counted -ne '1') { "  （未滿 8 分鐘，不算）" } elseif ($_.Result -eq 'L') { "  → +$PerLoss 下" } else { '' }) }
}

# ---- 寫網站用的 jj.json（只有累計數字；輸場數沒變就不改檔，避免只為時間戳記提交） ----
$losses = Get-Losses
$out = Join-Path $Site 'fitness\jj.json'
$old = $null; try { $old = Get-Content $out -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
if ($old -and $old.losses -eq $losses) {
  "累計輸 $losses 場 → 應做 $($losses * $PerLoss) 下（和網站上的一樣，jj.json 不用改）"
} else {
  $json = [ordered]@{ perLoss = $PerLoss; losses = $losses; owed = $losses * $PerLoss
                      updated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz') } | ConvertTo-Json -Compress
  [IO.File]::WriteAllText($out, $json, (New-Object Text.UTF8Encoding($false)))
  "累計輸 $losses 場 → 應做 $($losses * $PerLoss) 下。已寫入 $out"
}

if (-not $Push) { "（沒有加 -Push，所以還沒推上 GitHub）"; return }

# ---- 推送：只 commit jj.json；網站資料夾若有其他沒推的提交就停下，不連帶推出去 ----
$branch = git -C $Site rev-parse --abbrev-ref HEAD
if ($branch -ne 'main') { "⚠ 網站資料夾目前在 $branch 分支，不是 main，這次不推。"; return }
git -C $Site fetch -q origin
$ahead = git -C $Site rev-list --count origin/main..HEAD
if ($LASTEXITCODE -ne 0) { "⚠ 讀不到 origin/main，這次不推。"; return }
if ([int]$ahead -gt 0) { "⚠ 網站資料夾已有 $ahead 個沒推的提交，為了不連帶推出去，這次不推。"; return }
if ([int](git -C $Site rev-list --count HEAD..origin/main) -gt 0) { "⚠ GitHub 上有比本機新的提交，請先在網站資料夾 git pull 再跑。"; return }
if (-not (git -C $Site status --porcelain -- fitness/jj.json)) { "jj.json 沒有變動，不用推。"; return }
git -C $Site add -- fitness/jj.json
git -C $Site commit -q -m "jj: $losses losses" -- fitness/jj.json
if ($LASTEXITCODE -ne 0) { "commit 失敗，沒有推送。"; return }
git -C $Site push -q origin HEAD:main
if ($LASTEXITCODE -eq 0) { "已推上 GitHub，app 大約 10 分鐘內會看到新數字。" }
else { git -C $Site reset -q --soft HEAD~1; "推送失敗（上面有錯誤訊息），已撤回這次的 commit，下次再跑即可。" }
