# Checagens obrigatórias antes de qualquer commit (docs/policies/testes.md):
#   1. importa o projeto (valida a sintaxe de todos os scripts)
#   2. lint (gdlint, regras em gdlintrc)
#   3. testes das regras puras
#   4. textos (11 idiomas, marcadores), licenças, a página da política de privacidade e os limites dos textos da loja
#   5. testes de integração (dados, idiomas, save, licenças, layout em todas as resoluções)
#   6. determinismo e estresse da partida (a partir do Vertical Slice)
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
#       (opcional) -Godot "C:\caminho\Godot_v4.7.2-stable_win64_console.exe"
#       (opcional) -Jobs N            processos ao mesmo tempo (padrão: núcleos lógicos da máquina)
#       (opcional) -TimeoutMinutes M  processo que passar disso é morto e reprova (padrão: 15)
#
# Como fica rápido (1.14.4) sem perder nenhuma verificação:
#   - A importação roda primeiro e sozinha; as etapas 2 a 6 rodam ao mesmo tempo, até -Jobs processos.
#   - As regras (etapa 3) e a integração (etapa 5) rodam em fatias (`-- --shard=I/N`, tests/test_shard.gd):
#     cada unidade (missão inteira do bot, caso de layout, HUD, campanha da economia...) cai em exatamente
#     uma fatia. Cada fatia termina com "fatia <suíte> I/N: k de T unidades"; este script confere que as
#     fatias somam todas as T unidades e soma as verificações de todas (fatia que caiu no meio reprova).
#   - A integração roda com --fixed-fps 60: cada quadro avança 1/60 s de jogo sem esperar o relógio (antes,
#     o limite de 60 FPS das opções fazia cada `await process_frame` custar 16,7 ms de verdade). As esperas
#     dos testes contam quadros, então o tempo de jogo esperado é o mesmo de antes.
#   - As 4 partidas do determinismo (1x, 2x, 3x e 3x na qualidade Baixa) também rodam em paralelo.
#   - Cada processo do Godot usa uma pasta user:// própria e temporária (APPDATA e XDG_DATA_HOME apontam
#     para ela): processos ao mesmo tempo nunca gravam o mesmo save, settings.cfg, replay ou log, e o
#     perfil do jogador nunca é tocado. A pasta é apagada no fim.
#   - A saída de cada processo é guardada e impressa por etapa, na ordem de sempre; qualquer falha em
#     qualquer processo reprova (FALHOU e código de saída 1).
#
# Origem: tools/run_checks.ps1 do projeto hyakki (mesmo autor, MIT).

param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }),
    [int]$Jobs = [Environment]::ProcessorCount,
    [int]$TimeoutMinutes = 15
)

$ErrorActionPreference = 'Stop'
# Saída do Godot e do Python em UTF-8 (sem isto o PowerShell 5.1 lê em ANSI e os filtros por
# "verificações" não casam).
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = 'utf-8'
$project = Split-Path -Parent $PSScriptRoot
$failed = $false
$clock = [Diagnostics.Stopwatch]::StartNew()
$Jobs = [Math]::Max(1, $Jobs)
# Fatias: a integração tem uma unidade de ~1,5 min (campanha da economia, em série por natureza) e o resto
# se divide bem; as regras são 41 unidades de 1 a 10 s. Mais fatias que isso só disputam os núcleos.
$intShards = [int][Math]::Max(1, [Math]::Min(6, [Math]::Floor($Jobs / 2)))
$ruleShards = [int][Math]::Max(1, [Math]::Min(2, [Math]::Floor($Jobs / 4)))
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ("atlantis-checks-" + $PID)

function Invoke-Godot([string[]]$GodotArgs) {
    # O Godot escreve avisos no stderr; no PowerShell 5.1 isso não pode encerrar o script.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $Godot --headless --path $project @GodotArgs 2>&1 | ForEach-Object { "$_" }
    $ErrorActionPreference = $previous
    return $output
}

