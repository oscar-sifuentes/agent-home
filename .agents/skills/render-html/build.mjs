#!/usr/bin/env node
// Wraps a body fragment written by the render-html skill in the shared shell
// (styles, light/dark theme), and stamps which markdown sources it came from.
// Sources under a `tickets/` folder are also rendered in full, verbatim, into
// a second "Tickets" tab (pure CSS, no script), so the reader can read every
// ticket without opening the markdown.
//
//   node build.mjs <body.html> <out.html> "<title>" <source.md>...
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { basename, dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const [bodyPath, outPath, title, ...sources] = process.argv.slice(2);
if (!bodyPath || !outPath || !title) {
  console.error(
    'usage: build.mjs <body.html> <out.html> "<title>" <source.md>...',
  );
  process.exit(2);
}

const here = dirname(fileURLToPath(import.meta.url));
const shell = readFileSync(join(here, 'shell.html'), 'utf8');
let body = readFileSync(bodyPath, 'utf8');

const escapeHtml = (text) =>
  text.replace(
    /[&<>"]/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c],
  );

// --- minimal markdown (what specs and tickets use) -------------------------
const outDir = dirname(resolve(outPath));

const fixHref = (href, srcDir) => {
  if (/^([a-z]+:|#|\/)/i.test(href)) return href;
  return relative(outDir, resolve(srcDir, href));
};

const inline = (text, srcDir) => {
  const codes = [];
  let s = text.replace(/`([^`]+)`/g, (_, c) => {
    codes.push(`<code>${escapeHtml(c)}</code>`);
    return `\u0000${codes.length - 1}\u0000`;
  });
  s = escapeHtml(s)
    .replace(
      /\[([^\]]+)\]\(([^)\s]+)\)/g,
      (_, label, href) => `<a href="${fixHref(href, srcDir)}">${label}</a>`,
    )
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/(^|[^*\w])\*([^*\s][^*]*)\*/g, '$1<em>$2</em>')
    .replace(/(^|\W)_([^_\s][^_]*)_(?=\W|$)/g, '$1<em>$2</em>');
  return s.replace(/\u0000(\d+)\u0000/g, (_, i) => codes[i]);
};

const markdown = (md, srcDir) => {
  const lines = md.replace(/\r/g, '').split('\n');
  const out = [];
  let i = 0;
  const isList = (l) => /^\s*([-*+]|\d+\.)\s+/.test(l);
  const isBlockStart = (l) =>
    /^(#{1,6}\s|```|\s*\|.*\|\s*$|>\s?)/.test(l) || isList(l);
  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) {
      i++;
      continue;
    }
    if (line.startsWith('```')) {
      const code = [];
      for (i++; i < lines.length && !lines[i].startsWith('```'); i++)
        code.push(lines[i]);
      i++;
      out.push(`<pre><code>${escapeHtml(code.join('\n'))}</code></pre>`);
      continue;
    }
    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) {
      const level = Math.min(h[1].length + 1, 6);
      out.push(`<h${level}>${inline(h[2], srcDir)}</h${level}>`);
      i++;
      continue;
    }
    if (/^\s*\|.*\|\s*$/.test(line)) {
      const rows = [];
      while (i < lines.length && /^\s*\|.*\|\s*$/.test(lines[i]))
        rows.push(lines[i++]);
      const cells = (r) =>
        r.trim().replace(/^\||\|$/g, '').split('|').map((c) => c.trim());
      const [head, , ...rest] = rows;
      const th = cells(head).map((c) => `<th>${inline(c, srcDir)}</th>`);
      const trs = rest.map(
        (r) =>
          `<tr>${cells(r).map((c) => `<td>${inline(c, srcDir)}</td>`).join('')}</tr>`,
      );
      out.push(
        `<div class="tbl-wrap"><table class="tbl"><thead><tr>${th.join('')}</tr></thead><tbody>${trs.join('')}</tbody></table></div>`,
      );
      continue;
    }
    if (/^>\s?/.test(line)) {
      const quote = [];
      while (i < lines.length && /^>\s?/.test(lines[i]))
        quote.push(lines[i++].replace(/^>\s?/, ''));
      out.push(`<blockquote>${markdown(quote.join('\n'), srcDir)}</blockquote>`);
      continue;
    }
    if (isList(line)) {
      const ordered = /^\s*\d+\./.test(line);
      const items = [];
      while (i < lines.length && (isList(lines[i]) || /^\s{2,}\S/.test(lines[i]))) {
        if (isList(lines[i]) && !/^\s{2,}/.test(lines[i]))
          items.push(lines[i].replace(/^\s*([-*+]|\d+\.)\s+/, ''));
        else items[items.length - 1] += '\n' + lines[i].trim();
        i++;
      }
      const lis = items.map((item) => {
        const task = item.match(/^\[( |x|X)\]\s+([\s\S]*)$/);
        const text = inline(task ? task[2] : item, srcDir).replace(/\n/g, '<br>');
        if (!task) return `<li>${text}</li>`;
        const done = task[1] !== ' ';
        return `<li class="task${done ? ' done' : ''}"><span class="box">${done ? '✓' : ''}</span><span>${text}</span></li>`;
      });
      const tag = ordered ? 'ol' : 'ul';
      out.push(`<${tag}>${lis.join('')}</${tag}>`);
      continue;
    }
    const para = [];
    while (i < lines.length && lines[i].trim() && !isBlockStart(lines[i]))
      para.push(lines[i++]);
    out.push(`<p>${inline(para.join(' '), srcDir)}</p>`);
  }
  return out.join('\n');
};

