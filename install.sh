#!/usr/bin/env bash
set -e

PROJECT_NAME="zz-relay"
INSTALL_BIN="/usr/local/bin/zz"
INSTALL_LIB="/usr/local/lib/zz-relay"
DEFAULT_REPO="LUCK777777/zz-relay"
ZZ_REPO="${ZZ_REPO:-$DEFAULT_REPO}"
ZZ_REF="${ZZ_REF:-main}"

log() {
  printf '[%s] %s\n' "$PROJECT_NAME" "$*"
}

die() {
  printf '[%s] 错误: %s\n' "$PROJECT_NAME" "$*" >&2
  exit 1
}

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  die "请使用 root 用户运行安装脚本"
fi

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
LOCAL_SOURCE=0
if [[ -f "$SOURCE_DIR/zz" && -d "$SOURCE_DIR/lib" ]]; then
  LOCAL_SOURCE=1
fi

install_dependencies() {
  local packages=()

  command -v jq >/dev/null 2>&1 || packages+=(jq)
  command -v python3 >/dev/null 2>&1 || packages+=(python3)
  command -v ss >/dev/null 2>&1 || packages+=(iproute2)

  if [[ ${#packages[@]} -eq 0 ]]; then
    return
  fi

  command -v apt-get >/dev/null 2>&1 || \
    die "缺少依赖: ${packages[*]}，且系统没有 apt-get"

  log "安装缺少的依赖: ${packages[*]}"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
}

download_file() {
  local url="$1"
  local destination="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$destination"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$destination" "$url"
  else
    die "远程安装需要 curl 或 wget"
  fi
}

validate_source_tree() {
  local source_root="$1"
  local file

  for file in \
    zz \
    lib/utils.sh \
    lib/backup.sh \
    lib/node.sh \
    lib/relay.sh \
    lib/config.sh \
    lib/menu.sh \
    VERSION; do
    [[ -s "$source_root/$file" ]] || die "项目文件不存在或为空: $file"
  done

  bash -n "$source_root/zz"
  for file in utils backup node relay config menu; do
    bash -n "$source_root/lib/$file.sh"
  done
}

copy_project_files() {
  local source_root="$1"

  install -d -m 0755 "$INSTALL_LIB"
  install -m 0755 "$source_root/zz" "$INSTALL_BIN"
  install -m 0644 "$source_root/lib/utils.sh" "$INSTALL_LIB/utils.sh"
  install -m 0644 "$source_root/lib/backup.sh" "$INSTALL_LIB/backup.sh"
  install -m 0644 "$source_root/lib/node.sh" "$INSTALL_LIB/node.sh"
  install -m 0644 "$source_root/lib/relay.sh" "$INSTALL_LIB/relay.sh"
  install -m 0644 "$source_root/lib/config.sh" "$INSTALL_LIB/config.sh"
  install -m 0644 "$source_root/lib/menu.sh" "$INSTALL_LIB/menu.sh"
  install -m 0644 "$source_root/VERSION" "$INSTALL_LIB/VERSION"
}

if [[ $LOCAL_SOURCE -eq 1 ]]; then
  source_root="$SOURCE_DIR"
  log "使用本地项目目录"
else
  temp_dir="$(mktemp -d)"
  cleanup() {
    rm -f "$temp_dir/lib/utils.sh"
    rm -f "$temp_dir/lib/backup.sh"
    rm -f "$temp_dir/lib/node.sh"
    rm -f "$temp_dir/lib/relay.sh"
    rm -f "$temp_dir/lib/config.sh"
    rm -f "$temp_dir/lib/menu.sh"
    rm -f "$temp_dir/zz"
    rm -f "$temp_dir/VERSION"
    rmdir "$temp_dir/lib" 2>/dev/null || true
    rmdir "$temp_dir" 2>/dev/null || true
  }
  trap cleanup EXIT

  mkdir -p "$temp_dir/lib"
  base_url="https://raw.githubusercontent.com/$ZZ_REPO/$ZZ_REF"

  log "从 $ZZ_REPO@$ZZ_REF 下载项目文件"
  download_file "$base_url/zz" "$temp_dir/zz"
  download_file "$base_url/lib/utils.sh" "$temp_dir/lib/utils.sh"
  download_file "$base_url/lib/backup.sh" "$temp_dir/lib/backup.sh"
  download_file "$base_url/lib/node.sh" "$temp_dir/lib/node.sh"
  download_file "$base_url/lib/relay.sh" "$temp_dir/lib/relay.sh"
  download_file "$base_url/lib/config.sh" "$temp_dir/lib/config.sh"
  download_file "$base_url/lib/menu.sh" "$temp_dir/lib/menu.sh"
  download_file "$base_url/VERSION" "$temp_dir/VERSION"
  source_root="$temp_dir"
fi

validate_source_tree "$source_root"
install_dependencies

if [[ -e "$INSTALL_BIN" ]]; then
  old_backup="${INSTALL_BIN}.pre-${PROJECT_NAME}-$(date +%Y%m%d-%H%M%S)"
  cp -a "$INSTALL_BIN" "$old_backup"
  log "已备份原入口: $old_backup"
fi

copy_project_files "$source_root"

bash -n "$INSTALL_BIN"
for file in utils backup node relay config menu; do
  bash -n "$INSTALL_LIB/$file.sh"
done
[[ -s "$INSTALL_LIB/VERSION" ]] || die "安装后的 VERSION 文件为空"

log "安装完成"
log "运行 zz 打开中转管理菜单"
