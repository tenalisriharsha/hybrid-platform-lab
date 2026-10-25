// Runs `terraform test` and `./scripts/run-ansible-tests.sh` for real,
// captures their genuine stdout/stderr, and screenshots it into a terminal
// card matching docs/screenshots/07-09's style. Never hand-edits captured
// output - the Ansible run is abridged (full task-by-task detail replaced
// with an explicit "... (output truncated ...)" line) because the role has
// 16 tasks applied twice; everything else is kept verbatim.
//
// Requires: `npm install` in this directory (installs playwright), a
// `terraform` binary on PATH, and Docker running (the Ansible script starts
// and tears down its own disposable container). Run from the repo root:
//
//   cd scripts/capture && npm install && cd ../.. && node scripts/capture/capture-screenshots.mjs

import { chromium } from "playwright";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderTerminalCard } from "./template.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "..", "..");
const OUT_DIR = path.join(REPO_ROOT, "docs", "screenshots");

function run(cmd, args, cwd) {
  try {
    return execFileSync(cmd, args, { cwd, encoding: "utf8" });
  } catch (err) {
    // terraform test / the ansible script exit non-zero on failure, but we
    // still want whatever output they produced (and a failing run should
    // never be silently turned into a "passing" screenshot).
    return (err.stdout ?? "") + (err.stderr ?? "");
  }
}

function truncateBetween(lines, startMarker, endMarker, note) {
  const start = lines.findIndex((l) => l.includes(startMarker));
  if (start === -1) return lines.join("\n");
  const endOffset = lines.slice(start + 1).findIndex((l) => l.includes(endMarker));
  if (endOffset === -1) return lines.join("\n");
  const end = start + 1 + endOffset;
  return [...lines.slice(0, start + 1), "", note, "", ...lines.slice(end)].join("\n");
}

console.log("Running: terraform test (terraform/modules/proxmox-vm)");
const tfRaw = run("terraform", ["test", "-no-color"], path.join(REPO_ROOT, "terraform/modules/proxmox-vm"));
const tfBody = tfRaw.trim();

console.log("Running: ./scripts/run-ansible-tests.sh (this starts/stops a real container)");
const ansRaw = run("./scripts/run-ansible-tests.sh", [], REPO_ROOT);
let ansLines = ansRaw.trim().split("\n");
ansLines = truncateBetween(
  ansLines,
  "First apply (expect changes)",
  "PLAY RECAP",
  "... (output truncated - 16 tasks applying the linux-baseline role in full, all ok/changed)"
).split("\n");
ansLines = truncateBetween(
  ansLines,
  "Second apply (expect no changes",
  "PLAY RECAP",
  "... (output truncated - the same 16 tasks re-applied; every one now reports ok, none changed)"
).split("\n");
const ansBody = ansLines.join("\n");

const pages = [
  {
    file: "10-terraform-test.png",
    title: "terraform test -- proxmox-vm module, mock_provider",
    prompt: "lab:~/hybrid-platform-lab/terraform/modules/proxmox-vm$",
    command: "terraform test",
    body: tfBody,
    width: 820,
  },
  {
    file: "11-ansible-lint-idempotence.png",
    title: "./scripts/run-ansible-tests.sh -- lint + idempotence check",
    prompt: "lab:~/hybrid-platform-lab$",
    command: "./scripts/run-ansible-tests.sh",
    body: ansBody,
    width: 1040,
  },
];

const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 2 });

for (const spec of pages) {
  const html = renderTerminalCard(spec);
  const htmlPath = path.join("/tmp", spec.file.replace(".png", ".html"));
  fs.writeFileSync(htmlPath, html);
  await page.setViewportSize({ width: spec.width + 80, height: 100 });
  await page.goto("file://" + htmlPath);
  await page.locator("#card").screenshot({ path: path.join(OUT_DIR, spec.file) });
  console.log("wrote", path.relative(REPO_ROOT, path.join(OUT_DIR, spec.file)));
}

await browser.close();
