// Marketing cards from the real app: renders of docs/app in a phone frame, the brand's own
// colours and fonts, Arabic and English. Portrait cards 1080x1350 and a wide banner 1600x900.
// Needs the site served locally (python3 -m http.server 8765 in docs/) and the renders from
// tools/marketing/capture.mjs in /tmp/mkt/shots. Output: the folder given as the first argument.
import { chromium } from '/home/claude/.npm-global/lib/node_modules/playwright/index.mjs';
import { readFileSync } from 'node:fs';
import { mkdirSync } from 'node:fs';

const out = process.argv[2] || 'marketing';
const shot = (lang, page) => 'data:image/png;base64,' + readFileSync(`/tmp/mkt/shots/${lang}-${page}.png`).toString('base64');

const T = {
  ar: {
    site: 'nokhatha.3li.info', free: 'مجاني', open: 'مفتوح المصدر', local: 'بياناتك على جهازك', platforms: 'ويب · آيفون · أندرويد',
    cards: [
      { id: 'hero', page: 'today', kicker: 'نُوخذة', title: 'بيتك وسيارتك واشتراكاتك على مواسم الخليج', sub: 'تذكيرات تعرف الصيف والبوارح والوسم، وتقول لك شنو تسوي قبل كل موسم.',
        points: ['دائرة السنة على 14 موسم من سهيل إلى الكليبين', 'مهام البيت والسيارة بالترتيب الصحيح لدولتك', 'بلا حساب وبلا إنترنت، كل شي على جهازك'] },
      { id: 'seasons', page: 'home', kicker: 'المواسم', title: 'الصيانة اللي تعرف الجو', sub: 'الغبار والحر عندنا مو مثل أي مكان، فالتذكير يتغير معهم.',
        points: ['فلاتر المكيفات كل أسبوعين بالقيظ والبوارح', 'الخزان والفلاتر والمزاريب قبل أول مطرة', 'تنبيه غبار اختياري من طقس منطقتك'] },
      { id: 'car', page: 'car', kicker: 'السيارة', title: 'جدّد الدفتر بالترتيب الصحيح', sub: 'خطوات دولتك بروابطها الرسمية، وآخرها ضغطة وحدة تضبط كل المواعيد.',
        points: ['التأمين ثم الفحص ثم الدفع، لكل دولة خليجية', 'العداد يقدّر الكيلومترات ويذكّرك بالزيت والإطارات', 'سجل التكاليف يطلع لك مصاريف السنة'] },
      { id: 'docs', page: 'docs', kicker: 'الأوراق', title: 'الأوراق ما تخلص فجأة', sub: 'البطاقة والجواز والرخصة والإقامة لك وللعائلة والعمالة، كل وحدة بمهلتها.',
        points: ['الإقامة تذكّرك قبل شهرين، والجواز قبل ستة', '"قبلها لازم": الضمان الصحي قبل الإقامة', 'الاسم والتاريخ بس، بدون أرقام هويات'] },
      { id: 'subs', page: 'subs', kicker: 'الاشتراكات', title: 'نسألك قبل ما يتجدد', sub: 'التجربة المجانية ما تنقلب مدفوعة بدون ما تدري.',
        points: ['"للحين تستخدمه؟" قبل كل تجديد', 'المجموع بالشهر والسنة بعملتك', 'ملاحظة كيف تلغي، محفوظة عندك'] },
      { id: 'privacy', page: 'settings', kicker: 'أكتوبر · شهر التوعية بالأمن السيبراني', title: 'بياناتك ما تطلع من جهازك', sub: 'نُوخذة مبني على مبدأ واحد: التطبيق يخدمك بدون ما يجمع عنك شي.',
        points: ['بلا حساب وبلا سيرفر، ولا تتبّع', 'نسخة احتياطية مشفّرة AES-256 بكلمة سرك', 'مفتوح المصدر، أي أحد يقدر يراجع الكود'], awareness: true },
    ],
    banner: { title: 'بيتك وسيارتك واشتراكاتك على مواسم الخليج', sub: 'تذكيرات تعرف الصيف والبوارح والوسم، بلا حساب وبلا سيرفر.' },
    awarenessLine: 'أكتوبر شهر التوعية بالأمن السيبراني: اختر تطبيقات تحترم بياناتك.',
  },
  en: {
    site: 'nokhatha.3li.info', free: 'Free', open: 'Open source', local: 'Data stays on your device', platforms: 'Web · iPhone · Android',
    cards: [
      { id: 'hero', page: 'today', kicker: 'Nokhatha', title: 'Your home, car and subscriptions on the Gulf seasons', sub: 'Reminders that know the heat, the Bawarih and Al-Wasm, and tell you what to do before each season.',
        points: ['A year dial of 14 seasons, Suhail to Kulaibain', 'Home and car tasks in the right order for your country', 'No account, no internet, everything on your device'] },
      { id: 'seasons', page: 'home', kicker: 'Seasons', title: 'Maintenance that knows the weather', sub: 'Our dust and heat are like nowhere else, so the reminders move with them.',
        points: ['AC filters every two weeks through the heat and the Bawarih', 'Tank, filters and drains before the first rain', 'Optional dust alerts from your area\'s weather'] },
      { id: 'car', page: 'car', kicker: 'Car', title: 'Renew the registration in the right order', sub: 'Your country\'s steps with their official links, and one tap at the end sets every date.',
        points: ['Insurance, then inspection, then payment, for each Gulf country', 'The odometer estimates your kilometres for oil and tyres', 'A cost log adds up the year\'s spending'] },
      { id: 'docs', page: 'docs', kicker: 'Documents', title: 'Documents that never expire by surprise', sub: 'ID, passport, licence and residency for you, the family and the household staff, each with its own lead.',
        points: ['Residency reminds you two months ahead, passports six', '"Needs first": health cover before the residency', 'Names and dates only, never ID numbers'] },
      { id: 'subs', page: 'subs', kicker: 'Subscriptions', title: 'We ask before it renews', sub: 'A free trial never turns paid without you knowing.',
        points: ['"Still using it?" before every renewal', 'Monthly and yearly totals in your currency', 'A note on how to cancel, kept with you'] },
      { id: 'privacy', page: 'settings', kicker: 'October · Cybersecurity Awareness Month', title: 'Your data never leaves your device', sub: 'Nokhatha is built on one principle: an app that serves you without collecting anything about you.',
        points: ['No account, no server, no tracking', 'AES-256 encrypted backup with your own password', 'Open source, anyone can read the code'], awareness: true },
    ],
    banner: { title: 'Your home, car and subscriptions on the Gulf seasons', sub: 'Reminders that know the heat, the Bawarih and Al-Wasm. No account, no server.' },
    awarenessLine: 'October is Cybersecurity Awareness Month: choose apps that respect your data.',
  },
};

