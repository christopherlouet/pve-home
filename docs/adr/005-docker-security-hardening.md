# ADR-005: Hardening Docker systematique

## Statut

Accepted

## Contexte

Les stacks monitoring et tooling deploient 20 conteneurs Docker. Sans hardening, un conteneur compromis pourrait escalader ses privileges ou acceder au host.

## Decision

Appliquer systematiquement les mesures de securite Docker suivantes a **tous** les conteneurs :

1. **`security_opt: no-new-privileges:true`** : Empeche l'escalade de privileges
2. **`cap_drop: ALL`** : Supprime toutes les capabilities Linux
3. **`cap_add`** : Reattribue uniquement les capabilities necessaires (ex: PostgreSQL)
4. **`read_only: true`** : Filesystem en lecture seule avec tmpfs pour /tmp
5. **Images versionnees** : Pas de tag `:latest`, version explicite (ex: `v3.5.1`)
6. **`restart: unless-stopped`** : Resilience sans redemarrage apres arret manuel
7. **User non-root** : Quand supporte (Prometheus: 65534, Grafana: 472)

Tests BATS validant ces contraintes pour chaque service.

## Consequences

### Positif

- **Defense en profondeur** : Multiple couches de securite
- **Conformite** : Aligne avec CIS Docker Benchmark
- **Testable** : BATS verifie la presence de chaque directive
- **Pas de :latest** : Reproductibilite des deployements

### Negatif

- **Complexite initiale** : Identifier les capabilities necessaires par service
- **Debugging** : `read_only` peut casser certains conteneurs qui ecrivent dans /var/run
- **Mises a jour** : Les versions doivent etre mises a jour manuellement

## Exceptions documentees

- **harbor-db, authentik-db** : Necessitent CHOWN, SETUID, SETGID, FOWNER (PostgreSQL)
- **authentik-redis** : Necessite SETUID, SETGID
- **node-exporter** : Necessite `pid: host` pour les metriques CPU
- **promtail** : Necessite l'acces au Docker socket (lecture)
