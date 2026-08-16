$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$AiRoot = (Resolve-Path (Join-Path $Root '..\..')).Path
$LocalRoot = Join-Path $AiRoot '.local\ocr'

if (-not (Test-Path 'C:\Program Files\Tesseract-OCR\tesseract.exe')) {
  winget install --id UB-Mannheim.TesseractOCR --exact --silent `
    --accept-source-agreements --accept-package-agreements
}

New-Item -ItemType Directory -Force -Path $LocalRoot | Out-Null
python -m venv (Join-Path $LocalRoot 'venv-tesseract')
& (Join-Path $LocalRoot 'venv-tesseract\Scripts\python.exe') -m pip install -r `
  (Join-Path $Root 'requirements-server.txt')

python -m venv (Join-Path $LocalRoot 'venv-vietocr')
$HybridPython = Join-Path $LocalRoot 'venv-vietocr\Scripts\python.exe'
& $HybridPython -m pip install -r `
  (Join-Path $AiRoot 'requirements-ocr.txt')

$Best = Join-Path $AiRoot 'models\ocr\tessdata_best'
$Fast = Join-Path $AiRoot 'models\ocr\tessdata_fast'
$Osd = Join-Path $AiRoot 'models\ocr\tessdata_osd'
$Viet = Join-Path $AiRoot 'models\ocr\vietocr'
New-Item -ItemType Directory -Force -Path $Best, $Fast, $Osd, $Viet | Out-Null

Invoke-WebRequest 'https://github.com/tesseract-ocr/tessdata_best/raw/main/vie.traineddata' `
  -OutFile (Join-Path $Best 'vie.traineddata')
Invoke-WebRequest 'https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata' `
  -OutFile (Join-Path $Best 'eng.traineddata')
Invoke-WebRequest 'https://github.com/tesseract-ocr/tessdata_fast/raw/main/vie.traineddata' `
  -OutFile (Join-Path $Fast 'vie.traineddata')
Invoke-WebRequest 'https://github.com/tesseract-ocr/tessdata_fast/raw/main/eng.traineddata' `
  -OutFile (Join-Path $Fast 'eng.traineddata')
Copy-Item 'C:\Program Files\Tesseract-OCR\tessdata\osd.traineddata' `
  (Join-Path $Osd 'osd.traineddata') -Force
Invoke-WebRequest 'https://raw.githubusercontent.com/pbcquoc/vietocr/master/config/base.yml' `
  -OutFile (Join-Path $Viet 'base.yml')
Invoke-WebRequest 'https://raw.githubusercontent.com/pbcquoc/vietocr/master/config/vgg-transformer.yml' `
  -OutFile (Join-Path $Viet 'vgg-transformer.yml')
Invoke-WebRequest 'https://vocr.vn/data/vietocr/vgg_transformer.pth' `
  -OutFile (Join-Path $Viet 'vgg_transformer.pth')

Write-Output 'OCR benchmark dependencies and offline models are ready.'
