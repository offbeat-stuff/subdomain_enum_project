#!/bin/sh
mkdir -p bin && nim c -d:ssl -o:bin/main src/main.nim
