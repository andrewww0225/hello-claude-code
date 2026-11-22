# 開合跳帳本

和朋友的約定：英雄聯盟輸一局，做 10 下開合跳。這個資料夾從電腦上的英雄聯盟客戶端抓戰績、算出欠幾下，再交給彈力帶 app 顯示。

## 規則

- 輸一局 = 10 下，所有模式都算。
- 未滿 8 分鐘的場次（重開局等）不算，贏輸都一樣。
- 2026-11-22 第一次執行時，客戶端裡已有的 20 場（11/20–11/21）記成起點，不算欠款。

## 怎麼運作

1. `jj.ps1` 讀客戶端最近 20 場（客戶端一次最多給 20 場），把沒看過的場次加進 `games.csv`。
2. 算出累計輸幾場、應做幾下，寫進彈力帶 app 的 `fitness/jj.json`。這個檔案在公開 repo `andrewww0225/andrewww`（本機是 `D:\學校\專題\查證工具\evidence-mirror`），所以只放累計數字，不放英雄或 KDA。
3. 加 `-Push` 時，只 commit `jj.json` 並推上 GitHub。網站資料夾不在 `main`、有別的沒推的提交、或 GitHub 上比本機新的時候，會停下不推。推送失敗會撤回那次 commit。
4. 彈力帶 app 首頁的「開合跳」卡片讀 `jj.json`，顯示「還欠 N 下」。做了幾下在 app 裡按，存在那臺手機上。

## 檔案

| 檔案 | 內容 |
|---|---|
| `jj.ps1` | 同步、寫 `jj.json`、推送 |
| `jj-nightly.ps1` | 給排程用：客戶端開著才跑 `jj.ps1 -Push`，結果寫進 `jj.log` |
| `games.csv` | 每場一列（英雄、勝負、KDA、分鐘、是否計入）。只在本機，不進 git |
| `jj.log` | 每晚排程的執行紀錄。只在本機，不進 git |

## 手動執行

這臺電腦的 PowerShell 預設禁止執行腳本，所以要加 `-ExecutionPolicy Bypass`：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Claude Code\lol-jumping\jj.ps1" -Push
```

不加 `-Push` 只更新本機、不推送；把 `-Push` 換成 `status` 只看本機帳本。

## 每晚自動同步

Windows 工作排程器裡的「LoL 開合跳同步」每天 22:00 執行 `jj-nightly.ps1`。客戶端沒開就跳過；電腦關機或睡眠時那天不補跑。看結果：打開 `jj.log`。

停掉：在工作排程器裡停用它，或

```powershell
Unregister-ScheduledTask -TaskName 'LoL 開合跳同步' -Confirm:$false
```

## 限制

- 兩次同步之間打超過 20 場，更早的場次抓不到（會在輸出裡警告）。
- `games.csv` 被刪掉的話，下次執行會重新當成第一次，欠款歸零。
- 讀客戶端用的是非官方的本機介面，遊戲改版後可能失效。
