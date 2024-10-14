#!/usr/bin/env -S just --justfile
# just reference  : https://just.systems/man/en/

# @default:
#     just --list

DFLAGS := "-O3 --no-source-maps"

alias run     := release
alias default := build

# Build project
build:
    @dart compile js src/main.dart -o index.js

# Build in release mode
release:
    #!/bin/bash
    rm index.js.map
    dart compile js src/main.dart -o index.js {{DFLAGS}}
    rm index.js.deps

