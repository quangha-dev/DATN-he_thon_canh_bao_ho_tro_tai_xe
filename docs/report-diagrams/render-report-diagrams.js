const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const root = path.resolve(__dirname, '..', '..');
const reportPath = path.join(root, 'BAO_CAO_DO_AN_SAFEFLEET_CHUONG_1_DEN_3.md');
const sourceDir = path.join(__dirname, 'sources');

fs.mkdirSync(sourceDir, { recursive: true });

const report = fs.readFileSync(reportPath, 'utf8');
const pattern = /```mermaid\r?\n([\s\S]*?)\r?\n```/g;
const matches = [...report.matchAll(pattern)];

if (matches.length === 0) {
  console.log('No Mermaid blocks found. The report already references rendered images.');
  process.exit(0);
}

const rendered = [];

for (let index = 0; index < matches.length; index += 1) {
  const match = matches[index];
  const number = String(index + 1).padStart(2, '0');
  const baseName = `REPORT-DIAGRAM-${number}`;
  const sourcePath = path.join(sourceDir, `${baseName}.mmd`);
  const outputPath = path.join(__dirname, `${baseName}.svg`);
  const heading = report
    .slice(0, match.index)
    .split(/\r?\n/)
    .reverse()
    .find((line) => /^#{1,6}\s+/.test(line));
  const alt = (heading || baseName)
    .replace(/^#{1,6}\s+/, '')
    .replace(/[\[\]]/g, '');

  fs.writeFileSync(sourcePath, `${match[1].trim()}\n`, 'utf8');

  const mermaidArgs = [
      '--yes',
      '@mermaid-js/mermaid-cli',
      '--quiet',
      '--input',
      sourcePath,
      '--output',
      outputPath,
      '--backgroundColor',
      'transparent',
      '--puppeteerConfigFile',
      path.join(__dirname, 'puppeteer-config.json'),
      '--width',
      '2000',
      '--scale',
      '1.5',
    ];
  const result = process.platform === 'win32'
    ? spawnSync(
        process.env.ComSpec || 'cmd.exe',
        ['/d', '/s', '/c', `npx ${mermaidArgs.join(' ')}`],
        { cwd: root, encoding: 'utf8' },
      )
    : spawnSync('npx', mermaidArgs, { cwd: root, encoding: 'utf8' });

  if (result.status !== 0) {
    process.stderr.write(result.error ? `${result.error.message}\n` : '');
    process.stderr.write(result.stdout || '');
    process.stderr.write(result.stderr || '');
    throw new Error(`Unable to render ${baseName}`);
  }

  rendered.push({
    source: match[0],
    replacement: `![${alt}](docs/report-diagrams/${baseName}.svg)`,
  });
}

let updated = report;
for (const item of rendered) {
  updated = updated.replace(item.source, item.replacement);
}

fs.writeFileSync(reportPath, updated, 'utf8');
console.log(`Rendered and linked ${rendered.length} Mermaid diagrams.`);
