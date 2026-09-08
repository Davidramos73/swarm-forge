# Mantenimiento de este fork

Este repositorio es un fork de [`unclebob/swarm-forge`](https://github.com/unclebob/swarm-forge).
Añade soporte para el backend **opencode** y un adaptador de **GNOME Terminal**.

## No uses el botón "Sync fork" de GitHub

**El botón "Sync fork" de la web resetea la rama a upstream y borra los commits
propios.** Ya pasó una vez: los tres commits de opencode desaparecieron de
`origin/main` y hubo que recuperarlos del clon local.

Sincroniza siempre por línea de comandos, con rebase:

```sh
git fetch upstream
git rebase upstream/main
git push origin main
```

Mientras nadie más empuje al fork, el push es fast-forward y no necesita
`--force`. Si el rebase reescribió commits que ya estaban publicados, usa
`git push --force-with-lease` (nunca `--force` a secas).

Configuración del remoto, si falta en un clon nuevo:

```sh
git remote add upstream https://github.com/unclebob/swarm-forge.git
```

### Sincronizar las demás ramas

Cada rama de producto tiene su propia línea de historia y se sincroniza por
separado:

```sh
for b in two-pack four-pack six-pack project-manager lieutenant \
         adversaries squad sprint-module-squad; do
  git checkout "$b" && git fetch upstream && git rebase "upstream/$b"
done
git push origin --all
```

### Antes de sincronizar

Guarda el trabajo sin commitear (`git stash -u`) y crea una rama de respaldo
(`git branch backup-<fecha>`). Tras el rebase, `bb test` debe pasar; ten en
cuenta que `get-swarm-forge-copies-only-swarmforge-owned-paths` falla sin red,
también en upstream limpio.

## Cambios propios del fork

Al rebasar, los conflictos se concentran en estos puntos:

| Qué | Dónde |
|---|---|
| Backend `opencode` en la lista de agentes válidos | `swarmforge/scripts/swarmforge.bb` — `(def known-agents ...)` |
| Comando de arranque de `opencode` | `swarmforge/scripts/swarmforge.bb` — rama del `case` en `launch-command` |
| Test del comando de arranque | `test/swarmforge/script_test.clj` — `opencode-launch-command-passes-initial-prompt` |
| Menciones de backends soportados | `README.md` |
| Investigación de la integración | `OPEN_CODE_INTEGRATION_RESEARCH.md` (archivo propio) |
| Novena columna (modelo) en `roles.tsv` | `swarmforge/scripts/swarmforge.bb` — `model-of` y `write-roles-file!` |
| Assertions del formato de `roles.tsv` | `test/swarmforge/script_test.clj` — `swarmforge-parses-propagation-tokens` |
| `agent`, `model`, `repo` y `branch` en el payload | `swarmforge/scripts/pack_web.bb` — `model-name`, `queue-row`, `project-source`, `dashboard-state` |
| Modelo por rol, repo/branch y layout del board | `swarmforge/scripts/pack/dashboard.html` — `workRow`, `renderChrome`, `.attention`, `.col`, `.card` |
| Semántica de `NO_TASK` y de `AUDIT_REQUIRED` | `swarmforge/constitution/articles/handoffs.prompt` |
| Marcador `AUDIT_REQUIRED.txt` en `audit_pending/` | `swarmforge/scripts/swarm_handoff.bb` — `write-audit!` |
| Script de instalación de swarms opencode | `setup-swarm` (archivo propio) |
| Permiso `external_directory` de opencode | `swarmforge/scripts/swarmforge.bb` — `ensure-opencode-external-reads!`, llamada desde `launch-role!` |
| Adaptador de GNOME Terminal | `swarmforge/scripts/terminal-adapters/gnome-terminal.sh` (propio) y dos inserciones en `swarmforge/scripts/swarm-terminal-adapter.sh` |

`opencode` recibe el worktree como argumento posicional (no `-C` ni `--cwd`) y
el prompt inicial por `--prompt`, respetando `initial-prompt?` y los args extra
de `swarmforge.conf`. Además:

- `--auto` (auto-aprobación) se añade vía `yolo-flag`, como `--yolo` en
  codex/copilot. Sin él los agentes se bloquean pidiendo permiso y el swarm no
  avanza. No se duplica si ya lo pasas en `swarmforge.conf`.
- `--mini` va fijo, como `--minimal` en grok. Verificado en tmux: sin él la TUI
  completa no deja leer la conversación en `capture-pane`; con él el transcript
  queda lineal y el dashboard lo puede mostrar.
- Cada worktree de rol con backend `opencode` recibe un `opencode.json` con
  `permission.external_directory: "allow"`, análogo a `ensure-codex-trust!` para
  codex. Hace falta porque el documento de la tarea vive en el worktree master,
  fuera del worktree del rol, y `--auto` no cubre esa categoría: sin esto el
  agente se queda esperando una aprobación que nadie pulsa. **Tiene que estar
  dentro del worktree del rol**, no en la raíz del proyecto: opencode deja de
  subir por el árbol al encontrar un `.git`, y cada worktree tiene el suyo
  (comprobado con `opencode debug config`). El fichero se añade a
  `info/exclude` para que ningún agente lo commitee.

## Punteros al repositorio

Los ficheros que descargan código apuntan a **este** fork, para que las
instalaciones traigan el soporte de opencode:

- `get-swarm-forge` → `default_repo_url` (también en las copias que llevan las
  ramas `project-manager` y `lieutenant`)
- El wrapper `./swarm` de `two-pack`, `four-pack`, `six-pack`, `adversaries`,
  `squad` y `sprint-module-squad` → `ARCHIVE_URL`
- Los enlaces de los README

Ambos admiten override por entorno: `SWARMFORGE_REPO_URL` y
`SWARMFORGE_SCRIPTS_URL`.

**Las referencias a los demás repos de unclebob no se cambian.** `crap4clj`,
`dry4clj`, `clj-mutate`, `mutate4go`, `crap4go`, `dry4go`, `crap4java`,
`dry4java`, `mutate4java`, `speclj-structure-check` y
`Acceptance-Pipeline-Specification` son herramientas suyas, no este proyecto;
redirigirlas a este fork rompería las descargas. Aparecen en `bb.edn`,
`swarmforge/scripts/swarm_tool.bb` y
`swarmforge/constitution/articles/engineering.prompt`.
