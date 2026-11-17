// 把 design-tokens.json 转成原型用的 CSS 变量（design/prototype/tokens.css）。
// 令牌只在 JSON 里改，改完重跑：node design/tokens-to-css.mjs
// 浅色写在 :root，深色写在 [data-theme="dark"] 和跟随系统的 prefers-color-scheme 里
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const tokens = JSON.parse(readFileSync(join(here, 'design-tokens.json'), 'utf8'));

const light = [];
const dark = [];
const plain = [];

const kebab = (s) => s.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase();
const isMeta = (k) => k === 'about' || k === 'note' || k === 'rules' || k === 'use';

// { ref: "palette.green" } 指到调色板上的那个颜色
function refVar(ref) {
  return `var(--${ref.split('.').map(kebab).join('-')})`;
}

function color(name, v) {
  if (v.ref) {
    light.push(`  --${name}: ${refVar(v.ref)};`);
    return;
  }
  if (v.light) light.push(`  --${name}: ${v.light};`);
  if (v.dark) dark.push(`  --${name}: ${v.dark};`);
}

function font(name, v, family) {
  if (typeof v === 'string') {
    plain.push(`  --${name}: ${v};`);
    return;
  }
  plain.push(`  --${name}: ${v.weight} ${v.size}px/${v.lineHeight}px ${family};`);
  plain.push(`  --${name}-size: ${v.size}px;`);
}

// 数值一律当作点，原型里 1 点 = 1 CSS 像素
function numbers(prefix, obj) {
  for (const [k, v] of Object.entries(obj)) {
    if (isMeta(k)) continue;
    const name = `${prefix}-${kebab(k)}`;
    if (typeof v === 'number') plain.push(`  --${name}: ${v}px;`);
    else if (typeof v === 'object' && v !== null) numbers(name, v);
  }
}

for (const [k, v] of Object.entries(tokens.palette)) {
  if (!isMeta(k)) color(`palette-${kebab(k)}`, v);
}

for (const group of ['mac', 'touch']) {
  const g = tokens[group];
  for (const [k, v] of Object.entries(g.color)) if (!isMeta(k)) color(`${group}-${kebab(k)}`, v);
  const family = `var(--${group}-font-family)`;
  for (const [k, v] of Object.entries(g.font)) if (!isMeta(k)) font(`${group}-font-${kebab(k)}`, v, family);
  numbers(`${group}-space`, g.space);
  numbers(`${group}-radius`, g.radius);
  numbers(`${group}-size`, g.size);
  if (g.layout) numbers(`${group}-layout`, g.layout);
  if (g.iconTile) {
    for (const [k, v] of Object.entries(g.iconTile)) if (!isMeta(k)) light.push(`  --${group}-tile-${kebab(k)}: ${refVar(v.ref)};`);
  }
  if (g.status) {
    for (const [k, v] of Object.entries(g.status)) if (!isMeta(k)) light.push(`  --${group}-status-${kebab(k)}: ${refVar(v.ref)};`);
  }
}

for (const [k, v] of Object.entries(tokens.motion)) {
  if (isMeta(k)) continue;
  if (typeof v === 'number') plain.push(`  --motion-${kebab(k)}: ${v};`);
  else {
    plain.push(`  --motion-${kebab(k)}: ${v.duration}ms ${v.easing};`);
    plain.push(`  --motion-${kebab(k)}-duration: ${v.duration}ms;`);
  }
}

const css = `/* 由 design/tokens-to-css.mjs 从 design-tokens.json 生成，不要手改 */
:root {
${plain.join('\n')}
${light.join('\n')}
  color-scheme: light;
}

:root[data-theme="dark"] {
${dark.join('\n')}
  color-scheme: dark;
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
${dark.map((l) => '  ' + l).join('\n')}
    color-scheme: dark;
  }
}
`;

writeFileSync(join(here, 'prototype', 'tokens.css'), css);
console.log(`tokens.css：${plain.length + light.length} 个变量，深色覆盖 ${dark.length} 个`);
