// Regenerates every image in docs/screenshots (01-11) by RUNNING the real system:
//   * the FastAPI service is started and called for real (curl) and screenshotted (Swagger UI);
//   * pytest, ruff, the Pester suite, the PowerCLI demos, terraform test and the Ansible script are
//     executed, and their combined stdout/stderr is captured as it arrives and rendered into a terminal card.
// Nothing is typed, edited or reworded by hand. The command shown on each card is the command that ran
// (from the working directory named in the card). The only transformations are: colour escape codes are
// removed, and the very long Ansible run is abridged with an explicit "... (output truncated ...)" line.
// A command that exits non-zero aborts the run, so a failing run can never become a "passing" screenshot.
//
// Requires: Python venv in api/.venv (pytest, ruff, uvicorn), pwsh with Pester and VMware.PowerCLI, Docker,
// terraform, ansible, and `cd scripts/capture && npm install`. The browser is the Chromium Playwright cached.
// Run from the repo root:  node scripts/capture/capture-screenshots.mjs
import { chromium } from "playwright";
import { spawn, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderTerminalCard } from "./template.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, "..", "..");
const OUT = path.join(ROOT, "docs", "screenshots");
const PORT = process.env.CAPTURE_API_PORT ?? "8000"; // set CAPTURE_API_PORT if 8000 is already taken
const API = `http://127.0.0.1:${PORT}`;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const stripAnsi = (s) => s.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "");

function findChromium() {
  for (const dir of [path.join(os.homedir(), "Library/Caches/ms-playwright"), path.join(os.homedir(), ".cache/ms-playwright")]) {
    if (!fs.existsSync(dir)) continue;
    for (const d of fs.readdirSync(dir).filter((x) => x.startsWith("chromium-")).sort().reverse()) {
      for (const rel of ["chrome-mac/Chromium.app/Contents/MacOS/Chromium", "chrome-mac-arm64/Chromium.app/Contents/MacOS/Chromium", "chrome-linux/chrome"]) {
        const p = path.join(dir, d, rel);
        if (fs.existsSync(p)) return p;
      }
    }
  }
  return undefined;
}

function runShell(cmd, cwd, env = {}) {
  return new Promise((resolve) => {
    const child = spawn("bash", ["-c", cmd], { cwd, env: { ...process.env, ...env } });
    let out = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (out += d));
    child.on("close", (code) => resolve({ out: stripAnsi(out).replace(/\s+$/, ""), code }));
  });
}

const venvBin = path.join(ROOT, "api", ".venv", "bin");
const withVenv = { PATH: `${venvBin}:${process.env.PATH}` };
const browser = await chromium.launch({ executablePath: findChromium() });
const cardPage = await browser.newPage({ deviceScaleFactor: 2 });

async function card(file, title, cwdLabel, command, cwd, opts = {}) {
  const { out, code } = await runShell(command, cwd, withVenv);
  if (code !== 0) throw new Error(`${command} exited ${code}:\n${out}`);
  const body = opts.transform ? opts.transform(out) : out;
  const html = renderTerminalCard({ title, prompt: cwdLabel, command, body, width: opts.width ?? 1040 });
  const htmlPath = path.join(os.tmpdir(), file.replace(".png", ".html"));
  fs.writeFileSync(htmlPath, html);
  await cardPage.setViewportSize({ width: (opts.width ?? 1040) + 80, height: 100 });
  await cardPage.goto("file://" + htmlPath);
  await cardPage.locator("#card").screenshot({ path: path.join(OUT, file) });
  console.log("wrote", file);
}

function abridge(lines, startMarker, endMarker, note) {
  const start = lines.findIndex((l) => l.includes(startMarker));
  if (start === -1) return lines;
  const off = lines.slice(start + 1).findIndex((l) => l.includes(endMarker));
  if (off === -1) return lines;
  return [...lines.slice(0, start + 1), "", note, "", ...lines.slice(start + 1 + off)];
}

fs.mkdirSync(OUT, { recursive: true });
for (const f of fs.readdirSync(OUT)) if (f.endsWith(".png")) fs.rmSync(path.join(OUT, f));

