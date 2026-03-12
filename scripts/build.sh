#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p build

clang++ -O3 -std=c++17 \
  src/omtplayer.cpp \
  -I"$ROOT_DIR" \
  -L"$ROOT_DIR/lib" -lomt \
  -lSDL2 \
  -o build/omtplayer \
  -Wl,-rpath,'$ORIGIN'
