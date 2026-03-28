# 推送到 GitHub（本地仓库已就绪）

本目录**已经完成** `git init`、首条提交、分支 `main`，并排除了 `node_modules`、`.pio` 等大目录。

远程推送失败时，通常是：**仓库名 / 用户名不对**，或**未登录 GitHub**。

## 1. 在 GitHub 上建库（若还没有）

- 登录 GitHub → **New repository**
- 仓库名建议：`HackMITChina2026-finish`（GitHub 不支持仓库名里带空格；若你建的是别的名字，下面 URL 改成一致即可）
- **不要**勾选 “Add a README”（避免与本地首次推送冲突）；若已有旧仓库要**整库替换**，继续用下面 `push --force` 即可。

## 2. 把远程改成你的账号

把 `你的用户名` 换成你的 GitHub 用户名：

```bash
cd "/Users/a11/Documents/HackMITChina2026 finish"
git remote set-url origin "https://github.com/你的用户名/HackMITChina2026-finish.git"
```

若仓库名不是 `HackMITChina2026-finish`，把 URL 里最后一段改成你的仓库名。

## 3. 推送（覆盖远程与本地不一致的历史时用 force）

请使用**未被 shell 改写的 git**（若遇 `trailer` 报错，用 `command git`）：

```bash
command git push -u origin main --force
```

首次 HTTPS 推送会提示登录：可用 **Personal Access Token**（经典 token 需勾选 `repo`）作为密码。

## 4. 可选：用 SSH

```bash
git remote set-url origin "git@github.com:你的用户名/HackMITChina2026-finish.git"
command git push -u origin main --force
```

需本机已配置 `~/.ssh` 并已在 GitHub 添加公钥。

---

**说明：** 曾尝试的远程 `https://github.com/syh/HackMITChina2026-finish.git` 返回「仓库不存在」，因此需要你按上面改成**自己的用户名与仓库名**后再推送。
