---
name: new-plugin-version
description: >-
  Bring the Adivery Flutter plugin (pub.dev package `adivery`) up to a new
  Adivery Android SDK release, so a new plugin version (X.Y.Z, matching the
  SDK version) can be published. Use when the user asks for a "new plugin
  version", to "update the plugin to SDK X.Y.Z", "sync with the latest SDK
  release", "bump the SDK", or similar. Flow: preflight → pick the target SDK
  version (Maven Central) → diff the SDK API the Java code uses between the
  published AARs → check the Dart↔Java method-channel bridge → read the SDK's
  behaviour changes → port them to the Java plugin, the Dart API, the example
  app, README and CHANGELOG → verify (analyze, example APK, optional device
  run) → commit on a branch → hand off to `release` to publish. This skill
  never publishes anything itself.
---

# Cut a new plugin version for a new SDK release

The plugin has two bridges, and neither is fully checked by a compiler:

- **Java → SDK.** `android/src/main/java/com/adivery/plugin/*.java` calls the
  SDK's public API (`com.adivery.sdk.*`) directly. `javac` catches a removed or
  renamed SDK method, but not a **new callback** on a listener class the
  plugin subclasses (`AdiveryListener` in `AdiveryPlugin.java`,
  `AdiveryAdListener` in `AdiveryAdView.java`, `AdiveryNativeCallback` /
  `AdiveryCallback` in `NativeAd.java`). The plugin compiles without it, and
  the event is silently never forwarded to Dart.
- **Dart ↔ Java.** `lib/*.dart` reaches Java only by string, over method
  channels:
  - channel names: `adivery_plugin`, `adivery/banner_<id>`, `adivery/native_<id>`;
  - Dart → Java method names (`_channel.invokeMethod("rewarded", …)`) vs the
    `case "rewarded":` labels in Java's `onMethodCall`;
  - Java → Dart event names (`channel.invokeMethod("onRewardedAdLoaded", …)`)
    vs the `case "onRewardedAdLoaded":` labels in Dart's handlers;
  - payload keys (`arguments.put("placement_id", …)` vs `args["placement_id"]`,
    `call.argument("appId")` vs `{"appId": appId}`) and payload shape (a Java
    `(String) call.arguments` cast throws if Dart sends a map);
  - the platform-view type `adivery/bannerAd` and its creation-param keys.

  A typo in any of these fails at runtime, usually silently (an unhandled
  event is dropped; an unknown method returns `notImplemented`).

Plugin versions track SDK versions 1:1 (since 4.8.7): `pubspec.yaml`'s
`version`, `android/build.gradle.kts`'s `com.adivery:sdk` dependency, the
`CHANGELOG.md` heading and the example's `adivery: ^X.Y.Z` constraint are
bumped together, as in "Publish 4.9.0 version". Publishing (pub.dev, the git
tag, the GitHub release) is the **`release`** skill's job, not this one's.

Repo: `adivery/adivery-flutter-plugin` on GitHub. SDK sources (optional, used
for the changelog): `$ADIVERY_SDK_REPO`, default
`$HOME/Workspace/AndroidStudioProjects/mobile-android-sdk`. The Unity and React
Native plugins have the same skill (`../adivery-unity-plugin`,
`../adivery-react-native-plugin`, `.claude/skills/new-plugin-version`); when
porting a new format, their already-merged port is a useful reference.

Helper: `scripts/bridge.py` (run with `python3 -I`; needs `javap`).
- `bridge.py api <aar> <repo>` prints the API of every SDK class the Java
  uses, with inherited methods folded in and R8 noise removed. Diff two of
  these.
- `bridge.py check <aar> <repo> [--baseline <old.aar>]` checks both bridges
  and exits 1 on errors:
  - Java vs AAR: used classes, static calls and their arity, listener `@Override`s.
  - Dart vs Java, per channel: method names and argument keys/shape both ways,
    `invokeListMethod`/`invokeMapMethod` on a case that returns `true`, the
    platform-view type and creation params, and `_onX` fields that are called
    but never assigned.
  - "NOT FORWARDED" lists SDK callbacks the Java doesn't override; with
    `--baseline`, only the ones new since that AAR.

## Hard rules

- **Only depend on a version that's on Maven Central**, and only prepare a
  plugin version that isn't on pub.dev yet.
- **Diff the published AARs, not SDK sources.** Sources may hold unreleased
  changes. The AAR is what customers get.
