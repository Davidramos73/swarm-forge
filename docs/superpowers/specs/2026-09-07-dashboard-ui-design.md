# Dashboard: provider/modelo por rol y más sitio para el contenido

Fecha: 2026-09-07 · Estado: implementado en `feat/dashboard-provider-modelo-repo-branch`
Repo: `Davidramos73/swarm-forge` (rama `main`)

## Problema

Tres cosas concretas observadas corriendo un `four-pack` real con backends
mezclados (claude, opencode ×2, codex):

1. **El Work Queue no dice qué provider ni qué modelo usa cada rol.** Con cuatro
   roles repartidos entre tres suscripciones distintas, no hay forma de ver desde
   el dashboard quién está gastando qué cupo.
2. **La barra de aprobación queda apretada.** Aprobaciones y clarificaciones se
   apilan en una franja que obliga a scrollear.
3. **Las columnas del board son pequeñas y sobra espacio a los lados.** Con las
   5 lanes del four-pack en pantalla ancha, el ancho disponible no se reparte y
   las tarjetas quedan estrechas para su contenido.

## Alcance

Solo el dashboard y los datos que lo alimentan. No se toca el protocolo de
handoffs, ni los prompts de rol, ni la constitución.

## Cambio 1 — Provider y modelo en el Work Queue

### Estado actual

- `roles.tsv` tiene 8 columnas: role, worktree-name, worktree-path, session,
  display-name, **agent**, receive-mode, propagation. Lo escribe
  `write-roles-file!` en `swarmforge/scripts/swarmforge.bb:248`.
- El **provider** ya está ahí (`claude`, `opencode`, `codex`).
- El **modelo** no está en ningún sitio que el dashboard lea: vive solo en
  `swarmforge/swarmforge.conf` como argumentos extra del CLI
  (`--model sonnet`, `-m opencode-go/kimi-k2.7-code`).
- `pack_web.bb` lee `roles.tsv` en la línea 110 y **no expone `agent`** en su
  payload JSON (no hay ninguna referencia a `"agent"` en el archivo).
- El Work Queue es una tabla en el rail, `dashboard.html:167-176`, con columnas
  `c-story`, `c-role`, `c-state`, `c-age`, renderizada en `#work-rows`.

### Diseño

**a) `swarmforge.bb`** — añadir el modelo como **novena columna** de
`roles.tsv`, extraído de los args extra del rol: el valor que sigue a `-m` o
`--model`, o el literal `default` si el rol no fija modelo (el caso del
`architect`, que usa el default de Codex, `gpt-5.6-terra`).

Añadir al final es seguro, **verificado**: los 13 consumidores de `roles.tsv`
acceden por posición desde el principio y se protegen con guardas
`(>= (count cols) N)` — `commit_msg_hook.bb:38`, `handoff_lib.bb:52`,
`pack_dashboard_request.bb:64`, `swarm_handoff.bb:274`. Ninguno exige 8 columnas
exactas. `pack_web.bb:112-114` parte en vector e indexa. **Corrección de la investigación previa:** se afirmaba que el test
`swarmforge-parses-propagation-tokens` (`script_test.clj:295`) usa
`str/includes?` y por eso no rompía. Usa `str/ends-with?` en tres de sus cuatro
assertions y **sí rompe**: hubo que actualizarlas para esperar la novena
columna.

**b) `pack_web.bb`** — exponer `agent` y `model` en el payload que consume el
Work Queue.

**c) `dashboard.html`** — mostrarlos en la fila de cada rol, con el modelo en
tono secundario (`var(--muted)`), del estilo `opencode · kimi-k2.7-code`. Si el
ancho del rail aprieta, el modelo va en segunda línea bajo el rol en vez de
añadir una columna nueva a la tabla.

### Decisión y alternativa descartada

Se descartó que `pack_web.bb` parsee `swarmforge.conf` directamente: `roles.tsv`
ya es la fuente de datos del dashboard y no conviene darle un segundo origen que
pueda desincronizarse.

## Cambio 2 — Barra de aprobación con aire

### Estado actual

`dashboard.html:29`:

```css
.attention{display:grid;grid-template-columns:auto 1fr;gap:8px 12px;
  padding:8px 14px;background:var(--amber-bg);border-bottom:1px solid #efd7a8;
  font-size:12px;max-height:120px;overflow:auto;position:relative;z-index:30}
```

El `max-height:120px` fijo es la causa: con más de una aprobación o
clarificación, todo se apiña y hay que scrollear en una franja mínima.

### Diseño

