// =============================================================================
// Vérification automatique de la version Web dans Chromium (sans écran).
//
// Utilisé par tools/web/check_web.sh, qui sert build/web sur un petit serveur
// local dans un sous-dossier /paradoxe/ (comme GitHub Pages).
//
// Contrôles :
//   1. la page devient « cross-origin isolated » dès la première visite
//      (service worker de Godot + notre script de rechargement) ;
//   2. aucune erreur JavaScript ;
//   3. le contexte audio reste suspendu avant toute interaction (règle des navigateurs) ;
//   4. après un clic : du son sort vraiment (mesure du volume sur la sortie) ;
//   5. captures d'écran avant / après le clic.
// Code de sortie 0 si tout est bon, 1 sinon.
// =============================================================================
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright-core');

const url = process.argv[2];
const outDir = process.argv[3] || '.';

function findChromium() {
  if (process.env.CHROMIUM_PATH) return process.env.CHROMIUM_PATH;
  const root = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
  const dirs = fs.existsSync(root) ? fs.readdirSync(root).filter(d => /^chromium-\d+$/.test(d)).sort() : [];
  for (const d of dirs.reverse()) {
    const exe = path.join(root, d, 'chrome-linux', 'chrome');
    if (fs.existsSync(exe)) return exe;
  }
  return undefined; // laisse Playwright chercher lui-même
}

(async () => {
  const browser = await chromium.launch({
    executablePath: findChromium(),
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  // Branche un analyseur sur la sortie audio pour mesurer ce qui sort réellement.
  await context.addInitScript(() => {
    const origConnect = AudioNode.prototype.connect;
    AudioNode.prototype.connect = function (dest, ...rest) {
      const result = origConnect.call(this, dest, ...rest);
      if (dest instanceof AudioDestinationNode) {
        const ctx = dest.context;
        if (!ctx.__analyser) {
          ctx.__analyser = ctx.createAnalyser();
          ctx.__analyser.fftSize = 8192;
          window.__analyser = ctx.__analyser;
          window.__audioCtx = ctx;
        }
        origConnect.call(this, ctx.__analyser);
      }
      return result;
    };
  });

  const page = await context.newPage();
  const jsErrors = [];
  const consoleLines = [];
  page.on('pageerror', e => jsErrors.push(e.message));
  page.on('console', m => consoleLines.push(`[${m.type()}] ${m.text()}`));

  const problems = [];
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForTimeout(9000);          // premier chargement + rechargement(s) éventuel(s)
  await page.waitForLoadState('load');
  const iso = await page.evaluate(() => ({ isolated: window.crossOriginIsolated, controlled: !!navigator.serviceWorker.controller }));
  console.log('Isolation :', JSON.stringify(iso));
  if (!iso.isolated) problems.push('page non isolée (multithread impossible)');

  await page.waitForTimeout(8000);          // téléchargement du moteur et démarrage
  const rms = () => page.evaluate(async () => {
    const an = window.__analyser;
    if (!an) return { rms: 0, state: 'aucun contexte audio' };
    let sum = 0;
    for (let k = 0; k < 8; k++) {
      const buf = new Float32Array(an.fftSize);
      an.getFloatTimeDomainData(buf);
      sum += Math.sqrt(buf.reduce((a, v) => a + v * v, 0) / buf.length);
      await new Promise(r => setTimeout(r, 100));
    }
    return { rms: sum / 8, state: window.__audioCtx.state };
  });

  const before = await rms();
  console.log('Audio avant interaction :', JSON.stringify(before));
  if (before.rms > 0.001) problems.push('du son sort avant toute interaction');
  await page.screenshot({ path: path.join(outDir, 'web_before_click.png') });

  await page.mouse.click(640, 360);
  await page.waitForTimeout(3500);
  const after = await rms();
  console.log('Audio après un clic :', JSON.stringify(after));
  if (after.state !== 'running') problems.push(`contexte audio « ${after.state} » après le clic`);
  if (after.rms < 0.005) problems.push('aucun son mesuré après le clic');
  await page.screenshot({ path: path.join(outDir, 'web_after_click.png') });

  // Salle de test : Entrée active le bouton « salle de test » (il a le focus),
  // puis Élias tire (touche X) : on vérifie que le jeu tourne sans erreur.
  await page.keyboard.press('Enter');
  await page.waitForTimeout(4000);
  await page.keyboard.down('KeyX');
  await page.waitForTimeout(300);
  await page.keyboard.up('KeyX');
  await page.waitForTimeout(700);
  await page.screenshot({ path: path.join(outDir, 'web_level.png') });

  // Le message « Service worker already exists » de Godot est attendu et sans conséquence.
  const realErrors = jsErrors.filter(e => !e.includes('Service worker already exists'));
  if (realErrors.length) problems.push('erreurs JavaScript : ' + realErrors.join(' | '));
  const engineErrors = consoleLines.filter(l => l.startsWith('[error]') && !l.includes('Service worker already exists'));
  if (engineErrors.length) problems.push('erreurs du moteur : ' + engineErrors.join(' | '));

  console.log('--- Console du navigateur ---');
  consoleLines.forEach(l => console.log(l));
  await browser.close();

  if (problems.length) {
    console.log('\nPROBLÈMES :\n - ' + problems.join('\n - '));
    process.exit(1);
  }
  console.log('\nVersion Web : OK');
})().catch(e => { console.error(e); process.exit(1); });
