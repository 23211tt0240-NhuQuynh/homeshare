Add-Type -AssemblyName System.Drawing

$width = 1100
$height = 580
$bmp = New-Object System.Drawing.Bitmap($width, $height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

# Background: White or light grey
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 248, 250, 252))
$g.FillRectangle($bgBrush, 0, 0, $width, $height)

# Function to draw rounded rectangle
function Draw-RoundedCard($gfx, $x, $y, $w, $h, $radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $radius * 2
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc($x + $w - $diameter, $y, $diameter, $diameter, 270, 90)
    $path.AddArc($x + $w - $diameter, $y + $h - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($x, $y + $h - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    
    $cardBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $gfx.FillPath($cardBrush, $path)
    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 226, 232, 240), 1.5)
    $gfx.DrawPath($borderPen, $path)
}

# Draw 2 Cards
Draw-RoundedCard $g 30 30 500 520 16
Draw-RoundedCard $g 570 30 500 520 16

# Fonts
$fontTitle = New-Object System.Drawing.Font("Segoe UI", 13.5, [System.Drawing.FontStyle]::Bold)
$fontSub = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Regular)
$fontValLarge = New-Object System.Drawing.Font("Segoe UI", 26, [System.Drawing.FontStyle]::Bold)
$fontValSub = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$fontLegendTitle = New-Object System.Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Bold)
$fontLegendDesc = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

# Colors
$brushTitle = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 15, 23, 42))
$brushSub = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 100, 116, 139))
$brushGreen = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 16, 185, 129))
$brushRed = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 239, 68, 68))
$brushBlue = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 37, 99, 235))
$brushOrange = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 245, 158, 11))
$brushGray = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 148, 163, 184))

$sfCenter = New-Object System.Drawing.StringFormat
$sfCenter.Alignment = [System.Drawing.StringAlignment]::Center
$sfCenter.LineAlignment = [System.Drawing.StringAlignment]::Center

# --- CARD 1 (PASS/FAIL) ---
$g.DrawString("TỶ LỆ KẾT QUẢ KIỂM THỬ (PASS / FAIL)", $fontTitle, $brushTitle, 280, 60, $sfCenter)
$g.DrawString("Thực thi tự động 750/750 Test Cases phân hệ Admin (15 Modules)", $fontSub, $brushSub, 280, 85, $sfCenter)

# Donut Chart 1 (Green Ring)
$penGreen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 16, 185, 129), 30)
$g.DrawArc($penGreen, 175, 130, 210, 210, 0, 360)

# Center Text 1
$g.DrawString("100%", $fontValLarge, $brushTitle, 280, 222, $sfCenter)
$g.DrawString("PASSED (750/750)", $fontValSub, $brushGreen, 280, 252, $sfCenter)

# Legend 1
$g.FillRectangle($brushGreen, 70, 385, 16, 16)
$g.DrawString("Đạt (Passed): 750 test cases (100%)", $fontLegendTitle, $brushTitle, 96, 383)
$g.DrawString("Các chức năng hoạt động đúng đặc tả và kỳ vọng", $fontLegendDesc, $brushSub, 96, 404)

$g.FillRectangle($brushRed, 70, 445, 16, 16)
$g.DrawString("Không đạt (Failed): 0 test cases (0%)", $fontLegendTitle, $brushTitle, 96, 443)
$g.DrawString("Lỗi phát sinh trong quá trình kiểm thử tự động & UI", $fontLegendDesc, $brushSub, 96, 464)


# --- CARD 2 (PRIORITY) ---
$g.DrawString("PHÂN BỐ THEO MỨC ĐỘ ƯU TIÊN (PRIORITY)", $fontTitle, $brushTitle, 820, 60, $sfCenter)
$g.DrawString("Tổng số: 750 Test Cases trên 15 màn hình/module Admin", $fontSub, $brushSub, 820, 85, $sfCenter)

# Donut Chart 2 (Blue, Orange, Gray)
# High: 546/750 = 72.8% -> 262.08 deg
# Normal: 191/750 = 25.47% -> 91.68 deg
# Low: 13/750 = 1.73% -> 6.24 deg
$penBlue = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 37, 99, 235), 30)
$penOrange = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 245, 158, 11), 30)
$penGray = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 148, 163, 184), 30)

$startAngle = -90.0
$sweepBlue = 360.0 * (546.0 / 750.0)      # 262.08
$sweepOrange = 360.0 * (191.0 / 750.0)    # 91.68
$sweepGray = 360.0 - $sweepBlue - $sweepOrange # 6.24

$g.DrawArc($penBlue, 715, 130, 210, 210, [float]$startAngle, [float]$sweepBlue)
$g.DrawArc($penOrange, 715, 130, 210, 210, [float]($startAngle + $sweepBlue), [float]$sweepOrange)
$g.DrawArc($penGray, 715, 130, 210, 210, [float]($startAngle + $sweepBlue + $sweepOrange), [float]$sweepGray)

# Center Text 2
$g.DrawString("750", $fontValLarge, $brushTitle, 820, 222, $sfCenter)
$g.DrawString("TEST CASES", $fontValSub, $brushSub, 820, 252, $sfCenter)

# Legend 2
$g.FillRectangle($brushBlue, 610, 385, 16, 16)
$g.DrawString("Mức độ Cao (High): 546 TCs (72.8%)", $fontLegendTitle, $brushTitle, 636, 383)

$g.FillRectangle($brushOrange, 610, 430, 16, 16)
$g.DrawString("Mức độ Bình thường (Normal): 191 TCs (25.5%)", $fontLegendTitle, $brushTitle, 636, 428)

$g.FillRectangle($brushGray, 610, 475, 16, 16)
$g.DrawString("Mức độ Thấp (Low): 13 TCs (1.7%)", $fontLegendTitle, $brushTitle, 636, 473)


# Save to file
$outPath = "C:\Users\admin\Downloads\homeshare-dev-QUYNH\test\test_cases_ltdd\admin_test_chart_750_pass.png"
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "SUCCESS: Saved chart to $outPath"

$bmp.Dispose()
$g.Dispose()
