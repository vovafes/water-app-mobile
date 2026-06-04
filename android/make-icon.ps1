# Generate app icon PNGs at 1024x1024 matching the web app's branding:
# rounded square with a sky-400 -> cyan-500 linear gradient and a white
# droplet shape in the centre.
#
# Outputs:
#   assets/icon/icon.png            full icon (with gradient bg)
#   assets/icon/icon_foreground.png white droplet on transparent (for
#                                   Android adaptive icon foreground)
#
# Run:
#   cd C:\dev\water-app-mobile\android
#   .\make-icon.ps1

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$outDir = 'C:\dev\water-app-mobile\assets\icon'
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# Brand colors — match BrandColors in lib/theme.dart
$sky400  = [System.Drawing.Color]::FromArgb(255, 0x38, 0xBD, 0xF8)
$cyan500 = [System.Drawing.Color]::FromArgb(255, 0x06, 0xB6, 0xD4)

$size = 1024
$radius = 200  # corner radius for rounded square (icon size 1024 * 0.2)

function New-RoundedPath([int]$x, [int]$y, [int]$w, [int]$h, [int]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x, $y, $r * 2, $r * 2, 180, 90)
    $path.AddArc($x + $w - $r * 2, $y, $r * 2, $r * 2, 270, 90)
    $path.AddArc($x + $w - $r * 2, $y + $h - $r * 2, $r * 2, $r * 2, 0, 90)
    $path.AddArc($x, $y + $h - $r * 2, $r * 2, $r * 2, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-DropletPath([float]$cx, [float]$cy, [float]$h) {
    # Classic teardrop: rounded bell with a pointed apex. Built from two
    # cubic Beziers on a square bounding box centered at (cx, cy) with
    # vertical extent h.
    $w = $h * 0.78
    $top    = New-Object System.Drawing.PointF($cx, ($cy - $h / 2))
    $bottom = New-Object System.Drawing.PointF($cx, ($cy + $h / 2))
    $left   = New-Object System.Drawing.PointF(($cx - $w / 2), ($cy + $h / 6))
    $right  = New-Object System.Drawing.PointF(($cx + $w / 2), ($cy + $h / 6))

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath

    # Top -> right: gentle outward curve
    $c1 = New-Object System.Drawing.PointF(($cx + $w / 4), ($cy - $h / 4))
    $c2 = New-Object System.Drawing.PointF($right.X, ($cy - $h / 16))
    $path.AddBezier($top, $c1, $c2, $right)

    # Right -> bottom: round the bulb
    $c3 = New-Object System.Drawing.PointF($right.X, ($cy + $h / 2 - $w / 4))
    $c4 = New-Object System.Drawing.PointF(($cx + $w / 4), $bottom.Y)
    $path.AddBezier($right, $c3, $c4, $bottom)

    # Bottom -> left
    $c5 = New-Object System.Drawing.PointF(($cx - $w / 4), $bottom.Y)
    $c6 = New-Object System.Drawing.PointF($left.X, ($cy + $h / 2 - $w / 4))
    $path.AddBezier($bottom, $c5, $c6, $left)

    # Left -> top: close back to the apex
    $c7 = New-Object System.Drawing.PointF($left.X, ($cy - $h / 16))
    $c8 = New-Object System.Drawing.PointF(($cx - $w / 4), ($cy - $h / 4))
    $path.AddBezier($left, $c7, $c8, $top)

    $path.CloseFigure()
    return $path
}

function Save-Png($bitmap, $path) {
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Wrote $path" -ForegroundColor Green
}

# --- icon.png: gradient rounded square + white droplet ---
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

$rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
$gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect, $sky400, $cyan500,
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal)

$rounded = New-RoundedPath 0 0 $size $size $radius
$g.FillPath($gradient, $rounded)

# White droplet, centred slightly toward the top so it looks balanced
$dropletPath = New-DropletPath 512 540 600
$whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$g.FillPath($whiteBrush, $dropletPath)

Save-Png $bmp (Join-Path $outDir 'icon.png')
$g.Dispose(); $bmp.Dispose()

# --- icon_foreground.png: white droplet on transparent ---
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
# Centre the droplet smaller — adaptive icon foreground gets cropped
# to ~66% of the canvas, so we draw at that scale.
$dropletPath = New-DropletPath 512 540 460
$g.FillPath($whiteBrush, $dropletPath)
Save-Png $bmp (Join-Path $outDir 'icon_foreground.png')
$g.Dispose(); $bmp.Dispose()

Write-Host ''
Write-Host 'Done. Next:' -ForegroundColor Cyan
Write-Host '  flutter pub get' -ForegroundColor Cyan
Write-Host '  dart run flutter_launcher_icons' -ForegroundColor Cyan
