# DLP Changelog

## Unreleased

### New/Changed Features

* Add new command, `infer-attributes`, which will infer the attributes of all
regular functions.
* Added a flag, `--string-import-path`, which will add the given path as a
string import path

## 0.1.0
### New/Changed Features

* Added a flag, `--frontend-version`, which will print the version of the
frontend DLP is using
* Updated the D frontend DLP is using to DMD 2.085.0+ ([dd94ef465](https://github.com/dlang/dmd/commit/dd94ef465342d47a94f6c587638c49ce42f54590))
* New formatting of locations

### `leaf-functions`

#### New/Changed Features

* Added a flag, `--import-path`/`-i`, which will add the given path as an import
path

#### Bugs Fixed

* [Issue 1](https://github.com/jacob-carlborg/dlp/issues/1): No error if no input files are given

## 0.0.1

Initial release.
