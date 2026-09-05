/* Progressive enhancement: content and downloads work without JavaScript. */
(() => {
  'use strict';
  // Preserve the existing game login fallback; never log or send tokens elsewhere.
  if ((location.pathname === '/' || location.pathname === '/index.html') &&
      (location.hash.includes('access_token=') || location.hash.includes('code='))) {
    location.replace('/game/index.html' + location.hash);
    return;
  }
  document.documentElement.classList.add('js');
  const menu = document.querySelector('.menu-toggle');
  const nav = document.querySelector('#navigation');
  const closeMenu = () => { menu?.setAttribute('aria-expanded', 'false'); nav?.classList.remove('is-open'); };
  menu?.addEventListener('click', () => {
    const open = menu.getAttribute('aria-expanded') !== 'true';
    menu.setAttribute('aria-expanded', String(open)); nav?.classList.toggle('is-open', open);
  });
  nav?.addEventListener('click', event => { if (event.target.closest('a')) closeMenu(); });
  document.addEventListener('keydown', event => { if (event.key === 'Escape' && menu?.getAttribute('aria-expanded') === 'true') { closeMenu(); menu.focus(); } });
  const dialog = document.querySelector('.lightbox');
  document.querySelectorAll('[data-image]').forEach(button => button.addEventListener('click', () => {
    if (!dialog) return;
    const image = dialog.querySelector('img');
    image.src = button.dataset.image; image.alt = button.querySelector('img')?.alt || '遊戲畫面';
    dialog.showModal();
  }));
  dialog?.querySelector('.lightbox-close')?.addEventListener('click', () => dialog.close());
  dialog?.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  document.querySelector('.share-button')?.addEventListener('click', async () => {
    const status = document.querySelector('.share-status');
    try { await navigator.clipboard.writeText(location.href); if (status) status.textContent = '連結已複製'; }
    catch { if (status) status.textContent = '請複製瀏覽器網址列中的連結。'; }
  });
  document.querySelectorAll('[data-link]').forEach(link => {
    const value = window.GAME_LINKS?.[link.dataset.link];
    if (!value) return;
    try {
      const url = new URL(value);
      const allowed = link.dataset.link === 'ios' ? ['testflight.apple.com', 'apps.apple.com'] : ['play.google.com'];
      if (url.protocol === 'https:' && allowed.includes(url.hostname)) { link.href = url.href; link.textContent = link.dataset.link === 'ios' ? '前往 Apple 測試／下載 ↗' : '前往 Google Play ↗'; }
    } catch { /* Keep the dated announcement link. */ }
  });
  if (!document.querySelector('[data-direct-apk]')) return;
  const config = window.RELEASE_CATALOG;
  if (!config?.supabaseUrl || !config?.publishableKey) return;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5000);
  fetch(config.supabaseUrl + '/rest/v1/app_releases?select=version_name,version_code,download_url,file_size_bytes,minimum_os&platform=eq.android&channel=eq.direct&published=eq.true&order=version_code.desc&limit=1', { headers: { apikey: config.publishableKey }, signal: controller.signal })
    .then(response => { if (!response.ok) throw new Error('Release catalog unavailable'); return response.json(); })
    .then(rows => {
      const release = rows?.[0];
      if (!release || !Number.isInteger(release.version_code) || release.version_code < 177 || !/^\d+\.\d+\.\d+$/.test(release.version_name)) return;
      const url = new URL(release.download_url);
      if (url.origin !== 'https://github.com' || !/^\/eve1995927-svg\/basketballtw\/releases\/download\/[^/]+\/[^/]+\.apk$/.test(url.pathname)) return;
      document.querySelector('[data-direct-apk]').href = url.href;
      document.querySelector('[data-apk-version]').textContent = release.version_name + '（' + release.version_code + '）';
      if (Number.isFinite(release.file_size_bytes) && release.file_size_bytes > 0) document.querySelector('[data-apk-status]').textContent = '約 ' + Math.round(release.file_size_bytes / 1048576) + ' MiB · ' + (release.minimum_os || '請查看版本公告');
    })
    .catch(() => { /* The verified static download remains usable when offline or timed out. */ })
    .finally(() => clearTimeout(timer));
})();