const css = `
@import url('http://localhost:8765/assets/fonts/fonts.css');
* { box-sizing: border-box; margin: 0; padding: 0; }
:root { --night: #1C2340; --night2: #3A4263; --mist: #5F6886; --sadu: #A4262C; --gold: #C98A1B; --sand: #E4D8C4; --pearl: #EEF1F4; --paper: #F6F1E7; }
html, body { width: 100%; height: 100%; }
body { font-family: 'IBM Plex Sans Arabic', system-ui, sans-serif; color: var(--night); background: var(--paper); overflow: hidden; }
.card { position: relative; width: 1080px; height: 1350px; overflow: hidden; background: radial-gradient(120% 80% at 100% 0%, #FBF7EF 0%, var(--paper) 55%, #EFE6D6 100%); }
.card.dark { background: radial-gradient(110% 90% at 0% 0%, #2A3358 0%, var(--night) 55%, #151A2E 100%); color: var(--pearl); }
.band { position: absolute; left: 0; right: 0; height: 14px; background: repeating-linear-gradient(90deg, var(--sadu) 0 18px, var(--night) 18px 36px); opacity: .9; }
.band.top { top: 0; } .band.bottom { bottom: 0; }
.dark .band { background: repeating-linear-gradient(90deg, var(--sadu) 0 18px, var(--gold) 18px 36px); }
.head { position: absolute; top: 64px; inset-inline: 72px; }
.brand { display: flex; align-items: center; gap: 14px; }
.brand img { width: 52px; height: 52px; }
.brand span { font-family: 'Reem Kufi', 'IBM Plex Sans Arabic', sans-serif; font-weight: 700; font-size: 34px; }
.kicker { display: inline-block; margin-top: 44px; padding: 8px 18px; border-radius: 999px; background: var(--night); color: var(--pearl); font-size: 22px; font-weight: 600; }
.dark .kicker { background: var(--gold); color: var(--night); }
h1 { font-family: 'Reem Kufi', 'IBM Plex Sans Arabic', sans-serif; font-weight: 700; font-size: 66px; line-height: 1.22; margin-top: 22px; max-width: 940px; }
.en h1 { font-family: 'IBM Plex Sans Arabic', sans-serif; font-size: 58px; line-height: 1.16; letter-spacing: -.5px; }
.sub { font-size: 26px; line-height: 1.6; color: var(--night2); margin-top: 16px; max-width: 900px; }
.dark .sub { color: #C9CFDF; }
.body { position: absolute; top: 478px; inset-inline: 72px; bottom: 120px; display: flex; gap: 40px; align-items: flex-start; }
.points { flex: 1; padding-top: 38px; display: flex; flex-direction: column; gap: 26px; }
.point { display: flex; gap: 16px; align-items: flex-start; font-size: 27px; line-height: 1.5; font-weight: 500; }
.point i { flex: none; width: 46px; height: 46px; border-radius: 14px; background: var(--night); color: var(--pearl); display: grid; place-items: center; font-style: normal; font-weight: 700; font-size: 22px; margin-top: 2px; }
.dark .point i { background: var(--gold); color: var(--night); }
.phone { flex: none; width: 400px; height: 760px; border-radius: 54px; background: #0E1222; padding: 14px; box-shadow: 0 40px 80px rgba(20, 25, 50, .35), 0 0 0 2px rgba(255,255,255,.08) inset; position: relative; }
.phone .screen { width: 100%; height: 100%; border-radius: 46px; overflow: hidden; background: var(--pearl); position: relative; }
.phone .screen img { width: 100%; display: block; }
.phone .notch { position: absolute; top: 26px; left: 50%; transform: translateX(-50%); width: 120px; height: 34px; border-radius: 20px; background: #0E1222; }
.foot { position: absolute; bottom: 42px; inset-inline: 72px; display: flex; align-items: center; justify-content: space-between; font-size: 22px; color: var(--night2); }
.dark .foot { color: #C9CFDF; }
.foot .site { font-weight: 700; color: var(--night); font-size: 24px; }
.dark .foot .site { color: var(--pearl); }
.tags { display: flex; gap: 10px; }
.tag { padding: 6px 14px; border-radius: 999px; border: 1.5px solid currentColor; font-size: 19px; font-weight: 600; }
.aware { position: absolute; top: 64px; inset-inline-end: 72px; width: 150px; height: 150px; border-radius: 50%; background: var(--gold); color: var(--night); display: grid; place-items: center; text-align: center; font-weight: 700; font-size: 18px; line-height: 1.3; padding: 14px; box-shadow: 0 12px 30px rgba(0,0,0,.25); }
.aware b { display: block; font-size: 44px; line-height: 1; margin-bottom: 4px; font-family: 'Reem Kufi', 'IBM Plex Sans Arabic', sans-serif; }
.lock { position: absolute; bottom: 150px; inset-inline-start: 520px; width: 150px; height: 150px; opacity: .16; }
/* wide banner */
.banner { position: relative; width: 1600px; height: 900px; overflow: hidden; background: radial-gradient(110% 90% at 0% 0%, #2A3358 0%, var(--night) 55%, #151A2E 100%); color: var(--pearl); }
.banner .band { background: repeating-linear-gradient(90deg, var(--sadu) 0 18px, var(--gold) 18px 36px); }
.banner .text { position: absolute; top: 110px; inset-inline-start: 84px; width: 620px; }
.banner .brand span { color: var(--pearl); font-size: 38px; }
.banner h1 { font-size: 54px; margin-top: 30px; max-width: 620px; }
.banner.en h1 { font-size: 46px; }
.banner .sub { color: #C9CFDF; font-size: 24px; margin-top: 16px; max-width: 600px; }
.banner .tags { margin-top: 30px; flex-wrap: wrap; }
.banner .tag { border-color: var(--gold); color: var(--gold); }
.banner .site { position: absolute; bottom: 56px; inset-inline-start: 84px; font-size: 26px; font-weight: 700; color: var(--pearl); }
.banner .aw { position: absolute; bottom: 56px; inset-inline-end: 70px; font-size: 20px; color: var(--gold); font-weight: 600; max-width: 700px; text-align: end; }
.phones { position: absolute; inset-inline-end: 70px; top: 70px; display: flex; gap: 22px; align-items: flex-start; }
.phones .phone { width: 240px; height: 500px; border-radius: 36px; padding: 8px; }
.phones .phone .screen { border-radius: 28px; }
.phones .phone .notch { top: 14px; width: 68px; height: 20px; }
.phones .phone:nth-child(2) { margin-top: 50px; } .phones .phone:nth-child(3) { margin-top: 100px; }
`;

