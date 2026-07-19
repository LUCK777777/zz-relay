#!/usr/bin/env bash

node_menu() {
  while true; do
    clear
    echo "当前节点: $SELECTED_TAG  端口:$SELECTED_PORT"
    echo
    echo "1) 添加 SS 落地并绑定到这个节点"
    echo "2) 绑定已有落地到这个节点"
    echo "3) 查看这个节点的转发"
    echo "4) 取消这个节点的中转"
    echo "5) 检查重启并保存"
    echo "0) 返回"
    echo
    read -rp "请选择: " c

    case "$c" in
      1) add_ss_and_bind; read -rp "按回车继续..." ;;
      2) bind_existing; read -rp "按回车继续..." ;;
      3) show_node_forward; read -rp "按回车继续..." ;;
      4) remove_forward_for_node; read -rp "按回车继续..." ;;
      5) check_restart_save || true; read -rp "按回车继续..." ;;
      0) break ;;
      *) echo "无效选择"; read -rp "按回车继续..." ;;
    esac
  done
}

main_menu() {
  while true; do
    clear
    echo "========== zz 中转管理 =========="
    echo
    echo "1) 同步 233boy 节点"
    echo "2) 选择 VLESS 节点"
    echo "3) 查看所有转发"
    echo "4) 删除转发"
    echo "5) 检查重启并保存"
    echo "0) 退出"
    echo
    read -rp "请选择: " c

    case "$c" in
      1) sync_nodes || true; read -rp "按回车继续..." ;;
      2) choose_vless && node_menu ;;
      3) list_forwards; read -rp "按回车继续..." ;;
      4) delete_forward_menu ;;
      5) check_restart_save || true; read -rp "按回车继续..." ;;
      0) exit 0 ;;
      *) echo "无效选择"; read -rp "按回车继续..." ;;
    esac
  done
}
