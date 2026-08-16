const fs = require('fs');
const path = require('path');

function escapeHtml(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function namespaceSvg(svg, prefix) {
  let output = svg
    .replace(/^\uFEFF/, '')
    .replace(/<\?xml[\s\S]*?\?>\s*/i, '')
    .replace(/<!DOCTYPE[\s\S]*?>\s*/i, '');

  const ids = [...output.matchAll(/\bid="([^"]+)"/g)]
    .map((match) => match[1])
    .sort((a, b) => b.length - a.length);

  for (const id of ids) {
    const escaped = id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    output = output
      .replace(new RegExp(`id="${escaped}"`, 'g'), `id="${prefix}-${id}"`)
      .replace(new RegExp(`#${escaped}(?=[)"'\\s;,}])`, 'g'), `#${prefix}-${id}`);
  }

  // Some source diagrams repeat decorative element IDs. Keep the first ID as
  // the reference target and make later occurrences unique in the combined DOM.
  const seenIds = new Map();
  output = output.replace(/\bid="([^"]+)"/g, (_match, id) => {
    const occurrence = (seenIds.get(id) || 0) + 1;
    seenIds.set(id, occurrence);
    return occurrence === 1 ? `id="${id}"` : `id="${id}-instance-${occurrence}"`;
  });

  output = output.replace(/<svg\b([^>]*)>/i, (_match, attrs) => {
    const cleaned = attrs
      .replace(/\swidth="[^"]*"/i, '')
      .replace(/\sheight="[^"]*"/i, '')
      .replace(/\sstyle="[^"]*"/i, '');
    return `<svg${cleaned} width="100%" style="max-width:100%;height:auto;display:block;margin:0 auto;" data-contained-diagram="${prefix}">`;
  });

  return output.trim();
}

function main() {
  const [inputArg, outputArg] = process.argv.slice(2);
  if (!inputArg || !outputArg) {
    throw new Error('Usage: node build_self_contained_markdown.js <input.md> <output.md>');
  }

  const inputPath = path.resolve(inputArg);
  const outputPath = path.resolve(outputArg);
  const root = path.dirname(inputPath);
  let diagramIndex = 0;
  const source = fs.readFileSync(inputPath, 'utf8');

  const output = source.replace(
    /^!\[([^\]]*)\]\(([^)]+\.svg)\)\s*$/gm,
    (_whole, alt, relativePath) => {
      diagramIndex += 1;
      const absolutePath = path.resolve(root, relativePath.replaceAll('/', path.sep));
      if (!fs.existsSync(absolutePath)) {
        throw new Error(`Missing SVG diagram: ${absolutePath}`);
      }
      const prefix = `safefleet-diagram-${String(diagramIndex).padStart(2, '0')}`;
      const svg = namespaceSvg(fs.readFileSync(absolutePath, 'utf8'), prefix);
      return [
        `<figure data-diagram-index="${diagramIndex}">`,
        svg,
        `<figcaption style="text-align:center;font-style:italic;margin-top:0.5rem;">${escapeHtml(alt)}</figcaption>`,
        '</figure>',
      ].join('\n');
    },
  );

  const intro = [
    '<!-- SAFE-FLEET SELF-CONTAINED MARKDOWN: all diagrams are inline SVG. -->',
    '<!-- Open with a Markdown preview that permits inline HTML/SVG, such as VS Code Markdown Preview. -->',
    '',
  ].join('\n');

  fs.writeFileSync(outputPath, intro + output, 'utf8');
  console.log(`Created self-contained Markdown with ${diagramIndex} inline SVG diagrams: ${outputPath}`);
}

try {
  main();
} catch (error) {
  console.error(error.stack || error.message);
  process.exit(1);
}
