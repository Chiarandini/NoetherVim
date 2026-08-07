// Pull user-facing markdown from the repo into the Starlight content
// collection.
//
// The repo's markdown stays canonical -- nothing here is authored by hand,
// and everything written under src/content/docs/{start,guides}/ is
// gitignored. Editing those files is always the wrong move; edit the
// upstream source and re-run.
//
// Run via `npm run sync`, which `prebuild` and `predev` both call.

import { mkdir, readFile, writeFile, copyFile, readdir, rm } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');
const out = resolve(here, '../src/content/docs');

// Whole files lifted as-is.
const FILES = [
  {
    src: 'docs/onboarding/first-session.md',
    dest: 'start/first-session.md',
    title: 'Your first session',
    description: 'Keybinding prefixes, the commands worth running first, and a tour of the defaults.',
    sidebar: 2,
  },
  {
    src: 'docs/onboarding/mathematicians.md',
    dest: 'start/mathematicians.md',
    title: 'For mathematicians',
    description: 'The math bundles, snippets, citations, and how to extend the LaTeX setup.',
    sidebar: 3,
  },
  {
    src: 'docs/user-config-examples.md',
    dest: 'guides/recipes.md',
    title: 'Recipes',
    description: 'Copy-paste specs for plugins deliberately left out of the distribution.',
    sidebar: 4,
  },
];

// Sections sliced out of README.md by heading. A slice runs to the next
// heading of the same level, so it keeps its subsections unless `stopAt`
// names an earlier one to stop before.
//
// Installation stops before "Updating" on purpose. The README is one page
// read top to bottom, where the whole lifecycle under one heading reads
// fine; the site turns each slice into a sidebar step, where install is the
// step before "Your first session" and should end on a working editor.
const SECTIONS = [
  {
    dest: 'start/install.md',
    title: 'Installation',
    description: 'Requirements and the bootstrap command.',
    sidebar: 1,
    headings: ['Requirements', 'Installation'],
    stopAt: { Installation: 'Updating' },
  },
  {
    dest: 'guides/managing.md',
    title: 'Managing your install',
    description: 'Updating, migrating an existing config, and uninstalling.',
    sidebar: 5,
    subsections: ['Updating', 'Migrating from an existing config', 'Uninstalling'],
  },
  {
    dest: 'guides/configuration.md',
    title: 'Configuration',
    description: 'Enabling bundles, adding plugins, and overriding options and keymaps.',
    sidebar: 2,
    headings: ['Configuration'],
  },
  {
    dest: 'guides/keybindings.md',
    title: 'Keybinding philosophy',
    description: 'Prefix conventions and how to discover what the distro binds.',
    sidebar: 3,
    headings: ['Keybinding Philosophy'],
  },
];

