#!/usr/bin/env bash
# Everything this mirror knows about its upstream lives in this file. The
# updater workflow calls these three commands and publishes whatever
# `download` leaves in the directory:
#
#   fetch.sh version               print the newest upstream version
#   fetch.sh download VERSION DIR  download and verify every file of VERSION into DIR
#   fetch.sh notes VERSION         print the release notes of VERSION
#
# Only the three command bodies are upstream-specific. The helpers below them
# carry the rules every mirror shares.

set -euo pipefail

# Print the newest upstream version, for example:
#   latest=$(curl -fsSL https://example.com/releases/latest)
#   require_version "$latest"
version() {
    not_implemented
}

# Download every file of version $1 into directory $2, verifying each one
# against the checksum the upstream publishes, for example:
#   mkdir -p "$2"
#   download_file "https://example.com/releases/$1/tool-linux-x64" "$2/tool-$1-linux-x64" "$sha256"
# Every file in $2 becomes a release asset under its file name, so keep the
# names unique, stable across versions, and carrying the version.
download() {
    not_implemented
}

# Print the release notes of version $1, for example:
#   changelog_section https://example.com/CHANGELOG.md "## $1" https://example.com/changelog
notes() {
    not_implemented
}

# Prints $1 if it looks like a version. An error page served with 200 must
# not become a tag.
require_version() {
    if [[ ! $1 =~ ^v?[0-9]+(\.[0-9]+)*([-+][0-9A-Za-z.-]+)?$ ]]; then
        echo "Unexpected upstream version: $1" >&2
        exit 1
    fi
    echo "$1"
}

# Downloads URL $1 to FILE $2 and, given SHA-256 $3, verifies it. Any failure
# exits, so a partial release is never published.
download_file() {
    echo "Downloading $1"
    curl -fsSL -o "$2" "$1"
    if [[ -n ${3:-} ]]; then
        echo "$3  $2" | sha256sum -c --quiet
    fi
}

# Prints what sits under HEADING $2, an exact line such as "## 1.2.3", in the
# Markdown changelog at URL $1, up to the next heading of the same level or
# higher; or a pointer to LINK $3 when the changelog has no such heading yet.
changelog_section() {
    local section
    # Reads the whole file: stopping early would kill curl with SIGPIPE.
    section=$(curl -fsSL "$1" | awk -v heading="$2" '
        BEGIN { match(heading, /^#+/); level = RLENGTH }
        match($0, /^#+ /) && RLENGTH - 1 <= level { found = ($0 == heading); next }
        found')
    echo "${section:-See $3}"
}

not_implemented() {
    echo "fetch.sh: ${FUNCNAME[1]} is not implemented for this upstream yet" >&2
    exit 1
}

case "${1:-}" in
    version | download | notes) "$@" ;;
    *)
        echo "Usage: $0 version | download VERSION DIR | notes VERSION" >&2
        exit 1
        ;;
esac
