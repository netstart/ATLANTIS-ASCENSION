# Checagens obrigatórias antes de qualquer commit (docs/policies/testes.md):
#   1. importa o projeto (valida a sintaxe de todos os scripts)
#   2. lint (gdlint, regras em gdlintrc)
#   3. testes das regras puras
#   4. textos (11 idiomas, marcadores), licenças, a página da política de privacidade e os limites dos textos da loja
#   5. testes de integração (dados, idiomas, fontes, save, licenças, layout em todas as resoluções)
#   6. determinismo e estresse da partida (a partir do Vertical Slice)
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
#       (opcional) -Godot "C:\caminho\Godot_v4.7.2-stable_win64_console.exe"
#
# Origem: tools/run_checks.ps1 do projeto hyakki (mesmo autor, MIT).

param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' })
)

$ErrorActionPreference = 'Stop'
# Saída do Godot e do Python em UTF-8 (sem isto o PowerShell 5.1 lê em ANSI e os filtros por
# "verificações" não casam).
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = 'utf-8'
$project = Split-Path -Parent $PSScriptRoot
$failed = $false

function Invoke-Godot([string[]]$GodotArgs) {
    # O Godot escreve avisos no stderr; no PowerShell 5.1 isso não pode encerrar o script.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $Godot --headless --path $project @GodotArgs 2>&1 | ForEach-Object { "$_" }
    $ErrorActionPreference = $previous
    return $output
}

function Invoke-Python([string[]]$PyArgs) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & python -I @PyArgs 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $previous
    $output | Write-Host
    return $code
}

Write-Host '== 1. Importação' -ForegroundColor Cyan
$import = Invoke-Godot @('--import')
$importErrors = $import | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed' }
if ($importErrors) { $importErrors | Write-Host -ForegroundColor Red; $failed = $true } else { Write-Host 'ok' }

Write-Host '== 2. Lint (gdlint, regras em gdlintrc)' -ForegroundColor Cyan
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$lint = & python -m gdtoolkit.linter (Join-Path $project 'scripts') (Join-Path $project 'tests') 2>&1 | ForEach-Object { "$_" }
$lintCode = $LASTEXITCODE
$ErrorActionPreference = $previous
if ($lint -match 'No module named') {
    Write-Host 'gdtoolkit não instalado (python -m pip install --user "gdtoolkit==4.*"); FALHOU' -ForegroundColor Red
    $failed = $true
} else {
    $lint | Select-Object -Last 5 | Write-Host
    if ($lintCode -ne 0) { $failed = $true }
}

Write-Host '== 3. Testes de regras' -ForegroundColor Cyan
$tests = Invoke-Godot @('--script', 'res://tests/run_tests.gd')
$tests | Where-Object { $_ -match 'verificações|FALHOU|SCRIPT ERROR' } | Write-Host
if ($LASTEXITCODE -ne 0 -or ($tests -match 'FALHOU|SCRIPT ERROR')) { $failed = $true }

Write-Host '== 4. Textos (11 idiomas, marcadores) e licenças' -ForegroundColor Cyan
if ((Invoke-Python @((Join-Path $PSScriptRoot 'build_i18n.py'), '--check')) -ne 0) { $failed = $true }
if ((Invoke-Python @((Join-Path $PSScriptRoot 'check_licenses.py'))) -ne 0) { $failed = $true }
if ((Invoke-Python @((Join-Path $PSScriptRoot 'build_privacy_page.py'), '--check')) -ne 0) { $failed = $true }
if ((Invoke-Python @((Join-Path $PSScriptRoot 'check_store_texts.py'))) -ne 0) { $failed = $true }

Write-Host '== 5. Testes de integração (dados, idiomas, save, licenças, layout em todas as resoluções)' -ForegroundColor Cyan
$integration = Invoke-Godot @('res://tests/integration_tests.tscn')
$integration | Where-Object { $_ -match 'verificações|FALHOU|SCRIPT ERROR' } | Select-Object -First 40 | Write-Host
if ($LASTEXITCODE -ne 0 -or ($integration -match 'FALHOU|SCRIPT ERROR')) { $failed = $true }

Write-Host '== 6. Determinismo e estresse da partida' -ForegroundColor Cyan
if (Test-Path (Join-Path $project 'scenes\game\Game.tscn')) {
    $hashes = @()
    foreach ($speed in 1, 2, 3) {
        $run = Invoke-Godot @('--fixed-fps', '60', '--', '--bot', '--seed=7', "--speed=$speed", '--quit-at=90')
        $line = $run | Where-Object { $_ -match '^FIM ' } | Select-Object -Last 1
        Write-Host "${speed}x: $line"
        $hashes += ($line -replace '^.*hash=', '')
    }
    # Qualidade gráfica não pode mudar a simulação.
    $low = Invoke-Godot @('--fixed-fps', '60', '--', '--bot', '--seed=7', '--speed=3', '--gfx=low', '--quit-at=90')
    $line = $low | Where-Object { $_ -match '^FIM ' } | Select-Object -Last 1
    Write-Host "3x Baixa: $line"
    $hashes += ($line -replace '^.*hash=', '')
    if (($hashes | Select-Object -Unique).Count -ne 1) {
        Write-Host 'FALHOU: o estado mudou com a velocidade ou com a qualidade gráfica' -ForegroundColor Red
        $failed = $true
    } else { Write-Host 'ok: mesmo estado nas três velocidades e na qualidade Baixa' }
} else {
    Write-Host 'pulado: a partida (scenes\game\Game.tscn) entra no Vertical Slice' -ForegroundColor Yellow
}

if ($failed) { Write-Host 'FALHOU' -ForegroundColor Red; exit 1 }
Write-Host 'TUDO OK' -ForegroundColor Green