// ---- the API ---------------------------------------------------------------------------------------
const api = spawn(path.join(venvBin, "uvicorn"), ["app.main:app", "--port", PORT], { cwd: path.join(ROOT, "api"), detached: true, stdio: "ignore" });
const stopApi = () => { try { process.kill(-api.pid); } catch { /* gone */ } };
process.on("exit", stopApi);
for (let i = 0; i < 60; i++) { try { if ((await fetch(API + "/docs")).ok) break; } catch { /* starting */ } await sleep(500); }
const post = (body) => fetch(API + "/environments", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
await post({ name: "dev-box-1", template: "ubuntu-22.04-vsphere", size: "small", owner: "alice@example.com" });
await post({ name: "ci-runner-1", template: "ubuntu-22.04-proxmox", size: "medium", owner: "bob@example.com" });

const sw = await browser.newPage({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 2 });
await sw.goto(API + "/docs");
await sw.waitForSelector(".opblock", { timeout: 30000 });
await sleep(600);
await sw.screenshot({ path: path.join(OUT, "01-swagger-overview.png") });
console.log("wrote 01-swagger-overview.png");

await card("02-create-environment.png", "POST /environments against the running API", "$",
  `curl -s -X POST ${API}/environments -H 'Content-Type: application/json' -d '{"name":"windows-test-1","template":"windows-server-2022-vsphere","size":"large","owner":"carol@example.com"}' | python3 -m json.tool`, ROOT);
await card("03-list-environments.png", "GET /environments", "$", `curl -s ${API}/environments | python3 -m json.tool`, ROOT);
await card("06-metrics-endpoint.png", "GET /metrics (Prometheus exposition format)", "$",
  `curl -s ${API}/metrics | grep -E '^(http_|environments_)' | head -24`, ROOT);
stopApi();

// ---- tests and lint --------------------------------------------------------------------------------
await card("04-pytest-suite.png", "API test suite", "api $", "python -m pytest -q", path.join(ROOT, "api"));
await card("05-ruff-check.png", "ruff", "api $", "ruff check .", path.join(ROOT, "api"));
await card("07-pester-suite-vcsim.png", "PowerCLI Pester suite against vcsim (vCenter and ESXi modes)", "$",
  "./scripts/run-pester-tests.sh 2>&1 | tail -22", ROOT);

// ---- PowerCLI demos against a disposable vcsim ----------------------------------------------------------
const vcsim = async () => {
  spawnSync("docker", ["rm", "-f", "hpl-capture-vcsim"]);
  spawnSync("docker", ["run", "-d", "--name", "hpl-capture-vcsim", "-p", "8989:8989", "vmware/vcsim", "-l", ":8989"]);
  for (let i = 0; i < 40; i++) { const r = spawnSync("curl", ["-sk", "-o", "/dev/null", "-w", "%{http_code}", "https://127.0.0.1:8989/sdk"]); if (r.stdout.toString() !== "000") break; await sleep(500); }
};
try {
  await vcsim();
  await card("08-inventory-drift-report.png", "Get-VMInventoryReport: drift against a desired-state file (vcsim)", "$",
    "pwsh -NoProfile -File powercli/examples/demo-drift-report.ps1", ROOT);
  await vcsim();
  await card("09-snapshot-policy-protected-whatif.png", "Invoke-SnapshotPolicy -WhatIf: the protected VM is refused (vcsim)", "$",
    "pwsh -NoProfile -File powercli/examples/demo-snapshot-policy.ps1", ROOT);
} finally {
  spawnSync("docker", ["rm", "-f", "hpl-capture-vcsim"]);
}

// ---- Terraform and Ansible -----------------------------------------------------------------------------
await card("10-terraform-test.png", "terraform test: proxmox-vm module, mock_provider", "proxmox-vm $", "terraform test -no-color",
  path.join(ROOT, "terraform/modules/proxmox-vm"), { width: 820 });
await card("11-ansible-lint-idempotence.png", "lint and idempotence check for the linux-baseline role", "$", "./scripts/run-ansible-tests.sh", ROOT, {
  transform: (out) => {
    let lines = out.split("\n");
    lines = abridge(lines, "First apply (expect changes)", "PLAY RECAP", "... (output truncated - the 16 tasks of the first apply, all ok or changed)");
    lines = abridge(lines, "Second apply (expect no changes", "PLAY RECAP", "... (output truncated - the same 16 tasks re-applied; every one reports ok, none changed)");
    return lines.join("\n");
  },
});
await browser.close();
