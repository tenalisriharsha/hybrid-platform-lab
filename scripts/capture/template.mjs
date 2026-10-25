export function escapeHtml(s) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

// Colors a line based on simple, content-driven rules (no hand-edited text,
// only CSS classes applied per matched pattern) to match the existing
// docs/screenshots/07-09 terminal-card style.
function colorLine(line) {
  const esc = escapeHtml(line);
  if (/^\.\.\. \(output truncated/.test(line)) {
    return `<span class="trunc">${esc}</span>`;
  }
  if (/^Success!/.test(line) || /role is idempotent/.test(line)) {
    return `<span class="ok">${esc}</span>`;
  }
  if (/\bpass\b/i.test(line) && /^\s*(run |tests\/)/.test(line)) {
    return esc.replace(/\bpass\b/, '<span class="ok">pass</span>');
  }
  if (/^WARNING/.test(line)) {
    return `<span class="warn">${esc}</span>`;
  }
  if (/^PLAY RECAP/.test(line) || /^PLAY \[/.test(line) || /^TASK \[/.test(line) || /^RUNNING HANDLER/.test(line)) {
    return `<span class="section">${esc}</span>`;
  }
  if (/changed=0/.test(line)) {
    return esc.replace(/changed=0/, '<span class="ok">changed=0</span>');
  }
  if (/^==>/.test(line)) {
    return `<span class="step">${esc}</span>`;
  }
  if (/^changed:/.test(line)) {
    return `<span class="changed">${esc}</span>`;
  }
  if (/^ok:/.test(line) || /^skipping:/.test(line) || /^included:/.test(line)) {
    return `<span class="dim">${esc}</span>`;
  }
  return esc;
}

export function renderTerminalCard({ title, prompt, command, body, width = 1040 }) {
  const lines = body.split("\n").map(colorLine).join("\n");
  const promptLine = prompt
    ? `<div class="promptline"><span class="prompt">${escapeHtml(prompt)}</span> <span class="cmd">${escapeHtml(command)}</span></div>`
    : "";
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; }
  html, body {
    margin: 0;
    padding: 0;
    background: #11121b;
  }
  .card {
    width: ${width}px;
    background: #1a1b26;
    border-radius: 10px;
    border: 1px solid #2a2c3d;
    box-shadow: 0 12px 28px rgba(0,0,0,0.45);
    overflow: hidden;
    font-family: "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
  }
  .titlebar {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 12px 16px;
    background: #1f2133;
    border-bottom: 1px solid #2a2c3d;
  }
  .dots { display: flex; gap: 7px; }
  .dot { width: 11px; height: 11px; border-radius: 50%; }
  .dot.red { background: #ff5f56; }
  .dot.yellow { background: #ffbd2e; }
  .dot.green { background: #27c93f; }
  .title {
    color: #9aa1b1;
    font-size: 13px;
  }
  .body {
    padding: 20px 24px 26px 24px;
    color: #c6cad3;
    font-size: 13px;
    line-height: 1.55;
    white-space: pre-wrap;
    word-break: break-word;
  }
  .promptline { margin-bottom: 14px; }
  .prompt { color: #9ece6a; font-weight: 700; }
  .cmd { color: #e8eaf0; }
  .ok { color: #9ece6a; font-weight: 600; }
  .warn { color: #e0af68; }
  .section { color: #7aa2f7; }
  .step { color: #7dcfff; }
  .changed { color: #e0af68; }
  .dim { color: #7a7f8c; }
  .trunc { color: #7a7f8c; font-style: italic; }
</style>
</head>
<body>
  <div class="card" id="card">
    <div class="titlebar">
      <div class="dots">
        <div class="dot red"></div>
        <div class="dot yellow"></div>
        <div class="dot green"></div>
      </div>
      <div class="title">${escapeHtml(title)}</div>
    </div>
    <div class="body">${promptLine}<div class="output">${lines}</div></div>
  </div>
</body>
</html>`;
}
