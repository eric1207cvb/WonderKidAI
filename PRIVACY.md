# WonderKidAI Privacy Policy

**Last updated:** August 12, 2026

**Developer:** Hsueh Yi An (WonderKidAI)
**Contact:** eric1207cvb@msn.com

This policy describes the data flow in the current WonderKidAI app. It is written for parents and should be read together with the privacy policies of the services named below. The app is designed for children; please help children avoid entering names, addresses, phone numbers, account details, or other private information in a question.

---

## English

### 1. Information stored on the device

Questions, answers, language preference, and Growth Journey records are stored on the device by default. A parent can delete records individually or clear them from Growth Journey. To make replay faster, answer and audio files may be held in the app cache; iOS may remove cached files automatically.

The app creates a random **installation identifier** in the device Keychain. It is not a child’s name or contact detail. It is used for service reliability, rate limits, and abuse prevention.

### 2. Speech and AI requests

The app uses Apple Speech for speech recognition. The text recognized from speech, or text typed into the app, is sent for an AI response. The app does **not** send the raw microphone recording directly to its Render backend.

For answers and narration, the following flow is used:

1. Question text or narration text, the installation identifier, and (when available) a RevenueCat anonymous App User ID are sent over an encrypted connection to **Render**, which operates the WonderKidAI service gateway.
2. Render forwards the required text to **OpenAI** to generate an answer or speech audio.

Render and OpenAI process requests under their own terms and data policies. Do not assume that a provider’s processing is anonymous or that it is immediately deleted. We do not use the content ourselves to train an AI model.

### 3. Knowledge-source requests

For some factual questions, the app sends the search term directly from the device to the corresponding language edition of **Wikipedia** to obtain a public summary. Wikimedia receives that network request and handles it under its own privacy policy.

### 4. Subscriptions

**RevenueCat** processes App Store subscription status and Restore Purchases. Its anonymous App User ID is used to check access to paid features and may be included with service requests. Apple processes payments through the App Store; WonderKidAI does not receive a payment-card number.

### 5. iCloud sync

After a paid subscription has been verified, the app uses **Apple iCloud Key-Value Storage** to sync the language preference and up to 50 question-and-answer records (question, answer, date, and language) between devices using the same Apple ID. This sync is handled by Apple’s iCloud service.

### 6. No advertising or cross-app tracking

WonderKidAI does not serve third-party advertising and does not use this information to track a person across apps or websites owned by other companies.

### 7. Service policies

