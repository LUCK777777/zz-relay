# zz-relay

当前版本：`0.1.1`

`zz-relay`（命令名：`zz`）是一个独立的 sing-box 中转管理工具，面向使用 233boy sing-box 一键脚本的 Debian 服务器。

它不会修改或替换 233boy 的 `sb` 脚本。`sb` 继续负责节点管理，`zz` 负责把入口节点绑定到落地出站。

当前版本只对原有单文件脚本进行模块化重构，菜单与现有功能保持不变，没有加入新的协议、策略组、测速或自动更新功能。

## 当前兼容范围

- Debian
- sing-box 1.13.x
- 233boy script v1.18
- 当前入口：VLESS
- 当前落地：Shadowsocks
- 配置文件：`/etc/sing-box/config.json`
- 233boy 节点目录：`/etc/sing-box/conf/*.json`
- sing-box 核心：`/etc/sing-box/bin/sing-box`
- systemd 服务：`sing-box`

## 项目结构

```text
zz-relay/
├── install.sh
├── uninstall.sh
├── zz
├── lib/
│   ├── menu.sh
│   ├── relay.sh
│   ├── node.sh
│   ├── config.sh
│   ├── backup.sh
│   └── utils.sh
├── README.md
└── VERSION
```

模块职责：

- `zz`：加载模块并启动主菜单。
- `lib/menu.sh`：主菜单和节点菜单。
- `lib/node.sh`：同步 233boy 节点、选择 VLESS 节点。
- `lib/relay.sh`：添加、绑定、查看和删除转发。
- `lib/config.sh`：检查 sing-box 配置、重启服务、保存工作配置。
- `lib/backup.sh`：修改前备份主配置。
- `lib/utils.sh`：集中维护路径与共享状态。

## 依赖

- Bash 4 或更新版本（脚本使用 `mapfile`）
- `jq`
- `python3`
- `iproute2`（提供 `ss`）
- systemd

`install.sh` 会在 Debian 上通过 `apt-get` 安装缺少的 `jq`、`python3` 和 `iproute2`。默认还会检测 233boy：未安装时下载并原样执行官方安装脚本，已安装时直接跳过。

## 统一安装行为

默认安装器会按以下顺序执行：

1. 检测服务器是否已有 `sb` 或 233boy 风格的 sing-box 配置。
2. 如果没有，下载并原样执行 `233boy/sing-box` 官方 `install.sh`。
3. 如果已有，跳过 233boy，不覆盖、不重装、不修改原脚本。
4. 安装 `zz` 到独立目录。
5. 安装完成后只显示操作提示，**不会自动启动 `zz`**。

233boy 官方安装入口：

```text
https://raw.githubusercontent.com/233boy/sing-box/main/install.sh
```

如果只想安装 `zz`，明确跳过 233boy：

```bash
sudo bash install.sh --zz-only
```

## 本地安装

下载或克隆完整项目后执行：

```bash
cd zz-relay
sudo bash install.sh
```

安装位置：

```text
/usr/local/bin/zz
/usr/local/lib/zz-relay/*.sh
/usr/local/lib/zz-relay/VERSION
```

安装完成后不要直接配置中转，请先运行：

```bash
sb
```

使用 233boy 菜单创建 **VLESS WebSocket** 节点，创建完成后再运行：

```bash
zz
```

进入 `zz` 后先同步 233boy 节点，再配置中转。

## 远程安装

使用 curl：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LUCK777777/zz-relay/main/install.sh)
```

或者使用 wget：

```bash
wget https://raw.githubusercontent.com/LUCK777777/zz-relay/main/install.sh
sudo bash install.sh
```

这条命令会同时准备 233boy 官方安装脚本和 `zz` 项目文件；已有 233boy 时会自动跳过上游安装。

只安装 `zz`：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LUCK777777/zz-relay/main/install.sh) --zz-only
```

需要安装其他分支时，可以下载对应分支的安装脚本，或者显式指定：

```bash
sudo ZZ_REPO="LUCK777777/zz-relay" ZZ_REF="分支名" bash install.sh
```

## 卸载

在项目目录中执行：

```bash
sudo bash uninstall.sh
```

卸载只删除 `zz` 的程序入口和模块，不删除：

- `/etc/sing-box/config.json`
- `/etc/sing-box/conf/`
- `config.json.zz-bak-*` 备份
- `config.json.final-working-old-nodes`
- 安装时生成的原入口备份

## 菜单

主菜单：

```text
========== zz 中转管理 ==========

1) 同步 233boy 节点
2) 选择 VLESS 节点
3) 查看所有转发
4) 删除转发
5) 检查重启并保存
0) 退出
```

节点菜单：

```text
1) 添加 SS 落地并绑定到这个节点
2) 绑定已有落地到这个节点
3) 查看这个节点的转发
4) 取消这个节点的中转
5) 检查重启并保存
0) 返回
```

## 配置覆盖（测试或特殊部署）

默认路径没有改变。需要在测试环境或非标准部署中覆盖时，可以设置：

- `ZZ_CONFIG`
- `ZZ_CONF_DIR`
- `ZZ_CORE`
- `ZZ_SING_BOX_SERVICE`
- `ZZ_FINAL_CONFIG`
- `ZZ_LIB_DIR`（只在入口旁没有 `lib/` 目录时使用）

例如：

```bash
ZZ_CONFIG=/tmp/sing-box/config.json \
ZZ_CONF_DIR=/tmp/sing-box/conf \
./zz
```

## 当前行为说明

- 每次同步、添加、绑定或删除前，都会创建 `config.json.zz-bak-时间戳`。
- “检查重启并保存”先运行 sing-box `check`，通过后重启服务，并复制当前配置到 `config.json.final-working-old-nodes`。
- 当前版本保持原脚本行为，尚未实现“检查失败后自动恢复备份”。
- 当前 `ss://` 导入能力保持原脚本解析方式，没有扩大链接格式兼容范围。

## 后续路线

1. 完善扫描、绑定、删除、检查和自动回滚。
2. 增加 Reality、Hysteria2、TUIC、Shadowsocks、Trojan 入口。
3. 增加 VMess、Trojan、Hysteria2、TUIC、VLESS、Shadowsocks 落地。
4. 支持多落地和按规则选择。
5. 支持轮询、故障切换等策略组。
6. 内置测速、延迟、出口 IP 和流媒体检测。
7. 使用 GitHub Actions 发布，并增加 `zz update`。

## 安全建议

- 不要把包含密码、密钥或完整节点链接的 sing-box 配置提交到 Git。
- 修改正式配置前保留可验证备份。
- 首次安装后，先执行“查看所有转发”和“检查重启并保存”，确认 sing-box 配置兼容。
