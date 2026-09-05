import sharp from "/Users/yongye/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp/dist/index.cjs";
import {mkdir} from "node:fs/promises";
await mkdir("assets/web",{recursive:true});
const jobs=[
["assets/art/login/login_roster_arena_v1.png","hero",1672],
["playtest/full_ui_visual_complete/1280x720_full_roster.png","roster",1280],
["playtest/full_ui_visual_complete/1280x720_full_home_locker.png","locker",1280],
["assets/ui/app_icon_1024.png","icon",192]
];
for (const [src,name,width] of jobs) {
  await sharp(src).resize({width,withoutEnlargement:true}).webp({quality:82}).toFile("assets/web/"+name+".webp");
}
await sharp(jobs[0][0]).resize({width:840}).webp({quality:78}).toFile("assets/web/hero-small.webp");
await sharp(jobs[0][0]).resize(1200,630,{fit:"cover"}).jpeg({quality:83}).toFile("assets/web/social.jpg");
await sharp("assets/ui/app_icon_1024.png").resize(48,48).png().toFile("assets/web/favicon.png");
await sharp("assets/ui/app_icon_1024.png").resize(180,180).png().toFile("assets/web/apple-touch-icon.png");
