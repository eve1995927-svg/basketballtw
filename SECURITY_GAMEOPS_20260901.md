# 五項優先更新（0.9.3）

## 已落地

1. **伺服器經濟帳本**：`supabase/security_economy.sql` 建立 `godot_economy_accounts` 與私有 ledger。新 RPC `public.godot_economy_apply` 使用登入者身分、資料庫鎖與 `request_id` 冪等處理；客戶端目前只能提出簽約、交易、球探、訓練等扣款，不能自行發放資源。
2. **RLS 與權限邊界**：資源帳戶只能由本人讀取，寫入只能透過 RPC；ledger 與未來收據表對客戶端完全關閉。不要把 service role key 放入 Godot、APK、iOS 或網站。
3. **付費驗證資料層**：建立私有 `verified_purchases`，只接受伺服器驗證後的 Apple／Google 交易；正式商城仍需 Edge Function 串 Apple／Google 收據驗證後才發貨。
4. **遠端版本開關**：`godot_release_config` 可設定各平台最低版本、維護狀態與公告。客戶端下一版應在進入主畫面前讀取此表。

## 仍需在下一個版本接上的部分

- 將比賽、任務、簽約、球探、訓練、預測獎勵的本地加減，逐一改為呼叫 `godot_economy_apply`，成功回應後才更新畫面與本機存檔。
- 部署付費收據驗證 Edge Function，並處理退款、撤銷與恢復購買。
- 啟用 Supabase Auth 的洩漏密碼保護；確認 Apple Provider 的 Client Secret 已設定，否則 Apple 登入仍不可用。
- 所有新版本上線後，關閉舊版直接寫入政策；完成至少一輪舊版到新版的存檔遷移測試再收緊權限。
- 建立管理員專用分析查詢（DAU、留存、漏斗、錯誤率），不要把分析資料表直接開放給玩家。
- 加入帳號刪除、資料匯出、登入方式合併與撤銷所有裝置工作階段的 UI。

## 驗證

- Migration `security_economy_20260901` 已套用至 Supabase 專案。
- 已確認 `godot_economy_accounts`、`tb_economy_private.ledger`、`godot_release_config` 與 `godot_economy_apply` 存在。
- 本機 Godot headless 與手機回歸測試維持通過；本次沒有刪除或覆寫既有玩家存檔。
