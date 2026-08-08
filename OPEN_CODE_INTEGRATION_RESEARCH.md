# Investigación: Soporte de OpenCode como backend en SwarmForge

> **Estado: IMPLEMENTADO en `main`** (validación + launch command + tests + README).
> Ver sección 8 para el detalle de los cambios aplicados.

## 1. Resumen ejecutivo

SwarmForge orquesta agentes de IA en sesiones `tmux`, uno por rol, usando `git` worktrees para aislamiento. La lista de backends soportados y el comando de lanzamiento de cada uno están centralizados en `swarmforge/scripts/swarmforge.bb`.

OpenCode se integra lanzando su **TUI interactiva** (`opencode <project> --prompt ...`), que es un proceso persistente igual que los CLIs de `claude`, `codex`, `copilot` o `grok`. La selección de modelo por rol se hace con los `extra-cli-args` nativos de `swarmforge.conf` (`-m provider/model`).

## 2. Cómo funciona el lanzamiento de agentes

- Configuración: `swarmforge/swarmforge.conf`, línea:
  ```
  window <role> <agent> <worktree> [task|batch] [extra-cli-args...]
  ```
- Validación de agentes: `swarmforge/scripts/swarmforge.bb` (parse-config). Cualquier agente fuera del set soportado produce un error de validación.
- Comandos de lanzamiento: `launch-command`. El prompt del rol y la constitución se escriben en un archivo temporal (`<prompt-file>`), y cada backend lo recibe como argumento CLI.
- Los `extra-cli-args` se pasan tal cual al CLI del agente → permiten flags de modelo por rol.

## 3. OpenCode CLI: capacidades relevantes

Ruta detectada en este entorno: `/home/david/.opencode/bin/opencode`.

Comandos y opciones relevantes:
- `opencode [project]` — inicia la TUI interactiva (comportamiento por defecto, **proceso persistente**).
- `opencode run [message..]` — ejecuta un mensaje y termina (one-shot; **no usar** para SwarmForge).
- `opencode serve` / `opencode attach <url>` — servidor headless y cliente.
- `-m, --model provider/model` — selección de modelo.
- `--prompt <prompt>` — prompt inicial.
- `--auto` — auto-aprobar permisos no denegados (marcado como peligroso; opt-in).

**Corrección respecto a la primera versión de este documento:** OpenCode no es inherentemente one-shot. Lo one-shot es el subcomando `run`. La TUI por defecto es interactiva y persistente, que es lo que SwarmForge necesita (los wake-ups llegan por tmux send-keys al input del agente).

## 4. El gateway `opencode-go` (datos verificados)

Según models.dev y verificado en vivo con la credencial local:

- **API**: `https://opencode.ai/zen/go/v1`
- **Formato**: OpenAI-compatible (`@ai-sdk/openai-compatible`)
- **Env var**: `OPENCODE_API_KEY`
- `GET /models` → HTTP 200; `POST /chat/completions` → HTTP 200 (probado con `kimi-k3`).

Modelos disponibles en el gateway (`opencode models opencode-go`):

- Kimi: `kimi-k3`, `kimi-k2.7-code`, `kimi-k2.6`
- DeepSeek: `deepseek-v4-pro`, `deepseek-v4-flash`
- Otros: `glm-5.2`, `glm-5.1`, `qwen3.8-max`, `qwen3.7-*`, `minimax-m3`, `mimo-v2.5(-pro)`, `grok-4.5`, `gpt-5.6-luna`, `hy3`

**No hay modelos Anthropic en este gateway.** Para roles "Anthropic" se necesita una API key de Anthropic y el agente `claude` (SwarmForge soporta mezclar agentes por rol de fábrica). Alternativa: usar `glm-5.2`/`kimi-k2.7-code` como nivel intermedio, o los modelos free del tier `opencode` (p. ej. `opencode/deepseek-v4-flash-free`) para roles simples.

## 5. Modelo por rol (requisito del usuario)

Viable y nativo de SwarmForge: cada línea `window` lleva sus propios `extra-cli-args`. Ejemplo:

