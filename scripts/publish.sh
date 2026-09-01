#!/usr/bin/env bash

set -euo pipefail

# Publish flutter_zxing to pub.dev in one step: bump the version, refresh the
# generated iOS/macOS sources, then publish.
#
#   ./scripts/publish.sh [major|minor|patch] [--commit] [--dry-run] [--force]
#
# The bump level defaults to `patch`.
#
# The version lives in three files that must not drift apart -- pubspec.yaml and
# both podspecs -- so all three are written here rather than by hand. The
# iOS/macOS sources under ios/ and macos/ are generated and git-ignored, so
# publishing without regenerating them ships a package that cannot build on
# those platforms; that is why the refresh is part of this script and not a step
# to remember.

usage() {
    cat >&2 <<'USAGE'
Usage: scripts/publish.sh [major|minor|patch] [--commit] [--dry-run] [--force]

  major | minor | patch   Which part of the version to increment (default: patch)
  --commit                Commit the version bump before publishing, so the
                          released version exists in history and pub.dev has no
                          uncommitted changes to warn about
  --dry-run               Validate the package without publishing, then restore
                          the version files so the next run bumps from the same
                          version. Cannot be combined with --commit
  --force                 Skip pub.dev's interactive confirmation
USAGE
    exit 2
}

LEVEL=""
DRY_RUN=0
FORCE=0
COMMIT=0

for arg in "$@"; do
    case "$arg" in
        major|minor|patch)
            [ -z "$LEVEL" ] || { echo "error: bump level given twice ('$LEVEL' and '$arg')" >&2; usage; }
            LEVEL="$arg"
            ;;
        --dry-run) DRY_RUN=1 ;;
        --force)   FORCE=1 ;;
        --commit)  COMMIT=1 ;;
        -h|--help) usage ;;
        *) echo "error: unknown argument '$arg'" >&2; usage ;;
    esac
done
LEVEL="${LEVEL:-patch}"

if [ "$DRY_RUN" -eq 1 ] && [ "$COMMIT" -eq 1 ]; then
    echo "error: --dry-run and --commit are mutually exclusive; a dry run must not commit." >&2
    exit 2
fi

REPO_DIR="$(git rev-parse --show-toplevel)"
cd "$REPO_DIR"

PUBSPEC="pubspec.yaml"
PODSPECS=(ios/flutter_zxing.podspec macos/flutter_zxing.podspec)
CHANGELOG="CHANGELOG.md"
VERSIONED_FILES=("$PUBSPEC" "${PODSPECS[@]}")

# `pub publish` uploads what is on disk, not what is committed -- and that
# includes untracked files that no ignore rule covers. So require a fully clean
# tree, not just unmodified tracked files. Checking before anything is written
# also means the version files are the only thing this script has changed.
if [ -n "$(git status --porcelain)" ]; then
    echo "error: the working tree is not clean." >&2
    echo "       Commit, stash or ignore these first -- publishing uploads what is" >&2
    echo "       on disk, including untracked files." >&2
    git status --short >&2
    exit 1
fi

# --- work out the new version ------------------------------------------------

CURRENT="$(sed -n 's/^version:[[:space:]]*\(.*\)$/\1/p' "$PUBSPEC" | head -1)"
[ -n "$CURRENT" ] || { echo "error: no 'version:' line found in $PUBSPEC" >&2; exit 1; }

# Strip any -prerelease / +build suffix; a bump starts a fresh release.
CORE="${CURRENT%%[-+]*}"
SUFFIX="${CURRENT#"$CORE"}"

IFS=. read -r MAJOR MINOR PATCH <<EOF2
$CORE
EOF2
case "$MAJOR$MINOR$PATCH" in
    ''|*[!0-9]*) echo "error: cannot parse version '$CURRENT' as major.minor.patch" >&2; exit 1 ;;
esac

case "$LEVEL" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac
NEW="$MAJOR.$MINOR.$PATCH"

echo "==> $CURRENT -> $NEW ($LEVEL)"
[ -z "$SUFFIX" ] || echo "    note: dropping the '$SUFFIX' suffix from the current version"

# --- preflight ---------------------------------------------------------------

