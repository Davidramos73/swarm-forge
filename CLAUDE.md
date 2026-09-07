# CLAUDE.md

## Este repo es un fork

Fork de [`unclebob/swarm-forge`](https://github.com/unclebob/swarm-forge), con
soporte propio para el backend **opencode** y un adaptador de **GNOME Terminal**.

**Nunca sincronices con el botón "Sync fork" de GitHub.** Resetea la rama a
upstream y borra los commits propios; ya ocurrió una vez. Sincroniza siempre
así:

```sh
git fetch upstream && git rebase upstream/main && git push origin main
```

Si el rebase reescribió commits ya publicados, `git push --force-with-lease`,
nunca `--force` a secas. Antes de empezar: `git stash -u` y una rama de
respaldo.

Ver **[FORK.md](FORK.md)** para el procedimiento completo, la lista de cambios
propios y dónde suelen caer los conflictos.

## Punteros al repositorio

Los ficheros que descargan código (`get-swarm-forge`, los wrappers `./swarm`)
apuntan a este fork a propósito, para que las instalaciones traigan opencode.
No los revuelvas a unclebob.

Pero **las referencias a los otros repos de unclebob no se tocan**: `crap4clj`,
`dry4clj`, `clj-mutate`, `mutate4go`, `crap4go`, `dry4go`, `crap4java`,
`dry4java`, `mutate4java`, `speclj-structure-check` y
`Acceptance-Pipeline-Specification` son herramientas suyas, no este proyecto.

## Tests

`bb test`. El fallo de `get-swarm-forge-copies-only-swarmforge-owned-paths` es
preexistente: necesita red y también falla en upstream limpio. No lo persigas.

## Prompts

Ver [AGENTS.md](AGENTS.md): no se testea el texto de los prompts con tests
automáticos.
