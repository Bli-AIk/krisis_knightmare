# 发布工具

本目录包含通过 Game Jolt 和 GameBanana 发布构建产物的本地工具。工具使用 Chrome/Chromium 的独立用户配置目录执行网页操作，不依赖 npm 包，也不直接处理网站 API 凭据。

## 运行环境

- Node.js 22 或更高版本
- Google Chrome 或 Chromium
- `just`（使用 `just publish` 命令时需要）
- 已生成的 `dist/` 构建产物

Chrome/Chromium 必须支持远程调试协议。可通过环境变量指定浏览器路径：

```bash
KRISIS_CHROME_BIN=/path/to/chrome just publish -- --dry-run
```

## 配置

复制示例配置，并在本地编辑：

```bash
cp publish/config.example.json publish/config.local.json
```

配置文件中的构建文件与站点 ID 示例：

```json
{
    "gamejolt": {
        "game_id": "1085393",
        "builds": [
            {
                "package_id": "1109746",
                "release_id": "123456",
                "path": "dist/krisis-knightmare-release-win64.zip"
            },
            {
                "package_id": "1109746",
                "release_id": "123456",
                "path": "dist/krisis-knightmare-release.love"
            },
            {
                "package_id": "1109746",
                "release_id": "123456",
                "path": "dist/krisis-knightmare-mod.zip"
            }
        ]
    },
    "gamebanana": {
        "mod_id": "695877",
        "paths": [
            "dist/krisis-knightmare-mod.zip",
            "dist/krisis-knightmare-release-win64.zip"
        ]
    }
}
```

Game Jolt 的 `release_id` 位于 release 编辑页 URL：

```text
https://gamejolt.com/dashboard/games/1085393/packages/1109746/releases/<release_id>/edit
```

`game_id`、`package_id` 和 `release_id` 是不同的标识。下载 URL 中的 CDN 文件标识不能作为 `release_id` 使用。同一 release 中的多个文件可以使用相同的 `release_id`；不同 release 必须分别配置。

`config.local.json` 已加入 Git 忽略规则。不得将本地配置复制为其他名称后提交，因为配置可能包含本地路径或其他部署信息。

## 命令

只发布已有构建产物：

```bash
just publish
```

构建产物后再发布：

```bash
just publish-build
```

只处理一个站点：

```bash
just publish -- --site gamejolt
just publish -- --site gamebanana
```

检查页面和文件输入，但不选择文件、不上传：

```bash
just publish -- --dry-run
```

首次使用或登录状态失效时，初始化站点登录：

```bash
just publish -- --login
just publish -- --login --site gamejolt
just publish -- --login --site gamebanana
```

也可以直接运行脚本：

```bash
node publish/publish_release.js --site gamejolt
```

## 发布流程

### Game Jolt

配置中的每个 `builds` 条目对应一个 Game Jolt build。工具会依次打开对应的 release 编辑页，选择配置中的文件，并等待网页完成上传。上传前建议先使用 `--dry-run` 检查 release URL 和文件路径。

### GameBanana

GameBanana 更新必须按以下两个阶段完成：

1. 工具打开 `Updates` 页面。填写并提交 changelog update，提交完成后回到终端继续。
2. 工具打开文件管理页并选择 `paths` 中的文件。等待所有文件上传完成，再将新文件移动到文件列表顶部，确认后回到终端结束流程。

可在配置中使用 `update_page_url` 或 `file_manager_url` 覆盖默认页面地址。默认地址分别为：

```text
https://gamebanana.com/mods/updates/<mod_id>
https://gamebanana.com/mods/edit/<mod_id>
```

## 登录与隐私

登录由用户在浏览器窗口中完成。工具不会读取、打印或提交密码、Cookie、访问令牌、localStorage 或请求头，也不会将这些内容写入仓库。

默认的独立浏览器配置目录位于项目目录之外：

```text
${XDG_STATE_HOME:-~/.local/state}/krisis-knightmare/publisher-browser
```

可使用 `KRISIS_PUBLISH_PROFILE=/path/to/private/profile` 指定其他位置。该目录可能包含站点登录状态，不得复制到仓库或上传到远程服务。

`publish/` 下除以下公开文件外的内容均被 Git 忽略：

- `README.md`
- `config.example.json`
- `publish_release.js`

发布工具只会选择配置中明确指定的本地文件，并要求站点页面使用 HTTPS。
