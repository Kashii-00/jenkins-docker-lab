#!/usr/bin/env bash
set -euo pipefail

test -s index.html
grep -qi '<html' index.html
grep -qi '<h1>' index.html

test -s Dockerfile
grep -Eq '^FROM[[:space:]]+nginx:' Dockerfile

echo "Static website tests passed"