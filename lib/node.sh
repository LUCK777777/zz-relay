#!/usr/bin/env bash

sync_nodes() {
  if ! backup; then
    echo "主配置备份失败，已取消同步。" >&2
    return 1
  fi

  if ! python3 - "$CONFIG" "$CONF_DIR" <<'PY'
import json
import os
import sys
import tempfile
from collections import Counter
from pathlib import Path

main_path = Path(sys.argv[1])
conf_dir = Path(sys.argv[2])

if not main_path.is_file():
    raise SystemExit(f"主配置不存在: {main_path}")
if not conf_dir.is_dir():
    raise SystemExit(f"233boy 节点目录不存在: {conf_dir}")

try:
    main = json.loads(main_path.read_text())
except (OSError, json.JSONDecodeError) as exc:
    raise SystemExit(f"无法读取主配置 {main_path}: {exc}")

conf_files = sorted(conf_dir.glob("*.json"))
if not conf_files:
    raise SystemExit(f"没有找到 233boy 节点配置: {conf_dir}/*.json")

nodes = []
tags = []
for filename in conf_files:
    try:
        data = json.loads(filename.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"无法读取节点配置 {filename}: {exc}")

    inbounds = data.get("inbounds", [])
    if not isinstance(inbounds, list):
        raise SystemExit(f"节点配置的 inbounds 不是数组: {filename}")

    for inbound in inbounds:
        if not isinstance(inbound, dict):
            raise SystemExit(f"节点配置包含无效 inbound: {filename}")
        tag = inbound.get("tag")
        if not isinstance(tag, str) or not tag:
            raise SystemExit(f"节点配置包含缺少 tag 的 inbound: {filename}")
        nodes.append(inbound)
        tags.append(tag)

duplicates = sorted(tag for tag, count in Counter(tags).items() if count > 1)
if duplicates:
    raise SystemExit("233boy conf 目录存在重复 inbound tag: " + ", ".join(duplicates))

# 233boy 的 systemd 服务会同时加载 config.json 和 conf/*.json。
# 主配置只能保留公共配置、出站和路由；把入口复制到这里会导致 duplicate inbound tag。
had_main_inbounds = "inbounds" in main
removed = len(main.get("inbounds", [])) if isinstance(main.get("inbounds"), list) else 0
main.pop("inbounds", None)

if had_main_inbounds:
    mode = main_path.stat().st_mode
    fd, temp_name = tempfile.mkstemp(prefix=main_path.name + ".", suffix=".tmp", dir=main_path.parent)
    try:
        with os.fdopen(fd, "w") as temp_file:
            json.dump(main, temp_file, indent=2, ensure_ascii=False)
            temp_file.write("\n")
        os.chmod(temp_name, mode)
        os.replace(temp_name, main_path)
    except Exception:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise

vless_count = sum(1 for node in nodes if node.get("type") == "vless")
print(f"已扫描 233boy 节点: {len(nodes)}（VLESS: {vless_count}）")
if had_main_inbounds:
    print(f"已从主配置移除入口字段（入口数: {removed}）")
else:
    print("主配置未包含入口，无需清理。")
print("节点继续由 /etc/sing-box/conf/*.json 加载，不会复制到主配置。")
PY
  then
    echo "同步 233boy 节点失败，未重启 sing-box。" >&2
    return 1
  fi

  echo
  echo "节点同步完成，正在自动检查配置并重启 sing-box..."
  check_restart_save
}

choose_vless() {
  mapfile -t NODES < <(
    python3 - "$CONF_DIR" <<'PY'
import json
import sys
from pathlib import Path

conf_dir = Path(sys.argv[1])
if not conf_dir.is_dir():
    raise SystemExit(f"233boy 节点目录不存在: {conf_dir}")

for filename in sorted(conf_dir.glob("*.json")):
    try:
        data = json.loads(filename.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        print(f"跳过无法读取的节点配置 {filename}: {exc}", file=sys.stderr)
        continue

    for inbound in data.get("inbounds", []):
        if not isinstance(inbound, dict) or inbound.get("type") != "vless":
            continue

        tag = inbound.get("tag", "-")
        port = inbound.get("listen_port", "-")
        tls = inbound.get("tls") or {}
        reality = tls.get("reality") or {}
        handshake = reality.get("handshake") or {}
        sni = tls.get("server_name") or handshake.get("server") or "-"
        print(f"{tag}\t{port}\t{sni}")
PY
  )

  if [[ ${#NODES[@]} -eq 0 ]]; then
    echo "没有找到 VLESS 节点。先用 sb 创建节点，再回到 zz。"
    return 1
  fi

  echo "选择 VLESS 节点："
  for i in "${!NODES[@]}"; do
    n=$((i+1))
    tag=$(echo "${NODES[$i]}" | cut -f1)
    port=$(echo "${NODES[$i]}" | cut -f2)
    sni=$(echo "${NODES[$i]}" | cut -f3)
    echo "$n) $tag  端口:$port  SNI:$sni"
  done

  echo
  read -rp "请选择: " idx

  if ! [[ "$idx" =~ ^[0-9]+$ ]] || ((idx < 1 || idx > ${#NODES[@]})); then
    echo "选择无效"
    return 1
  fi

  SELECTED_TAG=$(echo "${NODES[$((idx-1))]}" | cut -f1)
  SELECTED_PORT=$(echo "${NODES[$((idx-1))]}" | cut -f2)
}