# pub.dev flags a release whose version is missing from the changelog, and it is
# easy to bump and forget. Check before editing anything.
ESCAPED="${NEW//./\\.}"
if ! grep -qE "^##[[:space:]]+v?${ESCAPED}([[:space:]]|$)" "$CHANGELOG"; then
    echo "error: $CHANGELOG has no '## $NEW' section." >&2
    echo "       Add the release notes for $NEW first, then re-run." >&2
    exit 1
fi

# --- write the version -------------------------------------------------------

write_file() { # write_file <path> <sed-expression>
    local file="$1" expr="$2" tmp
    tmp="$(mktemp)"
    sed "$expr" "$file" > "$tmp"
    mv "$tmp" "$file"
}

restore_versions() {
    git checkout -- "${VERSIONED_FILES[@]}" 2>/dev/null || true
}

write_file "$PUBSPEC" "s/^version:.*/version: $NEW/"
for podspec in "${PODSPECS[@]}"; do
    write_file "$podspec" "s/^\([[:space:]]*s\.version[[:space:]]*=[[:space:]]*\).*/\1'$NEW'/"
done

# Verify rather than trust the regexes: a silently missed podspec is how the
# version drifts out of sync in the first place.
for file in "${VERSIONED_FILES[@]}"; do
    if ! grep -q "$NEW" "$file"; then
        echo "error: failed to write version $NEW into $file" >&2
        restore_versions
        exit 1
    fi
    echo "    updated $file"
done

# From here on a failure leaves the version files modified, so say so.
trap 'echo "" >&2; echo "Publishing did not complete. Version files are still bumped to '"$NEW"'." >&2; echo "Restore them with: git checkout -- '"${VERSIONED_FILES[*]}"'" >&2' ERR

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

trap - ERR

if [ "$COMMIT" -eq 1 ]; then
    echo "==> Committing the version bump"
    git add -- "${VERSIONED_FILES[@]}"
    git commit -qm "chore: release $NEW"
    echo "    chore: release $NEW"
else
    echo ""
    echo "Note: pub will warn that pubspec.yaml and the podspecs are modified."
    echo "      That is this script's own version bump. Pass --commit to commit it"
    echo "      first and publish from a clean tree instead."
fi

PUBLISH_ARGS=()
[ "$DRY_RUN" -eq 1 ] && PUBLISH_ARGS+=(--dry-run)
[ "$FORCE" -eq 1 ] && PUBLISH_ARGS+=(--force)

echo ""
echo "==> flutter pub publish ${PUBLISH_ARGS[*]:-}"
# `pub publish` exits non-zero on warnings too, and for a dry run that is a
# result rather than a breakdown -- so capture the status instead of letting
# `set -e` abort, and clean up either way.
set +e
flutter pub publish ${PUBLISH_ARGS[@]+"${PUBLISH_ARGS[@]}"}
PUB_STATUS=$?
set -e

if [ "$DRY_RUN" -eq 1 ]; then
    restore_versions
    echo ""
    if [ "$PUB_STATUS" -eq 0 ]; then
        echo "Dry run passed. Nothing was published; the version files are back at $CURRENT."
    else
        echo "Dry run finished with warnings (exit $PUB_STATUS). Nothing was published;"
        echo "the version files are back at $CURRENT."
        echo ""
        echo "Expected here: the \"checked-in files are modified\" warning, which is this"
        echo "script's own version bump. Anything else in the output is worth reading."
    fi
    echo "Re-run without --dry-run to publish $NEW."
    exit "$PUB_STATUS"
fi

if [ "$PUB_STATUS" -ne 0 ]; then
    echo "" >&2
    echo "Publishing failed (exit $PUB_STATUS). Version $NEW is still written to:" >&2
    printf '  %s\n' "${VERSIONED_FILES[@]}" >&2
    if [ "$COMMIT" -eq 1 ]; then
        echo "and committed as 'chore: release $NEW'. Undo with: git reset --soft HEAD~1" >&2
    else
        echo "Restore them with: git checkout -- ${VERSIONED_FILES[*]}" >&2
    fi
    exit "$PUB_STATUS"
fi

echo ""
echo "Published $NEW."
if [ "$COMMIT" -eq 1 ]; then
    echo "Tag and push it:"
    echo "  git tag v$NEW && git push --follow-tags"
else
    echo "Commit and tag it:"
    echo "  git commit -am 'chore: release $NEW' && git tag v$NEW && git push --follow-tags"
fi
