#!/usr/bin/env bash

check_restart_save() {
  "$CORE" check -c "$CONFIG"
  systemctl restart "$SING_BOX_SERVICE"
  sleep 1
  cp "$CONFIG" "$FINAL_CONFIG"
  echo "已检查、重启，并保存当前配置。"
  ss -tulnp | grep sing-box || true
}
