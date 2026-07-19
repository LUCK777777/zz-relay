#!/usr/bin/env bash

show_recent_service_logs() {
  echo
  echo "最近的 sing-box 服务日志："
  journalctl -u "$SING_BOX_SERVICE" -n 50 --no-pager -o cat 2>/dev/null || true
}

check_restart_save() {
  echo "检查主配置和 233boy conf 目录的合并结果..."
  if ! "$CORE" check -c "$CONFIG" -C "$CONF_DIR"; then
    echo "配置检查失败，未重启 sing-box。" >&2
    return 1
  fi

  if ! systemctl restart "$SING_BOX_SERVICE"; then
    echo "sing-box 重启失败。" >&2
    show_recent_service_logs
    return 1
  fi

  sleep 1
  if ! systemctl is-active --quiet "$SING_BOX_SERVICE"; then
    echo "sing-box 重启后没有保持运行。" >&2
    show_recent_service_logs
    return 1
  fi

  cp "$CONFIG" "$FINAL_CONFIG"
  echo "已检查合并配置、重启服务，并保存当前主配置。"
  ss -tulnp | grep sing-box || true
}