// --- tickets tab -----------------------------------------------------------
const zoneOf = (text) =>
  /🔴|\bred\b/i.test(text) ? 'red' : /🟡|\byellow\b/i.test(text) ? 'yellow' : /🟢|\bgreen\b/i.test(text) ? 'green' : '';
const zoneLabel = { red: 'Red', yellow: 'Yellow', green: 'Green' };

const ticketSources = sources
  .filter((src) => /(^|\/)tickets\/[^/]+\.md$/.test(src))
  .sort();

const tickets = ticketSources.map((src) => {
  const md = readFileSync(src, 'utf8').replace(/^---\n[\s\S]*?\n---\n/, '');
  const srcDir = dirname(resolve(src));
  const no = basename(src).match(/^(\w+?)-/)?.[1] ?? basename(src, '.md');
  const lines = md.split('\n');
  const titleLine = lines.find((l) => /^#\s/.test(l)) ?? `# ${no}`;
  const heading = titleLine.replace(/^#\s+/, '').replace(new RegExp(`^${no}\\s*[:.\\-–]\\s*`), '');
  const afterTitle = lines.slice(lines.indexOf(titleLine) + 1);
  // leading "- **Key:** value" lines become the ticket's meta row
  const meta = [];
  let k = 0;
  while (k < afterTitle.length && (!afterTitle[k].trim() || /^-\s+\*\*[^*]+:\*\*/.test(afterTitle[k]))) {
    const m = afterTitle[k].match(/^-\s+\*\*([^*]+):\*\*\s*(.*)$/);
    if (m) meta.push([m[1], m[2]]);
    k++;
  }
  const field = (name) => meta.find(([key]) => key.toLowerCase() === name)?.[1] ?? '';
  const zone = zoneOf(field('zone'));
  return { src, srcDir, no, heading, meta, zone, field, rest: afterTitle.slice(k).join('\n') };
});

if (tickets.length) {
  const index = tickets
    .map(
      (t) =>
        `<li><a href="#t-${t.no}" class="${t.zone}"><span class="no">${escapeHtml(t.no)}</span>${inline(t.heading, t.srcDir)}</a></li>`,
    )
    .join('');
  const docs = tickets
    .map((t) => {
      const chips = t.meta
        .map(([key, value]) =>
          key.toLowerCase() === 'zone' && t.zone
            ? `<span class="zone ${t.zone}">${zoneLabel[t.zone]}</span>`
            : `<span class="chip"><b>${escapeHtml(key)}:</b> ${inline(value.replace(/🔴|🟡|🟢/g, '').trim(), t.srcDir)}</span>`,
        )
        .join(' ');
      return `<article id="t-${t.no}" class="ticket-doc ${t.zone}">
<div class="eyebrow">Ticket ${escapeHtml(t.no)} · <code>${escapeHtml(relative(process.cwd(), t.src))}</code></div>
<h2>${inline(t.heading, t.srcDir)}</h2>
<div class="tk-meta">${chips}</div>
<div class="md">${markdown(t.rest, t.srcDir)}</div>
<a class="tk-top" href="#tickets-view">↑ All tickets</a>
</article>`;
    })
    .join('\n');
  // ticket numbers on the spec's waves link to the full ticket
  body = body.replace(
    /<div class="no">(\w+)<\/div>/g,
    (whole, no) =>
      tickets.some((t) => t.no === no)
        ? `<a class="no" href="#t-${no}">${no} · read ↗</a>`
        : whole,
  );
  body = `<nav class="viewtabs"><div class="page"><a class="tab-spec" href="#spec-view">Spec</a><a class="tab-tickets" href="#tickets-view">Tickets (${tickets.length})</a></div></nav>
<div id="spec-view" class="view view-spec">
${body}
</div>
<div id="tickets-view" class="view view-tickets">
<div class="page tk-layout">
<aside class="tk-index"><div class="eyebrow">Tickets</div><ol>${index}</ol></aside>
<div class="tk-docs">${docs}</div>
</div>
</div>`;
}

const stamps = sources.map((src) => {
  const hash = createHash('sha256')
    .update(readFileSync(src))
    .digest('hex')
    .slice(0, 8);
  return `<code>${escapeHtml(relative(process.cwd(), src))}</code> (${hash})`;
});
const generated = new Date().toISOString().slice(0, 16).replace('T', ' ');
const footer =
  `Generated ${generated} UTC from ${stamps.join(', ') || 'markdown'}. ` +
  'The markdown is the source of truth: if they differ, trust the markdown and regenerate this page.';

const html = shell
  .replace('{{TITLE}}', () => escapeHtml(title))
  .replace('{{BODY}}', () => body)
  .replace('{{FOOTER}}', () => footer);

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, html);
console.log(outPath);
