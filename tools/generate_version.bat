if not exist "%DUB_PACKAGE_DIR%\tmp" mkdir "%DUB_PACKAGE_DIR%\tmp"

if exist "%DUB_PACKAGE_DIR%\.git" (
  git describe --tags --always > "%DUB_PACKAGE_DIR%\tmp\version"
) else (
  echo unknown > "%DUB_PACKAGE_DIR%\tmp\version"
)
