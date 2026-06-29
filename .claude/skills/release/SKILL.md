---
name: release
description: >-
  Build, verify, and publish a new version of the adivery Flutter plugin to
  pub.dev, then cut the git release and a draft GitHub release. Use when the
  user asks to "release", "publish", or "ship" the plugin / a new version. The
  version is read from pubspec.yaml (NOT bumped by this skill — set it first).
  Flow: preflight checks → build & analyze → build example release APK → run it
  on a connected device and WAIT for the user to confirm it works → publish to
  pub.dev → commit & push directly to master + tag → create a DRAFT GitHub release with
  the APK attached → prompt the user before publishing the GitHub release.
---

# Release the adivery plugin

This skill ships a new version of the `adivery` Flutter plugin. The version is
**already set** in `pubspec.yaml` before this skill runs — this skill never
edits version numbers.

Repo: `adivery/adivery-flutter-plugin` (origin is SSH: `git@github.com:adivery/adivery-flutter-plugin.git`)
Package: `adivery` on pub.dev
Example app APK: `example/build/app/outputs/flutter-apk/app-release.apk`

## Hard rules

- **Never bump the version.** Read it from `pubspec.yaml`. If the user wants a
  different version, ask them to edit `pubspec.yaml` (and `CHANGELOG.md`) first.
- **`flutter pub publish` is irreversible** (a version can never be re-uploaded
  to pub.dev). Only run it AFTER the user has confirmed the sample app works on
  their device.
- **Two mandatory human gates** — do not skip:
  1. After the sample app launches on the device → wait for explicit "it works,
     continue".
  2. Before flipping the GitHub release from draft → published.
- If any STOP condition below is hit, halt and report — do not work around it.

## STOP conditions (halt and report before doing anything destructive)

- `CHANGELOG.md` has no entry matching the pubspec version.
- The git tag for this version already exists (would clobber a prior release).
- `flutter analyze` reports **errors** (warnings/infos are OK — surface them).
- `flutter pub publish --dry-run` fails.
- No device/emulator is connected for the sample-app step.
- Working tree has unexpected uncommitted changes unrelated to the release
  (surface `git status` and ask before continuing).

---

## Phase 0 — Preflight

Run these and confirm each:

```bash
# 1. The version under release (single source of truth)
VERSION=$(grep -E '^version:' pubspec.yaml | head -1 | sed 's/version: *//' | tr -d '[:space:]')
echo "Releasing adivery $VERSION"

# 2. CHANGELOG must have a matching entry. Extract its body (used later as the
#    GitHub release notes). Matches "#X.Y.Z", "# X.Y.Z", "## X.Y.Z", optional v.
NOTES=$(awk -v v="$VERSION" 'BEGIN{gsub(/\./,"\\.",v)} $0 ~ "^#+ *v?" v "([^0-9.]|$)"{f=1;next} /^#/{if(f)exit} f' CHANGELOG.md)
[ -z "$NOTES" ] && echo "STOP: no CHANGELOG.md entry for $VERSION" || echo "$NOTES"

# 3. Surface the Adivery Android SDK dependency — it is INDEPENDENT of the
#    plugin version; just confirm with the user it is intended (do not edit).
grep -n 'com.adivery:sdk:' android/build.gradle.kts

# 4. Make sure this release does not already exist, and we're on master
git fetch --tags --quiet
git rev-parse "$VERSION" 2>/dev/null && echo "STOP: tag $VERSION exists"
[ "$(git rev-parse --abbrev-ref HEAD)" = "master" ] || echo "STOP: not on master (releases commit directly to master)"

# 5. Working tree status (release-related changes are fine; surface anything odd)
git status --short

# 6. pub.dev auth (publish fails without it) — should already exist:
ls ~/.config/dart/pub-credentials.json && echo "pub.dev authed" || echo "Run: dart pub login"

# 7. GitHub auth for the release step
if [ -n "$GITHUB_TOKEN" ]; then echo "GitHub: using GITHUB_TOKEN"; \
  elif command -v gh >/dev/null; then echo "GitHub: using gh CLI"; \
  else echo "GitHub: no token/gh — will push tag over SSH only, release created manually"; fi
```

Report the version, the changelog notes, the SDK dep line, and the auth status
to the user before proceeding.

## Phase 1 — Build & static analysis

```bash
flutter pub get
flutter analyze            # STOP on errors; surface warnings/infos
flutter pub publish --dry-run   # STOP if this fails; surface its warnings
```

`flutter pub publish --dry-run` validates the package exactly as pub.dev will,
and prints the exact file list that will be uploaded. The package root is the
repo root, so check that list for stray non-ignored files (e.g. `.idea/`) — pub
includes any file not matched by `.gitignore`/`.pubignore`. If junk appears,
STOP and have the user gitignore it before publishing. Relay all warnings.

## Phase 2 — Build the example release APK

```bash
cd example
flutter pub get
flutter build apk --release
cd ..
ls -la example/build/app/outputs/flutter-apk/app-release.apk
```

