# Plan: Torrent Service — Issue #15

## Context
Implement a BitTorrent download + streaming server in `torrent-service` (port 8004) using `anacrolix/torrent`. The service is currently a bare stub with only a `/health` endpoint and no external dependencies. The feature enables: on-demand torrent download triggered by the first user request, non-blocking simultaneous streaming from the first downloaded pieces, and persistent state in PostgreSQL.

---

## Files to Create / Modify

| Path | Action |
|------|--------|
| `api/torrent-service/go.mod` | Update — add anacrolix/torrent, Gin, GORM |
| `api/torrent-service/src/main.go` | Replace stub |
| `api/torrent-service/src/conf/db.go` | Create |
| `api/torrent-service/src/models/torrent.go` | Create |
| `api/torrent-service/src/types/request_types.go` | Create |
| `api/torrent-service/src/services/torrent_manager.go` | Create — core logic |
| `api/torrent-service/src/handlers/download.go` | Create |
| `api/torrent-service/src/handlers/status.go` | Create |
| `api/torrent-service/src/handlers/stream.go` | Create |
| `api/torrent-service/src/utils/response.go` | Create |
| `api/gateway/src/proxy/proxy.go` | Modify — streaming proxy for `/stream/` routes |

---

## Database

The `torrents` table already exists (`services/database/05_torrent_tables.sql`):
- `movie_id INT NOT NULL REFERENCES movies(id)` — caller **must** provide a valid movie_id
- `info_hash VARCHAR(64) UNIQUE NOT NULL`
- `status torrent_status_enum` — pending / downloading / ready / error
- `file_path TEXT`, `file_size BIGINT`, `downloaded BIGINT`, `progress NUMERIC(5,2)`
- `error_msg TEXT`

No migration needed — DB is pre-created by the SQL init scripts.

---

## go.mod Dependencies

```
github.com/anacrolix/torrent v1.56.1
github.com/gin-gonic/gin     v1.10.1
gorm.io/driver/postgres      v1.6.0
gorm.io/gorm                 v1.30.1
```

Run `go mod tidy` after editing go.mod.

---

## API Endpoints

Routes already registered in gateway (`api/gateway/src/routes/torrent.go`):

### `POST /api/v1/torrent/download`
**Request:** `{ "magnet_uri": "magnet:?xt=...", "movie_id": 42 }`  
**Response:** `202 Accepted` — `{ "info_hash": "abc...", "status": "downloading", "message": "..." }`  
**Logic:**
1. Validate magnet URI by parsing with anacrolix
2. Extract info_hash (lowercase hex)
3. Idempotency: check `activeTorrents` sync.Map, then DB — return existing if found
4. DB upsert with status `pending`
5. `client.AddMagnet(magnetURI)` (or `AddTorrentFromFile` for `.torrent` URLs)
6. Store in `activeTorrents`, launch `go monitorTorrent()`
7. Return 202 with info_hash

### `GET /api/v1/torrent/status/:id`
**Response:** `{ "info_hash", "status", "progress", "downloaded_bytes", "file_size_bytes", "error" }`  
**Logic:** SELECT from DB by info_hash — DB is single source of truth, updated every 5s by monitor goroutine.

### `GET /api/v1/stream/:id`
**Logic:**
1. Look up DB by info_hash
2. If `pending` → `202 Retry-After: 5`
3. If `error` → `503`
4. Call `GetTorrentReader(hash)` → `(io.ReadSeeker, int64, error)`
5. `http.ServeContent(w, r, filename, modtime, reader)` — handles Range/206 automatically

---

## Core Service: `torrent_manager.go`

### Singleton client init
```go
cfg := torrent.NewDefaultClientConfig()
cfg.DataDir = os.Getenv("TORRENT_DOWNLOAD_PATH")          // /data/torrents
cfg.DefaultStorage = storage.NewFileByInfoHash(downloadPath) // subdirs by hash
cfg.Seed = false
client, err = torrent.NewClient(cfg)
```
On startup, `reattachPendingTorrents()` re-adds any `status IN ('pending','downloading')` records from DB.

### `monitorTorrent(t *torrent.Torrent, record *models.TorrentRecord)`
1. `select { case <-t.GotInfo(): ... case <-time.After(2*time.Minute): }` — timeout → status `error`
2. `t.DownloadAll()` then `prioritizeForStreaming(t)`
3. Update DB status → `downloading`, set `file_size`
4. Ticker every 5s: update `downloaded`, `progress`
5. Stale watchdog: if no progress for 10 minutes → status `error`
6. On `t.Complete`: update DB status → `ready`, set `file_path`

### `prioritizeForStreaming(t *torrent.Torrent)`
- Find largest file (video file heuristic for YTS single-file torrents)
- Set first ~5 MB of pieces to `PiecePriorityNow`, rest to `PiecePriorityNormal`
- Called again from stream handler when player seeks to a new offset

### `GetTorrentReader(hash string) (io.ReadSeeker, int64, error)`
- **Downloading**: load from `activeTorrents`, find largest file, `file.NewReader()` — blocks on missing pieces naturally
- **Completed**: `os.Open(record.FilePath)` — reads directly from disk

### Concurrency
- Each streaming client calls `file.NewReader()` independently — anacrolix handles concurrent piece sharing
- `sync.Map` for `activeTorrents` (goroutine-safe)
- DB UNIQUE constraint on `info_hash` prevents duplicate inserts on race

---

## Gateway Fix: Streaming Proxy

**Problem:** `copyResponse` in `proxy.go:122` uses `io.ReadAll` (buffers entire video in memory) and the HTTP client has a 30-second timeout — both break streaming.

**Fix:** Detect stream routes (path starts with `/api/v1/stream/`) and use a dedicated streaming proxy:
- Remove `Timeout` from the HTTP client for stream requests (use `http.Client{Timeout: 0}` or context with no deadline)
- Replace `io.ReadAll` + `c.Data` with `io.Copy(c.Writer, resp.Body)` and flush progressively
- Copy response headers (especially `Content-Range`, `Accept-Ranges`, `Content-Length`) before streaming body

---

## Error Cases

| Scenario | Behaviour |
|----------|-----------|
| Invalid magnet URI | 400 immediately from `AddMagnet` parse error |
| No seeders / peers | `GotInfo()` never fires → 2-min timeout → status `error`, message "info timeout" |
| Disk full | Progress stalls for 10 min → status `error` |
| Duplicate request | Idempotent — returns existing hash + current status |
| Process restart | `reattachPendingTorrents()` resumes in-flight downloads |

---

## Verification

1. `docker compose -f docker-compose.dev.yml up torrent-service` — service starts, `/health` returns 200
2. `POST /api/v1/torrent/download` with a valid YTS magnet URI and a valid `movie_id`
3. Poll `GET /api/v1/torrent/status/:hash` — watch `progress` increase
4. Once status is `downloading` (or `ready`), open `GET /api/v1/stream/:hash` in VLC/browser — video plays from the start with seeking supported
5. Open two simultaneous stream connections to the same hash — both play without interference
6. Provide an invalid magnet → expect 400
7. Provide a magnet with no seeders → after ~2 min, status should be `error`
