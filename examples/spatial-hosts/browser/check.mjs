import {spawn} from "node:child_process";
import {readFile} from "node:fs/promises";
import {join} from "node:path";
import {setTimeout as pause} from "node:timers/promises";

const [executable, profile, url] = process.argv.slice(2);
const child = spawn(executable, [
  "--headless=new", "--disable-gpu", "--disable-background-networking",
  "--no-first-run", "--no-default-browser-check", "--remote-debugging-port=0",
  `--user-data-dir=${profile}`, url,
], {stdio: "ignore", windowsHide: true});
let launchError;
child.on("error", error => { launchError = error; });
let socket;
let messageId = 0;

async function until(probe) {
  for (let attempt = 0; attempt < 120; attempt++) {
    if (launchError) throw launchError;
    if (child.exitCode !== null) throw new Error(`Browser exited with code ${child.exitCode}`);
    const result = await probe();
    if (result) return result;
    await pause(200);
  }
  throw new Error("Browser page did not become ready");
}

function request(method, params = {}) {
  const id = ++messageId;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.removeEventListener("message", read);
      reject(new Error(`Timed out waiting for ${method}`));
    }, 15000);
    function read(event) {
      const response = JSON.parse(event.data);
      if (response.id !== id) return;
      clearTimeout(timer);
      socket.removeEventListener("message", read);
      if (response.error) reject(new Error(response.error.message));
      else resolve(response.result);
    }
    socket.addEventListener("message", read);
    socket.send(JSON.stringify({id, method, params}));
  });
}

try {
  const target = await until(async () => {
    try {
      const port = (await readFile(join(profile, "DevToolsActivePort"), "utf8")).split("\n")[0];
      const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      return pages.find(page => page.url === url);
    } catch {
      return null;
    }
  });
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, {once: true});
    socket.addEventListener("error", reject, {once: true});
  });
  await until(async () => {
    const reply = await request("Runtime.evaluate", {expression: 'typeof verifySpatialWorklet === "function"'});
    return reply.result.value;
  });
  const browser = await request("Browser.getVersion");
  const reply = await request("Runtime.evaluate", {
    expression: "verifySpatialWorklet()", awaitPromise: true, returnByValue: true,
  });
  if (reply.exceptionDetails) {
    throw new Error(reply.exceptionDetails.exception?.description || reply.exceptionDetails.text);
  }
  console.log(JSON.stringify({...reply.result.value, browser: browser.product}));
} finally {
  socket?.close();
  child.kill();
}