- **Don't touch the user's uncommitted work.** Gate on changes to **tracked**
  files. If there are any, show them and ask whether to stash or stop. Never
  discard them. Untracked junk (`.idea/`, `example/ios/Flutter/ephemeral/`,
  notes) stays out of every commit: never `git add -A`.
- **Work on a branch from `origin/master`.** Never commit to `master` here.
  Never push, open a PR, publish to pub.dev, or create a release without asking.
- **The example can't resolve the new version from pub.dev before it's
  published.** Build it through a temporary `example/pubspec_overrides.yaml`
  (path override to `../`) and delete that file afterwards. It is not
  gitignored and must never be committed.
- **pub.dev is geo-blocked from this machine.** Before any `flutter pub` step
  or pub.dev API call, check
  `curl -sS -o /dev/null -w '%{http_code}' https://pub.dev/api/packages/meta`:
  `200` is fine, `403` means the VPN is off. Ask the user to turn on a
  system-wide VPN; a fake "authorization failed" error from pub is the same
  problem, not a credentials one.
- **Pre-release versions keep their suffix everywhere** (`4.10.0-alpha.1`), in
  `pubspec.yaml`, the Gradle line, the CHANGELOG heading, the example
  constraint, the branch name and (later) the tag.
- **Never read or repeat credentials:** not `~/.config/dart/pub-credentials.json`,
  not `GITHUB_TOKEN`, and not the SDK repo's `gradle.properties`, which can hold
  real Maven Central credentials locally.

## STOP conditions

- The target version isn't on Maven Central (`.pom` isn't HTTP 200). The SDK's
  own release has to happen first.
- The target equals the SDK version on `origin/master`, or `adivery <target>`
  is already on pub.dev.
- No JDK 17+ or no Android SDK (the example build needs both).
- After the port, `bridge.py check` still reports an error that wasn't already
  there before the port (2a) and accepted by the user as out of scope.
- `flutter analyze` reports errors, or the example APK build fails.

---

## Phase 0: Preflight

```bash
cd /path/to/adivery-flutter-plugin   # repo root (pubspec.yaml with "name: adivery")

flutter --version | head -1; java -version 2>&1 | head -1; command -v javap adb
ANDROID_HOME="${ANDROID_HOME:-$(grep sdk.dir example/android/local.properties 2>/dev/null | cut -d= -f2-)}"
[ -d "$ANDROID_HOME" ] && echo "ANDROID_HOME: $ANDROID_HOME" || echo "no Android SDK: ask the user"
curl -sS -o /dev/null -w 'pub.dev: %{http_code}\n' https://pub.dev/api/packages/meta   # 200, else VPN

git fetch origin
git status --short --untracked-files=no   # tracked changes: must be empty (see Hard rules)
git branch --show-current

# Scratch space for downloads and logs. The scripts are copied here because Phase 1
# checks out origin/master, which may not contain this skill's directory.
WORKDIR=$(mktemp -d)
cp -r .claude/skills/new-plugin-version/scripts "$WORKDIR/scripts"
SKILL="$WORKDIR/scripts"
```

## Phase 1: Pick the versions and branch

```bash
CURRENT=$(git show origin/master:android/build.gradle.kts | grep -oP 'com\.adivery:sdk:\K[0-9A-Za-z.+-]+')
git show origin/master:pubspec.yaml | grep -E '^version:'    # normally equals CURRENT

MAVEN=https://repo1.maven.org/maven2/com/adivery/sdk
LATEST=$(curl -fsS "$MAVEN/maven-metadata.xml" | grep -oP '<release>\K[^<]+')
TARGET="${TARGET:-$LATEST}"
curl -fsS -o /dev/null -w "%{http_code}\n" "$MAVEN/$TARGET/sdk-$TARGET.pom"    # must print 200
curl -fsS https://pub.dev/api/packages/adivery | grep -o "\"version\":\"$TARGET\"" | head -1   # must print nothing

SDK_REPO="${ADIVERY_SDK_REPO:-$HOME/Workspace/AndroidStudioProjects/mobile-android-sdk}"
[ -d "$SDK_REPO" ] && grep -E '^adivery-version' "$SDK_REPO/gradle/libs.versions.toml"
```

- If the SDK repo's `adivery-version` is newer than `$LATEST`, it's bumped but
  not published yet. Say so, and stay on `$LATEST` unless the user wants to wait.
