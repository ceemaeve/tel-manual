# TELM-Manual: the backup stream

TELM-Manual is the server-free copy of TELM-Auto. You switch to it when TEL-SVS-01 or thisevelife.space is down,
or when the Discord feed shows the wrong show. It looks the same and uses the same scenes and Stream Deck keys.

| | Automatic (TELM-Auto) | Manual (TELM-Manual) |
| --- | --- | --- |
| Use it when | thisevelife.space is up | thisevelife.space is down, or you want nothing automatic |
| Overlay pages | thisevelife.space/overlay-metallic/ (server) | ceemaeve.github.io/tel-manual/ (GitHub Pages) |
| Show title, guest plates, UP NEXT scroll | Discord events through /api/public/feed | manual.json, which the "TEL-Manual feed" run on GitHub refills from the same Discord events every 15 minutes; the editor overrides it |
| Guest avatars | From the feed | From manual.json, portraits from CCP (a guest without an exact EVE name gets the logo) |
| Speaking glow | On | Off |
| Credits names, music, bumper | /overlay/ files on the server | credits-names.txt, credits/music.mp3 and credits/bumper.mp4 in the tel-manual repo |
| Music player (Now Playing), Countdown, stinger, cameras | Local to the PC | Same |
| StreamElements alerts and chat timers | StreamElements | Same |
| OBS scene collection | TELM-Auto | TELM-Manual |

The pages are the same files. `?src=manual` on the URL makes a page read `manual.json` and the credits files beside
itself instead of the server. Without it the page behaves as before, so TELM-Auto stays untouched.

## Switching to Manual on show day

1. Open https://ceemaeve.github.io/tel-manual/manual.json and check it shows today's show. If Discord is wrong or
   down, use the editor at https://ceemaeve.github.io/tel-manual/: fill in the shows, tick Hold, Build JSON, Copy JSON.
2. Editor only: open https://github.com/ceemaeve/tel-manual/edit/main/manual.json, paste over it, Commit changes.
   Pages serves the new file within about 5 minutes. Hold stops the feed from overwriting it; untick Hold (or paste a
   JSON without it) to hand control back to Discord.
3. Credits: edit https://github.com/ceemaeve/tel-manual/edit/main/credits-names.txt the same way.
4. OBS: Scene Collection, TELM-Manual. The Stream Deck keys stay the same.
5. Click through PreShow, the camera scene for today's guest count, Break, Credits and Outro. A blank plate or avatar
   means manual.json has not reached Pages yet: right-click the source, Refresh.

manual.json holds times in UTC (EVE time). The editor converts from Pacific if you pick that.

## Switching back

OBS: Scene Collection, TELM-Auto. You have nothing else to undo.

## Building the TELM-Manual scene collection

Do this once, and again after any TELM-Auto change you want in the backup.

1. OBS on TEL-HDT-01: Scene Collection, Export, `TELM-Auto.json`.
2. PowerShell (normal, not admin):
   `powershell -ExecutionPolicy Bypass -File make-telm-manual.ps1 -Export "$HOME\Downloads\TELM-Auto.json"`.
   The script is in this repo and in tel-sites `tel-metallic/manual/`. It writes `TELM-Manual.json` beside the
   export: overlay URLs (avatars included) point at the Pages site with `?src=manual`, and the collection takes the
   name TELM-Manual. It copies everything else as is, the StreamElements alerts and the music player included.
3. OBS: Scene Collection, Import, `TELM-Manual.json`.
4. Delete `TELM-Auto.json` and `TELM-Manual.json` from Downloads: both hold the StreamElements URL.

## When the credits song or bumper changes

The backup keeps its own copies in ceemaeve/tel-manual, and publish.sh leaves them alone. After you change the song or
bumper on the server, upload the same file to the repo as `credits/music.mp3` or `credits/bumper.mp4` (GitHub: Add
file, Upload files, into `credits`). TELM Credits times the scroll to the song, so an old song gives a different
scroll length. Last synced: 2026-11-16, the 32.5 s Outro song (557,943 bytes, same as the server copy).

## YouTube thumbnails when the server is down

The weekend thumbnails come from the server every evening. While it is down, run the same script on GitHub: in
ceemaeve/tel-sites open Actions, "TEL thumbs (VPS-down backup)", Run workflow (tick "dry run" first to see what it
would draw). It reads the Discord calendar, draws the next 4 days with the normal template, and pushes the PNGs and
their episodes.json entries to main. The run summary lists the title, first line and tags to paste into YouTube Studio,
where you set the thumbnail by hand until the watcher is back. Press it only during an outage, so it never competes
with the server over the same episodes.

## For TEL Stream: publishing

`bash tel-metallic/manual/publish.sh [path-to-tel-manual-clone]` from tel-sites copies the metallic pages, the editor,
this README, the converter, feed.py and the feed workflow into ceemaeve/tel-manual and pushes. It never overwrites
manual.json, credits-names.txt or credits/ there, and it removes retired pages. Run it after any change to
stream/overlay-metallic/.

## What is public

tel-manual is a public repo because GitHub Pages on a private repo needs a paid plan. It holds the overlay HTML
(already public at thisevelife.space/overlay-metallic/), the editor, sample data and scripts, plus the credits song and
bumper. It holds no stream key and no StreamElements URL; the Discord bot token sits in the repo's Actions secrets.
