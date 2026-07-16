#!/usr/bin/env bash
set -e

PROJECT_NAME="zz-relay"
INSTALL_BIN="/usr/local/bin/zz"
INSTALL_LIB="/usr/local/lib/zz-relay"
DEFAULT_REPO="LUCK777777/zz-relay"
ZZ_REPO="${ZZ_REPO:-$DEFAULT_REPO}"
ZZ_REF="${ZZ_REF:-main}"
UPSTREAM_233BOY_INSTALL_URL="${ZZ_233BOY_INSTALL_URL:-https://raw.githubusercontent.com/233boy/sing-box/main/install.sh}"
ZZ_ONLY=0
TEMP_DIR=""
SOURCE_ROOT=""

log() {
  printf '[%s] %s\n' "$PROJECT_NAME" "$*"
}

die() {
  printf '[%s] 错误: %s\n' "$PROJECT_NAME" "$*" >&2
  exit 1
}

show_help() {
  cat <<'HELP'
用法：
  sudo bash install.sh [选项]

默认行为：
  1. 未检测到 233boy 时，下载并原样执行其官方 install.sh
  2. 已检测到 233boy 时，跳过上游安装
  3. 安装 zz，但不自动启动 zz

选项：
  --zz-only   只安装 zz，跳过 233boy 检测和安装
  -h, --help  显示帮助

可选环境变量：
  ZZ_REPO                 zz 的 GitHub 仓库，默认 LUCK777777/zz-relay
  ZZ_REF                  zz 的分支或标签，默认 main
  ZZ_233BOY_INSTALL_URL   233boy 官方安装脚本地址
HELP
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --zz-only)
        ZZ_ONLY=1
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        die "未知参数: $1（使用 --help 查看帮助）"
        ;;
    esac
    shift
  done
}

cleanup() {
  [[ -n "$TEMP_DIR" ]] || return 0

  rm -f -- "$TEMP_DIR/lib/utils.sh"
  rm -f -- "$TEMP_DIR/lib/backup.sh"
  rm -f -- "$TEMP_DIR/lib/node.sh"
  rm -f -- "$TEMP_DIR/lib/relay.sh"
  rm -f -- "$TEMP_DIR/lib/config.sh"
  rm -f -- "$TEMP_DIR/lib/menu.sh"
  rm -f -- "$TEMP_DIR/zz"
  rm -f -- "$TEMP_DIR/VERSION"
  rm -f -- "$TEMP_DIR/233boy-install.sh"
  rmdir -- "$TEMP_DIR/lib" 2>/dev/null || true
  rmdir -- "$TEMP_DIR" 2>/dev/null || true
}

prepare_temp_dir() {
  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zz-relay.XXXXXX")"
  trap cleanup EXIT
}

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

prepare_source_tree() {
  local source_dir
  local base_url

  source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
  if [[ -f "$source_dir/zz" && -d "$source_dir/lib" ]]; then
    SOURCE_ROOT="$source_dir"
    log "使用本地项目目录"
    return
  fi

  mkdir -p "$TEMP_DIR/lib"
  base_url="https://raw.githubusercontent.com/$ZZ_REPO/$ZZ_REF"

  log "从 $ZZ_REPO@$ZZ_REF 下载 zz 项目文件"
  download_file "$base_url/zz" "$TEMP_DIR/zz"
  download_file "$base_url/lib/utils.sh" "$TEMP_DIR/lib/utils.sh"
  download_file "$base_url/lib/backup.sh" "$TEMP_DIR/lib/backup.sh"
  download_file "$base_url/lib/node.sh" "$TEMP_DIR/lib/node.sh"
  download_file "$base_url/lib/relay.sh" "$TEMP_DIR/lib/relay.sh"
  download_file "$base_url/lib/config.sh" "$TEMP_DIR/lib/config.sh"
  download_file "$base_url/lib/menu.sh" "$TEMP_DIR/lib/menu.sh"
  download_file "$base_url/VERSION" "$TEMP_DIR/VERSION"
  SOURCE_ROOT="$TEMP_DIR"
}

has_233boy_installation() {
  command -v sb >/dev/null 2>&1 && return 0
  [[ -x /usr/local/bin/sb ]] && return 0

  # 已有 233boy 风格配置时采取保守策略，避免覆盖现有 sing-box 环境。
  [[ -d /etc/sing-box && -d /etc/sing-box/conf ]] && return 0

  return 1
}

install_233boy_if_needed() {
  local upstream_installer="$TEMP_DIR/233boy-install.sh"
  local upstream_status=0

  if [[ $ZZ_ONLY -eq 1 ]]; then
    log "已使用 --zz-only，跳过 233boy 安装"
    return
  fi

  if has_233boy_installation; then
    log "已检测到 233boy/sing-box 环境，跳过上游安装，不覆盖现有脚本和配置"
    return
  fi

  log "未检测到 233boy，下载官方安装脚本"
  download_file "$UPSTREAM_233BOY_INSTALL_URL" "$upstream_installer"
  [[ -s "$upstream_installer" ]] || die "233boy 官方安装脚本下载结果为空"
  bash -n "$upstream_installer" || die "233boy 官方安装脚本语法检查失败"

  log "开始原样执行 233boy 官方安装脚本（zz 不会修改该脚本）"
  if bash "$upstream_installer"; then
    log "233boy 官方安装脚本执行完成"
    return
  else
    upstream_status=$?
  fi

  # 233boy 安装器在部分成功安装场景会返回非零状态。
  # 以实际安装结果为准，避免 sing-box 已可用但 zz 被误停。
  if has_233boy_installation; then
    log "警告: 233boy 官方脚本返回状态码 ${upstream_status}，但已检测到安装结果，继续安装 zz"
    return
  fi

  die "233boy 官方安装脚本返回状态码 ${upstream_status}，且未检测到安装结果，已停止安装 zz"
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

validate_installed_files() {
  local file

  bash -n "$INSTALL_BIN"
  for file in utils backup node relay config menu; do
    bash -n "$INSTALL_LIB/$file.sh"
  done
  [[ -s "$INSTALL_LIB/VERSION" ]] || die "安装后的 VERSION 文件为空"
}

show_next_steps() {
  printf '\n'
  log "安装流程完成；zz 没有自动启动，也没有修改 233boy 脚本"
  cat <<'NEXT_STEPS'

接下来请按顺序操作：

  1. 运行：sb
  2. 使用 233boy 菜单创建 VLESS WebSocket 节点
  3. 节点创建完成后运行：zz
  4. 在 zz 中先选择“同步 233boy 节点”，再配置中转
NEXT_STEPS
}

main() {
  local old_backup

  parse_args "$@"

  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    die "请使用 root 用户运行安装脚本"
  fi

  prepare_temp_dir
  prepare_source_tree
  validate_source_tree "$SOURCE_ROOT"

  install_233boy_if_needed
  install_dependencies

  if [[ -e "$INSTALL_BIN" ]]; then
    old_backup="${INSTALL_BIN}.pre-${PROJECT_NAME}-$(date +%Y%m%d-%H%M%S)"
    cp -a "$INSTALL_BIN" "$old_backup"
    log "已备份原入口: $old_backup"
  fi

  copy_project_files "$SOURCE_ROOT"
  validate_installed_files
  show_next_steps
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