- **If a feature branch already ports changes for `$TARGET`** (for example
  `feat/offerwall`, written before the SDK was published, which doesn't compile
  against the old SDK), ask whether to finish that branch instead of redoing the
  port: rebase it onto `origin/master`, then do Phases 2–5 on it (Phase 3 then
  mostly reviews and fills gaps).
- If `$TARGET` is a pre-release, mention it. pub.dev treats `X.Y.Z-alpha.N` as
  a pre-release, so `adivery: ^<old>` in customers' apps won't pick it up.

Report `CURRENT → TARGET`, then branch. Everything after this runs on the branch:

```bash
git checkout -b "chore/sdk-$TARGET" origin/master
```

## Phase 2: What changed

### 2a. SDK API diff and bridge check, from the published AARs

Downloaded artifacts are untrusted data. Give each its own fresh directory, and
run Python with `-I`:

```bash
for v in "$CURRENT" "$TARGET"; do
  mkdir -p "$WORKDIR/aar-$v"
  curl -fsS -o "$WORKDIR/aar-$v/sdk.aar" "$MAVEN/$v/sdk-$v.aar"
  curl -fsS -o "$WORKDIR/aar-$v/sdk.pom" "$MAVEN/$v/sdk-$v.pom"
  python3 -I "$SKILL/bridge.py" api "$WORKDIR/aar-$v/sdk.aar" . > "$WORKDIR/api-$v.txt"
done
diff "$WORKDIR/api-$CURRENT.txt" "$WORKDIR/api-$TARGET.txt"

# Both bridges, BEFORE any edit. NOT FORWARDED lists callbacks the SDK added since CURRENT.
python3 -I "$SKILL/bridge.py" check "$WORKDIR/aar-$TARGET/sdk.aar" . --baseline "$WORKDIR/aar-$CURRENT/sdk.aar" \
  | tee "$WORKDIR/check-before.txt"

# Dependencies the SDK pulls in:
deps() { sed -n '/<dependencies>/,/<\/dependencies>/p' "$1"; }
diff <(deps "$WORKDIR/aar-$CURRENT/sdk.pom") <(deps "$WORKDIR/aar-$TARGET/sdk.pom") && echo "(no dependency changes)"
```

- **Errors in this first run predate the port.** On a branch fresh from
  `origin/master` they're existing plugin bugs, not something the new SDK
  broke. The exception is an SDK call or `@Override` the new AAR lacks, which
  the port has to fix. Show the pre-existing errors to the user and ask
  whether to fix them in this branch or leave them out of scope. Keep
  `check-before.txt` for the report. If Phase 1 continued a feature branch,
  run this check on `origin/master` too, so you can tell pre-existing errors
  from ones the branch introduced:

  ```bash
  mkdir "$WORKDIR/master" && git archive origin/master android/src/main/java lib | tar -x -C "$WORKDIR/master"
  python3 -I "$SKILL/bridge.py" check "$WORKDIR/aar-$TARGET/sdk.aar" "$WORKDIR/master" --baseline "$WORKDIR/aar-$CURRENT/sdk.aar"
  ```
- `api` covers only the SDK classes the Java uses. For a **new ad format**
  that needs a class the plugin doesn't use yet, look in the AAR directly:
  `unzip -p <aar> classes.jar > c.jar`, then `javap -public -cp c.jar <class>`.
- A POM dependency change can matter to the example, which pins
  `mbridge_android_sdk` itself in `example/android/app/build.gradle.kts`.

Where each SDK listener class is forwarded:

| SDK class (and supers) | Plugin file | Forwarded over |
|---|---|---|
| `AdiveryListener` | `AdiveryPlugin.java` (`listener` field) | `adivery_plugin` → `lib/adivery.dart` `_handleMethodCall` |
| `AdiveryAdListener` | `AdiveryAdView.java` (`extends`) | `adivery/banner_<id>` → `BannerAdEventHandler.handle` |
| `AdiveryNativeCallback` → `AdiveryCallback` | `NativeAd.java` (`callback` field) | `adivery/native_<id>` → `NativeAdEventHandler.handle` |

### 2b. Behaviour changes, from the SDK's history

A signature diff misses behaviour changes. For example, from 4.10.0-alpha.1 an
OfferWall isn't prefetched again after it closes, so the app has to prepare it
again before each show.

