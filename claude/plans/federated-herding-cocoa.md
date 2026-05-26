# Plan: Movie Detail Page + Video Player (Issue #25)

## Context
Implement the movie detail page with an integrated HTML5 video player, torrent streaming flow, and comment section. The page lives at `/movies/[id]` (TMDB movie ID). The backend already exposes all necessary endpoints: library for metadata, torrent-service for download/stream, comment-service for CRUD.

---

## Architecture Overview

```
/movies/[id]/page.tsx         ← Server Component: fetch movie details, render layout
  └── MoviePlayer.tsx          ← Client Component: torrent download, polling, <video>
  └── CommentSection.tsx       ← Client Component: list + post comments
```

---

## Files to Create

### 1. `src/app/(main)/movies/[id]/page.tsx`
Server Component. Fetches `GET /api/v1/library/movies/:id` (with auth cookie). Renders:
- Backdrop image (full-width header)
- Poster + metadata: title, year, runtime (formatted as "Xh Ym"), rating (⭐ X.X), genres pills, overview paragraph
- Cast section: horizontal scroll of cast cards (name + character)
- `<MoviePlayer>` client component with `torrents` and `movieId` props
- `<CommentSection>` client component with initial `comments` and `movieId` props

If movie not found → redirect to `/` or show 404.

### 2. `src/components/page/MoviePlayer.tsx`
Client Component (`'use client'`). Props: `torrents: Torrent[]`, `movieId: number`.

**State machine:**
- `idle` → user selects quality + clicks "Watch"
- `downloading` → POST `/api/v1/torrent/download` → get `info_hash`, poll `/api/v1/torrent/status/:hash` every 2s
- `streaming` → status is `"downloading"` with progress > 0, or `"completed"` → set `<video src="/api/v1/stream/:hash">`
- `error` → show error message

**UI:**
- Quality selector: buttons for each torrent (e.g. "720p BluRay", "1080p")
- "Watch" button
- Progress bar + percentage during `downloading`
- Native `<video>` element with `controls`, `preload="metadata"`, `crossOrigin="use-credentials"` when `streaming`
- `<track>` for VTT subtitles if subtitle endpoint is available (currently 501 — render conditionally)

**Polling logic:** `useEffect` with `setInterval(2000)` while status ∈ `{pending, downloading}`. Transition to `streaming` as soon as status is `downloading` (stream starts serving partial file).

### 3. `src/components/page/CommentSection.tsx`
Client Component. Props: `movieId: number`, `initialComments: Comment[]`.

- Lists comments (avatar, username, content, date) with `useOptimistic` or local state
- Form: `<textarea>` + submit button
- `POST /api/v1/comments/:movieId` with `credentials: 'include'`
- Refresh comments after successful post
- Delete button shown only for own comments (compare `comment.user_id` with current user — fetch from `/api/v1/user/me` or pass as prop from server)

---

## Files to Modify

### 4. `src/components/page/MovieCard.tsx`
- Wrap card in `<Link href={/movies/${movie.id}}>` (Next.js Link)
- Remove `onClick={onToggle}` and `onToggle` prop (watched state tracked by backend)
- Keep `watched` prop for visual greyscale/opacity (still useful for display)
- Update `MovieCardProps` accordingly

### 5. `src/components/page/Thumbnails.tsx`
- Remove `onToggle` call since MovieCard no longer needs it
- Keep `watched` local state for display (can keep toggling for UX, just don't pass toggle handler to card)
- Or simplify: remove watched tracking entirely (backend does it)

### 6. `src/locales/fr.json` + `src/locales/en.json`
Add keys under `"movie"` namespace:
```json
"movie": {
  "watch": "Regarder",
  "select_quality": "Choisir la qualité",
  "loading": "Chargement…",
  "progress": "Téléchargement {{percent}}%",
  "error_stream": "Erreur lors du lancement du stream",
  "runtime": "{{hours}}h {{minutes}}m",
  "no_torrents": "Aucun torrent disponible",
  "comments_title": "Commentaires",
  "comment_placeholder": "Ajouter un commentaire…",
  "comment_submit": "Publier",
  "comment_submitting": "Publication…",
  "comment_delete": "Supprimer",
  "back": "Retour"
}
```

---

## API Calls Summary

| Purpose | Method | URL |
|---|---|---|
| Movie details | GET | `/api/v1/library/movies/:id` |
| Start torrent | POST | `/api/v1/torrent/download` body: `{magnet_uri, movie_id}` |
| Poll status | GET | `/api/v1/torrent/status/:hash` |
| Stream video | GET | `/api/v1/stream/:hash` (set as `<video src>`) |
| List comments | GET | `/api/v1/comments/:movieId` |
| Post comment | POST | `/api/v1/comments/:movieId` body: `{content}` |
| Delete comment | DELETE | `/api/v1/comments/:id` |

---

## Movie Detail Response Shape (from library-service)
```ts
interface MovieDetail {
  id: number
  imdb_id: string
  title: string
  year: string
  release_date: string
  overview: string
  runtime: number          // minutes
  rating: number
  poster_url: string
  backdrop_url: string
  genres: string[]
  cast: { name: string; character: string; order: number }[]
  torrents: { url: string; hash: string; quality: string; type: string; size: string; seeds: number; peers: number; magnet: string }[]
  comments: Comment[]
  watched: boolean
}
```

---

## Verification
1. `docker compose -f docker-compose.dev.yml up --build frontend` — rebuild frontend
2. Navigate to `http://localhost:8000` → click a movie card → should route to `/movies/:id`
3. Movie detail page shows backdrop, metadata, cast
4. Select a torrent quality → click Watch → download initiates → progress shows
5. Video starts playing once download begins
6. Comments section shows existing comments; post a new one and verify it appears
7. Test on mobile viewport (Chrome DevTools)
8. Test Firefox + Chrome compatibility for `<video>`
