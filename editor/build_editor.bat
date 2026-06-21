@echo off
if not exist bin mkdir bin
odin build ./../editor -debug -out:bin/editor_debug.exe
