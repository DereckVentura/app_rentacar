$ErrorActionPreference = 'Stop'
$autorentSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { 'C:\Users\Ventura\develop\Android\Sdk' }
$autorentAdb = Join-Path $autorentSdk 'platform-tools\adb.exe'
$autorentEmulator = Join-Path $autorentSdk 'emulator\emulator.exe'
if (-not (Test-Path -LiteralPath $autorentAdb) -or -not (Test-Path -LiteralPath $autorentEmulator)) { throw 'No se encuentran las herramientas Android. Consulta el manual.' }
function Find-AutoRentEmulator {
  $autorentDevices = & $autorentAdb devices
  foreach ($autorentLine in $autorentDevices) {
    if ($autorentLine -match '^(emulator-\d+)\s+device') {
      $autorentCandidate = $Matches[1]
      $autorentName = (& $autorentAdb -s $autorentCandidate emu avd name 2>$null) -join ' '
      if ($autorentName -match 'AutoRent_API_36') { return $autorentCandidate }
    }
  }
  return $null
}
$autorentSerial = Find-AutoRentEmulator
if (-not $autorentSerial) {
  $autorentLocal = Join-Path $PSScriptRoot '.local'
  New-Item -ItemType Directory -Path $autorentLocal -Force | Out-Null
  $autorentStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  Start-Process -FilePath $autorentEmulator -ArgumentList '-avd','AutoRent_API_36','-gpu','software','-memory','2048','-cores','2','-no-snapshot-load' -WindowStyle Normal -RedirectStandardOutput (Join-Path $autorentLocal "emulador-$autorentStamp-out.log") -RedirectStandardError (Join-Path $autorentLocal "emulador-$autorentStamp-error.log") | Out-Null
}
Write-Host 'Iniciando el emulador de AutoRent...'
$autorentReady = $false
for ($autorentAttempt=0; $autorentAttempt -lt 120; $autorentAttempt++) {
  $autorentSerial = Find-AutoRentEmulator
  if ($autorentSerial) {
    $autorentBoot = (& $autorentAdb -s $autorentSerial shell getprop sys.boot_completed 2>$null) -join ''
    if ($autorentBoot.Trim() -eq '1') { $autorentReady = $true; break }
  }
  Start-Sleep -Seconds 1
}
if (-not $autorentReady) { throw 'El emulador no termino de iniciar. Revisa los registros de .local.' }
$autorentApk = Join-Path $PSScriptRoot 'output\AutoRent.apk'
if (-not (Test-Path -LiteralPath $autorentApk)) { throw 'No se encuentra el instalador actualizado en output\AutoRent.apk.' }
& $autorentAdb -s $autorentSerial install --no-streaming -r $autorentApk
if ($LASTEXITCODE -ne 0) { throw 'No se pudo actualizar la app. Si Android indica una firma incompatible, retira la instalación anterior del emulador y vuelve a abrir este archivo.' }
$autorentOpened = $false
for ($autorentLaunchAttempt=0; $autorentLaunchAttempt -lt 10; $autorentLaunchAttempt++) {
  $autorentLaunchOutput = (& $autorentAdb -s $autorentSerial shell am start -W -n 'sv.autorent.autorent/.MainActivity' 2>&1) -join ' '
  if ($LASTEXITCODE -eq 0) { $autorentOpened = $true; break }
  Start-Sleep -Seconds 1
}
if (-not $autorentOpened) { throw 'Android no pudo abrir la app. Espera a que termine de cargar y vuelve a intentarlo.' }
Write-Host 'App abierta en el emulador AutoRent.'
