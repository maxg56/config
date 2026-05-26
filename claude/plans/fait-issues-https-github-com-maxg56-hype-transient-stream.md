# Plan — Issue #16: HTTP byte-range streaming depuis fichier torrent

## Context

The torrent-service already has a working `StreamHandler` in `stream.go` that uses `http.ServeContent()` — the standard library function that automatically handles `Range: bytes=X-Y` headers and returns `206 Partial Content`. The anacrolix reader (`reader.go`) supports seeking and blocks on missing pieces during in-progress downloads. The gateway proxy correctly forwards Range headers and streams 206 responses without buffering.

Two gaps remain before the acceptance criteria are fully met:

1. **MIME type reliability**: `mime.TypeByExtension()` reads the OS MIME database. On Linux containers, `.mkv` is rarely registered, so `ServeContent` would sniff the binary content and return `application/octet-stream`, which breaks some HTML5 `<video>` players.

2. **No tests for the happy path**: `handlers_test.go` covers error branches (not found, pending, error, missing file) but not the success path — no test verifies 200 OK with correct headers, nor a Range request returning 206 with `Content-Range`.

---

## Implementation

### 1. Register MIME types at startup
**File**: `api/torrent-service/src/main.go`

Add an `init()` function (or inline in `main()` before the router) that registers common video extensions:

```go
import "mime"

func init() {
    mime.AddExtensionType(".mkv",  "video/x-matroska")
    mime.AddExtensionType(".webm", "video/webm")
    mime.AddExtensionType(".mp4",  "video/mp4")
    mime.AddExtensionType(".avi",  "video/x-msvideo")
    mime.AddExtensionType(".mov",  "video/quicktime")
    mime.AddExtensionType(".ogg",  "video/ogg")
    mime.AddExtensionType(".m4v",  "video/mp4")
}
```

`mime.AddExtensionType` is safe to call multiple times (idempotent) and overrides OS entries with the correct value.

### 2. Remove the redundant manual `Content-Type` header in stream.go
**File**: `api/torrent-service/src/handlers/stream.go`

The current code sets `Content-Type` manually (lines 46-51) and then calls `http.ServeContent()`, which sets it again using its own MIME detection. After step 1, both will agree — but the manual call is redundant and can be removed. Keep only:
- `Accept-Ranges: bytes` (required for some players to send Range requests)
- `X-Content-Length` (consumed by the frontend)

```go
// Remove:
contentType := mime.TypeByExtension(filepath.Ext(result.FileName))
if contentType == "" {
    contentType = "application/octet-stream"
}
c.Header("Content-Type", contentType)

// Keep:
c.Header("Accept-Ranges", "bytes")
if result.Size > 0 {
    c.Header("X-Content-Length", fmt.Sprint(result.Size))
}
http.ServeContent(c.Writer, c.Request, result.FileName, time.Time{}, result.Reader)
```

Also remove the unused `mime`, `path/filepath` imports if no longer needed.

### 3. Add tests for the success path and Range requests
**File**: `api/torrent-service/src/handlers/handlers_test.go`

Add a helper that creates a temp file with known content and inserts a `StatusReady` DB record pointing to it. Then add:

**`TestStreamHandler_Ready_Success`**
- Creates temp `.mp4` file with 100 bytes of content
- Inserts DB record with `Status: StatusReady, FilePath: <tempfile>, FileSize: 100`
- GET `/api/v1/stream/<hash>` without Range header
- Asserts: status 200, `Accept-Ranges: bytes` header present, body length = 100

**`TestStreamHandler_Range_PartialContent`**
- Same temp file setup
- GET `/api/v1/stream/<hash>` with `Range: bytes=0-9`
- Asserts: status 206, `Content-Range: bytes 0-9/100`, body = first 10 bytes

**`TestStreamHandler_MimeType`**
- One sub-test per extension: `.mkv` → `video/x-matroska`, `.webm` → `video/webm`, `.mp4` → `video/mp4`
- Creates temp file with the right extension
- Asserts `Content-Type` header in response

---

## Critical Files

| File | Change |
|------|--------|
| `api/torrent-service/src/main.go` | Add `init()` with `mime.AddExtensionType` calls |
| `api/torrent-service/src/handlers/stream.go` | Remove redundant Content-Type manual set; remove unused imports |
| `api/torrent-service/src/handlers/handlers_test.go` | Add 3 new test functions for happy path + Range |

Files that do **not** need changes: `reader.go`, `monitor.go`, `proxy/proxy.go` — all already correct.

---

## Verification

```bash
cd api/torrent-service
go test ./src/handlers/... -v -run "TestStream"
go test ./src/... -count=1
```

Manual end-to-end (requires running stack):
1. POST a magnet to `/api/v1/torrent/download`
2. Poll `/api/v1/torrent/status/<hash>` until `downloading`
3. Open `<video src="/api/v1/stream/<hash>">` in Firefox and Chrome
4. Seek forward — verify no buffering hang (piece prioritization)
5. `curl -v -H "Range: bytes=0-1048575" http://localhost:8080/api/v1/stream/<hash>` → expect `HTTP/1.1 206`, `Content-Range: bytes 0-1048575/<total>`
