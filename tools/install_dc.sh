d_compiler() {
  case "${DLP_COMPILER}" in
    'dmd-latest') echo 'dmd' ;;
    'ldc-latest') echo 'ldc' ;;
    'dmd-master') echo 'dmd-nightly' ;;
    'ldc-master') echo 'ldc-latest-ci' ;;
    *) echo "${DLP_COMPILER}" ;;
  esac
}

install_compiler() {
  if [ "$(uname)" = 'FreeBSD' ]; then
    local compiler="$(d_compiler)"
    curl -sS -L https://github.com/dlang/installer/raw/d97cec87e464a703c44128d72c9ba89576df6e5c/script/install.sh | bash -s "${compiler}"
    source "$(~/dlang/install.sh "${compiler}" -a)"
  else
    export DMD="$([ "$DC" = 'ldc2' ] && echo 'ldmd2' || echo 'dmd')"
  fi
}
