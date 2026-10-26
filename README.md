# TEL-Manual: the backup stream

Two ways to run a This EVE Life stream. Pick one before the show starts.

| | Automatic (TEL-Normal) | Manual (TEL-Manual) |
| --- | --- | --- |
| Use it when | The VPS and thisevelife.space are up | thisevelife.space is down, the feed is wrong, or you want nothing automatic |
| Overlay pages come from | thisevelife.space/overlay/ (VPS) | ceemaeve.github.io/tel-manual/ (GitHub Pages) |
| Today, Next Episode, guest plates | Discord events through /api/public/feed | manual.json, which you edit |
| Speaking glow, avatars, Up Next from Discord | On | Off (Up Next reads manual.json) |
| Credits names, music, bumper | VPS files | credits-names.txt, credits/music.mp3 and credits/bumper.mp4 in the tel-manual repo (copied there from the stream PC) |
| Pre-show music, Now Playing, Countdown, alerts, Stream Deck | Local to the PC | Same, unchanged |
| OBS scene collection | TEL-Normal | TEL-Manual (same scene names) |

The pages are the same files. `?src=manual` on the URL is the only difference: with it a page reads
`manual.json` beside itself and skips the VPS; Credits reads its names, music and bumper from beside itself too. Without it the page behaves as before, so TEL-Normal
is not touched by any of this.

## Switching to Manual on show day

1. Open https://ceemaeve.github.io/tel-manual/ (the editor). Fill in today's show and the next
   one or two, press Build JSON, Copy JSON.
2. Open https://github.com/ceemaeve/tel-manual/edit/main/manual.json, paste over it, Commit changes.
   Pages serves the new file within about 5 minutes.
3. Credits: edit https://github.com/ceemaeve/tel-manual/edit/main/credits-names.txt the same way.
4. OBS: Scene Collection → TEL-Manual. Same Stream Deck keys; no re-pointing.
5. Click through PreShow, the camera scene for today's guest count, Break, Credits and Outro.
   A blank plate means manual.json has not reached Pages yet: right-click the source → Refresh.

Times in manual.json are UTC (EVE time). The editor converts from Pacific if you choose that.

## Switching back

OBS: Scene Collection → TEL-Normal. Nothing else to undo.

## First-time setup of the TEL-Manual scene collection

1. OBS on TEL-HDT-01: Scene Collection → Export → `TELNormal.json`.
2. PowerShell: `powershell -ExecutionPolicy Bypass -File make-tel-manual.ps1 -Export "<path>\TELNormal.json"`
   (the script is in this repo; download it or run it from a tel-sites checkout at `tel-manual/`).
   It writes `TELManual.json` beside the export: overlay URLs re-pointed to the Pages site with
   `?src=manual`, avatar sources removed, Election and Month removed, collection renamed TEL-Manual.
3. OBS: Scene Collection → Import → `TELManual.json`.
4. Upload the credits song as `credits/music.mp3` and the bumper as `credits/bumper.mp4` to the
   tel-manual repo (GitHub: Add file → Upload files, into a `credits` folder). The publish script
   never overwrites them.
5. Delete `TELNormal.json` and `TELManual.json` from Downloads: both hold the StreamElements URL.

Redo steps 1 to 3 after any change to TEL-Normal you want in the backup.

## Keeping the pages current

The pages live in ceemaeve/tel-sites under `stream/overlay/`. After an overlay change, a TEL Ops
chat runs `bash tel-manual/publish.sh`, which copies the core pages and this kit into the
tel-manual repo and pushes. GitHub Pages redeploys on its own. `manual.json`,
`credits-names.txt` and the `credits/` media in tel-manual are never overwritten by the publish.

## What is public

tel-manual is a public repo because GitHub Pages on a private repo needs a paid plan. It holds the
overlay HTML (already public at thisevelife.space/overlay/), the editor, the sample data and the
scripts, plus the credits song and bumper you upload. No stream key, no StreamElements URL.
