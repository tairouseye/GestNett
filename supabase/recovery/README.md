# supabase/recovery — scripts de reconstruction (DESTRUCTIFS)

⚠️ **Les fichiers de ce dossier ne sont PAS des migrations.** Ils ne doivent
jamais être rangés dans `supabase/migrations/` ni exécutés dans le cadre d'un
déploiement normal.

## `DANGER_rebuild_gespro_DROP_SCHEMA.sql`

Reconstruit *toute* la structure du schéma `public` à partir de zéro. Il
commence par :

```sql
drop schema if exists public cascade;
```

→ **Cela efface TOUTES les données** (clients, marchés, factures, paiements,
dépenses, employés, etc.). `auth.users` et le Storage ne sont pas touchés.

### Quand l'utiliser

Uniquement pour :
- reconstruire une base **vide** (nouveau projet), ou
- une reprise après **perte totale** de données.

### Avant de l'exécuter — vérifier impérativement

1. Que le projet ciblé est bien `dksowmyytsiubnnbmyfo` (GesPro) **et pas** un
   autre projet partagé (cf. incident de perte de données passé).
2. Qu'aucune donnée à conserver n'existe (faire une sauvegarde sinon).
3. Que c'est réellement l'action voulue.

### Cohérence avec les migrations

Ce script inline les migrations `001 → 016` + correctifs. Les migrations
postérieures (passage des buckets en privé `017`, contrainte statut `018`)
sont soit déjà reflétées inline, soit hors périmètre (le storage n'est pas
recréé par ce script). En cas d'ajout de nouvelles migrations, **penser à les
reporter ici** pour qu'un rebuild reste fidèle à la prod.
