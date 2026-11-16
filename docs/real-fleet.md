# Catálogo real de AutoRent

El propietario confirmó el 28 de octubre de 2026 que el catálogo debe mostrar **tres unidades**. La Nissan Rogue azul queda excluida.

| Unidad | Año indicado por el propietario | Tracción indicada | Fotos |
| --- | --- | --- | --- |
| Mitsubishi Outlander gris | 2017 | 4×2, registrada como FWD | 2 |
| Mitsubishi Outlander roja | 2017 | 4×2, registrada como FWD | 2 |
| Nissan Rogue gris | 2016, pendiente de comprobar | Pendiente | 2 |

Las tarifas, los kilometrajes, las placas y las ubicaciones están pendientes. No se asignó un precio cero ni una ubicación ficticia. Los campos se guardan como `null`. El catálogo sin fechas permite mostrar estas unidades; `reservable: false` indica que no se deben ofrecer reservas. Con un período, solo se listan unidades con placa, tarifa positiva, kilometraje y ubicación completos, además de las reglas de disponibilidad anteriores.

## Investigación de las especificaciones

Las referencias técnicas están guardadas en `ficha.referencias`, separadas de los datos confirmados de la unidad. El equipamiento no se deduce de “full”, las llantas o la fotografía. La versión, el motor y la capacidad se completarán cuando el propietario pueda comprobarlos.

**Outlander 2017, mercado estadounidense:** el boletín oficial Mitsubishi TSB-16-00-012 identifica ES, SE y SEL 2WD con motor 4J12 2.4 L MIVEC de cuatro cilindros y CVT. La GT tiene V6 3.0 L y S-AWC. No se asignó ES, SE, SEL o GT a ninguna de las unidades del propietario. [Fuente de Mitsubishi](https://mitsubishitechinfo.com/data/TECH_DOCS/2016/52006741/HTML/520067416.htm). El folleto del fabricante indica 166 hp, 162 lb-pie y siete plazas para la configuración 2.4 L; se conserva como referencia pendiente de verificar para estas unidades. [Folleto Mitsubishi 2017](https://cdn.dealereprocess.org/cdn/brochures/mitsubishi/2017-outlander.pdf).

**Rogue 2016, mercado estadounidense:** Nissan documenta motor QR25DE 2.5 L, cuatro cilindros, 170 hp, 175 lb-pie y transmisión Xtronic. Había versiones S, SV y SL, con FWD o AWD; cinco plazas estándar y tercera fila opcional en configuraciones compatibles. No se asignaron tracción ni número de plazas a la unidad gris. [Ficha oficial de Nissan](https://usa.nissannews.com/en-US/releases/us-2016-nissan-rogue-press-kit).

**Año de la Rogue gris:** el frente fotografiado parece corresponder al cambio introducido para el año modelo 2017. Esa observación es una inferencia visual; no demuestra el año ni descarta que haya cambios de carrocería. Se conserva 2016 como año indicado por el propietario con `anio_verificado: false`, pendiente de VIN o documentación. [Comparación oficial Nissan 2017/2016](https://usa.nissannews.com/en-US/releases/2017-rogue-versus-2016-rogue).

## Aplicar en la instalación existente

El código requiere la migración `002_real_fleet.sql`; no repitas la migración inicial ni las semillas de demostración.

En PowerShell ejecuta:

```powershell
& "C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent\aplicar-flota.ps1"
```

El asistente comprueba primero si la migración ya existe. Si falta, MySQL solicita la contraseña de `root` localmente para cambiar la estructura. La cuenta `autorent_app` mantiene únicamente permisos de datos; su contraseña y la configuración JWT no cambian. La contraseña de root no se guarda en archivos ni se solicita por el chat.

Después se importan las tres unidades. Los vehículos de demostración se ocultan con `publicado = false`, conservando sus registros y el historial. Repetir el importador conserva las ediciones de las tres unidades; vuelve a ocultar otras unidades, por lo que es una herramienta de carga inicial. Las altas posteriores se realizan mediante la administración.

Al terminar, reinicia la API:

```powershell
Set-Location "C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent\backend"
npm.cmd run dev
```

Consulta `http://127.0.0.1:3000/api/v1/vehicles`: debe devolver `pagination.total: 3`, las tres unidades y sus fotografías. Las seis fotos están en `backend/public/vehicles/` y se sirven bajo `/media/vehicles/`.

## Administración de la flota

Requiere JWT de una cuenta administradora. El servidor consulta el rol y el estado actual de la cuenta en cada petición.

| Método y ruta | Operación |
| --- | --- |
| `GET /api/v1/admin/vehicles?page=1&limit=20` | Consultar unidades publicadas y ocultas |
| `POST /api/v1/admin/vehicles` | Crear más vehículos; no hay un límite fijo de tres |
| `PATCH /api/v1/admin/vehicles/:id` | Editar información, fotos, tarifa, kilometraje y publicación |
| `DELETE /api/v1/admin/vehicles/:id` | Ocultar sin borrar el historial |

Para crear se requieren `marca`, `modelo`, `categoria_id` y `anio`. Una marca o modelo nuevo se agrega dentro de la misma transacción. La unidad comienza oculta e inactiva; el administrador puede publicar y establecer el estado operativo al revisarla.

Ejemplo de alta sin datos todavía disponibles:

```json
{
  "marca": "Nissan",
  "modelo": "Rogue",
  "categoria_id": 2,
  "anio": 2018
}
```

Ejemplo de edición cuando el propietario conozca los datos; los valores siguientes son solo un ejemplo de la petición:

```json
{
  "precio_dia": "60.00",
  "kilometraje": 85000,
  "publicado": true,
  "estado_operativo": "operativo"
}
```

Los datos ausentes se omiten en PATCH; `null` borra un dato pendiente permitido. `ficha`, cuando se envía, reemplaza la ficha completa. Puede contener color, versión, tracción, plazas, motor, potencia, transmisión, combustible, verificación del año, observaciones, hasta doce fotos y hasta cinco referencias técnicas. Las fotos se referencian mediante URL HTTPS o archivos de `/media/vehicles/`; todavía no hay un cargador de archivos desde Flutter.

Las pantallas de Flutter aún no se han implementado. Mantener el sistema de diseño negro y dorado y solicitar aprobación de cada propuesta visual antes de construirla.

## Verificación

Pasaron la comprobación de tipos, la compilación y **86 pruebas automatizadas**. También pasaron **17 comprobaciones con MySQL 8.4.13 temporal**: migración, importación de las tres unidades, datos pendientes, fotos, habilitación al completar datos, importación repetida sin sobrescritura, altas adicionales, placas duplicadas, transacciones y ocultación conservando registros. Estas pruebas no cambiaron MySQL84 ni el catálogo de la instalación del propietario.
