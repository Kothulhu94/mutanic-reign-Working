# Rebuild the map atlas from individual chunk PNGs at full 8192x8192 size
# Chunks are named chunk_COLUMN_ROW.png

Add-Type -AssemblyName System.Drawing

$chunkSize = 512
$gridSize = 16
$atlasSize = $chunkSize * $gridSize  # 8192x8192

Write-Host "Rebuilding atlas from individual chunks..." -ForegroundColor Cyan
Write-Host "Atlas size: ${atlas Size}x${atlasSize}" -ForegroundColor Cyan
Write-Host ""

# Create a new atlas image
$atlas = New-Object System.Drawing.Bitmap($atlasSize, $atlasSize)
$graphics = [System.Drawing.Graphics]::FromImage($atlas)

# Set high quality settings
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$chunksProcessed = 0
$missingChunks = @()

# Process all chunks in column_row order
for ($row = 0; $row -lt $gridSize; $row++) {
    for ($col = 0; $col -lt $gridSize; $col++) {
        $chunkFile = "chunks/chunk_${col}_${row}.png"
        
        if (Test-Path $chunkFile) {
            # Load chunk image
            $chunkImg = [System.Drawing.Image]::FromFile("$PWD\$chunkFile")
            
            # Calculate position in atlas
            # Column determines X position, Row determines Y position
            $x = $col * $chunkSize
            $y = $row * $chunkSize
            
            # Draw chunk onto atlas
            $destRect = New-Object System.Drawing.Rectangle($x, $y, $chunkSize, $chunkSize)
            $graphics.DrawImage($chunkImg, $destRect)
            
            $chunkImg.Dispose()
            $chunksProcessed++
            
            if ($chunksProcessed % 32 -eq 0) {
                Write-Host "  Processed $chunksProcessed / 256 chunks..." -ForegroundColor Gray
            }
        }
        else {
            $missingChunks += $chunkFile
            Write-Host "  WARNING: Missing $chunkFile" -ForegroundColor Yellow
        }
    }
}

$graphics.Dispose()

# Save the new atlas
$outputPath = "assets/themap_NEW.png"
$atlas.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$atlas.Dispose()

Write-Host ""
Write-Host "Atlas rebuilt successfully!" -ForegroundColor Green
Write-Host "Processed: $chunksProcessed chunks" -ForegroundColor Green
Write-Host "Output: $outputPath" -ForegroundColor Green

if ($missingChunks.Count -gt 0) {
    Write-Host ""
    Write-Host "WARNING: $($missingChunks.Count) chunks were missing:" -ForegroundColor Yellow
    $missingChunks | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Backup the old atlas: Rename assets/themap.png to assets/themap_OLD.png"
Write-Host "2. Use the new atlas: Rename assets/themap_NEW.png to assets/themap.png"
Write-Host "3. In Godot: Project -> Reload Current Project"
Write-Host "4. The .tres files should now work correctly!"
