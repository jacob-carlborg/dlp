# DLP - D Language Processing

DLP is a tool collecting commands/tasks related to processing the
D programming language. It uses the DMD frontend as a library to process D code.

## Requirements

To run this tool you need to have druntime and Phobos installed. This is easiest
accomplished by installing the DMD compiler: https://dlang.org/download.html.

## Download

For the latest release see: [releases/latest](https://github.com/jacob-carlborg/dlp/releases/latest).
Pre-compiled binaries are available for macOS and Linux as 64 bit binaries and
Windows as 32 and 64 bit binaries. The Linux binaries are completely statically
linked and should work on all distros. The macOS binaries should work on macOS
Mavericks (10.9) and later.

## Commands

* **leaf-functions** - Prints all leaf functions to standard out. A leaf
  function is a function that doesn't call any other functions, or doesn't have
  a body.

### Usage

```
$ cat test.d
void main()
{
}
$ dlp leaf-functions test
test.d(1): test.d.main
```

## Building

Building is done using Dub.

1. Clone the repository using:
    ```
    git clone --recursive https://github.com/jacob-carlborg/dlp.git
    ```
1. Run `dub build` to build the project

## Running the Tests

Running the tests is done using Dub.

1. Clone the repository using:
    ```
    git clone --recursive https://github.com/jacob-carlborg/dlp.git
    ```
1. Run `dub test` to run the tests
