Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile("$PWD\assets\themap.png")
Write-Host "themap.png dimensions:"
Write-Host "Width: $($img.Width)"
Write-Host "Height: $($img.Height)"
$img.Dispose()
