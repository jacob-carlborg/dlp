#!/usr/bin/env bash

set -eu
set -o pipefail

source ../../tools/install_dc.sh

function print_d_compiler_version {
  "${DMD}" --version
}

function run_tests {
  dub test --verror --compiler="${DMD}" --arch="${DLP_ARCH}"
}

install_compiler
print_d_compiler_version
run_tests
