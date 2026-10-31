# Gera todos os builds em build/ (docs/store/release-checklist.md):
#   - Android: APK de debug (teste em aparelho) e AAB de release para a Play (assinado com a chave de upload)
#   - Windows: pasta + zip; Linux: pasta + tar.gz (com a versão do project.godot no nome)
#
# A chave de upload NUNCA entra no repositório: o arquivo -KeyEnv (padrão C:\src\tools\keys\atlantis-upload.env)
# traz GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER e _PASSWORD, que o Godot lê do ambiente na hora do export.
# Sem esse arquivo, o AAB é pulado e o resto sai normalmente.
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
#       (opcional) -Godot "C:\...\Godot_v4.7.2-stable_win64_console.exe" -KeyEnv "C:\...\minha-chave.env"

param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }),
    [string]$KeyEnv = 'C:\src\tools\keys\atlantis-upload.env',
    [string]$Java = 'C:\src\tools\jdk\jdk-17.0.20.1+1'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$project = Split-Path -Parent $PSScriptRoot
$build = Join-Path $project 'build'
$version = (Select-String -Path (Join-Path $project 'project.godot') -Pattern 'config/version="([^"]+)"').Matches[0].Groups[1].Value
$env:JAVA_HOME = $Java
# Pastas de exportação limpas: arquivos de versões anteriores não podem entrar nos pacotes.
Remove-Item (Join-Path $build 'windows'), (Join-Path $build 'linux') -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem (Join-Path $build '*') -File -Include *.zip, *.tar.gz -ErrorAction SilentlyContinue | Remove-Item -Force
New-Item -ItemType Directory -Force (Join-Path $build 'windows'), (Join-Path $build 'linux') | Out-Null
$failed = $false

function Export([string]$Preset, [string]$Path, [string]$Kind) {
    Write-Host "== $Preset -> $Path" -ForegroundColor Cyan
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $Godot --headless --path $project --install-android-build-template "--export-$Kind" $Preset $Path 2>&1 |
        ForEach-Object { "$_" } | Where-Object { $_ -match 'ERROR|BUILD FAILED' } | Write-Host -ForegroundColor Red
    $ErrorActionPreference = $previous
    if (-not (Test-Path (Join-Path $project $Path))) { Write-Host "FALHOU: $Path" -ForegroundColor Red; $script:failed = $true }
}

Export 'Android' 'build/atlantis-ascension-debug.apk' 'debug'
if (Test-Path $KeyEnv) {
    foreach ($line in Get-Content $KeyEnv) {
        if ($line -match '^\s*([A-Z_]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] }
    }
    Export 'Android Play' 'build/atlantis-ascension-release.aab' 'release'
} else {
    Write-Host "Sem $KeyEnv : AAB de release pulado (ver docs/store/release-checklist.md)" -ForegroundColor Yellow
}
Export 'Windows' 'build/windows/AtlantisAscension.exe' 'release'
Export 'Linux' "build/linux/atlantis-ascension-$version-linux.x86_64" 'release'

Write-Host '== Pacotes' -ForegroundColor Cyan
$zip = Join-Path $build "AtlantisAscension-$version-windows.zip"
Remove-Item $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $build 'windows\*') -DestinationPath $zip
& tar -czf (Join-Path $build "atlantis-ascension-$version-linux.tar.gz") -C (Join-Path $build 'linux') .
Get-ChildItem $build -File | Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } } | Format-Table

if ($failed) { Write-Host 'FALHOU' -ForegroundColor Red; exit 1 }
Write-Host "BUILDS OK ($version)" -ForegroundColor Green
