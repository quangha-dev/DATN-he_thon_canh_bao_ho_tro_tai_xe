$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$AiRoot = (Resolve-Path (Join-Path $Root '..\..')).Path
$LocalRoot = Join-Path $AiRoot '.local\ocr'
$Artifacts = Join-Path $AiRoot 'artifacts\ocr-benchmark'
$Fixture = Join-Path $Root 'fixtures\phieutest.jpg'
$env:PYTHONPATH = $AiRoot

& (Join-Path $LocalRoot 'venv-tesseract\Scripts\python.exe') `
  (Join-Path $Root 'mobile_simulation\run_mobile_sim.py') $Fixture

& (Join-Path $LocalRoot 'venv-vietocr\Scripts\python.exe') `
  -m service.ocr.pipeline.run_hybrid $Fixture `
  --output (Join-Path $Artifacts 'server_hybrid.json') `
  --debug-dir (Join-Path $Artifacts 'debug')

& (Join-Path $LocalRoot 'venv-tesseract\Scripts\python.exe') `
  (Join-Path $Root 'compare.py') --results $Artifacts `
  --output (Join-Path $Artifacts 'comparison.json')

& (Join-Path $LocalRoot 'venv-vietocr\Scripts\python.exe') `
  -m pytest (Join-Path $Root 'tests') -q
