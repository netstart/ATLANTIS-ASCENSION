# Executa o jogo no Godot a partir do código-fonte (sem exportar).
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\run_game.ps1
#       -Editor              abre o projeto no editor em vez de rodar o jogo
#       -Bot -Seed 7         partida do bot, determinística (passo fixo de 60 fps)
#       -QuitAt 90           fecha sozinho após N segundos (com -Bot)
#       -Scene res://...     roda outra cena em vez da principal
#       -Godot "C:\...\Godot_v4.7.2-stable_win64_console.exe"   (padrão: $env:GODOT ou C:\src\tools\godot)
#       Argumentos extras vão para o jogo depois de "--" (ex.: tools\run_game.ps1 --shots=shots).

param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe' }),
    [switch]$Editor,
    [switch]$Bot,
    [int]$Seed = 7,
    [int]$QuitAt = 0,
    [string]$Scene = '',
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$GameArgs = @()
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$project = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $Godot)) { Write-Host "Godot não encontrado: $Godot (defina `$env:GODOT ou -Godot)" -ForegroundColor Red; exit 1 }

$arguments = @('--path', $project)
if ($Editor) {
    $arguments += '--editor'
} else {
    if ($Scene) { $arguments += $Scene }
    $userArgs = @($GameArgs)
    if ($Bot) {
        $arguments += @('--fixed-fps', '60')
        $userArgs += @('--bot', "--seed=$Seed")
        if ($QuitAt -gt 0) { $userArgs += "--quit-at=$QuitAt" }
    }
    if ($userArgs.Count -gt 0) { $arguments += @('--') + $userArgs }
}

Write-Host "== $Godot $($arguments -join ' ')" -ForegroundColor Cyan
& $Godot @arguments
exit $LASTEXITCODE
