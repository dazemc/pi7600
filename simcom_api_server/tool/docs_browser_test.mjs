import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const PAGE = 'http://127.0.0.1:8099/docs';
const cdpPort = 9222 + Math.floor(Math.random() * 500);
const profile = mkdtempSync(path.join(tmpdir(), 'pi7600-docs-browser-'));
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function findChrome() {
  const candidates = [
    process.env.CHROME_BIN,
    'google-chrome',
    'google-chrome-stable',
    'chromium',
    'chromium-browser',
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (spawnSync('which', [candidate], { stdio: 'ignore' }).status === 0) {
      return candidate;
    }
  }
  for (const candidate of [
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ]) {
    if (existsSync(candidate)) return candidate;
  }
  throw new Error('Chrome/Chromium not found; set CHROME_BIN.');
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function main() {
  if (typeof WebSocket === 'undefined') {
    throw new Error('This test requires Node.js 22 or newer.');
  }

  const chrome = spawn(
    findChrome(),
    [
      '--headless=new',
      '--no-sandbox',
      '--disable-gpu',
      `--remote-debugging-port=${cdpPort}`,
      `--user-data-dir=${profile}`,
      'about:blank',
    ],
    { stdio: 'ignore' },
  );

  try {
    let version;
    for (let i = 0; i < 100; i++) {
      try {
        const response = await fetch(`http://127.0.0.1:${cdpPort}/json/version`);
        if (response.ok) {
          version = await response.json();
          break;
        }
      } catch (_) {
        // Chrome is still starting.
      }
      await sleep(100);
    }
    assert(version, 'Chrome DevTools endpoint did not start');

    const ws = new WebSocket(version.webSocketDebuggerUrl);
    let nextId = 1;
    const pending = new Map();

    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.id && pending.has(message.id)) {
        const { resolve, reject } = pending.get(message.id);
        pending.delete(message.id);
        if (message.error) reject(new Error(JSON.stringify(message.error)));
        else resolve(message.result);
      }
    });

    await new Promise((resolve, reject) => {
      ws.addEventListener('open', resolve, { once: true });
      ws.addEventListener('error', reject, { once: true });
    });

    function send(method, params = {}, sessionId) {
      const id = nextId++;
      const payload = { id, method, params };
      if (sessionId) payload.sessionId = sessionId;
      return new Promise((resolve, reject) => {
        pending.set(id, { resolve, reject });
        ws.send(JSON.stringify(payload));
      });
    }

    const { targetId } = await send('Target.createTarget', { url: PAGE });
    const { sessionId } = await send('Target.attachToTarget', {
      targetId,
      flatten: true,
    });
    await send('Runtime.enable', {}, sessionId);
    await send('Page.enable', {}, sessionId);

    async function evaluate(expression) {
      const result = await send(
        'Runtime.evaluate',
        { expression, returnByValue: true, awaitPromise: true },
        sessionId,
      );
      if (result.exceptionDetails) {
        throw new Error(JSON.stringify(result.exceptionDetails));
      }
      return result.result.value;
    }

    async function waitFor(expression, predicate, timeoutMs = 15000) {
      const started = Date.now();
      while (Date.now() - started < timeoutMs) {
        const value = await evaluate(expression);
        if (predicate(value)) return value;
        await sleep(200);
      }
      throw new Error(`Timed out waiting for: ${expression}`);
    }

    async function execute(path) {
      return evaluate(`(async function () {
        const card = document.querySelector('.endpoint[data-path="${path}"]');
        card.open = true;
        await new Promise((r) => setTimeout(r, 500));
        card.querySelector('.execute').click();
        for (let i = 0; i < 100; i++) {
          const wrap = card.querySelector('.result-wrap');
          const status = card.querySelector('.result-status').textContent;
          if (wrap && !wrap.hidden && status) break;
          await new Promise((r) => setTimeout(r, 100));
        }
        return {
          status: card.querySelector('.result-status').textContent,
          body: card.querySelector('.result').textContent
        };
      })()`);
    }

    await waitFor(
      `({
        login: !!document.getElementById('login-form'),
        session: !!document.getElementById('session'),
        card: !!document.querySelector('.endpoint[data-path="/info"]')
      })`,
      (value) => value.login && value.session && value.card,
    );

    const initial = await evaluate(`({
      loginVisible: !document.getElementById('login-form').hidden,
      sessionHidden: document.getElementById('session').hidden,
      hasToken: !!localStorage.getItem('pi7600.docs.token')
    })`);
    assert(initial.loginVisible, 'login form is not visible');
    assert(initial.sessionHidden, 'session view is visible before login');
    assert(!initial.hasToken, 'a token is present before login');

    const unauthenticated = await execute('/info');
    assert(
      unauthenticated.status.startsWith('HTTP 401'),
      `expected 401 without a token, got ${unauthenticated.status}`,
    );

    await evaluate(`(function () {
      document.getElementById('username').value = 'alice';
      document.getElementById('password').value = 'wrong';
      document.getElementById('login-form').requestSubmit();
      return true;
    })()`);
    const wrongLogin = await waitFor(
      `document.getElementById('login-status').textContent`,
      (value) => value.includes('Incorrect'),
    );
    assert(wrongLogin.includes('Incorrect'), 'wrong credentials were accepted');
    assert(
      !(await evaluate(`!!localStorage.getItem('pi7600.docs.token')`)),
      'wrong login stored a token',
    );

    await evaluate(`(function () {
      document.getElementById('username').value = 'alice';
      document.getElementById('password').value = 'secret';
      document.getElementById('login-form').requestSubmit();
      return true;
    })()`);
    const sessionStatus = await waitFor(
      `document.getElementById('session-status').textContent`,
      (value) => value.includes('Signed in as alice'),
    );
    assert(sessionStatus.includes('Signed in as alice'), 'login did not succeed');
    assert(
      await evaluate(`!!localStorage.getItem('pi7600.docs.token')`),
      'login did not store a token',
    );

    await send('Page.reload', {}, sessionId);
    await sleep(2500);
    const reloaded = await evaluate(`({
      loginHidden: document.getElementById('login-form').hidden,
      sessionHidden: document.getElementById('session').hidden,
      sessionStatus: document.getElementById('session-status').textContent
    })`);
    assert(reloaded.loginHidden, 'login form visible after reload');
    assert(!reloaded.sessionHidden, 'session view hidden after reload');
    assert(
      reloaded.sessionStatus.includes('Signed in as alice'),
      'signed-in state did not survive reload',
    );

    const authenticated = await execute('/info');
    assert(
      authenticated.status.startsWith('HTTP 200'),
      `expected 200 with a token, got ${authenticated.status}`,
    );
    assert(
      authenticated.body.includes('docs-test'),
      'authenticated response body was not rendered',
    );

    await evaluate(`document.getElementById('logout').click()`);
    const loggedOut = await waitFor(
      `({
        loginVisible: !document.getElementById('login-form').hidden,
        hasToken: !!localStorage.getItem('pi7600.docs.token')
      })`,
      (value) => value.loginVisible && !value.hasToken,
    );
    assert(loggedOut.loginVisible, 'login form not visible after logout');
    assert(!loggedOut.hasToken, 'token still stored after logout');

    await send('Target.closeTarget', { targetId });
    ws.close();
    console.log('DOCS_BROWSER_TEST=pass');
  } finally {
    chrome.kill('SIGKILL');
    if (chrome.exitCode === null) {
      await new Promise((resolve) => {
        const timer = setTimeout(resolve, 2000);
        chrome.once('exit', () => {
          clearTimeout(timer);
          resolve();
        });
      });
    }
    try {
      rmSync(profile, {
        recursive: true,
        force: true,
        maxRetries: 5,
        retryDelay: 100,
      });
    } catch (_) {
      // Chrome may still be flushing its profile; cleanup is best-effort.
    }
  }
}

main().catch((error) => {
  console.error('DOCS_BROWSER_TEST=fail', error);
  process.exitCode = 1;
});
