# 登入與市場數據更新

## 已完成

- 登入頁保留離線遊玩、Gmail 驗證碼與 Google OAuth。
- iOS／Android 原生登入頁新增「使用 Apple 登入」，沿用 Supabase PKCE 回呼流程。
- 新增 `track_event()`，只在玩家登入後傳送不含 Email、Token、密碼的匿名化事件。
- 已將 `session_start`、`login_success`、`screen_dashboard`、`screen_activity`、`match_completed` 接入事件記錄。
- 新增 `supabase/analytics.sql`，並已在 Supabase 專案建立 `godot_analytics_events` 與每日報表 View。
- 事件表只允許已登入玩家寫入，玩家端不能讀取分析資料；RLS 已啟用。
- 資料庫已補上分析事件的 owner index，避免玩家數增加後查詢變慢。

## 管理員查詢

在 Supabase SQL Editor 以管理員執行：

```sql
select date(timezone('Asia/Taipei', created_at)) as day,
       count(distinct owner_id) filter (where event_name = 'session_start') as dau
from public.godot_analytics_events
group by 1 order by 1 desc;

select event_name, count(*) as events, count(distinct owner_id) as users
from public.godot_analytics_events
where created_at > now() - interval '7 days'
group by event_name order by users desc;
```

## 上線前設定

1. 在 Supabase Auth 開啟 Google provider，填入 Web、iOS、Android Client ID。
2. 在 Supabase Auth 開啟 Apple provider，設定 Service ID、Key 與 Redirect URL。
3. 將正式網站與 iOS／Android 回呼網址加入 Redirect URL allow list。
4. 開啟 Auth 的 leaked password protection。
5. 將隱私政策加入「收集遊戲事件、平台、版本與時間，用於改善遊戲」說明，並提供刪除帳號入口。

玩家不需要重新建立帳號；Apple、Google 與 Email 應在之後的帳號設定中綁定到同一個玩家 ID，避免產生兩份存檔。