// Repo-relative markdown paths and README anchors to their site routes.
//
// Both forms of every onboarding link belong here: the repo-rooted one the
// README uses, and the sibling-relative one the onboarding files use to link
// to each other when read on GitHub. A sibling-relative link that reaches the
// built site resolves against the page's own route and 404s, so checkLinks()
// below fails the build on anything left unrewritten.
const LINKS = [
  [/\]\(docs\/onboarding\/first-session\.md\)/g, '](/noethervim/start/first-session/)'],
  [/\]\(docs\/onboarding\/mathematicians\.md\)/g, '](/noethervim/start/mathematicians/)'],
  [/\]\(\.\.\/\.\.\/README\.md#installation\)/g, '](/noethervim/start/install/)'],
  [/\]\(\.\.\/\.\.\/README\.md#keybinding-philosophy\)/g, '](/noethervim/guides/keybindings/)'],
  [/\]\(\.\.\/\.\.\/README\.md(#[a-z0-9-]*)?\)/g, '](https://github.com/Chiarandini/NoetherVim)'],
  [/\]\(first-session\.md(#[a-z0-9-]*)?\)/g, '](/noethervim/start/first-session/)'],
  [/\]\(mathematicians\.md(#[a-z0-9-]*)?\)/g, '](/noethervim/start/mathematicians/)'],
  [/\]\(docs\/user-config-examples\.md\)/g, '](/noethervim/guides/recipes/)'],
  [/\]\(`?docs\/bundles\.md`?(#[a-z-]*)?\)/g, '](/noethervim/guides/bundles/)'],
  [/\]\(#configuration\)/g, '](/noethervim/guides/configuration/)'],
  [/\]\(#bundles\)/g, '](/noethervim/guides/bundles/)'],
  [/\]\(#keybinding-philosophy\)/g, '](/noethervim/guides/keybindings/)'],
  [/\]\(#enabling-bundles\)/g, '](/noethervim/guides/configuration/#enabling-bundles)'],
  [/\]\(#migrating-from-an-existing-config\)/g, '](/noethervim/guides/managing/#migrating-from-an-existing-config)'],
  [/\]\(docs\/assets\//g, '](/noethervim/assets/'],
  [/\(docs\/assets\//g, '(/noethervim/assets/'],
];

const ASIDES = {
  NOTE: 'note',
  TIP: 'tip',
  IMPORTANT: 'caution',
  WARNING: 'caution',
  CAUTION: 'danger',
};

/** GitHub alert blockquotes -> Starlight asides. */
function convertAsides(md) {
  const lines = md.split('\n');
  const result = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^>\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$/);
    if (!m) {
      result.push(lines[i]);
      continue;
    }
    const body = [];
    i++;
    while (i < lines.length && lines[i].startsWith('>')) {
      body.push(lines[i].replace(/^>\s?/, ''));
      i++;
    }
    i--;
    result.push(`:::${ASIDES[m[1]]}`, ...body, ':::');
  }
  return result.join('\n');
}

function frontmatter({ title, description, sidebar, mdx }) {
  return [
    '---',
    `title: ${JSON.stringify(title)}`,
    `description: ${JSON.stringify(description)}`,
    `sidebar:\n  order: ${sidebar}`,
    'editUrl: false',
    '---',
    '',
    // The comment syntax is not interchangeable. In .md files an HTML comment
    // is a comment and `{/* */}` renders as literal text with a phantom TOC
    // entry; in .mdx an HTML comment is a parse error.
    mdx
      ? '{/* Generated by scripts/sync-docs.mjs. Edit the upstream file, not this. */}'
      : '<!-- Generated by scripts/sync-docs.mjs. Edit the upstream file, not this. -->',
    '',
  ].join('\n');
}

function rewrite(md) {
  let s = md;
  for (const [pattern, replacement] of LINKS) s = s.replace(pattern, replacement);
  return convertAsides(s);
}

/**
 * Fail on any link target that only makes sense inside the repo.
 *
 * The site flattens `docs/onboarding/*.md` into `/noethervim/start/*`, so a
 * relative path that resolves on GitHub resolves to nothing here. Rewriting
 * happens through the LINKS table, and a link nobody added a rule for is
 * silently wrong -- it builds, ships, and 404s only when somebody clicks it.
 * Site-absolute (`/`), anchor-only (`#`) and external (`http`, `mailto:`)
 * targets are left alone.
 */
function checkLinks(md, source) {
  // Code is prose here, not markup: a fenced block or an inline span may show
  // link syntax as an example, and those examples are not links to resolve.
  const prose = md
    .replace(/^```[\s\S]*?^```/gm, '')
    .replace(/`[^`\n]*`/g, '');

  const bad = [];
  for (const m of prose.matchAll(/\[[^\]]*\]\(([^)\s]+)/g)) {
    const target = m[1];
    if (/^(https?:|mailto:|#|\/)/.test(target)) continue;
    bad.push(target);
  }
  if (bad.length) {
    throw new Error(
      `${source}: unrewritten repo-relative link(s): ${[...new Set(bad)].join(', ')}\n` +
        '  Add a rule to LINKS in scripts/sync-docs.mjs.',
    );
  }
}

/** Strip the leading h1 and any content before the first real section. */
function stripTitle(md) {
  return md.replace(/^#\s+.*\n+/, '');
}

/**
 * Render README's "Why another distribution?" as a Starlight card grid.
 *
 * The landing page wants this section as cards and every other page wants
 * markdown, so it is the one slice that cannot be copied verbatim. Generating
 * it keeps the README the only place the pitch is written: the alternative,
 * a hand-maintained second copy in index.mdx, had already drifted on four
 * points before this existed.
 *
 * Each `- **Lead.** body` bullet becomes one card. Prose before and after the
 * list passes through unchanged. Angle brackets in the bullets are all inside
 * backticks, which MDX leaves alone; a future bullet that puts one in prose
 * would be read as JSX, so checkPartial() below rejects that.
 */
function cardGrid(section) {
  const body = section.replace(/^##\s+.*\n/, '');
  const lines = body.split('\n');

  const before = [];
  const after = [];
  const bullets = [];

  // A bullet runs to the next blank line: its continuation lines sit flush at
  // column 0 in this README, so indentation cannot delimit them. After a blank
  // line, another `- **` starts the next card and anything else ends the list.
  let state = 'before';

  for (const line of lines) {
    const isBullet = /^-\s+\*\*/.test(line);
    const blank = line.trim() === '';

    if (state === 'before') {
      if (isBullet) {
        state = 'in-bullet';
        bullets.push([line.replace(/^-\s+/, '')]);
      } else {
        before.push(line);
      }
    } else if (state === 'in-bullet') {
      if (blank) state = 'between';
      else bullets[bullets.length - 1].push(line.trim());
    } else if (state === 'between') {
      if (isBullet) {
        state = 'in-bullet';
        bullets.push([line.replace(/^-\s+/, '')]);
      } else if (!blank) {
        state = 'after';
        after.push(line);
      }
    } else {
      after.push(line);
    }
  }

  const cards = bullets.map((chunk) => {
    const text = chunk.join(' ').replace(/\s+/g, ' ').trim();
    const m = text.match(/^\*\*(.+?)\*\*\s*(.*)$/);
    if (!m) throw new Error(`"Why another distribution?" bullet is not "**Lead.** body": ${text.slice(0, 60)}`);
    const title = m[1].replace(/[.,]$/, '');
    return `  <Card title="${title}">\n    ${m[2]}\n  </Card>`;
  });

  if (!cards.length) throw new Error('"Why another distribution?" has no bullets to render as cards');

  return [
    before.join('\n').trim(),
    '',
    '<CardGrid>',
    cards.join('\n'),
    '</CardGrid>',
    '',
    after.join('\n').trim(),
    '',
  ].join('\n');
}

// ── Vim help -> Starlight ──────────────────────────────────────────────────
//
// `doc/noethervim.txt` is the reference manual, and both the README and the
// first-session guide call it authoritative. Neither could link to it: it only
// existed inside a running Neovim, so six of its thirteen sections had no web
// presence at all, and `:help noethervim-user-config` could not be cited in an
// issue or a search result.
//
// It is published as-is rather than reflowed into web prose. 174 of its rows
// are column-aligned tables that assume a fixed width, so the body of each
// section stays monospace and only the tags and cross-links are made live.
// Section titles become real markdown headings, because Starlight builds its
// page navigation from headings in the .mdx source and would see none inside
// an injected block.

/** Escape for injection into MDX via `set:html`, including MDX's own `{`. */
function escapeHtml(s) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\{/g, '&#123;')
    .replace(/\}/g, '&#125;');
}

/**
 * Turn one help file into MDX: a heading per section, each body a monospace
 * block with `*tags*` as anchors and `|links|` as hrefs.
 *
 * Tags are matched against the set harvested from the whole file rather than
 * by shape, so prose containing `*` or `|` cannot be mistaken for markup.
 */
function vimdocToMdx(txt) {
  const all = txt.split('\n');

  // Tag set first: everything else keys off it.
  const tags = new Set();
  const seen = new Set();
  const dupes = [];
  for (const line of all) {
    for (const m of line.matchAll(/\*([a-zA-Z0-9_.:-]+)\*/g)) {
      if (seen.has(m[1])) dupes.push(m[1]);
      seen.add(m[1]);
      tags.add(m[1]);
    }
  }
  if (dupes.length) {
    throw new Error(`doc/noethervim.txt: duplicate help tags would collide as anchors: ${[...new Set(dupes)].join(', ')}`);
  }

  // Section titles come from the CONTENTS list, which is already title-cased;
  // the section headers themselves are shouted.
  const titles = new Map();
  for (const line of all) {
    const m = line.match(/^\s+(\d+)\.\s+(.+?)\s*\.{3,}\s*\|/);
    if (m) titles.set(m[1], m[2]);
  }

  const unresolved = new Set();
  const RULE = /^={70,}$/;
  const blocks = [];
  let current = [];
  for (const line of all) {
    if (RULE.test(line)) {
      blocks.push(current);
      current = [];
    } else {
      current.push(line);
    }
  }
  blocks.push(current);

  const render = (body) => {
    const out = [];
    for (let line of body) {
      // `>` opens a literal block and a lone `<` closes it. Neovim conceals
      // both; drop them so the page reads the way `:help` does.
      if (/^<\s*$/.test(line)) continue;
      line = line.replace(/(\s|^)>$/, '$1');

      line = escapeHtml(line);
      line = line.replace(/\*([a-zA-Z0-9_.:-]+)\*/g, (m, t) =>
        tags.has(t) ? `<a id="${t}" class="vimdoc-tag">*${t}*</a>` : m);
      // A link to a tag this file does not define points into Neovim's own
      // help (|mapleader|, |heirline-cookbook|); leave those as plain text
      // rather than emitting an anchor that goes nowhere. A `noethervim-`
      // link with no tag is a typo in our own file, not an outward reference,
      // so it is collected and raised rather than quietly flattened.
      line = line.replace(/\|([a-zA-Z0-9_.:-]+)\|/g, (m, t) => {
        if (tags.has(t)) return `<a href="#${t}">|${t}|</a>`;
        if (/^n(oether|eother)vim/.test(t)) unresolved.add(t);
        return m;
      });
      out.push(line);
    }
    return out.join('\n').replace(/\n{3,}/g, '\n\n').trim();
  };

  const parts = [];
  for (const block of blocks) {
    const text = block.join('\n');
    if (!text.trim()) continue;
    if (/^\s*vim:\s*tw=/m.test(text) && block.filter((l) => l.trim()).length <= 1) continue;

    const headerIdx = block.findIndex((l) => l.trim());
    const header = block[headerIdx] ?? '';
    const m = header.match(/^(\d+)\.\s+(.+?)(\s+\*.*)?$/);

    if (m) {
      const title = titles.get(m[1]) ?? m[2];
      parts.push(`## ${m[1]}. ${title}\n`);
      // Tags declared on the header line still need anchors.
      const anchors = [...(m[3] ?? '').matchAll(/\*([a-zA-Z0-9_.:-]+)\*/g)]
        .filter((a) => tags.has(a[1]))
        .map((a) => `<a id="${a[1]}" class="vimdoc-tag">*${a[1]}*</a>`)
        .join(' ');
      const body = render(block.slice(headerIdx + 1));
      parts.push(`<div class="vimdoc-reference" set:html={${JSON.stringify((anchors ? anchors + '\n\n' : '') + body)}} />\n`);
    } else {
      // The preamble and the CONTENTS block have no numbered header.
      parts.push(`<div class="vimdoc-reference" set:html={${JSON.stringify(render(block))}} />\n`);
    }
  }

  if (unresolved.size) {
    throw new Error(
      `doc/noethervim.txt: |links| to a noethervim tag that is not defined anywhere: ${[...unresolved].join(', ')}\n` +
        '  Either the tag is missing or the link is misspelled; :help would show it dead too.',
    );
  }

  // Belt and braces: every emitted href must land on an emitted id.
  const mdx = parts.join('\n');
  const emitted = new Set([...mdx.matchAll(/id="([^"]+)"/g)].map((m) => m[1]));
  const broken = [...mdx.matchAll(/href="#([^"]+)"/g)].map((m) => m[1]).filter((t) => !emitted.has(t));
  if (broken.length) {
    throw new Error(`doc/noethervim.txt: cross-links with no anchor: ${[...new Set(broken)].join(', ')}`);
  }

  return mdx;
}

/**
 * Reject an unescaped `<` outside code, which MDX parses as a JSX tag and
 * fails the build on with a message that points at the generated file rather
 * than at the README line that caused it.
 */
function checkPartial(mdx, source) {
  const prose = mdx.replace(/`[^`\n]*`/g, '').replace(/^\s*<\/?(Card|CardGrid).*$/gm, '');
  const m = prose.match(/<[A-Za-z-]/);
  if (m) {
    throw new Error(
      `${source}: "<" outside backticks would be parsed as JSX: ...${
        prose.slice(Math.max(0, m.index - 40), m.index + 40)
      }...\n  Wrap it in backticks in README.md.`,
    );
  }
}

/** Escape a heading for use inside a RegExp. */
function reEscape(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Slice `## <heading>` up to the next `##` or `---` rule.
 *
 * `stopAt` names a `###` subheading to stop before instead, for splitting one
 * README section across more than one page. It is keyed by heading in
 * SECTIONS so a name that stops matching the README fails here rather than
 * being silently ignored on the sections it was never meant to apply to.
 */
function section(md, heading, stopAt) {
  const start = md.search(new RegExp(`^##\\s+${reEscape(heading)}\\s*$`, 'm'));
  if (start === -1) throw new Error(`README section not found: ${heading}`);
  const rest = md.slice(start);
  let body = rest.slice(rest.indexOf('\n') + 1);
  const end = body.search(/^(##\s+|---\s*$)/m);
  if (end !== -1) body = body.slice(0, end);

  if (stopAt) {
    const cut = body.search(new RegExp(`^###\\s+${reEscape(stopAt)}\\s*$`, 'm'));
    if (cut === -1) throw new Error(`README subsection not found: ${stopAt} (in ${heading})`);
    body = body.slice(0, cut);
  }
  return `## ${heading}\n` + body;
}

/**
 * Slice `### <heading>` up to the next heading of any level or `---` rule,
 * promoting it to `##` so it reads as a top-level section on its own page.
 */
function subsection(md, heading) {
  const start = md.search(new RegExp(`^###\\s+${reEscape(heading)}\\s*$`, 'm'));
  if (start === -1) throw new Error(`README subsection not found: ${heading}`);
  const rest = md.slice(start);
  const body = rest.slice(rest.indexOf('\n') + 1);
  const end = body.search(/^(#{2,3}\s+|---\s*$)/m);
  return `## ${heading}\n` + (end === -1 ? body : body.slice(0, end));
}

async function main() {
  // This script owns every `.md` under start/ and guides/; authored pages use
  // `.mdx` and are left alone. Sweeping by extension rather than by the
  // manifest means dropping an entry from FILES also removes the page it used
  // to generate, instead of leaving a stale one to win over its replacement.
  // Generated by tools/gen-docs.lua from the Lua annotations, committed, and
  // not this script's to manage.
  const FOREIGN = new Set(['guides/bundles.md']);
  const owned = new Set([...FILES, ...SECTIONS].map((f) => f.dest));
  for (const dir of ['start', 'guides']) {
    await mkdir(join(out, dir), { recursive: true });
    for (const name of await readdir(join(out, dir))) {
      if (!name.endsWith('.md')) continue;
      const rel = `${dir}/${name}`;
      if (FOREIGN.has(rel)) continue;
      if (!owned.has(rel)) console.log(`  removing stale ${rel}`);
      await rm(join(out, rel), { force: true });
    }
  }

  for (const f of FILES) {
    const raw = await readFile(join(repo, f.src), 'utf8');
    const body = rewrite(stripTitle(raw));
    checkLinks(body, f.src);
    await writeFile(join(out, f.dest), frontmatter(f) + body + '\n');
    console.log(`  ${f.src} -> ${f.dest}`);
  }

  const readme = await readFile(join(repo, 'README.md'), 'utf8');
  for (const s of SECTIONS) {
    const parts = s.subsections
      ? s.subsections.map((h) => subsection(readme, h))
      : s.headings.map((h) => section(readme, h, s.stopAt && s.stopAt[h]));
    const label = (s.subsections || s.headings).join(', ');
    const body = rewrite(parts.join('\n'));
    checkLinks(body, `README.md [${label}]`);
    await writeFile(join(out, s.dest), frontmatter(s) + body + '\n');
    console.log(`  README.md [${label}] -> ${s.dest}`);
  }

  // The reference manual, published from the same file `:help noethervim`
  // reads, so the two cannot disagree.
  const helpfile = await readFile(join(repo, 'doc/noethervim.txt'), 'utf8');
  await writeFile(
    join(out, 'reference.mdx'),
    frontmatter({
      title: 'Reference',
      description: 'The complete reference manual: configuration, keymap namespaces, commands, bundles, FAQ.',
      sidebar: 1,
      mdx: true,
    }) +
      '\n:::note\nThis is `:help noethervim`, published verbatim. Inside a running\n' +
      'Neovim the in-editor version is faster to search and always matches the\n' +
      'version you have installed.\n:::\n\n' +
      vimdocToMdx(helpfile) +
      '\n',
  );
  console.log('  doc/noethervim.txt -> reference.mdx');

  // The landing page's pitch, generated from the README so there is only one
  // copy of it. index.mdx imports this and supplies the hero around it.
  const why = cardGrid(rewrite(section(readme, 'Why another distribution?')));
  checkPartial(why, 'README.md [Why another distribution?]');
  const partials = resolve(here, '../src/components');
  await mkdir(partials, { recursive: true });
  await writeFile(
    join(partials, 'why-another-distribution.mdx'),
    // The Starlight components are imported here rather than inherited from
    // index.mdx: an imported MDX file compiles in its own scope, so a name
    // only in the importer's scope resolves to undefined at render time.
    '{/* Generated by scripts/sync-docs.mjs from README.md. Edit the README. */}\n\n' +
      "import { Card, CardGrid } from '@astrojs/starlight/components';\n\n" +
      why,
  );
  console.log('  README.md [Why another distribution?] -> src/components/why-another-distribution.mdx');

  // Hero and demo GIFs referenced by the ported markdown.
  const assets = resolve(here, '../public/assets');
  await mkdir(assets, { recursive: true });
  for (const name of await readdir(join(repo, 'docs/assets'))) {
    await copyFile(join(repo, 'docs/assets', name), join(assets, name));
    console.log(`  docs/assets/${name} -> public/assets/${name}`);
  }
}

await main();
