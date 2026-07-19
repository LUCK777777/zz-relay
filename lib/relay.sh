#!/usr/bin/env bash

list_forwards() {
  echo "当前转发："
  jq -r '
    (.route.rules // [])
    | .[]
    | select(.inbound and .outbound)
    | "\(.inbound | join(","))  ->  \(.outbound)"
  ' "$CONFIG"

  echo
  echo "当前落地："
  jq -r '
    .outbounds[]?
    | select(.type!="direct")
    | "\(.tag)  \(.type)  \(.server // "-"):\(.server_port // "-")"
  ' "$CONFIG"
}

add_ss_and_bind() {
  echo "添加 SS 落地并绑定到：$SELECTED_TAG / $SELECTED_PORT"
  echo
  echo "可以直接粘贴完整 ss:// 链接，也可以只输入 IP/域名。"
  echo

  read -rp "落地 tag，例如 ss-jp-out: " out_tag
  read -rp "SS 地址/IP 或完整 ss:// 链接: " server_input

  backup

  if [[ "$server_input" == ss://* ]]; then
    python3 - "$CONFIG" "$SELECTED_TAG" "$out_tag" "$server_input" <<'PY2'
import json, sys, base64, urllib.parse
from pathlib import Path

config, inbound_tag, out_tag, url = sys.argv[1:]

def b64decode_padding(s):
    s = s.replace('-', '+').replace('_', '/')
    s += '=' * (-len(s) % 4)
    return base64.b64decode(s).decode()

u = urllib.parse.urlsplit(url)

if u.scheme != "ss":
    raise SystemExit("不是 ss:// 链接")

host = u.hostname
port = u.port

if not host or not port:
    raise SystemExit("无法解析 server/port")

userinfo = u.username or ""
decoded = b64decode_padding(userinfo)

if ":" not in decoded:
    raise SystemExit("无法解析 method/password")

method, password = decoded.split(":", 1)

p = Path(config)
data = json.loads(p.read_text())

data.setdefault("outbounds", [])
data.setdefault("route", {})
data["route"].setdefault("rules", [])

if any(ob.get("tag") == out_tag for ob in data["outbounds"]):
    raise SystemExit(f"落地 tag 已存在: {out_tag}")

data["outbounds"].append({
    "type": "shadowsocks",
    "tag": out_tag,
    "server": host,
    "server_port": int(port),
    "method": method,
    "password": password
})

new_rules = []
for r in data["route"]["rules"]:
    inbound = r.get("inbound")
    if isinstance(inbound, list) and inbound_tag in inbound:
        inbound = [x for x in inbound if x != inbound_tag]
        if inbound:
            r["inbound"] = inbound
            new_rules.append(r)
    else:
        new_rules.append(r)

new_rules.append({
    "inbound": [inbound_tag],
    "outbound": out_tag
})

data["route"]["rules"] = new_rules

p.write_text(json.dumps(data, indent=2, ensure_ascii=False))

print(f"已添加并绑定: {inbound_tag} -> {out_tag}")
print(f"SS: {host}:{port}")
print(f"method: {method}")
PY2

  else
    read -rp "SS 端口: " port
    read -rp "加密方式，例如 2022-blake3-aes-256-gcm: " method
    read -rsp "密码: " password
    echo

    python3 - "$CONFIG" "$SELECTED_TAG" "$out_tag" "$server_input" "$port" "$method" "$password" <<'PY2'
import json, sys
from pathlib import Path

config, inbound_tag, out_tag, server, port, method, password = sys.argv[1:]
port = int(port)

p = Path(config)
data = json.loads(p.read_text())

data.setdefault("outbounds", [])
data.setdefault("route", {})
data["route"].setdefault("rules", [])

if any(ob.get("tag") == out_tag for ob in data["outbounds"]):
    raise SystemExit(f"落地 tag 已存在: {out_tag}")

data["outbounds"].append({
    "type": "shadowsocks",
    "tag": out_tag,
    "server": server,
    "server_port": port,
    "method": method,
    "password": password
})

new_rules = []
for r in data["route"]["rules"]:
    inbound = r.get("inbound")
    if isinstance(inbound, list) and inbound_tag in inbound:
        inbound = [x for x in inbound if x != inbound_tag]
        if inbound:
            r["inbound"] = inbound
            new_rules.append(r)
    else:
        new_rules.append(r)

new_rules.append({
    "inbound": [inbound_tag],
    "outbound": out_tag
})

data["route"]["rules"] = new_rules
p.write_text(json.dumps(data, indent=2, ensure_ascii=False))
print(f"已添加并绑定: {inbound_tag} -> {out_tag}")
PY2
  fi

  echo
  echo "SS 落地添加并绑定成功，正在自动检查配置并重启 sing-box..."
  check_restart_save
}

bind_existing() {
  echo "选择已有落地绑定到：$SELECTED_TAG / $SELECTED_PORT"
  echo

  jq -r '
    .outbounds[]?
    | select(.type!="direct")
    | "\(.tag)  \(.type)  \(.server // "-"):\(.server_port // "-")"
  ' "$CONFIG"

  echo
  read -rp "输入落地 tag: " out_tag

  backup

  python3 - "$CONFIG" "$SELECTED_TAG" "$out_tag" <<'PY'
import json, sys
from pathlib import Path

config, inbound_tag, out_tag = sys.argv[1:]

p = Path(config)
data = json.loads(p.read_text())

if not any(ob.get("tag") == out_tag for ob in data.get("outbounds", [])):
    raise SystemExit(f"找不到落地: {out_tag}")

data.setdefault("route", {})
data["route"].setdefault("rules", [])

new_rules = []
for r in data["route"]["rules"]:
    inbound = r.get("inbound")
    if isinstance(inbound, list) and inbound_tag in inbound:
        inbound = [x for x in inbound if x != inbound_tag]
        if inbound:
            r["inbound"] = inbound
            new_rules.append(r)
    else:
        new_rules.append(r)

new_rules.append({
    "inbound": [inbound_tag],
    "outbound": out_tag
})

data["route"]["rules"] = new_rules
p.write_text(json.dumps(data, indent=2, ensure_ascii=False))
print(f"已绑定: {inbound_tag} -> {out_tag}")
PY
}

remove_forward_for_node() {
  backup

  python3 - "$CONFIG" "$SELECTED_TAG" <<'PY'
import json, sys
from pathlib import Path

config, inbound_tag = sys.argv[1:]

p = Path(config)
data = json.loads(p.read_text())

rules = data.get("route", {}).get("rules", [])
new_rules = []

for r in rules:
    inbound = r.get("inbound")
    if isinstance(inbound, list) and inbound_tag in inbound:
        inbound = [x for x in inbound if x != inbound_tag]
        if inbound:
            r["inbound"] = inbound
            new_rules.append(r)
    else:
        new_rules.append(r)

data.setdefault("route", {})
data["route"]["rules"] = new_rules

p.write_text(json.dumps(data, indent=2, ensure_ascii=False))
print(f"已取消中转: {inbound_tag}")
PY
}

show_node_forward() {
  jq -r --arg tag "$SELECTED_TAG" '
    (.route.rules // [])
    | .[]
    | select(.inbound and (.inbound | index($tag)))
    | "\($tag) -> \(.outbound)"
  ' "$CONFIG"
}

delete_forward_menu() {
  mapfile -t RULES < <(
    jq -r '
      (.route.rules // [])
      | .[]
      | select(.inbound and .outbound)
      | "\(.inbound | join(","))        \(.outbound)"
    ' "$CONFIG"
  )

  if [[ ${#RULES[@]} -eq 0 ]]; then
    echo "当前没有转发规则"
    read -rp "按回车继续..."
    return
  fi

  echo "选择要删除的转发："
  for i in "${!RULES[@]}"; do
    echo "$((i+1))) ${RULES[$i]}"
  done

  echo
  read -rp "请选择: " idx

  if ! [[ "$idx" =~ ^[0-9]+$ ]] || ((idx < 1 || idx > ${#RULES[@]})); then
    echo "选择无效"
    read -rp "按回车继续..."
    return
  fi

  inbound=$(echo "${RULES[$((idx-1))]}" | cut -f1)
  outbound=$(echo "${RULES[$((idx-1))]}" | cut -f2)

  backup

  python3 - "$CONFIG" "$inbound" "$outbound" <<'PY'
import json, sys
from pathlib import Path

config, inbound_str, outbound = sys.argv[1:]
inbounds = inbound_str.split(",")

p = Path(config)
data = json.loads(p.read_text())

new_rules = []
for r in data.get("route", {}).get("rules", []):
    if r.get("inbound") == inbounds and r.get("outbound") == outbound:
        continue
    new_rules.append(r)

data.setdefault("route", {})
data["route"]["rules"] = new_rules

p.write_text(json.dumps(data, indent=2, ensure_ascii=False))
print(f"已删除: {inbound_str} -> {outbound}")
PY

  read -rp "按回车继续..."
}
