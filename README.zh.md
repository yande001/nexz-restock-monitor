# NEXZ 髮夾補貨監控

監看 [JYP 日本官方商店](https://jypj-store.com)，**一偵測到售完的 NEXZ『LIVE TOUR 2026』髮夾
重新有貨，立刻寄 Email 通知你。**

程式每 10 秒輪詢 7 款髮夾（YUTiE、PPOMOYA、HYUROMI、SEIDEE、GEONSKY、HARUBEAR、JELLY-YU）。
FOX2Y 因為原本就有貨而被排除——要更改清單請編輯腳本。

[English README](./README.md)

## 運作原理

這間商店是用 **Shopify** 架設的，而 Shopify 為每項商品都提供一個隱藏的 JSON 端點：

```
https://jypj-store.com/products/<handle>.js  ->  { ... "available": true/false ... }
```

這個 `available` 布林值，正是商店自己「加入購物車」按鈕使用的同一個旗標——比起去爬 HTML 頁面
上的「Sold Out」文字（會因用字／翻譯改變而失效）可靠得多。監控程式只要輪詢這些極小的 JSON
端點，當任一項翻成 `true` 就寄信給你。

完整設計說明請見 [restock_monitor_explained.zh.md](./restock_monitor_explained.zh.md)。

## 需求

- `bash`、`curl`、`python3`（3.6+）——皆為標準工具。**不需要 `pip install`**（僅用 Python
  標準函式庫）。
- 一個用來寄信的 **Gmail 帳號**，並已啟用兩步驟驗證。

## 安裝設定

1. **下載：**
   ```bash
   git clone https://github.com/yande001/nexz-restock-monitor.git
   cd nexz-restock-monitor
   ```

2. **建立 Gmail 應用程式密碼**：前往 <https://myaccount.google.com/apppasswords>
   （需先啟用兩步驟驗證），會得到一組 16 碼密碼，形如 `abcd efgh ijkl mnop`。

3. **設定帳密：**
   ```bash
   cp mail.cfg.example mail.cfg
   ```
   編輯 `mail.cfg`：
   ```
   GMAIL_USER=你的信箱@gmail.com
   GMAIL_APP_PW=abcdefghijklmnop      # 16 碼，去掉空白
   MAIL_TO=要收通知的信箱@example.com
   ```
   `mail.cfg` 已被 gitignore，絕不會被提交。

4. **寄一封測試信** 確認可用：
   ```bash
   python3 send_mail.py "測試" "如果你收到這封，代表 Email 通知正常。"
   ```
   應會看到 `sent ok` 並收到信（也檢查一下垃圾信匣）。

## 執行

前景執行（Ctrl-C 停止）：
```bash
bash restock_monitor.sh
```

背景執行，關掉終端機也持續：
```bash
nohup bash restock_monitor.sh > /dev/null 2>&1 &
```

進度會附加寫入 `restock.log`：
```bash
tail -f restock.log
```

腳本在找到補貨（並寄信）後即結束，或在約 12 小時的安全上限（`MAX_ITERS=4320`）後結束。重新
執行即可繼續監看。

### 讓它持續運作（選用）

**cron** — 每次開機自動啟動：
```cron
@reboot cd /path/to/nexz-restock-monitor && nohup bash restock_monitor.sh >> restock.log 2>&1 &
```

**systemd 使用者服務** — `~/.config/systemd/user/nexz-restock.service`：
```ini
[Unit]
Description=NEXZ restock monitor

[Service]
WorkingDirectory=/path/to/nexz-restock-monitor
ExecStart=/usr/bin/bash restock_monitor.sh
Restart=on-success   # 找到補貨 -> exit 0 -> 重啟以繼續監看其他款

[Install]
WantedBy=default.target
```
```bash
systemctl --user daemon-reload && systemctl --user enable --now nexz-restock
```

## 自訂監看商品

編輯 `restock_monitor.sh` 裡的 `NAMES` 對照表。每一筆是 Shopify 商品 **handle**（商品網址
`/products/<handle>` 的最後一段）對應一個顯示名稱。要找 handle，打開商品頁複製網址最後一段，
或查看 `https://jypj-store.com/products/<handle>.js`。

## 限制

- **非事件驅動。** 10 秒輪詢代表最多有 10 秒延遲；Shopify 對買家沒有公開的 webhook。
- **只在程式運作期間有效。** 需要開機後自動復原請用上面的 cron／systemd 方式。
- **故障時偏安全。** 若商店做速率限制或回應錯誤，該輪會被視為「售完」並重試——可能漏掉一次
  檢查，但絕不會寄出「假補貨」通知。

## 安全性

你的 Gmail 應用程式密碼只存在本機的 `mail.cfg`（已被 gitignore）。萬一外洩，到
<https://myaccount.google.com/apppasswords> 撤銷即可——應用程式密碼可單獨撤銷，不必更動你的
主要 Google 密碼。

## 授權

[MIT](./LICENSE)
