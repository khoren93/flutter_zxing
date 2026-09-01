#!/usr/bin/env bash

set -euo pipefail

# Publish flutter_zxing to pub.dev.
#
#   ./scripts/publish.sh [--dry-run] [--force]
#
# The version is deliberately not bumped here. Releasing needs a CHANGELOG entry
# written for the new version anyway, and whoever writes it sets the version at
# the same time. What this script does is check that the version is consistent
# and documented, refresh the generated iOS/macOS sources, and publish.
#
# The refresh is the step that must not be forgotten: the sources under ios/ and
# macos/ are generated from src/ and git-ignored, so publishing without
# regenerating them ships a package that cannot build on those platforms.

usage() {
    cat >&2 <<'USAGE'
Usage: scripts/publish.sh [--dry-run] [--force]

  --dry-run   Validate the package without publishing it
  --force     Skip pub.dev's interactive confirmation

Before running, bump `version:` in pubspec.yaml and `s.version` in both
podspecs to the same value, and add the matching `## <version>` section to
CHANGELOG.md.
USAGE
    exit 2
}

DRY_RUN=0
FORCE=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --force)   FORCE=1 ;;
        -h|--help) usage ;;
        *) echo "error: unknown argument '$arg'" >&2; usage ;;
    esac
done

cd "$(git rev-parse --show-toplevel)"

PUBSPEC="pubspec.yaml"
IOS_PODSPEC="ios/flutter_zxing.podspec"
MACOS_PODSPEC="macos/flutter_zxing.podspec"
CHANGELOG="CHANGELOG.md"

# `pub publish` uploads what is on disk, not what is committed -- and that
# includes untracked files that no ignore rule covers.
if [ -n "$(git status --porcelain)" ]; then
    echo "error: the working tree is not clean." >&2
    echo "       Commit, stash or ignore these first -- publishing uploads what is" >&2
    echo "       on disk, including untracked files." >&2
    git status --short >&2
    exit 1
fi

# --- the version has to say the same thing in three places -------------------

podspec_version() {
    sed -n "s/^[[:space:]]*s\.version[[:space:]]*=[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p" "$1" | head -1
}

VERSION="$(sed -n 's/^version:[[:space:]]*\(.*\)$/\1/p' "$PUBSPEC" | head -1)"
[ -n "$VERSION" ] || { echo "error: no 'version:' line found in $PUBSPEC" >&2; exit 1; }

IOS_VERSION="$(podspec_version "$IOS_PODSPEC")"
MACOS_VERSION="$(podspec_version "$MACOS_PODSPEC")"

MISMATCH=0
for entry in "$IOS_PODSPEC:$IOS_VERSION" "$MACOS_PODSPEC:$MACOS_VERSION"; do
    file="${entry%%:*}"
    found="${entry#*:}"
    if [ -z "$found" ]; then
        echo "error: no 's.version' line found in $file" >&2
        MISMATCH=1
    elif [ "$found" != "$VERSION" ]; then
        echo "error: $file is at $found, but $PUBSPEC is at $VERSION" >&2
        MISMATCH=1
    fi
done
if [ "$MISMATCH" -ne 0 ]; then
    echo "       The podspecs carry their own version and drift silently." >&2
    echo "       Set all three to the same value, then re-run." >&2
    exit 1
fi

# pub.dev flags a release whose version is missing from the changelog.
ESCAPED="${VERSION//./\\.}"
if ! grep -qE "^##[[:space:]]+v?${ESCAPED}([[:space:]]|$)" "$CHANGELOG"; then
    echo "error: $CHANGELOG has no '## $VERSION' section." >&2
    echo "       Add the release notes for $VERSION first, then re-run." >&2
    exit 1
fi

echo "==> Publishing $VERSION"
echo "    $PUBSPEC, $IOS_PODSPEC and $MACOS_PODSPEC agree; $CHANGELOG documents it"

# --- regenerate the iOS/macOS sources ----------------------------------------

echo "==> Refreshing the generated iOS/macOS sources"
REFRESH_LOG="$(mktemp)"
if ! ./scripts/update_ios_macos_src.sh > "$REFRESH_LOG" 2>&1; then
    echo "error: scripts/update_ios_macos_src.sh failed:" >&2
    tail -30 "$REFRESH_LOG" >&2
    rm -f "$REFRESH_LOG"
    exit 1
fi
rm -f "$REFRESH_LOG"
echo "    done"

# --- publish -----------------------------------------------------------------

PUBLISH_ARGS=()
[ "$DRY_RUN" -eq 1 ] && PUBLISH_ARGS+=(--dry-run)
[ "$FORCE" -eq 1 ] && PUBLISH_ARGS+=(--force)

echo ""
echo "==> flutter pub publish ${PUBLISH_ARGS[*]:-}"
# `pub publish` exits non-zero on warnings too, so capture the status rather
# than letting `set -e` abort on what may only be a hint.
set +e
flutter pub publish ${PUBLISH_ARGS[@]+"${PUBLISH_ARGS[@]}"}
PUB_STATUS=$?
set -e

if [ "$PUB_STATUS" -ne 0 ]; then
    echo "" >&2
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Dry run finished with warnings (exit $PUB_STATUS). Nothing was published." >&2
    else
        echo "Publishing failed (exit $PUB_STATUS)." >&2
    fi
    exit "$PUB_STATUS"
fi

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run passed. Re-run without --dry-run to publish $VERSION."
else
    echo "Published $VERSION. Tag it:"
    echo "  git tag v$VERSION && git push --follow-tags"
fi
