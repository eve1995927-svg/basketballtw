import { chromium } from '/Users/yongye/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
import { mkdir, writeFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const base = process.env.SITE_URL || 'http://127.0.0.1:8767';
const out = process.env.SITE_QA_OUT || '/tmp/basketgm-site-qa';
await mkdir(out, {recursive:true});
const browser = await chromium.launch({headless:true, executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const paths=['/','/news/','/news/android-177.html','/news/test-guide.html','/guide.html','/support.html','/privacy.html','/legal.html','/404.html'];
const results=[]; const links = new Set(); const assets=new Set();
for(const viewport of [{width:1440,height:1000},{width:390,height:844},{width:320,height:568},{width:844,height:390}]) {
  const context=await browser.newContext({viewport,reducedMotion:'reduce'});
  const page=await context.newPage(); const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  for(const path of paths){
    const response=await page.goto(base+path,{waitUntil:'networkidle'});
    // Visit lazy images before the full-page visual audit, as a real reader does.
    await page.evaluate(async()=>{for(const image of document.querySelectorAll('img[src]')){image.loading='eager';await image.decode().catch(()=>{});}});
    assert.equal(response.status(),200,path);
    const seo=await page.evaluate(()=>({h1:document.querySelectorAll('h1').length,title:document.title,description:document.querySelector('meta[name=description]')?.content,canonical:document.querySelector('link[rel=canonical]')?.href,schemas:[...document.querySelectorAll('script[type="application/ld+json"]')].map(el=>JSON.parse(el.textContent)),overflow:document.documentElement.scrollWidth>innerWidth,broken:[...document.images].filter(i=>i.getAttribute('src')&&i.complete&&!i.naturalWidth).map(i=>i.src),links:[...document.querySelectorAll('a[href]')].map(a=>a.getAttribute('href')),assets:[...document.querySelectorAll('img[src],script[src],link[rel=stylesheet]')].map(a=>a.getAttribute('src')||a.getAttribute('href'))}));
    assert.equal(seo.h1,1,path+' h1'); assert.ok(seo.description); assert.equal(seo.canonical,'https://basketgm.tw'+path); assert.equal(seo.overflow,false,path+' overflow at '+viewport.width); assert.deepEqual(seo.broken,[],path+' images'); assert.ok(seo.schemas.length);
    seo.links.filter(l=>l.startsWith('/')).forEach(l=>links.add(l)); seo.assets.filter(l=>l.startsWith('/')).forEach(l=>assets.add(l));
    if(path==='/' || (viewport.width===390 && ['/news/android-177.html','/support.html'].includes(path))) await page.screenshot({path:out+'/'+viewport.width+'-'+(path==='/'?'home':path.replaceAll('/','_'))+'.png',fullPage:true});
    results.push({path,width:viewport.width,ok:true});
  }
  await page.goto(base+'/',{waitUntil:'networkidle'});
  if(viewport.width<820){ await page.locator('.menu-toggle').click(); assert.equal(await page.locator('.menu-toggle').getAttribute('aria-expanded'),'true'); await page.keyboard.press('Escape'); assert.equal(await page.locator('.menu-toggle').getAttribute('aria-expanded'),'false'); }
  await page.locator('[data-image]').first().click(); assert.equal(await page.locator('dialog').evaluate(e=>e.open),true); await page.keyboard.press('Escape'); assert.equal(await page.locator('dialog').evaluate(e=>e.open),false);
  await page.locator('summary').first().click(); assert.equal(await page.locator('details').first().getAttribute('open'),''); assert.deepEqual(errors,[]);
  await context.close();
}
const context=await browser.newContext({javaScriptEnabled:false,viewport:{width:320,height:568}}); const page=await context.newPage(); await page.goto(base+'/'); assert.ok((await page.locator('[data-direct-apk]').getAttribute('href')).endsWith('.apk')); assert.equal(await page.locator('#navigation').isVisible(),true); assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false); await context.close();
const edge=await browser.newContext();const ep=await edge.newPage();await ep.route('**/rest/v1/app_releases?**',r=>r.fulfill({status:503,body:'unavailable'}));await ep.goto(base+'/',{waitUntil:'networkidle'});assert.ok((await ep.locator('[data-direct-apk]').getAttribute('href')).includes('android-177/'));await edge.close();
const behavior=await browser.newContext({permissions:['clipboard-read','clipboard-write']});const bp=await behavior.newPage();
await bp.goto(base+'/news/android-177.html');await bp.locator('.share-button').click();await bp.waitForFunction(()=>document.querySelector('.share-status').textContent==='連結已複製');
await bp.route('**/game/index.html',r=>r.fulfill({status:200,contentType:'text/html',body:'<title>Login callback test</title>'}));
await bp.goto(base+'/#access_token=synthetic-test-value');await bp.waitForURL('**/game/index.html#access_token=synthetic-test-value');await behavior.close();
const api=await browser.newContext();
for(const link of [...links,...assets]){const path=link.split('#')[0]||'/'; const response=await api.request.get(base+path);assert.equal(response.status(),200,'internal '+path);if(link.includes('#')){const id=link.split('#')[1];if(id)assert.ok((await response.text()).includes('id="'+id+'"'),'anchor '+link);}}
const sitemap=await api.request.get(base+'/sitemap.xml');assert.equal(sitemap.status(),200);assert.ok(!(await sitemap.text()).includes('github.io'));const robots=await api.request.get(base+'/robots.txt');assert.ok((await robots.text()).includes('Sitemap: https://basketgm.tw/sitemap.xml'));
await api.close();await browser.close();
const report={base,pages:results.length,results,internalLinks:links.size,assets:assets.size,checks:['no overflow','one h1','canonical','description','JSON-LD parse','images','menu','lightbox','FAQ','no-JS','API failure fallback','internal URLs and anchors','sitemap','robots'],passed:true};
await writeFile(out+'/report.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
