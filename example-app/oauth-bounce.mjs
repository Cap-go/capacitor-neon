// Local stand-in for the OAuth bounce page you would host on your own trusted domain.
// Neon Auth only redirects to http(s) URLs on trusted domains, and localhost is trusted
// by default. This page forwards the session verifier to the app's custom URL scheme.
//
// Android emulator: run `adb reverse tcp:8787 tcp:8787` so the emulator's localhost reaches it.
import { createServer } from 'node:http';

const scheme = process.env.APP_SCHEME ?? 'com.capacitorneon.example';
const port = Number(process.env.PORT ?? 8787);

createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${port}`);
  if (url.pathname !== '/auth/callback') {
    res.writeHead(404).end('Not found');
    return;
  }
  const target = `${scheme}://auth/callback${url.search}`;
  const href = target.replaceAll('&', '&amp;').replaceAll('"', '&quot;');
  console.log(`Forwarding OAuth callback to ${scheme}://auth/callback`);
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }).end(`<!doctype html>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Returning to the app</title>
<body style="font-family: system-ui; padding: 2rem; text-align: center">
  <p>Signed in. Returning to the app.</p>
  <p><a href="${href}" style="font-size: 1.2rem">Open the app</a></p>
  <script>location.href = ${JSON.stringify(target).replaceAll("<", "\\u003c")};</script>
</body>`);
}).listen(port, () => console.log(`OAuth bounce page on http://localhost:${port}/auth/callback -> ${scheme}://`));
