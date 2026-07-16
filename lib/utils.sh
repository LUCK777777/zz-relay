#!/usr/bin/env bash

CONFIG="${ZZ_CONFIG:-/etc/sing-box/config.json}"
CONF_DIR="${ZZ_CONF_DIR:-/etc/sing-box/conf}"
if [[ -n "${ZZ_CORE:-}" ]]; then
  CORE="$ZZ_CORE"
elif [[ -x /etc/sing-box/bin/sing-box ]]; then
  CORE="/etc/sing-box/bin/sing-box"
elif [[ -x /usr/local/bin/sing-box ]]; then
  CORE="/usr/local/bin/sing-box"
elif command -v sing-box >/dev/null 2>&1; then
  CORE="$(command -v sing-box)"
else
  CORE="/etc/sing-box/bin/sing-box"
fi
SING_BOX_SERVICE="${ZZ_SING_BOX_SERVICE:-sing-box}"
FINAL_CONFIG="${ZZ_FINAL_CONFIG:-/etc/sing-box/config.json.final-working-old-nodes}"

SELECTED_TAG="${SELECTED_TAG:-}"
SELECTED_PORT="${SELECTED_PORT:-}"
