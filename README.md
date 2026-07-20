# KRISIS KNIGHTMARE

[![license](https://img.shields.io/badge/license-MIT%2FApache--2.0-blue)](LICENSE-APACHE)

![KRISIS KNIGHTMARE](./cover.jpg)

**KRISIS KNIGHTMARE** — 动画 [KRISIS KNIGHTMARE](https://www.bilibili.com/video/BV1r7f1ByETC) 的授权游戏化项目，基于 [Kristal](https://github.com/KristalTeam/Kristal) 构建。

| 简体中文 | English |
|---------|---------|
| 简体中文 | [English](./README_en.md) |

## 简介

本项目是 B 站动画 [KRISIS KNIGHTMARE](https://www.bilibili.com/video/BV1r7f1ByETC) 的同人游戏化作品，经授权将其全部内容开源发布。

*你也可以在 [Youtube](https://www.youtube.com/watch?v=GOfVuCJ4BG8) 观看此动画的英文版本。*

## 下载与运行

本项目保留 Kristal 项目包（mod 形式）和 standalone 两种分发方式。[GitHub Releases](https://github.com/Bli-AIk/krisis_knightmare/releases)、GameBanana 和 Gamejolt 都是本游戏的**官方发布源**。目前 GitHub Releases 已开放，GameBanana 和 Gamejolt 页面正在准备中，即将发布。

- **Kristal 项目包（mod 形式，实验性）**：下载 release 中的 `krisis-knightmare-mod.zip`，安装 Kristal `v0.10.0`，将 ZIP 直接放入 Kristal 主菜单打开的 projects 文件夹（源码运行时对应 `mods/` 目录），然后在项目列表中选择 `krisis_knightmare`。不要在 ZIP 外再套一层目录。
- **Standalone**：Windows 用户可以下载 `*-win64.zip`，解压后直接运行；其他平台可以根据需要使用 `.love` 文件和对应的 LÖVE 运行时。

以 Kristal 项目包形式单独运行目前尚未经过完整验证，但从项目结构和开发方式来看理论上可行。

<details>
<summary>关于 mod 运行方式和开发环境</summary>

本项目本身就是在 Kristal 的 mod 运行方式下开发的：开发时将项目放在 Kristal 的 `mods/` 目录中运行，游戏逻辑和资源都位于本项目内。这里的 mod ZIP 是项目文件包，不包含 standalone 构建时使用的修改版 Kristal 引擎。

为了生成 standalone 构建，构建脚本会把 Kristal 复制到临时构建目录，再只对那份副本做轻度修改。这些修改不会写入仓库中的 Kristal，也不会进入 mod ZIP，主要包括：

- 设置目标项目、自动启动项目、窗口标题和窗口身份；
- 将引擎默认帧率改为不限制；
- 在启动画面显示 `made with` 署名；
- 在检测到 finisher 恢复记录时跳过启动动画；
- 让 `.love` 中的 HTTPS 原生库可以释放到存档目录后加载；
- release 构建中关闭 Kristal DebugSystem 的输入钩子；
- debug 构建中支持外部 `mod.json` 覆盖，并根据构建类型调整 mod 的开发配置。

因此，mod 形式是否能在未经修改的 Kristal 环境中完整运行仍需要实际测试；目前不能将其视为已经验证的独立玩家版本。
</details>

## 致谢

### 原片制作

| 职责 | 人员 |
|------|------|
| 三角符文 作者 | TOBY FOX |
| 主要制作 | UJB传说官方 |
| 弹幕设计 | 滑稽体验镇魂曲 |

| 职责 | 人员 |
|------|------|
| 设计提供 | Nahisa图文 |
| 文案提供 | 这里不是红耀西 |
| 音效嵌入 | 5P4mt0n |

| 章节 | 作者 |
|------|------|
| -FINAL PROPHECY- | \_B0TtLE\_ (Bilibili) |
| -NEVER FORGETTING- | Local, H00ligan, The Joker |
| -DARK OUTSKIRTS- | Vision Crew's Deltarune |
| -REBIRTH- | Chirou-P (Bilibili) |

| 职责 | 人员 |
|------|------|
| 封面 | GFM |
| 宣传片 | GA |
| 设计提供 | Waga_Love |

| 特别鸣谢 |
|----------|
| Aug_ust八月 |
| Alivall\_ |
| Saarasin |
| 青柠不是人 |

| 特别鸣谢 |
|----------|
| 飞上天的开心果 |
| GoodTeaIce |
| Xx_FrekGT_xX |
| Rock |

### 游戏化开发

| 职责 | 人员 |
|------|------|
| 游戏化开发 | Bli_AIk |
| 游戏测试 | church\_wafer, Nahisa图文, 滑稽体验镇魂曲, Gpie\_A, Anskiyy |
| 引擎 | [Kristal](https://github.com/KristalTeam/Kristal) |

## 从源码运行

以下步骤适用于开发者从源码运行项目，不是 release mod ZIP 的安装步骤。

1. 安装 [Kristal](https://github.com/KristalTeam/Kristal) `v0.10.0`。
2. 将本仓库克隆到 Kristal 的 `mods/` 目录下：

   ```bash
   cd Kristal/mods
   git clone https://github.com/Bli-AIk/krisis_knightmare.git
   ```

3. 启动 Kristal，在模组选择中选择 **krisis_knightmare**。

## 调试 CLI

本 mod 启用了 `terminal-cli` library。使用 `just run` 在当前终端启动，或使用
`just term` 在独立终端启动；游戏窗口和该终端会共享同一个 Kristal debug console。

在终端中输入 Lua 表达式或语句即可操作当前游戏状态，例如：

```text
=Game.world.player.x
Game.world.player:setPosition(160, 120)
```

终端命令会进入游戏内 console 的历史记录，游戏 GUI 中输入的命令也会同步回终端。
library 默认只在 dev mode 启用，可在 `mod.json` 的 `terminal-cli` 配置中关闭或调整
`max_commands_per_frame`。

## 参与贡献

欢迎提交 Issue 或 Pull Request。

## 许可证

本项目采用双许可证授权，您可以选择以下任一许可证：

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) 或 http://www.apache.org/licenses/LICENSE-2.0)
- MIT license ([LICENSE-MIT](LICENSE-MIT) 或 http://opensource.org/licenses/MIT)
