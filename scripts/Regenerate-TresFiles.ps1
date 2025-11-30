# Regenerate all .tres AtlasTexture files with correct coordinates
# Now that we have the full-size 8192x8192 atlas

$outputDir = "resources\map_chunks"
$chunkSize = 512
$gridSize = 16

Write-Host "Regenerating AtlasTexture .tres files..." -ForegroundColor Cyan
Write-Host "Using column_row naming convention" -ForegroundColor Cyan
Write-Host ""

$count = 0

for ($row = 0; $row -lt $gridSize; $row++) {
    for ($col = 0; $col -lt $gridSize; $col++) {
        # Calculate atlas region
        # Column determines X, Row determines Y
        $x = $col * $chunkSize
        $y = $row * $chunkSize
        
        # Create .tres file content
        $tresContent = @"
[gd_resource type="AtlasTexture" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/themap.png" id="1_atlas"]

[resource]
atlas = ExtResource("1_atlas")
region = Rect2($x, $y, $chunkSize, $chunkSize)
"@
        
        # Save .tres file with UTF8 no BOM (Godot requirement)
        $filename = "chunk_${col}_${row}.tres"
        $filepath = Join-Path $outputDir $filename
        
        # Use .NET to write UTF8 without BOM (critical for Godot)
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($filepath, $tresContent, $utf8NoBom)
        
        $count++
    }
}

Write-Host ""
Write-Host "Successfully regenerated $count .tres files!" -ForegroundColor Green
Write-Host "Location: $outputDir" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. In Godot, run: Project -> Reload Current Project"
Write-Host "2. The atlas should now work correctly with the .tres files!"
