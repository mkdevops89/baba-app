#!/usr/bin/env zsh
set -e
SCRIPT_DIR=${0:A:h}
cd "$SCRIPT_DIR/../backend"
mvn spring-boot:run
