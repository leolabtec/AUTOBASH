# 🚀 WordPress 多站点自动部署系统

一个一键式部署多个 WordPress 网站的自动化管理系统，基于 **Docker + Docker Caddy + Shell 脚本**，支持多站独立管理、自动生成反向代理、数据库隔离、快捷启动命令等。

> 🌟 适合个人建站、多域名项目管理、技术爱好者自动化学习

---

## 🧩 功能特点

- ✅ 支持部署多个独立 WordPress 站点
- ✅ 每个站点自动生成数据库、密码、配置
- ✅ 自动配置反向代理（Caddy），支持 HTTPS
- ✅ 使用 `.env` 管理数据库密码、安全性高
- ✅ 所有配置文件按站点归类，结构清晰
- ✅ 提供卸载脚本，一键清理部署环境
- ✅ 支持自定义快捷命令，如 `wpctl` 直接进入主面板

---

## 🚀 一键安装命令

```bash
sudo curl -LO https://raw.githubusercontent.com/leolabtec/Autobuild_openwrt/refs/heads/main/install.sh && chmod +x install.sh && ./install.sh
