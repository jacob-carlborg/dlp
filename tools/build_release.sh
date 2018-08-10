#!/bin/bash

set -ex

function build {
  dub build --verror -b release
  strip "$target_path"
}

function version {
  "$target_path" --version
}

function arch {
  uname -m
}

function os {
  local os=$(uname | tr '[:upper:]' '[:lower:]')
  [ "$os" = 'darwin' ] && echo 'macos' || echo "$os"
}

function release_name {
  local release_name="$app_name-$(version)-$(os)"

  if [ "$(os)" = 'macos' ]; then
    echo "$release_name"
  else
    echo "$release_name-$(arch)"
  fi
}

function archive {
  tar Jcf "$(release_name).tar.xz" -C "$target_dir" "$app_name"
}

app_name="dlp"
target_dir="."
target_path="$target_dir/$app_name"

build
archive
