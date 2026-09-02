#!/usr/bin/env zsh
set -e
SCRIPT_DIR=${0:A:h}
cd "$SCRIPT_DIR/../frontend"
[[ -f .env.local ]] || cp .env.example .env.local
npm install
npm run dev
