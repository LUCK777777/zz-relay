#!/usr/bin/env bash

backup() {
  cp "$CONFIG" "$CONFIG.zz-bak-$(date +%Y%m%d-%H%M%S)"
}
