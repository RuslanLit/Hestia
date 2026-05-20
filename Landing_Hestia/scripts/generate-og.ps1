param(
  [Parameter(Mandatory = $true)]
  [string]$DataPath,

  [Parameter(Mandatory = $true)]
  [string]$Root
)

Add-Type -AssemblyName System.Drawing

$canvasWidth = 1200
$canvasHeight = 630
$data = Get-Content -LiteralPath $DataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$logoPath = Join-Path $Root "logo\logo.png"

function New-Brush($hex) {
  return New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($hex))
}

function New-Pen($hex, $width) {
  return New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($hex), $width)
}

function Draw-StringBlock($graphics, $text, $font, $brush, $x, $y, $width, $height, $lineAlignment = "Near") {
  $rect = New-Object System.Drawing.RectangleF($x, $y, $width, $height)
  $format = New-Object System.Drawing.StringFormat
  $format.Alignment = [System.Drawing.StringAlignment]::Near
  $format.LineAlignment = [System.Drawing.StringAlignment]::$lineAlignment
  $format.Trimming = [System.Drawing.StringTrimming]::EllipsisWord
  $format.FormatFlags = 0
  $graphics.DrawString($text, $font, $brush, $rect, $format)
  $format.Dispose()
}

foreach ($item in @($data.items)) {
  $output = [string]$item.output
  $directory = Split-Path -Parent $output
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $bitmap = New-Object System.Drawing.Bitmap($canvasWidth, $canvasHeight)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
  $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml("#FAF7F2"))

  $cream = New-Brush "#FAF7F2"
  $ink = New-Brush "#1F2933"
  $muted = New-Brush "#5F6B7A"
  $soft = New-Brush "#F4ECE3"
  $green = New-Brush "#3B82C4"
  $line = New-Pen "#E4D8CC" 2

  $graphics.FillRectangle((New-Brush "#FAF7F2"), 0, 0, $canvasWidth, $canvasHeight)
  $graphics.FillEllipse((New-Brush "#D8ECFF"), 780, -220, 560, 560)
  $graphics.FillEllipse((New-Brush "#FCE8C9"), -180, 410, 520, 320)
  $graphics.DrawLine($line, 88, 110, 1112, 110)

  if (Test-Path -LiteralPath $logoPath) {
    $logo = [System.Drawing.Image]::FromFile($logoPath)
    $graphics.DrawImage($logo, 88, 54, 64, 64)
    $logo.Dispose()
  }

  $brandFont = New-Object System.Drawing.Font("Segoe UI Semibold", 32, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $titleFont = New-Object System.Drawing.Font("Segoe UI Semibold", 76, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $descFont = New-Object System.Drawing.Font("Segoe UI", 34, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $pillFont = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $smallFont = New-Object System.Drawing.Font("Segoe UI", 21, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

  $graphics.DrawString("Hestia", $brandFont, $ink, 170, 67)

  $pillRect = New-Object System.Drawing.RectangleF(88, 162, 300, 52)
  $graphics.FillRectangle($soft, $pillRect)
  $graphics.DrawString(([string]$item.languageName), $pillFont, $green, 108, 174)

  Draw-StringBlock $graphics ([string]$item.title) $titleFont $ink 88 245 940 180
  Draw-StringBlock $graphics ([string]$item.description) $descFont $muted 92 435 920 110
  $graphics.DrawString("private messenger for close circles", $smallFont, $muted, 88, 570)

  $graphics.Dispose()
  $bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()

  $cream.Dispose()
  $ink.Dispose()
  $muted.Dispose()
  $soft.Dispose()
  $green.Dispose()
  $line.Dispose()
  $brandFont.Dispose()
  $titleFont.Dispose()
  $descFont.Dispose()
  $pillFont.Dispose()
  $smallFont.Dispose()
}