```bash
cd "$SDK_REPO"
intro() { git log --reverse --format=%H -S"adivery-version = \"$1\"" -- gradle/libs.versions.toml | head -1; }
FROM=$(intro "$CURRENT"); TO=$(intro "$TARGET")
git log --format='%h %s' "$FROM..$TO" -- \
  lib/src/main/java/com/adivery/sdk/Adivery.java \
  lib/src/main/java/com/adivery/sdk/AdiveryListener.java \
  lib/src/main/java/com/adivery/sdk/AdiveryListenerController.kt \
  lib/src/main/java/com/adivery/sdk/ParallelAdLoader.kt \
  lib/src/main/java/com/adivery/sdk/core
cd -
```

`intro` finds the commit that *introduced* each version line (`-G` would also
match the bump that removes it). If the SDK repo isn't present or the range is
empty, ask the user for the changelog instead of guessing. Read the relevant
commits (`git show <sha>`) and the SDK sample
(`app/src/main/java/com/adivery/sample/`) for intended usage.

Summarise for the user, **before editing anything**:
- API additions, removals and signature changes;
- new callbacks to forward;
- behaviour changes that affect callers;
- dependency changes.

## Phase 3: Port

On `chore/sdk-$TARGET`:

1. **Versions:**
   - `android/build.gradle.kts`: `implementation("com.adivery:sdk:<TARGET>")`;
   - `pubspec.yaml`: `version: <TARGET>`;
   - `example/pubspec.yaml`: `adivery: ^<TARGET>` (leave the commented-out
     `path: ../` alone);
   - `CHANGELOG.md`: a new entry **at the top**, in the file's existing format
     (`#<TARGET>` then `* ` bullets), written for integrators. The `release`
     skill refuses to run without it and uses it as the GitHub release notes.
2. **Java** (`android/src/main/java/com/adivery/plugin/`):
   - **A new SDK static** (e.g. `Adivery.prepareXAd(ctx, id)`) becomes a
     `case "<name>":` in `AdiveryPlugin.onMethodCall`, calling a small private
     method like `requestRewardedAd`. A case that returns a value calls
     `result.success(value)` and `return`s; the others `break` to the shared
     `result.success(true)`. Read a scalar argument with
     `(String) call.arguments`, map arguments with `call.argument("key")`.
   - **A new `AdiveryListener` callback** gets an `@Override` in the `listener`
     field that calls `channel.invokeMethod("<sameName>", …)`: the placement ID
     alone as the argument, or a `HashMap` with snake_case keys
     (`placement_id`, ...) when there's more than one value.
   - **Banner / native callbacks** go through `AdiveryAdView` /
     `NativeAd.java`'s own channels the same way.
   - **Removed or renamed SDK API:** update the Java, and call it out in the
     summary and the CHANGELOG, since it can change Dart behaviour for users.
3. **Dart** (`lib/adivery.dart`, `lib/adivery_ads.dart`). For each new event:
   - a typedef if the signature is new (like `OfferWallRewardFunction`);
   - a `static <Type>? _onX;` field;
   - an optional named parameter in `addListener({...})` **and** its
     assignment `_onX = onX;` (a field that's never assigned is always null,
     so the event silently never fires);
   - a `case "<eventName>":` in `_handleMethodCall` with the **same string**
     as Java, reading only keys Java puts (`args["placement_id"] as String`).

   For each new Java `case`, add a `static` wrapper on `AdiveryPlugin` that
   calls `_channel.invokeMethod("<sameName>", …)` with the argument shape the
   Java reads (a bare string for `(String) call.arguments`, a map for
   `call.argument(...)`).
4. **Example** (`example/lib/main.dart`): a placement constant, the listener
   callbacks (with a `print(...)` so a device run shows them), and a button
   for the new format or API, next to the existing ones. `addListener` must
   run before the prepare calls' events can arrive. Reflect behaviour changes
   in how the example uses the API (e.g. prepare again after an OfferWall
   closes).
5. **README:** it's a two-line stub today; if the user wants, document new
   formats and APIs and any behaviour change integrators must handle.
   Otherwise the CHANGELOG entry carries it.

Re-run the check until the only errors left are pre-existing ones the user
chose to leave out of scope (2a):

```bash
python3 -I "$SKILL/bridge.py" check "$WORKDIR/aar-$TARGET/sdk.aar" . --baseline "$WORKDIR/aar-$CURRENT/sdk.aar"
```

