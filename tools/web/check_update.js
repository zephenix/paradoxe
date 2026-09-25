// =============================================================================
// Vérifie qu'une NOUVELLE version du jeu remplace l'ancienne dans le navigateur,
// sans que le joueur ait à fermer ses onglets (voir tools/web/check_update.sh).
//
// Arguments : <url> <lien_symbolique_du_site> <dossier_v1> <dossier_v2>
//   1. le site pointe sur la v1 : on l'ouvre, le jeu doit afficher « PARADOXE v9.0.1 » ;
//   2. on attend que le service worker soit « au repos » (voir plus bas) ;
//   3. on remplace le site par la v2 et on revient sur la page ;
//   4. le jeu doit se recharger tout seul et afficher « PARADOXE v9.0.2 ».
//
// TRACE_SW=1 affiche les messages de la page, avec l'heure (en secondes).
// =============================================================================
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright-core');
const [url, siteLink, dirV1, dirV2] = process.argv.slice(2);

function findChromium() {
  if (process.env.CHROMIUM_PATH) return process.env.CHROMIUM_PATH;
  const root = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
  const dirs = fs.existsSync(root) ? fs.readdirSync(root).filter(d => /^chromium-\d+$/.test(d)).sort().reverse() : [];
  for (const d of dirs) {
    const exe = path.join(root, d, 'chrome-linux', 'chrome');
    if (fs.existsSync(exe)) return exe;
  }
  return undefined;
}

function pointSiteTo(dir) {
  fs.rmSync(siteLink, { force: true });
  fs.symlinkSync(dir, siteLink);
}

(async () => {
  const browser = await chromium.launch({ executablePath: findChromium(), args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
  const t0 = Date.now();
  const versions = [];
  page.on('console', m => { const v = m.text().match(/PARADOXE v(\S+)/); if (v) versions.push(v[1]); });
  if (process.env.TRACE_SW) page.on('console', m => console.log('   [page]', ((Date.now() - t0) / 1000).toFixed(1), m.text().slice(0, 120)));
  const waitVersion = async (expected, ms) => {
    for (let t = 0; t < ms; t += 500) {
      if (versions.includes(expected)) return true;
      await page.waitForTimeout(500);
    }
    return false;
  };

  pointSiteTo(dirV1);
  await page.goto(url, { waitUntil: 'load' });
  const v1 = await waitVersion('9.0.1', 40000);
  console.log('Version 1 affichée :', v1, versions);

  // Juste après la TOUTE PREMIÈRE installation du service worker, Chromium met en
  // attente les recherches de mise à jour pendant environ 60 s (constaté, pas
  // documenté). Un joueur qui revient sur le site des heures plus tard ne voit
  // jamais ce cas : on attend donc que reg.update() réponde normalement.
  const settledAfter = await page.evaluate(async () => {
    const reg = await navigator.serviceWorker.getRegistration();
    const start = performance.now();
    for (;;) {
      const ok = await Promise.race([reg.update().then(() => true, () => true), new Promise(r => setTimeout(() => r(false), 2000))]);
      if (ok || performance.now() - start > 120000) return Math.round((performance.now() - start) / 1000);
    }
  });
  console.log('Service worker au repos après', settledAfter, 's');

  pointSiteTo(dirV2);
  versions.length = 0;
  await page.goto(url, { waitUntil: 'load' });  // le joueur revient sur la page
  const v2 = await waitVersion('9.0.2', 20000);
  console.log('Version 2 affichée après retour sur la page :', v2, versions);
  const iso = await page.evaluate(() => window.crossOriginIsolated);
  console.log('Isolation après mise à jour :', iso);
  await browser.close();
  if (!v1 || !v2 || !iso) {
    console.log('\nPROBLÈME : la mise à jour ne remplace pas l\'ancienne version');
    process.exit(1);
  }
  console.log('\nMise à jour Web : OK');
})().catch(e => { console.error(e); process.exit(1); });
