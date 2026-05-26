# Plan — Issue #18 : Sous-titres (clôture)

## Context
L'issue #18 demandait l'intégration OpenSubtitles, la conversion SRT→VTT, un endpoint `/movies/:id/subtitles/:lang` et le cache. Toute l'implémentation est déjà présente dans les commits récents. Il reste des modifications uncommittées dans `MoviePlayer.tsx` à committer, puis l'issue doit être fermée.

## État actuel — tout est implémenté

| Critère | Fichier |
|---|---|
| OpenSubtitles API + `.env` | `api/torrent-service/src/services/subtitle.go` + `.env.example` |
| Recherche anglais automatique | `frontend/src/components/page/MoviePlayer.tsx` (l.140) |
| Langue préférée utilisateur | `MoviePlayer.tsx` (i18n.language, l.139) |
| Conversion SRT → VTT | `services/subtitle.go` → `srtToVTT()` |
| Endpoint GET `/movies/:id/subtitles/:lang` | `torrent-service/src/main.go:39` + `gateway/src/routes/torrent.go:30` |
| Cache disque `/data/subtitles/{id}/{lang}.vtt` | `services/subtitle.go` → `FetchSubtitle()` |

## Actions à effectuer

1. **Committer les modifications uncommittées** de `frontend/src/components/page/MoviePlayer.tsx`
   - Vérifier le diff pour s'assurer que les changements sont cohérents
   - Commit : `feat(subtitles): finalize subtitle injection in MoviePlayer`

2. **Fermer l'issue #18** via `gh issue close 18 --comment "..."` avec un commentaire listant tous les critères satisfaits

## Fichiers critiques
- `frontend/src/components/page/MoviePlayer.tsx` (modifié, uncommitted)
- `api/torrent-service/src/services/subtitle.go`
- `api/torrent-service/src/handlers/subtitle.go`
- `api/gateway/src/routes/torrent.go`

## Vérification
- Lancer `make` et tester un film → les sous-titres apparaissent automatiquement
- Vérifier que le fichier `.vtt` est créé dans `volumes/subtitles/{movieId}/`
