# Grava no GitHub os secrets do workflow .github/workflows/android-play.yml (docs/store/play-console.md).
# Lê a chave de upload do -KeyEnv (GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER, _PASSWORD) e, se passado, o JSON da
# conta de serviço da Play. Nunca imprime valores: cada um vai ao `gh` pela entrada padrão, a partir de um arquivo
# temporário apagado logo em seguida.
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\setup_ci_secrets.ps1
#       (opcional) -ServiceAccountJson C:\...\conta-de-servico.json   grava PLAY_SERVICE_ACCOUNT_JSON
#       (opcional) -KeyEnv C:\...\minha-chave.env

param(
    [string]$KeyEnv = 'D:\src\keys\atlantis-upload.env',
    [string]$ServiceAccountJson = '',
    [string]$Repo = 'netstart/ATLANTIS-ASCENSION'
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host 'GitHub CLI (gh) não encontrado. Instale com: winget install GitHub.cli   e depois: gh auth login' -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $KeyEnv)) { Write-Host "Arquivo da chave não encontrado: $KeyEnv" -ForegroundColor Red; exit 1 }

$keys = @{}
foreach ($line in Get-Content $KeyEnv) {
    if ($line -match '^\s*([A-Z_]+)=(.*)$') { $keys[$Matches[1]] = $Matches[2] }
}
foreach ($name in 'GODOT_ANDROID_KEYSTORE_RELEASE_PATH', 'GODOT_ANDROID_KEYSTORE_RELEASE_USER', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD') {
    if (-not $keys[$name]) { Write-Host "$name ausente em $KeyEnv" -ForegroundColor Red; exit 1 }
}
$keystore = $keys['GODOT_ANDROID_KEYSTORE_RELEASE_PATH']
if (-not (Test-Path $keystore)) { Write-Host "Keystore não encontrado: $keystore" -ForegroundColor Red; exit 1 }

# Valor exato (sem quebra de linha no fim) pela entrada padrão do gh.
function Set-Secret([string]$Name, [string]$File) {
    $p = Start-Process gh -ArgumentList "secret set $Name -R $Repo" -RedirectStandardInput $File -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) { Write-Host "FALHOU: $Name" -ForegroundColor Red; exit 1 }
    Write-Host "ok: $Name"
}
function Set-SecretValue([string]$Name, [string]$Value) {
    $tmp = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($tmp, $Value)
        Set-Secret $Name $tmp
    } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

Set-SecretValue 'ANDROID_UPLOAD_KEYSTORE_BASE64' ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $keystore))))
Set-SecretValue 'ANDROID_UPLOAD_KEYSTORE_ALIAS' $keys['GODOT_ANDROID_KEYSTORE_RELEASE_USER']
Set-SecretValue 'ANDROID_UPLOAD_KEYSTORE_PASSWORD' $keys['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD']

if ($ServiceAccountJson) {
    if (-not (Test-Path $ServiceAccountJson)) { Write-Host "JSON não encontrado: $ServiceAccountJson" -ForegroundColor Red; exit 1 }
    Set-Secret 'PLAY_SERVICE_ACCOUNT_JSON' (Resolve-Path $ServiceAccountJson).Path
    Write-Host "Guarde um backup de $ServiceAccountJson fora deste computador, como o do keystore." -ForegroundColor Yellow
} else {
    Write-Host 'PLAY_SERVICE_ACCOUNT_JSON não alterado (passe -ServiceAccountJson <arquivo>).' -ForegroundColor Yellow
}
