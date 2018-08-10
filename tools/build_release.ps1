Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

$appName="dlp"
$targetDir="."
$targetPath="$targetDir/$appName.exe"

function Build
{
  dub build --verror -b release
}

function Version
{
  Invoke-Expression "$targetPath --version"
}

function Arch
{
  if ($env:PLATFORM -eq 'x86') { '32' } else { '64' }
}

function ReleaseName
{
  "$appName-$(Version)-win$(Arch)"
}

function Archive
{
  7z a "$(ReleaseName).7z" "$targetPath"
}

Build
Archive
