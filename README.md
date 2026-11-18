# Vaivén

Una isla en el notch de la Mac con dos cosas:

- **Mover cursor** (a la izquierda del notch): el cursor va de lado a lado en el centro de la pantalla para que la Mac no se bloquee mientras esperas, por ejemplo a Claude. **Esc** lo para.
- **Uso de Claude** (a la derecha del notch): un anillo con el % de la sesión de 5 h. Al tocarlo se ven la sesión y la semana, con **Sincronizar**. Usa la sesión de Claude Code de esa Mac.

Es para Mac con Apple Silicon y macOS 14 o más nuevo. En una Mac sin notch sale como una píldora arriba al centro.

## Instalar

Dile a Claude Code en la otra Mac:

> Baja https://github.com/SantiagoRamirezForero/vaiven e instálala siguiendo INSTALAR.md

Claude clona el repo, lo compila, lo instala en Aplicaciones, conecta la cuenta de Claude y lo deja arrancando solo al prender la Mac. Los pasos detallados (y qué hacer si algo falla) están en [INSTALAR.md](INSTALAR.md).

A mano, el mismo resultado sale con:

```bash
git clone https://github.com/SantiagoRamirezForero/vaiven.git ~/vaiven
cd ~/vaiven && ./scripts/install.sh
```

## Cómo funciona

- **Mover cursor:**
  - El cursor se mueve con `CGWarpMouseCursorPosition`, sin pedir permisos.
  - Mover el cursor así no cuenta como actividad, así que además la app toma la aserción `PreventUserIdleDisplaySleep` (lo mismo que `caffeinate -d`) y declara actividad cada 30 s.
  - Esc es un atajo global de Carbon que solo existe mientras el cursor se mueve. Si no se puede reservar, no arranca.
  - Se para solo si la Mac se duerme, se bloquea la pantalla o se cambia de usuario.
- **Uso de Claude:**
  - Lee la sesión de Claude Code del Llavero y le pide el uso a `api.anthropic.com/api/oauth/usage` (lo mismo que `/usage`), cada 5 min y al tocar Sincronizar.
  - El token solo vive en memoria y nunca se escribe.
  - `Vaiven --check-claude` prueba la cuenta sin abrir la isla.

## Desarrollo

```bash
swift build && swift test        # compila y corre las pruebas
./scripts/build-app.sh           # dist/Vaiven.app y dist/Vaiven.zip
./scripts/install.sh             # instala y arranca (LaunchAgent local.vaiven)
./scripts/uninstall.sh
```

`Sources/VaivenCore` es la parte pura (geometría, estados, lectura del uso, textos) y tiene pruebas. `Sources/Vaiven` es la app (AppKit).