- [OpenAI Privacy Policy](https://openai.com/policies/privacy-policy/)
- [Render Privacy Policy](https://render.com/privacy)
- [RevenueCat Privacy Policy](https://www.revenuecat.com/privacy/)
- [Wikimedia Foundation Privacy Policy](https://foundation.wikimedia.org/wiki/Policy:Privacy_policy)
- [Apple Privacy Policy](https://www.apple.com/legal/privacy/)

### 8. Contact and deletion requests

You can delete local history in Growth Journey. For questions about this policy or a request relating to data handled by the developer, contact **eric1207cvb@msn.com**. Requests concerning data held by a provider may also require contacting that provider directly.

### End User License Agreement

WonderKidAI is offered under the [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/). The agreement is between the user and the Developer, not Apple. The Developer is responsible for the app and its content; Apple has no maintenance or support obligation.

---

## 繁體中文（台灣）

### 1. 儲存在裝置上的資料

提問、回答、語言偏好與「成長足跡」紀錄預設保存在裝置上。家長可在「成長足跡」逐筆或全部刪除紀錄。為加快重播，回答與語音檔可能暫存於 App 快取；iOS 可自動移除快取檔。

App 會在裝置 Keychain 建立一組隨機的**安裝識別碼**。它不是孩子的姓名或聯絡資料，用於服務穩定、用量限制與防止濫用。

### 2. 語音與 AI 請求

App 使用 Apple Speech 進行語音辨識。辨識出的文字或在 App 內輸入的文字會送出以取得 AI 回覆；App 不會將原始麥克風錄音直接傳至 Render 後端。

回答與朗讀的資料流程如下：

1. 提問文字或朗讀文字、安裝識別碼，以及可取得時的 RevenueCat 匿名 App User ID，會透過加密連線傳至 **Render**；Render 為 WonderKidAI 的服務閘道。
2. Render 會把必要文字轉送給 **OpenAI**，產生回答或語音檔。

Render 與 OpenAI 依各自的條款及資料政策處理請求。請勿假設服務供應商的處理一定是匿名或會立即刪除。我們不會自行使用這些內容訓練 AI 模型。

### 3. 知識來源請求

部分知識型問題會由裝置直接將查詢詞送至相應語言版本的 **Wikipedia**，以取得公開摘要。Wikimedia 會依其隱私權政策處理該網路請求。

### 4. 訂閱

**RevenueCat** 處理 App Store 的訂閱狀態與恢復購買。其匿名 App User ID 用於核對付費功能資格，也可能隨服務請求傳送。付款由 Apple App Store 處理；WonderKidAI 不會取得付款卡號。

### 5. iCloud 同步

付費訂閱經驗證後，App 會使用 **Apple iCloud Key-Value Storage**，在同一 Apple ID 的裝置間同步語言偏好與最多 50 筆問答紀錄（問題、回答、日期、語言）。此同步由 Apple iCloud 服務處理。

### 6. 不投放廣告或跨 App 追蹤

WonderKidAI 不投放第三方廣告，也不會將這些資料用於跨不同公司 App 或網站追蹤個人。

### 7. 服務供應商政策

- [OpenAI 隱私權政策](https://openai.com/policies/privacy-policy/)
- [Render 隱私權政策](https://render.com/privacy)
- [RevenueCat 隱私權政策](https://www.revenuecat.com/privacy/)
- [Wikimedia Foundation 隱私權政策](https://foundation.wikimedia.org/wiki/Policy:Privacy_policy)
- [Apple 隱私權政策](https://www.apple.com/legal/privacy/)

### 8. 聯絡與刪除

可在「成長足跡」刪除本機歷史紀錄。如對本政策有疑問，或想提出與開發者處理資料相關的要求，請聯絡 **eric1207cvb@msn.com**。若資料由服務供應商處理，可能也需要直接向該供應商提出要求。

### 使用者授權合約

WonderKidAI 採用 [Apple 標準 EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)。本協議締約雙方為使用者與開發者，而非 Apple；開發者對 App 與其內容負責，Apple 不負維護或支援義務。

---

## 日本語

### 1. 端末に保存される情報

質問、回答、言語設定、「成長の記録」は標準で端末に保存されます。保護者は「成長の記録」から、記録を1件ずつまたはすべて削除できます。再生を速くするため、回答と音声ファイルをアプリのキャッシュに一時保存することがあります。iOS によりキャッシュが自動削除される場合があります。

アプリは端末の Keychain にランダムな**インストール識別子**を作成します。これはお子さまの氏名や連絡先ではなく、サービスの安定運用、利用回数の制限、不正利用の防止に使用されます。

### 2. 音声と AI リクエスト

アプリは音声認識に Apple Speech を使用します。音声から認識された文字、またはアプリ内で入力した文字を AI の回答取得のために送信します。アプリが生のマイク録音を直接 Render のバックエンドに送信することはありません。

回答と読み上げのデータの流れは次のとおりです。

1. 質問文または読み上げ用テキスト、インストール識別子、および利用可能な場合は RevenueCat の匿名 App User ID を、暗号化接続で WonderKidAI のサービスゲートウェイである **Render** に送信します。
2. Render は必要なテキストを **OpenAI** に転送し、回答または音声を生成します。

Render と OpenAI は、それぞれの規約およびデータポリシーに従ってリクエストを処理します。サービス提供者による処理が匿名である、または直ちに削除されるとは限りません。当方がこの内容を AI モデルの学習に使用することはありません。

### 3. 知識ソースへのリクエスト

一部の知識に関する質問では、公開要約を得るために、端末から検索語を対応言語版の **Wikipedia** へ直接送信します。このネットワークリクエストは Wikimedia のプライバシーポリシーに従って処理されます。

### 4. サブスクリプション

**RevenueCat** は App Store のサブスクリプション状態と購入の復元を処理します。匿名の App User ID は有料機能の利用資格確認に使用され、サービスリクエストに含まれることがあります。支払いは Apple App Store が処理し、WonderKidAI がカード番号を受け取ることはありません。

### 5. iCloud 同期

有料サブスクリプションの確認後、アプリは **Apple iCloud Key-Value Storage** を使用して、言語設定と最大50件の質問・回答記録（質問、回答、日付、言語）を同じ Apple ID の端末間で同期します。この同期は Apple の iCloud サービスにより処理されます。

### 6. 広告およびアプリ横断トラッキング

WonderKidAI は第三者広告を配信せず、この情報を他社が所有するアプリやウェブサイトをまたぐ個人の追跡には使用しません。

### 7. サービス提供者のポリシー

- [OpenAI Privacy Policy](https://openai.com/policies/privacy-policy/)
- [Render Privacy Policy](https://render.com/privacy)
- [RevenueCat Privacy Policy](https://www.revenuecat.com/privacy/)
- [Wikimedia Foundation Privacy Policy](https://foundation.wikimedia.org/wiki/Policy:Privacy_policy)
- [Apple Privacy Policy](https://www.apple.com/legal/privacy/)

### 8. お問い合わせと削除

端末内の履歴は「成長の記録」から削除できます。本ポリシーについてのご質問、または開発者が取り扱うデータに関するご依頼は **eric1207cvb@msn.com** までご連絡ください。サービス提供者が処理するデータについては、その提供者へ直接依頼が必要になる場合があります。

### エンドユーザー使用許諾契約

WonderKidAI は [Apple 標準 EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) に基づいて提供されます。本契約は利用者と開発者の間の契約であり、Apple との契約ではありません。アプリとその内容は開発者が責任を負い、Apple に保守・サポート義務はありません。
