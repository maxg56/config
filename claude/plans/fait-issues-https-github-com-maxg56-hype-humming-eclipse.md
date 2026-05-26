# Plan: Issue #13 — Library Movie Search & Infinite Pagination

## Context

Issue #13 requests a `GET /movies` endpoint for the library-service that:
- Returns popular movies (sorted by seeders by default) with no query
- Supports full-text search with `?q=<search>`
- Supports filtering by genre, rating (min), and year
- Supports sorting by title, rating, or year
- Uses cursor-based pagination for infinite scroll
- Returns: title, year, rating, cover image, watched status

The gateway already proxies `GET /api/v1/library/movies` → library-service, but the library-service has no handler for the base `/movies` route (only `/movies/search`, `/movies/yts`, etc.).

**Primary data source**: YTS API (already wired) because it natively supports genre filter, minimum_rating, sort_by seeds/title/year/rating, and includes torrent availability. TMDb is kept for individual movie detail enrichment only.

**Watched status**: The library-service has no access to user identity (no user ID in request), so `watched` defaults to `false`. Full watch-history integration requires a separate issue.

---

## Implementation Plan

### 1. Extend YTS client — `api/library-service/src/client/yts.go`

Add a `ListParams` struct and a `List(params ListParams)` method that calls `list_movies.json` with all supported filters. Year filter is applied client-side (YTS has no year param) by stripping results where `Year != params.Year`.

```go
type ListParams struct {
    Query     string
    Genre     string
    MinRating float64
    Year      int    // applied client-side post-fetch
    SortBy    string // "seeds" | "title" | "year" | "rating" (maps to YTS sort_by)
    Page      int
}

// List fetches movies from YTS with optional filters and sorting.
func (c *YTSClient) List(p ListParams) (*models.SearchResult, error)
```

YTS `sort_by` mapping: `"title"→"title"`, `"rating"→"rating"`, `"year"→"year"`, default `"seeds"`.

### 2. Update ytsClient interface — `api/library-service/src/handlers/handler.go`

Add `List(p client.ListParams) (*models.SearchResult, error)` to the `ytsClient` interface.

### 3. Add CursorResult model — `api/library-service/src/models/movie.go`

```go
type CursorResult struct {
    Results    []Movie `json:"results"`
    NextCursor string  `json:"next_cursor,omitempty"`
    Total      int     `json:"total"`
}
```

Also add `Watched bool` field to `Movie` struct (default `false`).

### 4. New handler — `api/library-service/src/handlers/movies.go`

`Movies()` handler implementing:
- Parse params: `q`, `genre`, `rating` (float), `year` (int), `sort_by`, `cursor`
- Decode cursor: `base64(page_number)` → page int; default page=1
- Build cache key from all params
- Call `h.yts.List(params)`
- Build `CursorResult`: set `next_cursor = encodeCursor(page+1)` if more pages remain
- Cache result with `ytsCacheTTL` (1h)

Cursor helpers (in same file):
```go
func encodeCursor(page int) string  // base64(strconv.Itoa(page))
func decodeCursor(s string) int     // inverse; returns 1 on error
```

### 5. Register route — `api/library-service/src/main.go`

Add `movies.GET("", h.Movies)` before the `/:id` route.

---

## Files Modified

| File | Change |
|------|--------|
| `api/library-service/src/client/yts.go` | Add `ListParams` struct + `List()` method |
| `api/library-service/src/handlers/handler.go` | Add `List()` to `ytsClient` interface |
| `api/library-service/src/models/movie.go` | Add `CursorResult` struct + `Watched bool` to `Movie` |
| `api/library-service/src/handlers/movies.go` | **New file** — `Movies()` handler + cursor helpers |
| `api/library-service/src/main.go` | Register `GET ""` route |

Gateway (`api/gateway/src/routes/library.go`) already has the proxy route — no change needed.

---

## API Contract

### Request
```
GET /api/v1/library/movies
  ?q=inception        # optional search query
  &genre=Action       # optional genre filter
  &rating=7.0         # optional minimum rating (float)
  &year=2010          # optional year filter (client-side)
  &sort_by=seeds      # seeds | title | rating | year (default: seeds)
  &cursor=MQ==        # base64 page cursor (omit for first page)
```

### Response
```json
{
  "success": true,
  "data": {
    "results": [
      {
        "id": 123,
        "title": "Inception",
        "year": "2010",
        "rating": 8.8,
        "poster_url": "https://...",
        "genres": ["Sci-Fi"],
        "watched": false,
        "source": "yts"
      }
    ],
    "next_cursor": "Mg==",
    "total": 500
  }
}
```

---

## Verification

1. Start the library-service: `cd api/library-service && go run ./src/main.go`
2. Test popular movies (no query): `curl "localhost:8003/api/v1/library/movies"`
3. Test search: `curl "localhost:8003/api/v1/library/movies?q=inception"`
4. Test filters: `curl "localhost:8003/api/v1/library/movies?genre=Action&rating=7.0&year=2010"`
5. Test sort: `curl "localhost:8003/api/v1/library/movies?sort_by=rating"`
6. Test cursor: take `next_cursor` from response, add `&cursor=<value>` to next request
7. Test existing routes still work: `curl "localhost:8003/api/v1/library/movies/search?q=test"`
8. Run tests: `cd api/library-service && go test ./...`
