# WonderKidAI Server Protection Layer

這份範本是給你的 backend repo 用的，不是目前 iOS app 直接可用的 drop-in 替換。重點是把現在「client 直接轉發 OpenAI body」改成「server 自己決定 plan、quota、model、TTS 參數」。

## 這層保護處理什麼

- 免費版每種語言各 `3` 次 / 日
- `pro` 無限問，但保留 rate limit 防濫用
- `/api/chat` 不接受任意 OpenAI body，只接受 app-level request
- `/api/speech` 不接受任意 TTS 參數，只接受 server 簽發的 `speechTicket`
- `/api/intro-speech` 由 server 鎖定三語自我介紹文字與 TTS 參數
- TTS 音檔做 server 端快取，降低重複 OpenAI 請求
- 每次公開 API request 都需要 `x-install-id`
- 同一個 RevenueCat `app_user_id` 可綁定的 install 數量有限，降低帳號分享濫用
- `重播同一段回答` 不算新提問
- `聽不懂 / Simplify` 因為會重新生成新答案，所以算新提問

## 建議 client 流程

1. 啟動時先打 `GET /api/session`
2. 問問題時打 `POST /api/chat`
3. server 回傳：
   - `answer`
   - `ttsInput`
   - `speechTicket`
   - `quota`
4. 播音時打 `POST /api/speech`
5. 單純重播：
   - 不要再打 `/api/chat`
   - 直接重用上一輪的 `ttsInput + speechTicket`
6. 三語自我介紹音檔打 `POST /api/intro-speech`，不要讓 client 自帶 voice/model/instructions

## Request / Response

### `GET /api/session`

Headers:

- `x-install-id: <uuid>`
- `x-app-user-id: <revenuecat-app-user-id>` optional

Response:

```json
{
  "plan": "free",
  "quota": {
    "zh-TW": { "remaining": 3, "limit": 3 },
    "en-US": { "remaining": 3, "limit": 3 },
    "ja-JP": { "remaining": 3, "limit": 3 }
  }
}
```

### `POST /api/chat`

Headers:

- `x-install-id: <uuid>`
- `x-app-user-id: <revenuecat-app-user-id>` optional

Request:

```json
{
  "message": "企鵝為什麼不會飛？",
  "language": "zh-TW"
}
```

Response:

```json
{
  "answer": "…",
  "ttsInput": "…",
  "speechTicket": "…",
  "plan": "free",
  "quota": {
    "remaining": 2,
    "limit": 3
  }
}
```

### `POST /api/speech`

Headers:

- `x-install-id: <uuid>`
- `x-app-user-id: <revenuecat-app-user-id>` optional

Request:

```json
{
  "language": "zh-TW",
  "ttsInput": "…",
  "speechTicket": "…"
}
```

Response:

- `audio/wav`

### `POST /api/intro-speech`

Headers:

- `x-install-id: <uuid>`
- `x-app-user-id: <revenuecat-app-user-id>` optional

Request:

```json
{
  "language": "zh-TW"
}
```

Response:

- `audio/wav`

## RevenueCat 串法

這份範本沒有直接綁死 RevenueCat webhook payload，而是提供 `POST /internal/plan-sync`。

你可以在真正的 backend repo 裡：

- 接 RevenueCat webhook
- 驗證 webhook secret
- 解析 `app_user_id`
- 再轉成這個 server 內部的 `plan-sync`

## 環境變數

- `OPENAI_API_KEY`
- `PORT`
- `SPEECH_TICKET_SECRET`
- `ADMIN_SYNC_SECRET`
- `MAX_INSTALLS_PER_APP_USER` optional, default `8`

## 注意

- `NODE_ENV=production` 時，`OPENAI_API_KEY`、`SPEECH_TICKET_SECRET`、`ADMIN_SYNC_SECRET` 未設定或仍是預設值會直接拒絕啟動。
- 目前 iOS app 已改成新 request shape；正式發版前必須先部署支援 `/api/chat`、`/api/speech`、`/api/intro-speech` 的 backend。
- 這份範本把 TTS `model / voice / speed` 固定鎖在 server 端，不讓 client 覆寫。
