# Fix overworld.tscn to use AtlasTexture .tres files instead of individual chunk PNGs

$sceneFile = "overworld.tscn"
$backupFile = "overworld_backup_original.tscn"

# Create backup if it doesn't exist
if (-not (Test-Path $backupFile)) {
    Copy-Item $sceneFile $backupFile
    Write-Host "✓ Created backup: $backupFile" -ForegroundColor Green
}
else {
    Write-Host "ℹ Backup already exists: $backupFile" -ForegroundColor Cyan
}

# Read the scene file
$content = Get-Content $sceneFile -Raw

# Pattern to match chunk PNG ext_resource lines
# Example: [ext_resource type="Texture2D" uid="uid://..." path="res://chunks/chunk_12_7.png" id="127_x2dlj"]
$pattern = '\[ext_resource type="Texture2D" uid="([^"]*)" path="res://chunks/chunk_(\d+)_(\d+)\.png" id="([^"]*)"\]'

$replacements = 0
$lines = $content -split "`n"
$newLines = @()

foreach ($line in $lines) {
    if ($line -match $pattern) {
        $oldUid = $matches[1]
        $x = $matches[2]
        $y = $matches[3]
        $idValue = $matches[4]
        
        # Create new line referencing the AtlasTexture .tres file
        $newLine = "[ext_resource type=`"AtlasTexture`" path=`"res://resources/map_chunks/chunk_${x}_${y}.tres`" id=`"$idValue`"]"
        $newLines += $newLine
        $replacements++
        
        if ($replacements -le 5) {
            Write-Host "  Chunk $x,$y : $oldUid -> .tres" -ForegroundColor Gray
        }
    }
    else {
        $newLines += $line
    }
}

# Join lines back together
$newContent = $newLines -join "`n"

# Write the updated scene file
$newContent | Set-Content $sceneFile -NoNewline

Write-Host ""
Write-Host "✓ Updated $replacements chunk references in $sceneFile" -ForegroundColor Green
Write-Host "✓ Changed from individual PNGs to AtlasTexture .tres files" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Open Godot and reload the project"
Write-Host "2. Open overworld.tscn and verify chunks render correctly"
Write-Host "3. If everything works, you can delete the chunks/ directory"
