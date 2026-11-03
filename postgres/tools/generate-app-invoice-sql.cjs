#!/usr/bin/env node
// =====================================================================
// Generates each app's invoice objects (tables, types, view, functions, seed, migration) from the
// templates in common/invoices/templates, so GPP, SJO and ROSPBU keep separate invoice tables
// (gpp.gpp_invoices, sjo.sjo_invoices, rospbu.rospbu_invoices and their child tables) while the
// shared SQL is written once.
//
//   node database/postgres/tools/generate-app-invoice-sql.cjs          (writes <app>/invoices/**)
//   node database/postgres/tools/generate-app-invoice-sql.cjs --check  (fails if out of date)
//
// Template syntax:
//   {{S}}    schema (gpp | sjo | rospbu)          {{T}}    invoices table (gpp_invoices ...)
//   {{APP}}  label (GPP | SJO | ROSPBU)            {{CODE}} app.applications.code (GP | sjo | rospbu)
//   {{#gpp}} ... {{/gpp}}  only for that app      {{^sjo}} ... {{/sjo}}  for every app except it
// File names may use {{S}} / {{T}} too. Edit the templates, never the generated files.
// =====================================================================
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const TEMPLATES = path.join(ROOT, 'common', 'invoices', 'templates');
const APPS = [
  { S: 'gpp', T: 'gpp_invoices', APP: 'GPP', CODE: 'GP' },
  { S: 'sjo', T: 'sjo_invoices', APP: 'SJO', CODE: 'sjo' },
  { S: 'rospbu', T: 'rospbu_invoices', APP: 'ROSPBU', CODE: 'rospbu' },
];
const check = process.argv.includes('--check');

const walk = (dir) =>
  fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]));

const render = (text, app) => {
  let out = text;
  // Sections: {{#name}}..{{/name}} kept for that app, {{^name}}..{{/name}} kept for the others
  const SECTION = /\{\{([#^])(gpp|sjo|rospbu)\}\}([\s\S]*?)\{\{\/\2\}\}/;
  for (let m = out.match(SECTION); m; m = out.match(SECTION)) {
    const keep = m[1] === '#' ? app.S === m[2] : app.S !== m[2];
    out = out.replace(m[0], keep ? m[3] : '');
  }
  out = out.replace(/\{\{(S|T|APP|CODE)\}\}/g, (_, k) => app[k]);
  if (/\{\{/.test(out)) throw new Error(`unresolved placeholder: ${out.match(/\{\{[^}]*\}\}/)[0]}`);
  // Drop lines left empty by sections, keep single blank lines
  return out.replace(/[ \t]+$/gm, '').replace(/\n{3,}/g, '\n\n');
};

let stale = 0;
for (const file of walk(TEMPLATES).filter((f) => f.endsWith('.sql.tpl'))) {
  const rel = path.relative(TEMPLATES, file).split(path.sep).join('/');
  const template = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
  for (const app of APPS) {
    const outRel = rel.replace(/\.tpl$/, '').replace(/\{\{(S|T)\}\}/g, (_, k) => app[k]);
    const target = path.join(ROOT, app.S, 'invoices', outRel);
    const header = `-- GENERATED from common/invoices/templates/${rel} by tools/generate-app-invoice-sql.cjs - do not edit.\n`;
    const content = header + render(template, app);
    const current = fs.existsSync(target) ? fs.readFileSync(target, 'utf8') : null;
    if (current === content) continue;
    stale += 1;
    if (check) {
      console.error(`out of date: ${path.relative(ROOT, target)}`);
      continue;
    }
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, content);
    console.log(`wrote ${path.relative(ROOT, target).split(path.sep).join('/')}`);
  }
}
if (check && stale) process.exit(1);
if (!check) console.log(stale ? `${stale} file(s) written` : 'up to date');
