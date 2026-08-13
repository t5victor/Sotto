#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
INFO_PLIST="$PROJECT_ROOT/Sources/Sotto/Resources/Info.plist"
CASK_PATH="$PROJECT_ROOT/Casks/sotto.rb"
CHANGELOG_PATH="$PROJECT_ROOT/CHANGELOG.md"

next_version() {
  local current_version="$1"
  if [[ ! "$current_version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 "Invalid semantic version: $current_version"
    return 1
  fi

  typeset major minor patch
  IFS=. read -r major minor patch <<< "$current_version"

  if (( patch < 10 )); then
    (( patch += 1 ))
  elif (( minor < 10 )); then
    (( minor += 1 ))
    patch=0
  else
    (( major += 1 ))
    minor=0
    patch=0
  fi

  print -- "${major}.${minor}.${patch}"
}

if [[ "${1:-}" == "--next" ]]; then
  if (( $# != 2 )); then
    print -u2 "Usage: $0 --next CURRENT_VERSION"
    exit 1
  fi
  next_version "$2"
  exit 0
fi

CURRENT_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
CASK_VERSION="$(perl -ne 'if (/^\s*version\s+"([^"]+)"/) { print "$1\n"; exit }' "$CASK_PATH")"
if [[ "$CASK_VERSION" != "$CURRENT_VERSION" ]]; then
  print -u2 "Cask version $CASK_VERSION does not match app version $CURRENT_VERSION"
  exit 1
fi

NEXT_VERSION="$(next_version "$CURRENT_VERSION")"
RELEASE_TAG="cask-$NEXT_VERSION"
RELEASE_DATE="$(date +%Y-%m-%d)"

plutil -replace CFBundleShortVersionString -string "$NEXT_VERSION" "$INFO_PLIST"
plutil -replace CFBundleVersion -string "$NEXT_VERSION" "$INFO_PLIST"

SOTTO_NEXT_VERSION="$NEXT_VERSION" perl -0pi -e \
  's/^(\s*version\s+")[^"]+("\s*)/$1$ENV{SOTTO_NEXT_VERSION}$2/m' \
  "$CASK_PATH"

if [[ "$(sed -n '1p' "$CHANGELOG_PATH")" != "# Changelog" ]]; then
  print -u2 "Unexpected CHANGELOG.md header"
  exit 1
fi

temporary_changelog="$(mktemp "${TMPDIR:-/tmp}/sotto-changelog.XXXXXX")"
trap 'rm -f "$temporary_changelog"' EXIT
{
  print -r -- "# Changelog"
  print -r --
  print -r -- "## $NEXT_VERSION — $RELEASE_DATE"
  print -r --
  print -r -- "- Published automated Homebrew release."
  print -r --
  sed '1,2d' "$CHANGELOG_PATH"
} > "$temporary_changelog"
mv "$temporary_changelog" "$CHANGELOG_PATH"
trap - EXIT

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  print "version=$NEXT_VERSION" >> "$GITHUB_OUTPUT"
  print "release_tag=$RELEASE_TAG" >> "$GITHUB_OUTPUT"
fi

print -r -- "Sotto version: $CURRENT_VERSION -> $NEXT_VERSION"
