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

### `leaf-functions`

Prints all leaf functions to standard out. A leaf function is a function that
doesn't call any other functions, or doesn't have a body.

#### Usage

```
$ cat test.d
void main()
{
}
$ dlp leaf-functions test.d
test.d:1:6: test.d.main
```

### `infer-attributes`

Prints the inferred attributes of all functions that are normally not inferred
by the compiler. These are regular functions and methods. Templates, nested
functions and lambdas are inferred by the compiler and will not be included by
this command

#### Usage

```
$ cat test.d
void main()
{
}
$ dlp infer-attributes test.d
test.d:1:6: main: pure nothrow @nogc @safe
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
