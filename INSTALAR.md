# Instalar Vaivén en otra Mac

Pasos para Claude Code (o para quien instale a mano). Todo se hace en la terminal, sin `sudo`. La persona solo tiene que tocar algo en pantalla en dos casos, marcados con **(la persona)**.

## 0. Requisitos

```bash
uname -m                 # debe decir arm64 (Apple Silicon)
sw_vers -productVersion  # 14 o más
xcode-select -p          # debe imprimir una ruta
```

- Si `uname -m` no dice `arm64` o macOS es menor que 14: Vaivén no funciona en esta Mac. Detente y avísale a la persona.
- Si `xcode-select -p` falla, faltan las Command Line Tools (traen `git` y `swift`). Corre `xcode-select --install`; **(la persona)** acepta la ventana. Luego espera a que terminen:

  ```bash
  until xcode-select -p >/dev/null 2>&1; do sleep 15; done
  ```

- Para el uso de Claude hace falta una sesión iniciada en Claude Code. Si estás leyendo esto desde Claude Code, esa sesión ya existe.

## 1. Bajar el repo

```bash
git clone https://github.com/SantiagoRamirezForero/vaiven.git ~/vaiven
cd ~/vaiven
```

Si `~/vaiven` ya existe: `cd ~/vaiven && git pull`.

## 2. Instalar

```bash
./scripts/install.sh
```

El script:

1. Compila la app. La primera vez tarda uno o dos minutos.
2. La copia a `/Applications/Vaiven.app`, o a `~/Applications/Vaiven.app` si no puede escribir en `/Applications`.
3. Prueba la cuenta de Claude con la sesión de Claude Code y la deja conectada.
4. Registra el LaunchAgent `local.vaiven`, que la arranca ya y cada vez que se inicia sesión.

Si macOS pregunta si `security` puede usar la información guardada en «Claude Code-credentials», **(la persona)** elige **Permitir siempre**.

Al terminar, el script debe imprimir:

- `Cuenta de Claude conectada: ok · sesión 5 h …`
- `Vaivén instalada en … y corriendo.`

Si la cuenta no se conectó, mira la sección de problemas abajo.

## 3. Verificar

```bash
launchctl print gui/$(id -u)/local.vaiven | grep "state ="   # state = running
/Applications/Vaiven.app/Contents/MacOS/Vaiven --check-claude  # ok · sesión 5 h 42 % · semana 65 %
```

Si la app quedó en `~/Applications`, usa esa ruta en el segundo comando.

## 4. Contarle a la persona cómo se usa

- Arriba, a la **izquierda del notch**, está el ícono del cursor. Al tocarlo se abre **Mover cursor**. Con eso, el cursor va de lado a lado en el centro de la pantalla y la Mac no se bloquea mientras esperas. **Esc** lo para y devuelve el cursor a donde estaba.
- Mientras el cursor se mueve, el mouse no sirve. Para recuperarlo, presiona Esc.
- A la **derecha del notch** está el anillo con el % de la sesión de 5 h de Claude. Al tocarlo se ven la sesión y la semana, con el botón **Sincronizar**. El uso se lee solo cada 5 minutos.
- El **clic derecho** sobre la isla permite sincronizar, agregar o quitar la cuenta de Claude, y salir.
- En una Mac sin notch, la isla es una píldora arriba al centro.

## Problemas

| Síntoma | Qué hacer |
|---|---|
| `Cuenta de Claude sin conectar (error · No hay sesión de Claude Code en esta Mac)` | **(la persona)** abre Claude Code (`claude`) e inicia sesión con `/login`. Después vuelve a correr `./scripts/install.sh`, o toca **Agregar cuenta** en la isla. |
| `Sesión vencida: abre Claude Code` | Claude Code renueva la sesión al abrirse. Ábrelo y toca **Sincronizar**. |
| `Claude rechazó la sesión` | Igual que arriba. Si sigue fallando, en Claude Code corre `/logout` y luego `/login`. |
| La isla no aparece | `tail -50 ~/Library/Logs/Vaiven.log` y luego `launchctl kickstart -k gui/$(id -u)/local.vaiven`. |
| El botón dice `Esc no disponible` | Otra app tiene reservada la tecla Esc como atajo global. Ciérrala y vuelve a intentar. |

## Actualizar y desinstalar

```bash
cd ~/vaiven && git pull && ./scripts/install.sh   # actualizar
cd ~/vaiven && ./scripts/uninstall.sh             # desinstalar (no toca la sesión de Claude Code)
```

## Privacidad

- **La sesión de Claude Code:** Vaivén la lee del Llavero con `/usr/bin/security` cada vez que pide el uso. El token solo vive en memoria durante esa petición y solo se envía a `api.anthropic.com`. Nunca se escribe en disco.
- **Lo único que se guarda:** que la cuenta está agregada (`defaults read local.vaiven`).
- **El endpoint de uso:** es el mismo que usa `/usage` en Claude Code. No es una API pública y puede cambiar.
