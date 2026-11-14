# Emulatordeki ekranin goruntusunu docs/ekranlar klasorune kaydeder.
# Kullanim: powershell -ExecutionPolicy Bypass -File .\scripts\ekran-goruntusu.ps1 ana-sayfa
param([Parameter(Mandatory = $true)][string]$Ad)

$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

$hedef = Join-Path $PSScriptRoot "..\docs\ekranlar"
New-Item -ItemType Directory -Force -Path $hedef | Out-Null
$dosya = Join-Path $hedef ($Ad + ".png")

& $adb shell screencap -p /sdcard/bilge_ekran.png
& $adb pull /sdcard/bilge_ekran.png $dosya | Out-Null
& $adb shell rm /sdcard/bilge_ekran.png

if (Test-Path $dosya) {
    Write-Host ("Kaydedildi: docs/ekranlar/" + $Ad + ".png") -ForegroundColor Green
} else {
    Write-Host "Ekran goruntusu alinamadi. Emulator acik mi?" -ForegroundColor Red
}
