#!/usr/bin/env bash

CONFIG="${ZZ_CONFIG:-/etc/sing-box/config.json}"
CONF_DIR="${ZZ_CONF_DIR:-/etc/sing-box/conf}"
CORE="${ZZ_CORE:-/etc/sing-box/bin/sing-box}"
SING_BOX_SERVICE="${ZZ_SING_BOX_SERVICE:-sing-box}"
FINAL_CONFIG="${ZZ_FINAL_CONFIG:-/etc/sing-box/config.json.final-working-old-nodes}"

SELECTED_TAG="${SELECTED_TAG:-}"
SELECTED_PORT="${SELECTED_PORT:-}"