Sustituir el tope duro por uno relativo al viewport (del orden de `40vh`), de
modo que crezca con el contenido y solo scrollee cuando de verdad sea mucho.
Subir `font-size` y el `gap`/`padding` de las filas de aprobación y
clarificación. Mantener el `z-index:30` y el borde, que están bien.

## Cambio 3 — Las columnas reparten el ancho

### Estado actual

- `dashboard.html:61` — `.col{flex:0 0 auto;...}` → **las columnas no crecen**.
- `dashboard.html:63` — `.col-body{...width:max-content;min-width:var(--card-min-w)}`
- `dashboard.html:65` — `.card{...width:max-content;max-width:var(--card-max-w);
  min-width:var(--card-min-w);min-height:var(--card-min-h)}`
- `dashboard.html:8` — `--card-min-w:148px; --card-max-w:200px; --card-min-h:72px`

Con `flex:0 0 auto` y anchos por contenido, las columnas se quedan en su mínimo
y el espacio sobrante del `.columns` (línea 60) no se reparte.

### Diseño

Que las columnas compartan el ancho disponible (`flex:1 1 0` con un
`min-width` para que sigan siendo usables cuando hay muchas lanes), subir
`--card-max-w`, y que las tarjetas ocupen el ancho de su columna en vez de
`max-content`. Conservar `min-width:var(--card-min-w)` para que con muchas lanes
el board siga haciendo scroll horizontal en lugar de comprimirse hasta ser
ilegible.

Todo esto sale de las variables del `:root` y de tres reglas, así que es
reversible con facilidad.

## Cambio 4 — Repo y branch de la task

### Problema

El dashboard no dice sobre qué repositorio ni sobre qué rama trabaja la task.
Con varios swarms en paralelo no hay forma de saber si esa task toca
`concilia_docker` o `concilia_llm_docker`, ni de qué rama salió. Ya nos pasó
lanzar un swarm desde la base equivocada y no notarlo hasta mucho después.

### Diseño

`pack_web.bb` calcula el par a partir del worktree **master**, que es el árbol
del proyecto: los roles tienen su propia rama (`swarmforge-coder`, etc.), pero
lo que le interesa al operador es de dónde salió la task.

- `git remote get-url origin` → repo, recortado a `owner/repo`.
- `git rev-parse --abbrev-ref HEAD` → branch.

Ambas llamadas van envueltas en `git-line`, que devuelve `""` si git falla: el
dashboard no puede romperse porque el worktree todavía no exista. Se exponen
como `repo` y `branch` en `dashboard-state`, y se muestran en `pack-meta`,
junto a `master = …`.

No se añade estado nuevo: los datos salen de git en cada refresco.

## Verificación

1. `bb test` — cubre `roles.tsv` y el parseo. Recordar que
   `get-swarm-forge-copies-only-swarmforge-owned-paths` **falla sin red también
   en upstream limpio**; no es una regresión.
2. Los 14 tests de Playwright de `test/dashboard/dashboard.spec.js`, antes y
   después. Requieren `cd test/dashboard && npm install && npx playwright install chromium`.
3. Capturas antes/después de las tres zonas, para juicio visual del operador.
4. Comprobar con un `four-pack` real que el Work Queue muestra los tres
   providers y que el `architect` aparece como `default`.

## Riesgos

- **La novena columna de `roles.tsv`.** Analizado arriba: bajo riesgo, pero es
  el único cambio que sale del dashboard y toca un formato compartido. Si
  apareciera un consumidor estricto, la alternativa es que `pack_web.bb` parsee
  `swarmforge.conf`.
- **Iteración visual.** `pack_web.bb:819` sirve `dashboard.html` con `slurp` en
  cada petición, así que basta recargar el navegador. Ojo: cada proyecto usa su
  **copia descargada** en `swarmforge/scripts/pack/`; para iterar rápido se edita
  esa copia, y el cambio bueno se lleva al fork para que lo hereden los tickets
  nuevos.
- **Divergencia con upstream.** Los tres cambios tocan archivos que upstream
  mantiene activamente (`dashboard.html`, `pack_web.bb`, `swarmforge.bb`), así que
  suman conflicto potencial en el próximo rebase. Anotarlos en `FORK.md` al
  terminar, junto al resto de cambios propios.

## Fuera de alcance

Tema oscuro, reordenar el layout general del cockpit, y modularizar las 1245
líneas de JS de `dashboard.html`. Si el bloque de JS estorba al implementar el
cambio 1, se extrae solo lo que haga falta para ese cambio.
