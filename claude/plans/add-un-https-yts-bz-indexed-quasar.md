# Plan: Intégration YTS.bz dans library-service

## Context

Hypertube est une app de streaming via torrent. La library-service fournit déjà les métadonnées films (TMDb + OMDb). YTS.bz expose une API publique (sans clé) qui retourne les films disponibles en torrent avec leurs liens magnet/hash. L'intégration de YTS enrichit chaque film avec les données torrent dont le torrent-service aura besoin pour streamer.

## Scope des changements

### 1. Nouveau modèle `Torrent` + enrichissement de `Movie`
**Fichier:** `api/library-service/src/models/movie.go`

Ajouter :
```go
type Torrent struct {
    URL     string `json:"url"`
    Hash    string `json:"hash"`
    Quality string `json:"quality"`
    Type    string `json:"type"`   // "bluray", "web"
    Size    string `json:"size"`
    Seeds   int    `json:"seeds"`
    Peers   int    `json:"peers"`
}
```

Dans `Movie`, ajouter deux champs :
```go
IMDbID   string    `json:"imdb_id,omitempty"`
Torrents []Torrent `json:"torrents,omitempty"`
```

---

### 2. Nouveau client YTS
**Fichier à créer:** `api/library-service/src/client/yts.go`

- Base URL: `https://yts.mx/api/v2/` (domaine officiel actuel de YTS.bz)
- Pas de clé API nécessaire — `Available()` retourne toujours `true`
- Timeout HTTP : 10 secondes

**Méthodes :**

`Search(query string, page int) (*models.SearchResult, error)`
→ GET `list_movies.json?query_term={q}&page={n}&limit=20&sort_by=seeds`
→ Retourne films avec `Torrents` inclus

`GetMovieByIMDbID(imdbID string) (*models.Movie, error)`
→ GET `list_movies.json?query_term={imdbID}&limit=1`
→ Utilisé pour enrichir un résultat TMDb avec les torrents YTS

**Réponse YTS (structure interne) :**
```
data.movies[].{id, title, year, rating, runtime, genres,
               medium_cover_image, large_cover_image,
               summary, imdb_code,
               torrents[].{url, hash, quality, type, size_bytes, seeds, peers}}
```

---

### 3. Mise à jour du client TMDb
**Fichier:** `api/library-service/src/client/tmdb.go`

Dans `tmdbDetailResponse`, ajouter `IMDbID string \`json:"imdb_id"\`` pour récupérer l'IMDB ID depuis TMDb.
Dans `GetMovie()`, mapper `IMDbID: raw.IMDbID` dans le `Movie` retourné.

---

### 4. Mise à jour des handlers
**Fichier:** `api/library-service/src/handlers/movie.go`

**`NewMovieHandler()`** : ajouter `yts *client.YTSClient`

**`GetMovie()`** — après avoir récupéré le film via TMDb :
1. Si `movie.IMDbID != ""`, appeler `h.yts.GetMovieByIMDbID(movie.IMDbID)`
2. Si YTS retourne des torrents, les attacher à `movie.Torrents`
3. Mettre en cache le résultat enrichi (clé `movie:{id}` — inchangée)

**Nouveau handler `SearchYTS()`** pour `GET /api/v1/library/movies/yts?q=&page=` :
1. Vérifie param `q`
2. Cache key : `yts:search:{q}:page:{n}` (TTL 1h — les seeds changent fréquemment)
3. Appelle `h.yts.Search(query, page)`
4. Retourne `SearchResult` avec torrents inclus

---

### 5. Mise à jour des routes
**Fichier:** `api/library-service/src/main.go`

Ajouter :
```go
movies.GET("/yts", h.SearchYTS)
```

La route `/:id` existante est automatiquement enrichie grâce au changement du handler `GetMovie`.

---

## Clés de cache Redis

| Endpoint | Clé | TTL |
|---|---|---|
| `GET /movies/:id` (enrichi) | `movie:{tmdb_id}` | 24h (inchangé) |
| `GET /movies/yts?q=` | `yts:search:{q}:page:{n}` | 1h (seeds varient) |

---

## Fichiers modifiés

| Fichier | Action |
|---|---|
| `src/models/movie.go` | Ajouter `Torrent`, `IMDbID`, `Torrents` dans `Movie` |
| `src/client/tmdb.go` | Ajouter `imdb_id` dans la réponse détail |
| `src/client/yts.go` | **Créer** le client YTS complet |
| `src/handlers/movie.go` | Enrichir `GetMovie`, ajouter `SearchYTS` |
| `src/main.go` | Enregistrer la route `/movies/yts` |

---

## Vérification

1. `go build ./src/...` — compilation sans erreur
2. Avec Docker : `docker compose -f docker-compose.dev.yml up --build library-service`
3. Test search YTS : `curl "http://localhost:8000/api/v1/library/movies/yts?q=inception" -H "Authorization: Bearer <token>"`
   → Réponse avec `torrents[{hash, quality, seeds, ...}]`
4. Test enrichissement : `curl "http://localhost:8000/api/v1/library/movies/27205"` (Inception TMDb ID)
   → Réponse contient `imdb_id` + `torrents` si disponibles sur YTS
