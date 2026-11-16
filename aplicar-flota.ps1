$ErrorActionPreference = 'Stop'
$autorentProject = $PSScriptRoot
$autorentBackend = Join-Path $autorentProject 'backend'
$autorentMysql = 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe'

Push-Location -LiteralPath $autorentBackend
try {
    & node 'scripts/fleet-schema-status.mjs'
    $autorentSchemaStatus = $LASTEXITCODE
    if ($autorentSchemaStatus -eq 2) {
        Write-Host 'Se aplicará la migración 002. Escribe la contraseña de root únicamente cuando MySQL la solicite.'
        $autorentMigration = (Join-Path $autorentProject 'database\migrations\002_real_fleet.sql').Replace('\', '/')
        & $autorentMysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 --execute="SOURCE $autorentMigration"
        if ($LASTEXITCODE -ne 0) { throw 'La migración no terminó correctamente. Conserva el mensaje; no se importó la flota.' }
    } elseif ($autorentSchemaStatus -ne 0) {
        throw 'No se pudo confirmar el estado de la migración. No se importó la flota.'
    }

    & node 'dist/scripts/import-real-fleet.js'
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo importar la flota. Conserva el mensaje mostrado.' }

    Write-Host ''
    Write-Host 'Listo: Outlander gris, Outlander roja y Rogue gris. Reinicia la API para usar el catálogo actualizado.'
    Write-Host 'En la ventana de la API: Ctrl+C y después npm.cmd run dev desde la carpeta backend.'
} finally {
    Pop-Location
}
