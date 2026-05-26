# Plan : Refactoring MoviePlayer

## Contexte
`MoviePlayer.tsx` mélange logique métier (polling torrent, gestion d'état), présentation (placeholder, boutons qualité) et hooks d'effets secondaires dans un seul fichier de 274 lignes. La page `movies/[id]/page.tsx` embarque aussi du JSX inline non réutilisable (hero, casting). L'utilisateur veut séparer tout ça en composants indépendants dans un dossier `components/Player/`.

## Structure cible

```
src/
  hooks/
    useTorrentStream.ts          ← NOUVEAU : toute la logique polling/état torrent
  components/
    Player/                      ← NOUVEAU dossier (capital P)
      MoviePlayer.tsx            ← orchestrateur slim (~50 lignes)
      PlayerPlaceholder.tsx      ← états idle/checking/downloading/error
      TorrentButton.tsx          ← bouton badge qualité individuel
      TorrentSelector.tsx        ← rangée boutons + bouton Regarder
      SubtitleIndicator.tsx      ← indicateur "aucun sous-titre"
    page/
      MovieHero.tsx              ← NOUVEAU : backdrop + poster + titre + meta + actions
      MovieCast.tsx              ← NOUVEAU : section casting
      MoviePlayer.tsx            ← SUPPRIMÉ (remplacé par Player/MoviePlayer.tsx)
      player/                    ← SUPPRIMÉ (dossier vide résiduel)
  app/(main)/movies/[id]/
    page.tsx                     ← MISE À JOUR : imports MovieHero, MovieCast, MoviePlayer
```

## Fichiers à créer / modifier

### 1. `src/hooks/useTorrentStream.ts` (NOUVEAU)
Extrait de `MoviePlayer.tsx` :
- Type `Torrent` et `PlayerState` (exportés)
- États : `selected`, `state`, `progress`, `infoHash`, `errorMsg`
- Effets : fast-path HEAD check + status check au changement de torrent sélectionné
- Callbacks : `stopPolling`, `pollStatus` (interval 2s), `selectTorrent`, `startWatch`
- Reçoit `(initialTorrent: Torrent | null, movieId: number)`

### 2. `src/components/Player/PlayerPlaceholder.tsx` (NOUVEAU)
- Props : `{ state: PlayerState, progress: number, errorMsg: string | null }`
- Appelle `useTranslation()` directement (client component)
- Contient le rendu checking/idle/downloading/error

### 3. `src/components/Player/TorrentButton.tsx` (NOUVEAU)
- Props : `{ torrent, selected, state, onSelect }`
- Logique `isSelected` et `locked` (state === 'starting')

### 4. `src/components/Player/TorrentSelector.tsx` (NOUVEAU)
- Props : `{ torrents, selected, state, onSelect, onWatch }`
- Groupe les `TorrentButton` + bouton "Regarder" conditionnel (`idle | error`)

### 5. `src/components/Player/SubtitleIndicator.tsx` (NOUVEAU)
- Props : `{ show: boolean }`
- Affiche l'icône barrée + texte `movie.no_subtitles_available` si `show`

### 6. `src/components/Player/MoviePlayer.tsx` (NOUVEAU - remplace page/MoviePlayer.tsx)
- `useRef<HTMLVideoElement>`, `useTorrentStream`, `useProgressSync`, `useSubtitleTracks`
- Rendu : `<video>` ou `<PlayerPlaceholder>`, `<SubtitleIndicator>`, `<TorrentSelector>`
- Guard `!torrents.length` → message `movie.no_torrents`
- Re-exporte le type `Torrent` pour la page

### 7. `src/components/page/MovieHero.tsx` (NOUVEAU)
- Server Component (pas de 'use client')
- Props issues de `MovieDetail` : id, title, year, runtime (string formaté), rating, overview, genres[], posterUrl, backdropUrl
- Contient backdrop img + gradient, poster img, titre, méta, badges genres, overview, `<FavoriteButton>` + `<WatchLaterButton>`

### 8. `src/components/page/MovieCast.tsx` (NOUVEAU)
- Server Component
- Props : `{ cast: CastMember[] }`
- Retourne `null` si cast vide
- Section h2 "Casting" + scroll horizontal des 12 premiers membres

### 9. `src/app/(main)/movies/[id]/page.tsx` (MISE À JOUR)
- Supprime le JSX hero et casting inline
- Importe `MovieHero`, `MovieCast` depuis `@/components/page/`
- Importe `MoviePlayer` depuis `@/components/Player/MoviePlayer`
- Passe `movie.backdrop_url` à `MovieHero` pour gérer le `-mt-24` conditionnel

### 10. Nettoyage
- Supprimer `src/components/page/MoviePlayer.tsx`
- Supprimer le dossier vide `src/components/page/player/`

## Vérification
```bash
cd frontend
pnpm tsc --noEmit   # pas de nouvelles erreurs TS (recharts déjà ignoré)
```
Tester manuellement : naviguer sur `/movies/:id`, vérifier player + hero + casting.
