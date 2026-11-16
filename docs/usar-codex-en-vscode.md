# Usar Codex con AutoRent en VS Code

Abre esta carpeta en Visual Studio Code:

```text
C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent
```

## Panel de la extensión

Después de instalar o reinstalar la extensión oficial de OpenAI:

1. Guarda los archivos abiertos.
2. Presiona **Ctrl + Shift + P** y ejecuta **Developer: Reload Window**.
3. Abre la paleta otra vez y ejecuta **Codex: Open Codex Sidebar**.

Si aparece `The extension could not start its user interface`, puedes utilizar la terminal mientras se resuelve el fallo del panel. Los registros revisados el 29 de octubre de 2026 mostraron que el panel no respondió durante sus primeros 30 segundos; el proceso de Codex sí inició. Esto no identifica por sí solo la causa del fallo.

## Acceso desde la terminal integrada

En VS Code, abre **Terminal > New Terminal**. Desde la carpeta de AutoRent, ejecuta:

```powershell
.\CODEX-EN-VSCODE.cmd
```

Se abrirá Codex en modo interactivo, con AutoRent como carpeta de trabajo. Escribe allí los cambios que necesitas. El acceso utiliza el ejecutable incluido en la extensión oficial y su inicio de sesión; no instala otro programa ni envía instrucciones automáticamente.

Ejemplo de una instrucción que puedes escribir:

> Revisa cómo se administra el catálogo de vehículos y permite editar la tarifa diaria desde la administración. Conserva únicamente los tres vehículos actuales.

Si Codex solicita iniciar sesión, sigue su opción de acceso con ChatGPT. No compartas contraseñas ni claves en el chat. El 29 de octubre se comprobó que el ejecutable respondía y tenía una sesión de ChatGPT disponible; no se ejecutó una modificación automática para probar este acceso.

Para consultar la versión instalada sin abrir una conversación:

```powershell
.\CODEX-EN-VSCODE.cmd --version
```

El acceso está preparado para Windows de 64 bits y una instalación normal de extensiones en `%USERPROFILE%\.vscode\extensions`. Si se desinstala la extensión o se usa una carpeta de extensiones diferente, habrá que adaptar esa ruta.

Referencia: [documentación oficial de Codex para editores](https://learn.chatgpt.com/docs/ide).
