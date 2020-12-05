#!/usr/bin/env bash

set -eu
set -o pipefail

. ./install_dc.sh

build() {
  dub build --verror -b release --compiler="${DMD}" --arch="${DLP_ARCH}"
  strip "$target_path"
}

version() {
  "$target_path" --version
}

arch() {
  if [ "$(os)" = 'win' ]; then
    [ "$ARCH" = 'x86' ] && echo '32' || echo '64'
  elif [ "$(os)" = 'darwin' ]; then
    echo ''
  else
    echo "-$(uname -m)"
  fi
}

os() {
  local os=$(uname | tr '[:upper:]' '[:lower:]')

  if [ "$os" = 'darwin' ]; then
    echo 'macos'
  elif echo "$os" | grep -i -q mingw; then
    echo 'win'
  else
    echo "$os"
  fi
}

os_version() {
  if [ "$(os)" = 'freebsd' ]; then
    freebsd-version | cut -d . -f 1
  else
    echo ''
  fi
}

release_name() {
  echo "$app_name-$(version)-$(os)$(os_version)$(arch)"
}

archive() {
  if [ "$(os)" = 'win' ]; then
    7z a "$(release_name).7z" "$target_path"
  else
    tar Jcf "$(release_name).tar.xz" -C "$target_dir" "$app_name"
  fi
}

app_name="dlp"
target_dir="."
extension=$([ "$(os)" = 'win' ] && echo '.exe' || echo '')
target_path="${target_dir}/${app_name}${extension}"

install_compiler
build
archive
