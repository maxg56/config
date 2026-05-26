# Plan: Issue #17 — Transcoding à la volée avec ffmpeg (mkv → mp4/webm)

## Context
Le streaming actuel (`handlers/stream.go`) utilise `http.ServeContent` pour servir les fichiers torrent directement avec gestion des byte-range. Les navigateurs ne supportent pas nativement MKV, AVI, MOV, etc. L'objectif est d'intercaler ffmpeg entre le lecteur torrent et la réponse HTTP pour transcoder à la volée, sans fichier temporaire intermédiaire.

## Critères d'acceptation
- Détection format source (ffprobe si fichier disque, extension sinon)
- MKV → MP4 (H.264/AAC) ou remux si les codecs sont déjà compatibles
- Pipeline : torrent reader → ffmpeg stdin → HTTP response (pas de fichier tmp)
- Compatible Firefox & Chrome

---

## Fichiers critiques
- `api/torrent-service/src/handlers/stream.go` — à modifier
- `api/torrent-service/src/services/reader.go` — ajouter `FilePath` dans `readerResult`
- `api/torrent-service/src/services/transcoder.go` — nouveau fichier à créer
- `api/torrent-service/src/services/client.go` — vérifier la config du download dir

---

## Implémentation

### Étape 1 — Enrichir `readerResult` (services/reader.go)
Ajouter un champ `FilePath string` dans la struct `readerResult` :
```go
type readerResult struct {
    Reader   torrentReader
    Size     int64
    FileName string
    FilePath string  // chemin absolu sur disque, vide si pas encore disponible
}
```
- Dans `readerFromDisk` : `FilePath = record.FilePath`
- Dans `readerFromActiveTorrent` : `FilePath = filepath.Join(downloadDir, f.DisplayPath())` (si la config expose le download dir)

### Étape 2 — Nouveau fichier `services/transcoder.go`

```go
// Formats nativement supportés par les navigateurs
var nativeBrowserFormats = map[string]bool{
    ".mp4": true, ".webm": true, ".ogg": true, ".m4v": true,
}

// CodecInfo résultat de ffprobe
type CodecInfo struct {
    VideoCodec string  // "h264", "vp9", "hevc", etc.
    AudioCodec string  // "aac", "opus", "ac3", etc.
}

// NeedsTranscoding retourne true si le fichier n'est pas nativement supporté
func NeedsTranscoding(filename string) bool {
    ext := strings.ToLower(filepath.Ext(filename))
    return !nativeBrowserFormats[ext]
}

// ProbeCodecs lance ffprobe sur le fichier pour détecter les codecs
func ProbeCodecs(filePath string) (*CodecInfo, error) {
    // ffprobe -v quiet -print_format json -show_streams <filePath>
    // Parser la sortie JSON pour extraire video/audio codec_name
}

// canCopyStream retourne true si les codecs sont déjà H.264+AAC (remux uniquement)
func canCopyStream(info *CodecInfo) bool {
    return (info.VideoCodec == "h264") && (info.AudioCodec == "aac" || info.AudioCodec == "mp3")
}

// TranscodeJob encapsule le process ffmpeg en cours
type TranscodeJob struct {
    Reader      io.ReadCloser
    Cmd         *exec.Cmd
    ContentType string
}

// StartTranscode démarre ffmpeg avec le reader torrent en stdin
// Si codecInfo != nil et codecs compatibles → remux (-c copy)
// Sinon → transcode libx264 + aac
func StartTranscode(reader io.Reader, codecInfo *CodecInfo) (*TranscodeJob, error) {
    args := buildFFmpegArgs(codecInfo)
    cmd := exec.Command("ffmpeg", args...)
    cmd.Stdin = reader
    stdout, _ := cmd.StdoutPipe()
    cmd.Stderr = io.Discard  // ou logger
    if err := cmd.Start(); err != nil { ... }
    return &TranscodeJob{Reader: stdout, Cmd: cmd, ContentType: "video/mp4"}, nil
}

// buildFFmpegArgs choisit entre remux et transcode complet
// Remux (rapide) :
//   -i pipe:0 -c copy -f mp4 -movflags frag_keyframe+empty_moov+default_base_moof pipe:1
// Transcode complet :
//   -i pipe:0 -c:v libx264 -preset ultrafast -tune zerolatency -c:a aac -b:a 128k
//   -f mp4 -movflags frag_keyframe+empty_moov+default_base_moof pipe:1
```

### Étape 3 — Modifier `handlers/stream.go`

Après avoir obtenu `result` de `services.GetTorrentReader(hash)` :

```go
if services.NeedsTranscoding(result.FileName) {
    // Essayer ffprobe si on a le chemin disque
    var codecInfo *services.CodecInfo
    if result.FilePath != "" {
        codecInfo, _ = services.ProbeCodecs(result.FilePath)
    }

    job, err := services.StartTranscode(result.Reader, codecInfo)
    if err != nil {
        utils.RespondError(c, http.StatusInternalServerError, "transcoding error: "+err.Error())
        return
    }
    defer job.Cmd.Wait()
    defer job.Reader.Close()

    c.Header("Content-Type", job.ContentType)
    c.Header("Cache-Control", "no-cache")
    c.Header("Transfer-Encoding", "chunked")
    c.Status(http.StatusOK)
    io.Copy(c.Writer, job.Reader)
    return
}

// Format natif → comportement existant inchangé
http.ServeContent(c.Writer, c.Request, result.FileName, time.Time{}, result.Reader)
```

**Note importante** : Pour le contenu transcodé, les byte-range requests ne sont pas supportées (ffmpeg pipe non-seekable). Le client reçoit un stream continu en `Transfer-Encoding: chunked`. C'est acceptable pour la lecture linéaire mais la seek dans la timeline sera limitée côté navigateur.

---

## Précisions techniques

| Scénario | Commande ffmpeg |
|---|---|
| MKV avec H.264+AAC | `-i pipe:0 -c copy -f mp4 -movflags frag_keyframe+empty_moov+default_base_moof pipe:1` |
| MKV avec HEVC/autres | `-i pipe:0 -c:v libx264 -preset ultrafast -tune zerolatency -c:a aac -b:a 128k -f mp4 -movflags frag_keyframe+empty_moov+default_base_moof pipe:1` |
| Format natif (MP4, WebM) | Pas de transcoding, `http.ServeContent` direct |

Les flags `-movflags frag_keyframe+empty_moov+default_base_moof` sont essentiels pour que le MP4 soit streamable (fragmented MP4 / fMP4) sans avoir besoin de `moov` atom à la fin du fichier.

---

## Vérification

1. Lancer le service : `cd api/torrent-service && go run ./src/...`
2. Télécharger un torrent MKV via `POST /api/v1/torrent/download`
3. Accéder à `GET /api/v1/stream/:hash` → vérifier header `Content-Type: video/mp4`
4. Ouvrir dans Firefox et Chrome → la vidéo doit se lancer
5. Pour un MP4 natif → vérifier que `http.ServeContent` est toujours utilisé (byte-range fonctionne)
6. Vérifier avec `ffprobe` que la sortie est bien un fMP4 valide
