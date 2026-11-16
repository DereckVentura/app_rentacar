$ErrorActionPreference = 'Stop'
$autorentBackend = Join-Path $PSScriptRoot 'backend'
$autorentNode = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
if (-not $autorentNode) { $autorentNode = 'C:\Program Files\nodejs\Documents\node.exe' }
if (-not (Test-Path -LiteralPath $autorentNode)) { throw 'No se encuentra Node.js.' }
Push-Location $autorentBackend
$autorentPreviousUser = $env:MIGRATION_DB_USER
$autorentPreviousPassword = $env:MIGRATION_DB_PASSWORD
try {
    Write-Host 'Creando un respaldo antes de actualizar...'
    & $autorentNode 'scripts/backup.mjs'
    if ($LASTEXITCODE -ne 0) { throw 'El respaldo no pudo completarse. No se aplicaron cambios.' }
    Write-Host 'Introduce la contraseña local de MySQL root. No se mostrará ni se guardará.'
    $autorentSecure = Read-Host 'Contraseña MySQL root' -AsSecureString
    $autorentPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($autorentSecure)
    try { $env:MIGRATION_DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($autorentPtr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($autorentPtr) }
    $env:MIGRATION_DB_USER = 'root'
    & $autorentNode 'scripts/migrate.mjs'
    if ($LASTEXITCODE -ne 0) { throw 'La actualización requiere revisión. El respaldo se conserva.' }
    Write-Host 'Actualización comprobada. La flota y el historial se conservaron.'
    Write-Host 'Reinicia el servidor desde iniciar-servidor.cmd y abre la app desde abrir-app.cmd.'
} finally {
    $env:MIGRATION_DB_USER = $autorentPreviousUser
    $env:MIGRATION_DB_PASSWORD = $autorentPreviousPassword
    Pop-Location
}
