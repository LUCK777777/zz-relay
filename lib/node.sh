#!/usr/bin/env bash

sync_nodes() {
  backup
  python3 - "$CONFIG" "$CONF_DIR" <<'PY'
import glob
import json
import sys
from pathlib import Path

main_path = Path(sys.argv[1])
conf_dir = Path(sys.argv[2])
main = json.loads(main_path.read_text())

old_outbounds = main.get("outbounds", [])
old_route = main.get("route", {})
old_dns = main.get("dns", {})
old_log = main.get("log", {})

inbounds = []

for filename in sorted(glob.glob(str(conf_dir / "*.json"))):
    data = json.loads(Path(filename).read_text())
    for inbound in data.get("inbounds", []):
        inbounds.append(inbound)

main["inbounds"] = inbounds
main["outbounds"] = old_outbounds
main["route"] = old_route
main["dns"] = old_dns
main["log"] = old_log

main_path.write_text(json.dumps(main, indent=2, ensure_ascii=False))
print(f"已同步 VLESS/SS 节点: {len(inbounds)}")
PY
}

choose_vless() {
  mapfile -t NODES < <(
    jq -r '
      .inbounds[]?
      | select(.type=="vless")
      | [.tag, .listen_port, (.tls.server_name // "-")]
      | @tsv
    ' "$CONFIG"
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