- **"NOT FORWARDED" lines:** forward each one, or list it in the report as
  skipped on purpose, with the reason.
- **Warnings** (a Java case Dart never calls, a Dart case Java never sends, a
  map key nobody reads) are dead code, not runtime failures. Mention any new
  ones.
- **Reference count:** the summary line includes how many references were
  checked: 95 for the 4.9.0 code against 4.10.0-alpha.1, and 107 once
  OfferWall is ported. It grows as the plugin grows. If it collapses, the
  parsing broke. Don't read that as success.

## Phase 4: Verify

### 4a. Static analysis

```bash
flutter pub get      # needs pub.dev (VPN); with a warm cache, --offline works
flutter analyze      # 0 errors; surface warnings/infos
```

### 4b. Example APK (compiles the Java against the target SDK)

```bash
printf 'dependency_overrides:\n  adivery:\n    path: ../\n' > example/pubspec_overrides.yaml
(cd example && flutter pub get && flutter build apk --debug)
(cd example/android && ./gradlew -q :adivery:dependencies --configuration releaseRuntimeClasspath \
  | grep -m1 'com.adivery:sdk')     # must show $TARGET
```

This takes several minutes, so run it in the background. `example/android/gradlew`
is generated by the first `flutter build`, so the `dependencies` step only works
after it. The APK lands at
`example/build/app/outputs/flutter-apk/app-debug.apk`. A Java compile error
here is the Java → SDK bridge breaking: fix it in Phase 3, don't work around it.

### 4c. Device run (optional; when `adb devices` lists one)

```bash
adb install -r example/build/app/outputs/flutter-apk/app-debug.apk
adb shell dumpsys window | grep -E "isKeyguardShowing"   # must be false
adb logcat -c
adb shell am start -W -n com.adivery.plugin_example/.MainActivity
adb logcat -d -s flutter:V   # the example's print() lines: "<format> loaded", "onError..."
```

- **Locked phone:** wake it with `adb shell input keyevent KEYCODE_WAKEUP` and
  ask the user to unlock. Don't try to bypass a secure lock screen.
- **Wireless ADB** drops often, especially during long builds. Wait for
  `adb devices` to show the device again before giving up.
- **Tapping through an ad:** `adb shell input tap X Y`, with coordinates from
  `adb exec-out screencap -p`. Or ask the user to tap through each format.

### 4d. Clean up

```bash
rm -f example/pubspec_overrides.yaml
git status --short     # no pubspec_overrides.yaml; only the files this skill changed
```

`example/pubspec.lock` may now point `adivery` at the path dependency; restore it
with `git checkout example/pubspec.lock` rather than committing that.

## Phase 5: Commit and hand off

Two commits on `chore/sdk-$TARGET`, staged by explicit path, each leaving the
plugin buildable:

1. `Bump Adivery SDK to <TARGET>`: `android/build.gradle.kts`, `pubspec.yaml`,
   `CHANGELOG.md`, `pubspec.lock` if it changed, and the Java/Dart bridge
   changes the new SDK requires. New `@Override`s don't compile without the
   bump, so they land together.
2. Example (`example/lib/main.dart`, `example/pubspec.yaml`) and README
   changes, with a message describing what changed for integrators.

If Phase 1 chose to finish an existing feature branch, commit on that branch
instead, on top of its existing port.

Follow the session's commit-attribution rules. Then **ask** before each of
these outward-facing steps:

1. Push the branch and open a PR against `master`.
2. After it's merged, run **`release`** from an up-to-date `master`. It reads
   the version from `pubspec.yaml`, builds and device-checks the release APK,
   and asks again before the irreversible `flutter pub publish` and before
   publishing the GitHub release. Its notes come from the CHANGELOG entry
   written in Phase 3.

---

## Final report

Summarize:
- `CURRENT → TARGET`, and whether it's a pre-release;
- the API diff and how each change was ported: new method-channel methods,
  newly forwarded events with their names and payload keys, and callbacks
  skipped on purpose, with the reason;
- behaviour changes and how the example, CHANGELOG and README reflect them;
- POM dependency changes;
- verification:
  - `bridge.py check`: references checked, and errors before (2a) vs after
    the port, with any pre-existing ones left out of scope;
  - `flutter analyze`;
  - the APK build, with the resolved SDK version;
  - the device run if one happened, or why not;
- the branch, its commits, and what's left (PR, `release`);
- `$WORKDIR`, which is safe to delete.
