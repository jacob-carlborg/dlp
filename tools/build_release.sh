#!/bin/bash

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
  else
    uname -m
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

function release_name {
  local release_name="$app_name-$(version)-$(os)"

  if [ "$(os)" = 'macos' ]; then
    echo "$release_name"
  elif [ "$(os)" = 'win' ]; then
    echo "${release_name}$(arch)"
  else
    echo "$release_name-$(arch)"
  fi
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
