#!/bin/sh

set -e

mkdir -p "$DUB_PACKAGE_DIR/tmp"

if [ -d "$DUB_PACKAGE_DIR/.git" ]; then
  git describe --tags --always > "$DUB_PACKAGE_DIR/tmp/version"
else
  echo 'unknown' > "$DUB_PACKAGE_DIR/tmp/version"
fi