const lockSvg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="10.5" width="16" height="10" rx="2.5"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/><circle cx="12" cy="15.5" r="1.3" fill="currentColor"/></svg>`;
const mark = 'http://localhost:8765/assets/mark.svg';

function cardHtml(lang, c) {
  const t = T[lang];
  const dir = lang === 'ar' ? 'rtl' : 'ltr';
  const aw = c.awareness;
  return `<!doctype html><html lang="${lang}" dir="${dir}"><head><meta charset="utf-8"><style>${css}</style></head><body class="${lang}">
<div class="card ${aw ? 'dark' : ''} ${lang}">
  <div class="band top"></div>
  ${aw ? `<div class="aware"><b>10</b>${lang === 'ar' ? 'شهر التوعية بالأمن السيبراني' : 'Cybersecurity Awareness Month'}</div><div class="lock">${lockSvg}</div>` : ''}
  <div class="head">
    <div class="brand"><img src="${mark}"><span>${lang === 'ar' ? 'نُوخذة' : 'Nokhatha'}</span></div>
    <div class="kicker">${c.kicker}</div>
    <h1>${c.title}</h1>
    <p class="sub">${c.sub}</p>
  </div>
  <div class="body">
    <div class="phone"><div class="screen"><img src="${shot(lang, c.page)}"><div class="notch"></div></div></div>
    <div class="points">${c.points.map((p, i) => `<div class="point"><i>${i + 1}</i><span>${p}</span></div>`).join('')}</div>
  </div>
  <div class="foot"><span class="site">${t.site}</span><div class="tags"><span class="tag">${t.free}</span><span class="tag">${t.open}</span><span class="tag">${t.local}</span></div></div>
  <div class="band bottom"></div>
