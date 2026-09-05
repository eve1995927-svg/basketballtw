import fs from 'node:fs/promises';
import path from 'node:path';
import sharp from '/Users/yongye/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp/dist/index.cjs';

const root = process.cwd();
const srcDir = path.join(root, 'playtest/full_ui_visual_complete');
const outRoot = path.join(root, 'store/ios');
const screens = [
  ['01_login.jpg', '1280x720_full_login.png', '台灣籃球，從你的王朝開始', '選一支隊伍，建立屬於你的籃球故事'],
  ['02_roster.jpg', '1280x720_full_roster.png', '組出你的十二人陣容', '位置、風格與薪資，每個選擇都會影響戰局'],
  ['03_locker.jpg', '1280x720_full_home_locker.png', '你的球員，你的主場', '更衣室、球場與卡框，打造獨一無二的球隊風格'],
  ['04_tactics.jpg', '1280x720_full_tactics.png', '三次決策，改變一場比賽', '賽前、中場與末節，讀懂數據再下指令'],
  ['05_training.jpg', '1280x720_full_training.png', '特訓你的關鍵球員', '從基礎 OVR 到五星技能，穩定養成你的核心'],
];
const captions = {
  'zh-Hant-TW': { subtitle: '簡約日式風格的台灣籃球經營模擬', footer: '台籃模擬器  ·  現在開始你的賽季' },
};
const esc = (s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const overlay = (w, h, title, desc) => Buffer.from(`<svg width="${w}" height="${h}" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0" x2="1"><stop stop-color="#061323" stop-opacity=".96"/><stop offset=".48" stop-color="#061323" stop-opacity=".42"/><stop offset="1" stop-color="#061323" stop-opacity=".08"/></linearGradient></defs><rect width="${w}" height="${h}" fill="url(#g)"/><rect x="72" y="68" width="8" height="150" rx="4" fill="#f39a32"/><text x="112" y="120" fill="#f7c56a" font-size="28" font-family="sans-serif" font-weight="700">台籃模擬器</text><text x="112" y="190" fill="#ffffff" font-size="58" font-family="sans-serif" font-weight="700">${esc(title)}</text><text x="112" y="242" fill="#d7e4ef" font-size="27" font-family="sans-serif">${esc(desc)}</text><text x="112" y="${h-72}" fill="#a9c6d7" font-size="22" font-family="sans-serif">簡約．策略．你的台灣籃球王朝</text></svg>`);

async function makeSet(dir, w, h) {
  await fs.mkdir(dir, { recursive: true });
  for (const [name, source, title, desc] of screens) {
    const input = path.join(srcDir, source);
    const base = await sharp(input).resize({ width: w, height: h, fit: 'cover' }).jpeg({ quality: 92 }).toBuffer();
    await sharp(base).composite([{ input: overlay(w, h, title, desc) }]).jpeg({ quality: 92, chromaSubsampling: '4:4:4' }).toFile(path.join(dir, name));
  }
}

await makeSet(path.join(outRoot, '6.7'), 2796, 1290);
await makeSet(path.join(outRoot, '6.5'), 2778, 1284);
const metadata = `# 台籃模擬器｜App Store Connect（繁體中文／台灣）\n\n- App 名稱：台籃模擬器\n- 副標題：打造你的台灣籃球王朝\n- 宣傳文字：組出十二人陣容，讀懂比賽，再用你的決策改變下一場。台灣籃球經營模擬，現在開放體驗。\n- 關鍵字：籃球,台籃,籃球經營,球隊,戰術,陣容,球員卡,體育模擬,台灣籃球\n- 支援網址：https://basketgm.tw/support.html\n- 行銷網址：https://basketgm.tw/\n- 隱私權政策：https://basketgm.tw/privacy.html\n\n## 描述\n\n台籃模擬器是一款簡約、日式風格的台灣籃球經營模擬遊戲。從選隊開始，打造你的十二人陣容，安排位置、薪資與球員風格，讓每一張球員卡都有清楚的用途。\n\n每場比賽不只是看 OVR。賽前選擇攻防策略，中場根據數據調整，第四節再決定穩定進攻、快速追分或消耗時間。你的判斷，會改變比賽走向。\n\n收集並培養球員卡、挑戰賽事、解鎖五星技能，再用更衣室、球場與卡框主題留下你的球隊風格。一般列表保持清爽，重要時刻才用光效與演出，讓每次成功都值得記住。\n\n本作為獨立開發的遊戲作品，球員、球隊與數值皆為遊戲模擬設定，非任何聯盟或球隊官方產品。部分功能需要網路連線；目前正式版付款功能尚未開放，不會進行真實扣款。\n\n## 審核備註\n\n- 這是一款獨立籃球經營模擬遊戲，使用繁體中文。\n- 目前可用訪客流程體驗主要玩法；若審核需要測試帳號，請透過支援網址聯繫。\n- 付款入口在正式付款服務啟用前會明確標示「尚未開放」，不會模擬成功交易。\n`;
await fs.writeFile(path.join(outRoot, 'app_store_metadata_zh-Hant-TW.md'), metadata);
await fs.writeFile(path.join(outRoot, 'asset_manifest.json'), JSON.stringify({ locale: 'zh-Hant-TW', icon: 'assets/ui/app_icon_1024.png', screenshot_sets: [{ folder: '6.7', width: 2796, height: 1290, files: screens.map((s) => s[0]) }, { folder: '6.5', width: 2778, height: 1284, files: screens.map((s) => s[0]) }], generated_key_art: 'marketing/key_art.png', notes: '截圖採實際遊戲畫面，文字以 SVG 疊加；無透明背景。' }, null, 2));
console.log('Prepared iOS store assets in store/ios');
