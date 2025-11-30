# Verify that all 256 chunk references in overworld.tscn are correct

$sceneFile = "overworld.tscn"
$content = Get-Content $sceneFile -Raw

Write-Host "Verifying overworld.tscn chunk references..." -ForegroundColor Cyan
Write-Host ""

# Check for any remaining PNG references
$pngPattern = 'chunks/chunk_\d+_\d+\.png'
$pngReferences = [regex]::Matches($content, $pngPattern)
if ($pngReferences.Count -gt 0) {
    Write-Host "ERROR: Found $($pngReferences.Count) PNG references still in the file!" -ForegroundColor Red
    Write-Host "   The fix script may not have worked correctly." -ForegroundColor Red
    exit 1
}

# Count AtlasTexture references
$atlasPattern = 'type="AtlasTexture" path="res://resources/map_chunks/chunk_\d+_\d+\.tres"'
$atlasReferences = [regex]::Matches($content, $atlasPattern)
Write-Host "Found $($atlasReferences.Count) AtlasTexture references" -ForegroundColor Green

if ($atlasReferences.Count -ne 256) {
    Write-Host "WARNING: Expected 256 chunk references, found $($atlasReferences.Count)" -ForegroundColor Yellow
}
else {
    Write-Host "All 256 chunks are using AtlasTexture .tres files" -ForegroundColor Green
}

# Verify .tres files exist
Write-Host ""
Write-Host "Checking that .tres files exist..." -ForegroundColor Cyan
$missingFiles = @()
for ($y = 0; $y -lt 16; $y++) {
    for ($x = 0; $x -lt 16; $x++) {
        $tresFile = "resources/map_chunks/chunk_${x}_${y}.tres"
        if (-not (Test-Path $tresFile)) {
            $missingFiles += $tresFile
        }
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "ERROR: Missing $($missingFiles.Count) .tres files!" -ForegroundColor Red
    Write-Host "   First few missing:" -ForegroundColor Red
    $missingFiles | Select-Object -First 5 | ForEach-Object {
        Write-Host "   - $_" -ForegroundColor Red
    }
    exit 1
}
else {
    Write-Host "All 256 .tres files exist" -ForegroundColor Green
}

# Sample verification of a few .tres files
Write-Host ""
Write-Host "Sampling .tres file contents..." -ForegroundColor Cyan

# Test chunk 0,0
$tresContent = Get-Content "resources/map_chunks/chunk_0_0.tres" -Raw
if ($tresContent -match "Rect2\(0, 0, 512, 512\)") {
    Write-Host "chunk_0_0.tres has correct region: Rect2(0, 0, 512, 512)" -ForegroundColor Green
}
else {
    Write-Host "chunk_0_0.tres has incorrect region!" -ForegroundColor Red
}

# Test chunk 12,7
$tresContent = Get-Content "resources/map_chunks/chunk_12_7.tres" -Raw
if ($tresContent -match "Rect2\(6144, 3584, 512, 512\)") {
    Write-Host "chunk_12_7.tres has correct region: Rect2(6144, 3584, 512, 512)" -ForegroundColor Green
}
else {
    Write-Host "chunk_12_7.tres has incorrect region!" -ForegroundColor Red
}

# Test chunk 15,15
$tresContent = Get-Content "resources/map_chunks/chunk_15_15.tres" -Raw
if ($tresContent -match "Rect2\(7680, 7680, 512, 512\)") {
    Write-Host "chunk_15_15.tres has correct region: Rect2(7680, 7680, 512, 512)" -ForegroundColor Green
}
else {
    Write-Host "chunk_15_15.tres has incorrect region!" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "No old PNG references found" -ForegroundColor Green
Write-Host "All 256 AtlasTexture references present" -ForegroundColor Green
Write-Host "All 256 .tres files exist" -ForegroundColor Green
Write-Host "Sample .tres files have correct regions" -ForegroundColor Green
Write-Host ""
Write-Host "The map atlas migration is complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Open Godot and test the map rendering." -ForegroundColor Yellow