</div></body></html>`;
}

function bannerHtml(lang) {
  const t = T[lang];
  return `<!doctype html><html lang="${lang}" dir="${lang === 'ar' ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><style>${css}</style></head><body class="${lang}">
<div class="banner ${lang}">
  <div class="band top"></div>
  <div class="text">
    <div class="brand"><img src="${mark}"><span>${lang === 'ar' ? 'نُوخذة' : 'Nokhatha'}</span></div>
    <h1>${t.banner.title}</h1>
    <p class="sub">${t.banner.sub}</p>
    <div class="tags"><span class="tag">${t.free}</span><span class="tag">${t.open}</span><span class="tag">${t.local}</span><span class="tag">${t.platforms}</span></div>
  </div>
  <div class="phones">${['today', 'car', 'docs'].map((p) => `<div class="phone"><div class="screen"><img src="${shot(lang, p)}"><div class="notch"></div></div></div>`).join('')}</div>
  <div class="site">${t.site}</div>
  <div class="aw">${t.awarenessLine}</div>
  <div class="band bottom"></div>
</div></body></html>`;
}

const b = await chromium.launch();
for (const lang of ['ar', 'en']) {
  mkdirSync(`${out}/${lang}`, { recursive: true });
  const ctx = await b.newContext({ viewport: { width: 1080, height: 1350 }, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  let n = 1;
  for (const c of T[lang].cards) {
    await page.setContent(cardHtml(lang, c), { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(300);
    await page.screenshot({ path: `${out}/${lang}/${n}-${c.id}.png`, clip: { x: 0, y: 0, width: 1080, height: 1350 } });
    n++;
  }
  await ctx.close();
  const wide = await b.newContext({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 1 });
  const wp = await wide.newPage();
  await wp.setContent(bannerHtml(lang), { waitUntil: 'networkidle' });
  await wp.evaluate(() => document.fonts.ready);
  await wp.waitForTimeout(300);
  await wp.screenshot({ path: `${out}/${lang}/banner-1600x900.png`, clip: { x: 0, y: 0, width: 1600, height: 900 } });
  await wide.close();
}
await b.close();
console.log('cards written to', out);