This APK is both what the user verifies on-device and what gets attached to the
GitHub release. Keep its path: `APK=example/build/app/outputs/flutter-apk/app-release.apk`.

## Phase 3 — Run on a device and WAIT for confirmation (gate #1)

```bash
flutter devices    # confirm a real device/emulator is connected (else STOP)
```

Install **and launch** the release build the user just verified. `flutter
install` only copies the APK to the device — it does NOT start the app — so
launch it explicitly afterward (the example's applicationId is
`com.adivery.plugin_example`):

```bash
# Install the exact APK from Phase 2 (no rebuild), then launch it.
cd example && flutter install --use-application-binary build/app/outputs/flutter-apk/app-release.apk; cd ..
adb shell monkey -p com.adivery.plugin_example -c android.intent.category.LAUNCHER 1
```

Alternative: `cd example && flutter run --release` (installs **and** launches in
one step) run in the background so the tool call doesn't block — but it rebuilds,
so the running binary may not be byte-identical to the asset APK. Stop it after
the user confirms.

Then **stop and ask the user to exercise the sample app** (load each ad type,
etc.) and explicitly confirm before continuing. Do not proceed to publish until
they say so. This is the point of no return.

## Phase 4 — Prepare the git release locally (commit + tag, no push yet)

Releases go **directly on `master`** — no release branch, no PR. Commit + tag
locally **before** publishing so the commit you tag is exactly what lands on
pub.dev. Tag name = the plain pubspec version (e.g. `4.8.9`), matching `CHANGELOG.md`.

**Scope the commit to release files only** — do NOT `git add -A` (the tree has
untracked `.idea/` and `example/ios/.../ephemeral/` that must not be committed):

```bash
git checkout master            # releases commit directly to master
git add pubspec.yaml CHANGELOG.md pubspec.lock android/build.gradle.kts
git commit -m "Publish version $VERSION" || echo "nothing to commit"
git tag -a "$VERSION" -m "Release $VERSION"
```

Do not push yet — if publish fails, undo locally before anything hits the remote:
`git reset --soft HEAD~1 && git tag -d "$VERSION"`.

## Phase 5 — Publish to pub.dev (after gate #1)

Only after the user confirms the app works:

```bash
flutter pub publish --force
```

`--force` skips the interactive y/N prompt — it is acceptable here ONLY because
the user has already confirmed via gate #1. Confirm the new version appears at
https://pub.dev/packages/adivery .

## Phase 6 — Push master + tag

Now that pub.dev has accepted the version, push the tagged commit to master:

```bash
git push origin master
git push origin "$VERSION"
```

## Phase 7 — Draft GitHub release with the APK

### Path A — `GITHUB_TOKEN` is set (primary)

Create a **draft** release on the pushed tag, capture its id + upload URL,
attach the APK, then show the user the draft URL.

```bash
REPO="adivery/adivery-flutter-plugin"
APK="example/build/app/outputs/flutter-apk/app-release.apk"
ASSET="adivery-example-$VERSION-release.apk"

# 1. Create the draft release (body = the CHANGELOG notes from Phase 0)
RESP=$(curl -sS -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/releases" \
  -d "$(jq -n --arg tag "$VERSION" --arg notes "$NOTES" \
        '{tag_name:$tag, name:$tag, body:$notes, draft:true, prerelease:false}')")
RELEASE_ID=$(echo "$RESP" | jq -r '.id')
echo "Draft release id: $RELEASE_ID"
echo "$RESP" | jq -r '.html_url'

# 2. Upload the APK as a release asset
curl -sS -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/vnd.android.package-archive" \
  --data-binary @"$APK" \
  "https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=$ASSET" \
  | jq -r '.browser_download_url // .message'
```

Then **stop and prompt the user** (gate #2): show them the draft release URL and
ask whether to publish it. Only on confirmation, flip it to published:

```bash
curl -sS -X PATCH \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/releases/$RELEASE_ID" \
  -d '{"draft":false}' | jq -r '.html_url'
```

### Path B — no `GITHUB_TOKEN`, `gh` available

```bash
gh release create "$VERSION" \
  --repo adivery/adivery-flutter-plugin \
  --title "$VERSION" --notes "$NOTES" --draft \
  "example/build/app/outputs/flutter-apk/app-release.apk#adivery-example-$VERSION-release.apk"
# After the user confirms (gate #2):
gh release edit "$VERSION" --repo adivery/adivery-flutter-plugin --draft=false
```

### Path C — no token and no `gh` (SSH fallback)

The tag is already pushed over SSH in Phase 6. A GitHub *release* (with an
attached asset) can't be created over plain git/SSH, so:

1. Tell the user the tag `$VERSION` is pushed.
2. Give them the prefilled URL to finish manually:
   `https://github.com/adivery/adivery-flutter-plugin/releases/new?tag=$VERSION`
3. Tell them to attach `example/build/app/outputs/flutter-apk/app-release.apk`
   and paste the CHANGELOG notes.

---

## Final report

Summarize: pub.dev version URL, the master commit + pushed tag `$VERSION`, and
the GitHub release URL (draft or published). Note anything that needs manual
follow-up.
