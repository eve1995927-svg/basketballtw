# 台籃模擬器官網維護

正式站：https://basketgm.tw/。GitHub Pages 使用 `main` 根目錄；不是 `website/`，也不是 Godot 遊戲 UI。

## 本次設計

- 深藍球場主視覺、暖白公告區、橘色重點；使用已核准插畫及實際測試畫面。
- 首頁：遊戲介紹、最新消息、下載、常見問題。
- `news/index.html` 為公告列表；每篇公告為獨立 HTML，關閉 JavaScript 仍可閱讀與下載。
- `guide.html` 新手與安裝指南；`support.html` 客服與資料申請入口；`privacy.html` 官網隱私說明；`legal.html` 保留既有權利聲明全文。
- 真正的網頁遊戲仍在 `game/`，`play.html` 的遊戲載入與 OAuth 邏輯保留。

## 新版本發布

1. 確認版本號、簽章、檔案與發布狀態。不能把待審查寫成已開放，也不填未驗證的玩法改動。
2. 在 `news/` 新增文章。可複製現有文章結構，更新標題、日期、本文、canonical、OG URL、Article 結構化資料。日期須對應真實發布時間。
3. 更新 `news/index.html` 與首頁消息區；保留舊公告連結，不覆寫歷史紀錄。
4. 新增文章 URL 至 `sitemap.xml`；lastmod 只在內容真正修改時更新。
5. 首頁靜態 APK 連結必須指向已驗證版本；公開 release catalog 查詢失敗時會保留此備援。API 有新版本只更新下載資訊，不自動編造公告。
6. `site-config.js` 的商店連結取得後再填寫。目前空值會導向進度公告，不是假裝可下載的按鈕。
7. 修改共用 `official.css` 或 `official.js` 後更新 HTML 中的快取版本字串。

## 素材

`assets/web/` 是本次上線的壓縮圖片，不影響 Godot 原素材。`tools/prepare_site_assets.mjs` 可重製：手機主圖約 50 KB、桌面主圖約 152 KB，實際遊戲截圖約 85–96 KB。沒有首頁自動播放影片或外部字型。

## 測試

```sh
python3 -m http.server 8767 --bind 127.0.0.1
node tools/test_official_site.mjs
SITE_URL=https://basketgm.tw SITE_QA_OUT=/tmp/basketgm-live-qa node tools/test_official_site.mjs
git diff --check
```

工具使用此工作機的 Codex Playwright/Sharp 套件及 Google Chrome；其他工作機需調整 import 與 executablePath。測試資料使用合成登入片段，不包含帳號憑證。

覆蓋 1440×1000、390×844、320×568、844×390；九頁共 36 個頁面／尺寸組合。檢查版面溢出、H1、canonical、描述、JSON-LD 可解析、圖片、內部連結及錨點、選單、截圖視窗、FAQ、分享、登入轉址、無 JS 與版本 API 失敗備援。

不涵蓋真機完整登入、遊戲效能、商店審核、Google 真實索引或搜尋排名。隱私說明不是完整遊戲資料處理或法律合規稽核。

## SEO 後續

已提供正式網域 canonical、robots、sitemap、社群分享圖片、Organization/WebSite/VideoGame/Article 結構化資料。資料對應可見內容，不填假評論、評分或下載人數。

需由已驗證的 Google Search Console 網站擁有者提交 `https://basketgm.tw/sitemap.xml`，檢查重要 URL 是否可索引，並持續發布真實更新。本站未擅自設定 DNS、驗證擁有權或聲稱已完成索引。

Google 官方依據：[SEO 入門指南](https://developers.google.com/search/docs/fundamentals/seo-starter-guide)、[AI 搜尋功能](https://developers.google.com/search/docs/appearance/ai-features)。基本做法是可抓取的文字、可靠內容、合理連結和良好使用體驗；沒有保證排名的特殊標記。

Supabase 串接遵循 publishable key 用於前端、只讀公開版本資訊的原則；保留既有登入 fragment 轉址，不修改 Auth 設定、RLS 或玩家資料。[官方 API key 說明](https://supabase.com/docs/guides/api/api-keys)。
