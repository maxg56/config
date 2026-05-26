# Plan : Fix sous-titres + extraction depuis torrents

## Contexte

Les sous-titres ne se téléchargent pas. Le bug principal est dans le frontend : `useSubtitleTracks` vérifie d'abord les langues déjà en cache (`GET /api/v1/movies/:id/subtitles`), et si la liste est vide, il abandonne immédiatement sans jamais tenter de télécharger depuis OpenSubtitles. La route `/api/v1/movies/:id/subtitles/:lang` — qui déclenche le téléchargement depuis OpenSubtitles si pas en cache — n'est donc jamais appelée.

Par ailleurs, certains torrents contiennent déjà des fichiers de sous-titres (`.srt`, `.vtt`, `.ass`) qui sont actuellement ignorés. L'objectif est de combiner les deux sources : sous-titres extraits du torrent + OpenSubtitles en fallback.

---

## Changements prévus

### 1. Fix frontend — `frontend/src/hooks/useSubtitleTracks.ts`

**Problème :** Si `available.length === 0`, le hook fait `setStatus('none')` et stoppe. Il ne tente jamais de télécharger.

**Fix :** Quand la liste cache est vide, construire une liste de langues à essayer (`userLang` + `"en"`, dédupliqués). Appeler `/subtitles/:lang` pour chacune — le backend téléchargera depuis OpenSubtitles si pas en cache. Si au moins une réussit → `'available'`, sinon → `'none'`.

```ts
// Avant :
if (available.length === 0) { setStatus('none'); return }

// Après :
const toFetch = available.length > 0
  ? available
  : [...new Set([userLang, 'en'])]
```

Puis itérer sur `toFetch` au lieu de `available`.

---

### 2. Extraction des sous-titres depuis le torrent — `api/torrent-service/src/services/subtitle.go`

Ajouter une nouvelle fonction `ExtractTorrentSubtitles(t *torrent.Torrent, tmdbID int)` qui :

1. Itère sur `t.Files()` pour trouver les fichiers avec extensions `.srt`, `.vtt`, `.ass`, `.ssa`, `.sub`
2. Détecte la langue depuis le nom du fichier (ex. `movie.en.srt`, `English.srt`, `Subs/fr.srt`)
3. Lit le contenu via `f.NewReader()`
4. Convertit vers VTT selon le format source :
   - `.srt` → `srtToVTT()` (déjà existant)
   - `.vtt` → copie directe
   - `.ass`/`.ssa` → nouveau `assToVTT()` basique (strip styles, convertir timing)
5. Sauvegarde dans `/data/subtitles/{tmdbID}/{lang}.vtt` (écrase uniquement si pas déjà présent)

**Détection de langue** — mapping `strings.ToLower(nomFichier)` :
- `"en"`, `"eng"`, `"english"` → `"en"`
- `"fr"`, `"fra"`, `"fre"`, `"french"`, `"francais"` → `"fr"`
- `"es"`, `"spa"`, `"spanish"` → `"es"`
- `"de"`, `"deu"`, `"ger"`, `"german"` → `"de"`
- etc. (langues principales)
- Si non reconnu et fichier unique → utiliser `"und"` (undetermined) ou ignorer

---

### 3. Appel post-download — `api/torrent-service/src/services/monitor.go`

Dans `monitorTorrent`, après la mise à jour `StatusReady` :

```go
// Lookup tmdb_id depuis le local movie_id
var movie models.Movie
conf.DB.Where("id = ?", record.MovieID).First(&movie)
if movie.TmdbID > 0 {
    go ExtractTorrentSubtitles(t, movie.TmdbID)
}
```

Lancer en goroutine pour ne pas bloquer. L'extraction ne bloque pas le streaming.

---

## Flux combiné résultant

```
User ouvre le player
  → useSubtitleTracks démarre
  → GET /subtitles → liste cache (peut être vide ou populée depuis extraction torrent)
  → Si vide : essaie userLang + "en"
  → Si non vide : essaie toutes les langues listées
  → Pour chaque lang : GET /subtitles/:lang
      → cache hit → sert directement
      → cache miss → FetchSubtitle → OpenSubtitles → télécharge → convertit → cache → sert
```

---

## Fichiers à modifier

| Fichier | Changement |
|---|---|
| `frontend/src/hooks/useSubtitleTracks.ts` | Ne plus abandonner si cache vide, essayer userLang + "en" |
| `api/torrent-service/src/services/subtitle.go` | Ajouter `ExtractTorrentSubtitles`, `assToVTT`, `detectLangFromPath` |
| `api/torrent-service/src/services/monitor.go` | Appeler `ExtractTorrentSubtitles` après `StatusReady` |

---

## Vérification

1. Lancer le stack avec `make`
2. Ouvrir un film qui a un torrent déjà téléchargé avec des `.srt` inclus → les sous-titres apparaissent sans appel OpenSubtitles
3. Ouvrir un film sans sous-titres en cache → les sous-titres se téléchargent depuis OpenSubtitles (vérifier logs du torrent-service)
4. Vérifier que l'indicateur de sous-titres disparaît quand ils sont chargés
5. Vérifier le bon comportement quand OpenSubtitles renvoie une erreur (status `'none'` affiché)
