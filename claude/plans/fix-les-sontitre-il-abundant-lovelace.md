# Plan : Correction de l'affichage des sous-titres

## Contexte

Les sous-titres ne s'affichent pas dans le lecteur vidéo. L'investigation montre que :
- Le backend télécharge et met bien en cache les fichiers `.vtt` dans `/data/subtitles/`
- Le frontend reçoit la liste des langues disponibles et télécharge les fichiers VTT
- **Problème principal :** les éléments `<track>` ajoutés dynamiquement ignorent l'attribut `default` dans la plupart des navigateurs. Il faut explicitement définir `el.track.mode = 'showing'` après l'ajout au DOM.
- **Problème secondaire :** si aucune langue ne correspond à `userLang`, tous les tracks restent en mode `disabled` — aucun sous-titre ne s'affiche même si des fichiers sont disponibles.

## Fichiers à modifier

| Fichier | Rôle |
|---|---|
| `frontend/src/hooks/useSubtitleTracks.ts` | Hook qui charge et attache les tracks au `<video>` |

## Changements détaillés

### `useSubtitleTracks.ts` (lignes 67-74)

**Correction 1 — activer explicitement le track de la langue utilisateur :**

```typescript
video.appendChild(el)
if (lang === userLang) {
  el.track.mode = 'showing'
}
```

L'attribut `el.default = true` peut rester (utile pour certains navigateurs), mais il ne suffit pas seul pour les tracks ajoutés dynamiquement.

**Correction 2 — fallback si aucune langue ne correspond :**

Après la boucle, si `loaded > 0` mais qu'aucun track `userLang` n'a été trouvé, activer le premier track disponible :

```typescript
if (loaded > 0 && !available.includes(userLang)) {
  const firstTrack = video.textTracks[0]
  if (firstTrack) firstTrack.mode = 'showing'
}
```

## Plan d'implémentation

1. Dans `useSubtitleTracks.ts`, après `video.appendChild(el)` (ligne 73), ajouter `if (lang === userLang) el.track.mode = 'showing'`
2. Après la boucle `for (const lang of available)`, ajouter le fallback sur le premier track si la langue de l'utilisateur n'est pas disponible
3. Conserver `el.default = true` car certains navigateurs le respectent

## Vérification

1. Lancer l'application (`make`)
2. Ouvrir un film qui a des sous-titres disponibles
3. Démarrer le stream
4. Vérifier que les sous-titres apparaissent automatiquement
5. Tester avec une langue différente de celle disponible pour vérifier le fallback
