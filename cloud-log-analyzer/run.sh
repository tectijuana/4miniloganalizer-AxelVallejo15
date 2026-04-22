#!/usr/bin/env bash
# Script de ejecución rápida para la variante base.
# Lee el archivo de ejemplo D y lo envía a stdin del analizador.

set -euo pipefail

if [[ ! -x ./analyzer ]]; then
  echo "[INFO] No existe ./analyzer o no tiene permisos de ejecución. Ejecutando make..."
  make
fi

if [[ $(uname -m) == "aarch64" ]]; then
  # Ejecución nativa en ARM64 (escenario esperado en AWS Ubuntu 24 ARM64).
  cat data/logs_A.txt | ./analyzer
elif command -v qemu-aarch64 >/dev/null 2>&1; then
  # Ejecución emulada para quienes trabajan en host x86_64.
  cat data/logs_D.txt | qemu-aarch64 ./analyzer
else
  echo "[ERROR] Este host no es ARM64 y no se encontró qemu-aarch64." >&2
  echo "        Ejecute esta práctica en AWS Ubuntu 24 ARM64." >&2
  exit 1
fi