```conf
window specifier  opencode master     task -m opencode-go/kimi-k3
window coder      opencode coder      task -m opencode-go/deepseek-v4-flash
window refactorer claude   refactorer task --model sonnet
window architect  opencode architect  batch -m opencode-go/kimi-k3
```

Flags de modelo verificados por CLI: `opencode -m provider/model`, `codex -m <model>`, `claude --model <model>`.

## 6. Alternativas evaluadas

### Opción A (elegida e implementada): TUI de opencode como backend

```sh
opencode <worktree> <extra-args> --prompt "$(cat <prompt-file>)"
```

Un proceso por rol dentro de tmux, igual que los demás backends. Máxima compatibilidad con el gateway (opencode habla nativamente con él).

### Opción B (descartada por ahora): `opencode serve` + `attach`

Más compleja: gestión de puertos, auth básica y coordinación de sesiones.

### Opción C (descartada): `opencode agent create` por rol

Requiere mantener agentes preconfigurados fuera del repo; el formato no estaba claro.

### Opción D (viable, no requiere cambios a SwarmForge): codex CLI contra el gateway

Como el gateway es OpenAI-compatible, `codex` CLI podría configurarse vía `~/.codex/config.toml` con `base_url = "https://opencode.ai/zen/go/v1"` y `wire_api = "chat"`. `claude` CLI no es compatible (necesita API Anthropic-compatible). Queda como alternativa local si se prefiere no tocar SwarmForge.

## 7. Riesgos y consideraciones

- **Permisos**: la TUI pedirá aprobaciones por defecto. Para modo desatendido agregar `--auto` como `extra-cli-arg` (peligroso, opt-in).
- **Tamaño del prompt**: se pasa como `--prompt "$(cat file)"`; los shells soportan argumentos grandes, pero conviene observar en la práctica.
- **TUI dentro de tmux**: opencode es una app de terminal; debería comportarse como claude/codex en tmux, pero la primera ejecución real debe verificarse (colores, input, wake-ups por send-keys).
- **Propagación a las ramas workflow**: los wrappers `./swarm` de `two-pack`/`four-pack`/`six-pack` descargan los scripts desde `unclebob/swarm-forge@main` por defecto. Para usar este fork hay que exportar `SWARMFORGE_SCRIPTS_URL=https://github.com/Davidramos73/swarm-forge/archive/refs/heads/main.tar.gz` (o copiar `swarmforge/scripts/` manualmente al proyecto).

## 8. Cambios aplicados (main, 2026-08-08)

1. `swarmforge/scripts/swarmforge.bb`
   - Set de agentes ampliado: `#{"claude" "codex" "copilot" "grok" "opencode"}`.
   - Nuevo case en `launch-command`:
     ```clojure
     "opencode" (str "opencode " (sq (str role-worktree)) " " (extra-args-prefix row) "--prompt \"$(cat " (sq (str prompt-file)) ")\"")
     ```
2. `test/swarmforge/script_test.clj`
   - Nuevo test `opencode-launch-command-passes-initial-prompt` (pasa).
3. `README.md`
   - `opencode` agregado a las listas de backends soportados (prerequisitos, features y backend-per-role).
   - Ejemplo de config con modelo por rol: `window reviewer opencode wt-review task -m opencode-go/kimi-k3`.

### Verificación

- `bb test`: 25 tests / 68 aserciones. Los 7 fallos + 9 errores son **idénticos en `main` pristine** (ambiente sin `zsh`/`tmux`); ninguno proviene de este cambio.
- `--test-parse` con config opencode: valida y genera `roles.tsv`/`sessions.tsv` correctamente, preservando `-m opencode-go/deepseek-v4-flash` por rol.

## 9. Próximos pasos recomendados

1. Commit/push de `main` al fork (el usuario revisa primero).
2. Prueba real en un proyecto: exportar `SWARMFORGE_SCRIPTS_URL` al fork, editar `swarmforge.conf` con agentes `opencode` y modelos por rol, lanzar `./swarm`.
3. Verificar que la TUI reciba los wake-ups del handoff daemon y que `--prompt` inicial se procese.
4. Si la TUI da problemas de permisos en modo desatendido, evaluar `--auto` por rol o ajustar la config de opencode del proyecto.
