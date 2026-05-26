# Plan — Recherche d'utilisateurs via la barre de recherche

## Context
Permettre de rechercher des utilisateurs depuis la barre de recherche de la page d'accueil. Quand l'utilisateur tape `user:<username>`, la grille de films est remplacée par des résultats de profils utilisateurs publics. Cliquer sur un résultat redirige vers `/users/[id]`.

---

## 1. Backend — user-service

### Nouveau handler `api/user-service/src/handlers/search_users.go`
```go
// GET /api/v1/users/search?q=<username>  (public, no auth required)
func SearchUsersHandler(c *gin.Context) {
    q := strings.TrimSpace(c.Query("q"))
    if q == "" {
        utils.RespondSuccess(c, 200, gin.H{"users": []struct{}{}})
        return
    }
    var results []struct {
        ID        uint   `json:"id"`
        Username  string `json:"username"`
        AvatarURL string `json:"avatar_url"`
        FirstName string `json:"first_name"`
        LastName  string `json:"last_name"`
    }
    conf.DB.Model(&models.User{}).
        Select("id, username, avatar_url, first_name, last_name").
        Where("is_public = true AND username ILIKE ?", "%"+q+"%").
        Limit(20).
        Find(&results)
    utils.RespondSuccess(c, 200, gin.H{"users": results})
}
```

### Modification `api/user-service/src/main.go`
Dans le groupe **public** (sans auth) :
```go
users.GET("/search", handlers.SearchUsersHandler)
```

### Modification `api/gateway/src/routes/user.go`
Dans le groupe **public** :
```go
users.GET("/search", proxy.ProxyRequest("user", "/api/v1/users/search"))
```

---

## 2. Frontend

### Hook `src/hooks/useUserSearch.ts`
- Fetch `GET /api/v1/users/search?q=<query>` avec debounce 300ms
- Retourne `{ users: UserResult[], loading: boolean }`
- `UserResult` : `{ id, username, avatar_url, first_name, last_name }`
- Aucun résultat si query vide

### Composant `src/components/page/UserCard.tsx`
Carte utilisateur pour la grille de résultats :
- Avatar (robohash fallback), username, nom complet
- Lien vers `/users/[id]`
- Style cohérent avec MovieCard (même hauteur, même arrondi)

### Modification `src/components/page/MovieFilters.tsx`
- Quand la query commence par `user:`, afficher un badge/indicateur bleu dans la barre de recherche ("Mode recherche utilisateur")
- Les selects genre/rating/year/sort passent en `opacity-40 pointer-events-none`
- Les toggles Favoris/Voir-plus-tard passent en `opacity-40 pointer-events-none`

### Modification `src/components/page/Thumbnails.tsx`
Détecter le préfixe `user:` dans la query :
```tsx
const isUserSearch = filters.query.startsWith('user:')
const userQuery = isUserSearch ? filters.query.slice(5).trim() : ''
```
- Si `isUserSearch` : afficher grille de `UserCard` via `useUserSearch(userQuery)`
- Sinon : comportement actuel inchangé (movies)
- L'IntersectionObserver est désactivé en mode user search

### Traductions `fr.json` et `en.json`
```json
"user_search": {
  "mode_hint": "Recherche d'utilisateurs",
  "empty": "Aucun utilisateur trouvé.",
  "placeholder_hint": "ex: user:johndoe"
}
```

---

## Fichiers modifiés / créés

| Fichier | Action |
|---|---|
| `api/user-service/src/handlers/search_users.go` | Créer |
| `api/user-service/src/main.go` | Modifier (route publique) |
| `api/gateway/src/routes/user.go` | Modifier (route publique) |
| `frontend/src/hooks/useUserSearch.ts` | Créer |
| `frontend/src/components/page/UserCard.tsx` | Créer |
| `frontend/src/components/page/MovieFilters.tsx` | Modifier |
| `frontend/src/components/page/Thumbnails.tsx` | Modifier |
| `frontend/src/locales/fr.json` | Modifier |
| `frontend/src/locales/en.json` | Modifier |

---

## Vérification

1. Taper `user:` dans la barre → les filtres se grisent, badge "Recherche d'utilisateurs" apparaît
2. Taper `user:john` → grille de cartes utilisateurs apparaît avec les profils publics correspondants
3. Cliquer sur une carte → redirige vers `/users/[id]`
4. Compte privé (`is_public = false`) → n'apparaît pas dans les résultats
5. Effacer le préfixe `user:` → retour à la grille de films normale
6. Query vide ou `user:` seul → aucune requête API déclenchée
