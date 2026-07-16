#!/usr/bin/env bash
set -e

INSTALL_BIN="/usr/local/bin/zz"
INSTALL_LIB="/usr/local/lib/zz-relay"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "zz-relay: 请使用 root 用户运行卸载脚本" >&2
  exit 1
fi

rm -f "$INSTALL_BIN"
rm -f "$INSTALL_LIB/utils.sh"
rm -f "$INSTALL_LIB/backup.sh"
rm -f "$INSTALL_LIB/node.sh"
rm -f "$INSTALL_LIB/relay.sh"
rm -f "$INSTALL_LIB/config.sh"
rm -f "$INSTALL_LIB/menu.sh"
rm -f "$INSTALL_LIB/VERSION"
rmdir "$INSTALL_LIB" 2>/dev/null || true

echo "zz-relay 已卸载。"
echo "未删除 /etc/sing-box 下的配置、节点、备份或保存文件。"
echo "安装时生成的 /usr/local/bin/zz.pre-zz-relay-* 备份也会保留。"
