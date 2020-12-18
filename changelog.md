# DLP Changelog

## 0.3.0

### New/Changed Features

* Add support for FreeBSD
* Updated the D frontend DLP is using to DMD 2.094.1
* Add new command, `infer-attributes`, which will infer the attributes of all
regular functions
* Added a flag, `--string-import-path`, for all commands, which will add the
given path as a string import path
* Added a flag, `--version`, for all commands, which will set the given string
as a version identifier

#### Bugs Fixed

* [Issue 3](https://github.com/jacob-carlborg/dlp/issues/3): Segmentation fault when processing out contract

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
