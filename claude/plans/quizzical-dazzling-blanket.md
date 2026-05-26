# Plan: Available Subtitle Languages Endpoint + UI Indicator

## Context

The subtitle language selector (already implemented) always shows all 8 language buttons, but has no way to know which languages are actually available (cached on disk) for a given movie. The user wants a backend endpoint that returns the list of cached subtitle languages, and the frontend should use it to visually distinguish available languages from ones that still need to be fetched.

---

## Backend — New endpoint

### `GET /api/v1/movies/:id/subtitles`

Returns the list of language codes for which a `.vtt` file is already cached on disk for this movie.

**New handler** `handlers/subtitle.go` — add `SubtitleAvailableHandler`:

```go
func SubtitleAvailableHandler(c *gin.Context) {
    movieID, err := strconv.Atoi(c.Param("id"))
    if err != nil || movieID <= 0 {
        utils.RespondError(c, http.StatusBadRequest, "invalid movie id")
        return
    }

    dir := filepath.Join(services.SubtitleCacheDirPublic(), fmt.Sprintf("%d", movieID))
    entries, err := os.ReadDir(dir)
    if err != nil {
        // directory doesn't exist = no cached subtitles
        utils.RespondSuccess(c, http.StatusOK, map[string]interface{}{"languages": []string{}})
        return
    }

    langs := []string{}
    for _, e := range entries {
        if !e.IsDir() && strings.HasSuffix(e.Name(), ".vtt") {
            langs = append(langs, strings.TrimSuffix(e.Name(), ".vtt"))
        }
    }
    utils.RespondSuccess(c, http.StatusOK, map[string]interface{}{"languages": langs})
}
```

**Expose cache dir** in `services/subtitle.go` — add a public wrapper:

```go
func SubtitleCacheDirPublic() string { return subtitleCacheDir() }
```

**Register route** in `torrent-service/src/main.go` — add BEFORE the `:lang` route (Gin matches in order):

```go
movies.GET("/:id/subtitles", handlers.SubtitleAvailableHandler)
movies.GET("/:id/subtitles/:lang", handlers.SubtitleHandler)
```

**Gateway** `api/gateway/src/routes/torrent.go` — add:

```go
movies.GET("/:id/subtitles", proxy.ProxyRequest("torrent", "/api/v1/movies/:id/subtitles"))
```

---

## Frontend — Use availability in MoviePlayer

### Changes to `frontend/src/components/page/MoviePlayer.tsx`

1. Add state:
   ```ts
   const [availableLangs, setAvailableLangs] = useState<string[] | null>(null)
   ```

2. Add `useEffect` on `state === 'streaming'` to fetch available langs:
   ```ts
   useEffect(() => {
     if (state !== 'streaming') return
     void fetch(`/api/v1/movies/${movieId}/subtitles`, { credentials: 'include' })
       .then(r => r.ok ? r.json() : null)
       .then(json => {
         const langs = (json?.data ?? json)?.languages ?? []
         setAvailableLangs(langs)
       })
       .catch(() => setAvailableLangs([]))
   }, [state, movieId])
   ```

3. In the subtitle selector UI, mark cached languages visually:
   - Available (in `availableLangs`): full opacity + small green dot indicator
   - Not cached yet: slightly muted, no dot
   - Both are still clickable (fetching on demand stays intact)

4. After a subtitle is successfully loaded (in the subtitle `useEffect`), add the lang to `availableLangs`:
   ```ts
   setAvailableLangs(prev => prev ? [...new Set([...prev, subLang])] : [subLang])
   ```

---

## Files to modify

| File | Change |
|---|---|
| `api/torrent-service/src/handlers/subtitle.go` | Add `SubtitleAvailableHandler` |
| `api/torrent-service/src/services/subtitle.go` | Export `SubtitleCacheDirPublic()` |
| `api/torrent-service/src/main.go` | Register new GET `/:id/subtitles` route (before `:lang`) |
| `api/gateway/src/routes/torrent.go` | Proxy new route |
| `frontend/src/components/page/MoviePlayer.tsx` | Fetch availability, show dot on cached langs |

---

## Verification

1. Start the app
2. Open a movie page where no subtitles are cached → all subtitle buttons show without the dot
3. Click a language → loading spinner → subtitle loads → that language button now shows the green dot
4. Refresh the page → same movie → the previously loaded language already has the dot (served from cache)
5. Check `GET /api/v1/movies/{id}/subtitles` directly → returns `{"data": {"languages": ["en"]}}` etc.
