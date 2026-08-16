const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

async function main() {
  const [reportArg, outputArg] = process.argv.slice(2);
  if (!reportArg || !outputArg) {
    throw new Error('Usage: node convert_report_svg_to_png.js <report.md> <output-dir>');
  }

  const reportPath = path.resolve(reportArg);
  const root = path.dirname(reportPath);
  const outputDir = path.resolve(outputArg);
  fs.mkdirSync(outputDir, { recursive: true });

  const markdown = fs.readFileSync(reportPath, 'utf8');
  const refs = [...markdown.matchAll(/!\[[^\]]*\]\(([^)]+\.svg)\)/g)]
    .map((match) => match[1]);
  const uniqueRefs = [...new Set(refs)];
  const manifest = {};

  for (const ref of uniqueRefs) {
    const input = path.resolve(root, ref.replaceAll('/', path.sep));
    if (!fs.existsSync(input)) {
      throw new Error(`Missing diagram: ${input}`);
    }

    const safeName = `${path.basename(ref, '.svg')}.png`;
    const output = path.join(outputDir, safeName);
    await sharp(input, { density: 240, limitInputPixels: false })
      .flatten({ background: '#ffffff' })
      .resize({ width: 2400, withoutEnlargement: false })
      .png({ compressionLevel: 9, adaptiveFiltering: true })
      .toFile(output);
    manifest[ref] = output;
  }

  fs.writeFileSync(
    path.join(outputDir, 'manifest.json'),
    JSON.stringify(manifest, null, 2),
    'utf8',
  );
  console.log(`Converted ${uniqueRefs.length} SVG diagrams to embedded PNG assets.`);
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});
