#!/usr/bin/env bash

set -e

function build {
  dub build --verror -b release
  strip "$target_path"
}

function version {
  "$target_path" --version
}

function arch {
  if [ "$(os)" = 'win' ]; then
    [ "$ARCH" = 'x86' ] && echo '32' || echo '64'
  elif [ "$(os)" = 'darwin' ]; then
    echo ''
  else
    echo "-$(uname -m)"
  fi
}

function os {
  local os=$(uname | tr '[:upper:]' '[:lower:]')

  if [ "$os" = 'darwin' ]; then
    echo 'macos'
  elif echo "$os" | grep -i -q mingw; then
    echo 'win'
  else
    echo "$os"
  fi
}

function os_version {
  if [ "$(os)" = 'freebsd' ]; then
    freebsd-version | cut -d . -f 1
  else
    echo ''
  fi
}

function release_name {
  echo "$app_name-$(version)-$(os)$(os_version)$(arch)"
}

function archive {
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

build
archive