# Argumentos para Start-Process (o PowerShell 5.1 junta com espaço sem pôr aspas).
function Join-Arguments([string[]]$List) {
    ($List | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
}

$jobList = New-Object System.Collections.ArrayList
function Add-Job([string]$Name, [string]$Exe, [string[]]$Arguments, [bool]$Sandbox) {
    [void]$jobList.Add([pscustomobject]@{
        Name = $Name; Exe = $Exe; Arguments = $Arguments; Sandbox = $Sandbox
        Process = $null; Out = $null; Err = $null; Code = $null; Seconds = 0.0; Lines = @(); TimedOut = $false
        Clock = $null
    })
}

function Start-CheckJob($Job) {
    $dir = Join-Path $runRoot ($Job.Name -replace '[^\w.-]', '_')
    New-Item -ItemType Directory -Force $dir | Out-Null
    $Job.Out = Join-Path $dir 'stdout.txt'
    $Job.Err = Join-Path $dir 'stderr.txt'
    $savedAppData = $env:APPDATA
    $savedXdg = $env:XDG_DATA_HOME
    if ($Job.Sandbox) {
        # user:// do Godot passa a ser <dir>\user\Godot\app_userdata\Atlantis Ascension (o filho herda o ambiente).
        $env:APPDATA = Join-Path $dir 'user'
        $env:XDG_DATA_HOME = Join-Path $dir 'user'
        New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    }
    try {
        $Job.Process = Start-Process -FilePath $Job.Exe -ArgumentList (Join-Arguments $Job.Arguments) `
            -WorkingDirectory $project -NoNewWindow -PassThru `
            -RedirectStandardOutput $Job.Out -RedirectStandardError $Job.Err
        $null = $Job.Process.Handle  # PowerShell 5.1: sem ler o Handle agora, o ExitCode volta vazio depois.
    } finally {
        $env:APPDATA = $savedAppData
        $env:XDG_DATA_HOME = $savedXdg
    }
    $Job.Clock = [Diagnostics.Stopwatch]::StartNew()
}

function Complete-CheckJob($Job) {
    $Job.Seconds = $Job.Clock.Elapsed.TotalSeconds
    $Job.Code = if ($Job.TimedOut) { 124 } else { $Job.Process.ExitCode }
    $lines = @()
    foreach ($file in $Job.Out, $Job.Err) {
        if (Test-Path $file) { $lines += @(Get-Content -LiteralPath $file -Encoding UTF8) }
    }
    if ($Job.TimedOut) { $lines += "FALHOU: passou de $TimeoutMinutes min e foi encerrado" }
    $Job.Lines = $lines
    $mark = if ($Job.Code -eq 0) { 'ok' } else { "código $($Job.Code)" }
    Write-Host ("   {0,-24} {1,6:N1} s  {2}" -f $Job.Name, $Job.Seconds, $mark) -ForegroundColor DarkGray
}

# Roda a lista com no máximo $Jobs processos ao mesmo tempo, na ordem da lista (os mais longos primeiro).
function Invoke-Jobs {
    $pending = New-Object System.Collections.Queue
    foreach ($job in $jobList) { $pending.Enqueue($job) }
    $running = New-Object System.Collections.ArrayList
    while ($pending.Count -gt 0 -or $running.Count -gt 0) {
        while ($pending.Count -gt 0 -and $running.Count -lt $Jobs) {
            $job = $pending.Dequeue()
            Start-CheckJob $job
            [void]$running.Add($job)
        }
        Start-Sleep -Milliseconds 200
        foreach ($job in @($running)) {
            if (-not $job.Process.HasExited -and $job.Clock.Elapsed.TotalMinutes -ge $TimeoutMinutes) {
                $job.TimedOut = $true
                & taskkill.exe /T /F /PID $job.Process.Id 2>&1 | Out-Null
                $job.Process.WaitForExit()
            }
            if ($job.Process.HasExited) {
                $job.Process.WaitForExit()
                Complete-CheckJob $job
                $running.Remove($job)
            }
        }
    }
}

function Find-CheckJob([string]$Name) { $jobList | Where-Object { $_.Name -eq $Name } | Select-Object -First 1 }

# Fatias de uma suíte: cada fatia sem erro e com a linha final, as fatias somando todas as unidades.
# Imprime as linhas que interessam e o total de verificações. Devolve $true se passou.
function Test-Shards([string]$Suite, [string]$Prefix, [int]$Count, [int]$MaxLines) {
    $ok = $true
    $shown = @()
    $checks = 0
    $fails = 0
    $units = 0
    $totals = @()
    for ($i = 0; $i -lt $Count; $i++) {
        $job = Find-CheckJob "$Prefix $i/$Count"
        $shown += $job.Lines | Where-Object { $_ -match 'FALHOU|SCRIPT ERROR' }
        $summary = $job.Lines | Where-Object { $_ -match '^(\d+) verificações, (\d+) falhas' } | Select-Object -Last 1
        $slice = $job.Lines | Where-Object { $_ -match "^fatia $Suite \d+/\d+: (\d+) de (\d+) unidades" } | Select-Object -Last 1
        if (-not $summary -or -not $slice) {
            $shown += "FALHOU: a fatia $i/$Count de $Suite terminou sem o resumo (código $($job.Code))"
            $ok = $false
        } else {
            $null = $summary -match '^(\d+) verificações, (\d+) falhas'
            $checks += [int]$Matches[1]
            $fails += [int]$Matches[2]
            $null = $slice -match "^fatia $Suite \d+/\d+: (\d+) de (\d+) unidades"
            $units += [int]$Matches[1]
            $totals += [int]$Matches[2]
        }
        if ($job.Code -ne 0 -or ($job.Lines -match 'FALHOU|SCRIPT ERROR')) { $ok = $false }
    }
    $total = ($totals | Select-Object -Unique)
    if ($ok -and (@($total).Count -ne 1 -or $units -ne [int]$total)) {
        $shown += "FALHOU: as fatias de $Suite rodaram $units unidades de $(@($total) -join '/')"
        $ok = $false
    }
    # O prefixo da integração roda em toda fatia: a mesma falha aparece uma vez só.
    $shown | Select-Object -Unique | Select-Object -First $MaxLines | Write-Host
    Write-Host ("{0} verificações, {1} falhas ({2} fatias, {3} unidades)" -f $checks, $fails, $Count, $units)
    return $ok
}

function Test-Python([string]$Name) {
    $job = Find-CheckJob $Name
    $job.Lines | Write-Host
    return $job.Code -eq 0
}

Write-Host '== 1. Importação' -ForegroundColor Cyan
$import = Invoke-Godot @('--import')
$importErrors = $import | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed' }
if ($importErrors) { $importErrors | Write-Host -ForegroundColor Red; $failed = $true } else { Write-Host 'ok' }
$importSeconds = $clock.Elapsed.TotalSeconds

# Etapas 2 a 6 em paralelo; as mais longas entram primeiro na fila.
$godotBase = @('--headless', '--path', $project)
for ($i = 0; $i -lt $intShards; $i++) {
    Add-Job "integração $i/$intShards" $Godot ($godotBase + @('--fixed-fps', '60', 'res://tests/integration_tests.tscn', '--', "--shard=$i/$intShards")) $true
}
for ($i = 0; $i -lt $ruleShards; $i++) {
    Add-Job "regras $i/$ruleShards" $Godot ($godotBase + @('--script', 'res://tests/run_tests.gd', '--', "--shard=$i/$ruleShards")) $true
}
$hasGame = Test-Path (Join-Path $project 'scenes\game\Game.tscn')
if ($hasGame) {
    foreach ($speed in 1, 2, 3) {
        Add-Job "partida ${speed}x" $Godot ($godotBase + @('--fixed-fps', '60', '--', '--bot', '--seed=7', "--speed=$speed", '--quit-at=90')) $true
    }
    # Qualidade gráfica não pode mudar a simulação.
    Add-Job 'partida 3x Baixa' $Godot ($godotBase + @('--fixed-fps', '60', '--', '--bot', '--seed=7', '--speed=3', '--gfx=low', '--quit-at=90')) $true
}
Add-Job 'lint' 'python' @('-m', 'gdtoolkit.linter', (Join-Path $project 'scripts'), (Join-Path $project 'tests')) $false
Add-Job 'textos' 'python' @('-I', (Join-Path $PSScriptRoot 'build_i18n.py'), '--check') $false
Add-Job 'licenças' 'python' @('-I', (Join-Path $PSScriptRoot 'check_licenses.py')) $false
Add-Job 'privacidade' 'python' @('-I', (Join-Path $PSScriptRoot 'build_privacy_page.py'), '--check') $false
Add-Job 'loja' 'python' @('-I', (Join-Path $PSScriptRoot 'check_store_texts.py')) $false

Write-Host "== Etapas 2 a 6 em paralelo ($Jobs processos; integração em $intShards fatias, regras em $ruleShards)" -ForegroundColor Cyan
try {
    Invoke-Jobs
} finally {
    foreach ($job in $jobList) {
        if ($job.Process -and -not $job.Process.HasExited) { & taskkill.exe /T /F /PID $job.Process.Id 2>&1 | Out-Null }
    }
}

Write-Host '== 2. Lint (gdlint, regras em gdlintrc)' -ForegroundColor Cyan
$lint = Find-CheckJob 'lint'
if ($lint.Lines -match 'No module named') {
    Write-Host 'gdtoolkit não instalado (python -m pip install --user "gdtoolkit==4.*"); FALHOU' -ForegroundColor Red
    $failed = $true
} else {
    $lint.Lines | Select-Object -Last 5 | Write-Host
    if ($lint.Code -ne 0) { $failed = $true }
}

Write-Host '== 3. Testes de regras' -ForegroundColor Cyan
if (-not (Test-Shards 'regras' 'regras' $ruleShards 40)) { $failed = $true }

Write-Host '== 4. Textos (11 idiomas, marcadores) e licenças' -ForegroundColor Cyan
foreach ($name in 'textos', 'licenças', 'privacidade', 'loja') {
    if (-not (Test-Python $name)) { $failed = $true }
}

Write-Host '== 5. Testes de integração (dados, idiomas, save, licenças, layout em todas as resoluções)' -ForegroundColor Cyan
if (-not (Test-Shards 'integração' 'integração' $intShards 40)) { $failed = $true }

Write-Host '== 6. Determinismo e estresse da partida' -ForegroundColor Cyan
if ($hasGame) {
    $hashes = @()
    foreach ($name in 'partida 1x', 'partida 2x', 'partida 3x', 'partida 3x Baixa') {
        $run = Find-CheckJob $name
        $line = $run.Lines | Where-Object { $_ -match '^FIM ' } | Select-Object -Last 1
        Write-Host "$($name -replace '^partida ', ''): $line"
        if (-not $line) { $failed = $true }
        $hashes += ($line -replace '^.*hash=', '')
    }
    if (($hashes | Select-Object -Unique).Count -ne 1) {
        Write-Host 'FALHOU: o estado mudou com a velocidade ou com a qualidade gráfica' -ForegroundColor Red
        $failed = $true
    } else { Write-Host 'ok: mesmo estado nas três velocidades e na qualidade Baixa' }
} else {
    Write-Host 'pulado: a partida (scenes\game\Game.tscn) entra no Vertical Slice' -ForegroundColor Yellow
}

Remove-Item -LiteralPath $runRoot -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("Tempo: importação {0:N0} s, total {1:N0} s" -f $importSeconds, $clock.Elapsed.TotalSeconds) -ForegroundColor DarkGray
if ($failed) { Write-Host 'FALHOU' -ForegroundColor Red; exit 1 }
Write-Host 'TUDO OK' -ForegroundColor Green
