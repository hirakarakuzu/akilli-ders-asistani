# Ders Asistani - n8n akislarini temizler, yeniden yukler ve yayinlar.
# Calistirma: powershell -ExecutionPolicy Bypass -File .\import-workflows.ps1
$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot

Write-Host "1/6 n8n durduruluyor..." -ForegroundColor Cyan
docker stop n8n | Out-Null

Write-Host "2/6 Eski ve kopya akislar siliniyor..." -ForegroundColor Cyan
docker cp scripts/temizle-akislar.sql ders_postgres:/tmp/temizle-akislar.sql
docker exec ders_postgres sh -c 'psql -v ON_ERROR_STOP=1 -U $POSTGRES_USER -d $POSTGRES_DB -f /tmp/temizle-akislar.sql'
if ($LASTEXITCODE -ne 0) {
    Write-Host "Temizlik basarisiz oldu, hicbir sey degistirilmedi. Yukaridaki hatayi Claude'a gonder." -ForegroundColor Red
    docker start n8n | Out-Null
    exit 1
}

Write-Host "3/6 n8n baslatiliyor (15 sn)..." -ForegroundColor Cyan
docker start n8n | Out-Null
Start-Sleep -Seconds 15

Write-Host "4/6 Yeni akislar yukleniyor..." -ForegroundColor Cyan
$dir = "/tmp/akislar-" + (Get-Date -Format "yyyyMMddHHmmss")
docker cp n8n-workflows "n8n:$dir"
docker exec n8n n8n import:workflow --separate --input=$dir

Write-Host "5/6 Akislar yayinlaniyor..." -ForegroundColor Cyan
$lines = docker exec n8n n8n list:workflow 2>$null
foreach ($l in $lines) {
    if ($l -match '^([A-Za-z0-9]+)\|(.+)$') {
        Write-Host ("   yayinlaniyor: " + $Matches[1])
        docker exec n8n n8n publish:workflow --id=$($Matches[1]) 2>$null | Out-Null
    }
}

Write-Host "6/6 n8n yeniden baslatiliyor (15 sn)..." -ForegroundColor Cyan
docker restart n8n | Out-Null
Start-Sleep -Seconds 15

Write-Host ""
Write-Host "Tamamlandi!" -ForegroundColor Green
Write-Host "Kontrol icin tarayicida ac: http://localhost:5678/webhook/saglik"
