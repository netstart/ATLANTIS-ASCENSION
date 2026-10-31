# Gera a arte da ficha da Google Play em build/store/play/ (docs/store/play-console.md):
#   - <idioma>/phone_01..08.png: capturas de celular 1080x1920 (9:16; tela lógica 270x480 em 4x)
#   - <idioma>/feature_graphic.png: imagem de destaque 1024x500, sem transparência
#   - icon_512.png: ícone de alta resolução 512x512
# As capturas de partida são as mesmas para todos os idiomas (o HUD quase não tem texto); as de menu e a
# imagem de destaque saem em cada um dos 11 idiomas do jogo. Precisa de janela (sem --headless).
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\build_store_art.ps1
#       (opcional) -Godot "C:\...\Godot_v4.7.2-stable_win64_console.exe" -Langs pt_BR,en

param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }),
    [string[]]$Langs = @('pt_BR', 'en', 'es', 'de', 'fr', 'ru', 'id', 'ja', 'ko', 'zh_TW', 'zh_CN')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$project = Split-Path -Parent $PSScriptRoot
$out = Join-Path $project 'build\store\play'
$raw = Join-Path $project 'build\store\raw'
Remove-Item $out, $raw -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $out, $raw | Out-Null

function Invoke-Runner([string]$Scene, [string[]]$RunnerArgs) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $Godot --path $project $Scene -- @RunnerArgs 2>&1 | ForEach-Object { "$_" } |
        Where-Object { $_ -match 'ERROR|SCRIPT ERROR' } | Write-Host -ForegroundColor Red
    $ErrorActionPreference = $previous
}

# Partida: o bot joga com semente fixa; os instantes mostram chefes e padrões de balas legíveis.
$battles = @(
    @{ Mission = 'c2m3'; At = 100 },  # Kraken Engine
    @{ Mission = 'c5m3a'; At = 125 }, # Sky Leviathan
    @{ Mission = 'c3m2'; At = 60 }    # tempestade, pickups e multiplicador
)
foreach ($b in $battles) {
    Write-Host "== partida $($b.Mission) em $($b.At) s" -ForegroundColor Cyan
    Invoke-Runner 'res://tests/game_shots_runner.tscn' @("--shots=$raw\$($b.Mission)", '--res=270x480', '--zoom=4',
        "--mission=$($b.Mission)", "--at=$($b.At)")
}

$menus = @('boot', 'hub', 'hangar', 'ships', 'city')
Write-Host "== menus ($($Langs -join ','))" -ForegroundColor Cyan
Invoke-Runner 'res://tests/screens_runner.tscn' @("--shots=$raw\menus", '--res=270x480', '--zoom=4', '--showcase',
    "--langs=$($Langs -join ',')", "--screens=$($menus -join ',')")

$failed = $false
foreach ($lang in $Langs) {
    Write-Host "== $lang" -ForegroundColor Cyan
    $dir = Join-Path $out $lang
    New-Item -ItemType Directory -Force $dir | Out-Null
    Invoke-Runner 'res://tests/store_art_runner.tscn' @("--out=$dir", "--lang=$lang")
    Move-Item (Join-Path $dir "feature_graphic_$lang.png") (Join-Path $dir 'feature_graphic.png') -Force -ErrorAction SilentlyContinue
    # Ordem da ficha: ação primeiro (o que decide a instalação), depois título e a meta-progressão.
    $shots = @(
        (Join-Path $raw 'c2m3\game_100_270x480.png'),
        (Join-Path $raw 'c5m3a\game_125_270x480.png'),
        (Join-Path $raw "menus\boot_270x480_$lang.png"),
        (Join-Path $raw 'c3m2\game_060_270x480.png'),
        (Join-Path $raw "menus\hub_270x480_$lang.png"),
        (Join-Path $raw "menus\hangar_270x480_$lang.png"),
        (Join-Path $raw "menus\ships_270x480_$lang.png"),
        (Join-Path $raw "menus\city_270x480_$lang.png")
    )
    for ($i = 0; $i -lt $shots.Count; $i++) {
        if (Test-Path $shots[$i]) {
            Copy-Item $shots[$i] (Join-Path $dir ('phone_{0:D2}.png' -f ($i + 1)))
        } else {
            Write-Host "FALTOU: $($shots[$i])" -ForegroundColor Red
            $failed = $true
        }
    }
    if (-not (Test-Path (Join-Path $dir 'feature_graphic.png'))) { Write-Host "FALTOU: destaque $lang" -ForegroundColor Red; $failed = $true }
}
Copy-Item (Join-Path $project 'assets\art\generated\icon\icon_512.png') (Join-Path $out 'icon_512.png')

# Conferência das medidas que a Play exige (lidas do cabeçalho PNG).
foreach ($png in Get-ChildItem $out -Recurse -Filter *.png) {
    $bytes = [System.IO.File]::ReadAllBytes($png.FullName)
    $w = [int]$bytes[18] * 256 + [int]$bytes[19]
    $h = [int]$bytes[22] * 256 + [int]$bytes[23]
    $want = if ($png.Name -like 'phone_*') { '1080x1920' } elseif ($png.Name -eq 'feature_graphic.png') { '1024x500' } else { '512x512' }
    if ("${w}x${h}" -ne $want) { Write-Host "MEDIDA ERRADA: $($png.FullName) ${w}x${h} (quer $want)" -ForegroundColor Red; $failed = $true }
}
Remove-Item $raw -Recurse -Force

if ($failed) { Write-Host 'FALHOU' -ForegroundColor Red; exit 1 }
Write-Host "ARTE DA LOJA OK: $out" -ForegroundColor Green
