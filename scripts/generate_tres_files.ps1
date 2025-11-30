# Generate 256 AtlasTexture .tres files for map chunks
# Each chunk is 512x512 in a 16x16 grid

$atlasPath = "res://assets/themap.png"
$chunkSize = 512
$gridSize = 16

for ($y = 0; $y -lt $gridSize; $y++) {
    for ($x = 0; $x -lt $gridSize; $x++) {
        $regionX = $x * $chunkSize
        $regionY = $y * $chunkSize
        
        $tresContent = @"
[gd_resource type="AtlasTexture" load_steps=2 format=3]

[ext_resource type="Texture2D" path="$atlasPath" id="1"]

[resource]
atlas = ExtResource("1")
region = Rect2($regionX, $regionY, $chunkSize, $chunkSize)
"@
        
        $filePath = "resources\map_chunks\chunk_${x}_${y}.tres"
        Set-Content -Path $filePath -Value $tresContent -Encoding UTF8
    }
}

Write-Host "Generated 256 AtlasTexture .tres files in resources/map_chunks/"
