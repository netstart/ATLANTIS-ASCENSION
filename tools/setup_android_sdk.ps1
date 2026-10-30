# Instala o Android SDK que o Godot 4.7.2 exige para exportar (docs do Godot, "Exporting for Android"):
#   platform-tools, build-tools;35.0.1, platforms;android-35, cmake;3.10.2.4988404, ndk;28.1.13356709
# e aponta o editor do Godot para o JDK 17 e para o SDK.
#
# Rode você mesmo: o sdkmanager mostra as licenças do Android SDK e pede que VOCÊ as aceite.
#   powershell -ExecutionPolicy Bypass -File tools\setup_android_sdk.ps1
#
# Parâmetros opcionais: -SdkRoot C:\src\tools\android-sdk  -JdkRoot C:\src\tools\jdk\jdk-17.0.20.1+1

param(
    [string]$SdkRoot = 'C:\src\tools\android-sdk',
    [string]$JdkRoot = $(Get-ChildItem 'C:\src\tools\jdk' -Directory -Filter 'jdk-17*' | Select-Object -First 1 -ExpandProperty FullName)
)

$ErrorActionPreference = 'Stop'
if (-not $JdkRoot -or -not (Test-Path (Join-Path $JdkRoot 'bin\java.exe'))) { throw "JDK 17 não encontrado em C:\src\tools\jdk" }
$env:JAVA_HOME = $JdkRoot
$env:Path = "$JdkRoot\bin;$env:Path"

# 1. Command-line tools (link oficial lido da página do Android Studio).
$latest = Join-Path $SdkRoot 'cmdline-tools\latest'
if (-not (Test-Path (Join-Path $latest 'bin\sdkmanager.bat'))) {
    $page = (Invoke-WebRequest -UseBasicParsing 'https://developer.android.com/studio').Content
    $zip = [regex]::Match($page, 'commandlinetools-win-\d+_latest\.zip').Value
    if (-not $zip) { throw 'Não achei o link das command-line tools em developer.android.com/studio' }
    $download = Join-Path 'C:\src\downloads\tools' $zip
    New-Item -ItemType Directory -Force (Split-Path $download) | Out-Null
    Write-Host "Baixando $zip"
    Invoke-WebRequest -UseBasicParsing "https://dl.google.com/android/repository/$zip" -OutFile $download
    $tmp = Join-Path $SdkRoot 'cmdline-tools\_tmp'
    Expand-Archive -Force $download $tmp
    New-Item -ItemType Directory -Force (Split-Path $latest) | Out-Null
    Move-Item (Join-Path $tmp 'cmdline-tools') $latest
    Remove-Item -Recurse -Force $tmp
}
$sdkmanager = Join-Path $latest 'bin\sdkmanager.bat'

# 2. Licenças: leia e aceite (ou recuse) no terminal.
& $sdkmanager --sdk_root=$SdkRoot --licenses

# 3. Pacotes exigidos pelo Godot 4.7.
& $sdkmanager --sdk_root=$SdkRoot 'platform-tools' 'build-tools;35.0.1' 'platforms;android-35' 'cmake;3.10.2.4988404' 'ndk;28.1.13356709'

# 4. Caminhos no editor do Godot (editor_settings-4.7.tres).
$settings = Join-Path $env:APPDATA 'Godot\editor_settings-4.7.tres'
if (Test-Path $settings) {
    $text = Get-Content -Raw -Encoding UTF8 $settings
    $java = ($JdkRoot -replace '\\', '/')
    $sdk = ($SdkRoot -replace '\\', '/')
    foreach ($pair in @(@('export/android/java_sdk_path', $java), @('export/android/android_sdk_path', $sdk))) {
        $line = "$($pair[0]) = `"$($pair[1])`""
        if ($text -match [regex]::Escape($pair[0])) {
            $text = [regex]::Replace($text, "(?m)^$([regex]::Escape($pair[0])) = .*$", $line)
        } else {
            $text = $text.TrimEnd() + "`n$line`n"
        }
    }
    Set-Content -Encoding UTF8 -NoNewline $settings $text
    Write-Host "Editor do Godot aponta para o JDK ($java) e o SDK ($sdk)"
} else {
    Write-Host 'Abra o editor do Godot uma vez e rode este script de novo para gravar os caminhos.' -ForegroundColor Yellow
}
Write-Host 'Android SDK pronto' -ForegroundColor Green
