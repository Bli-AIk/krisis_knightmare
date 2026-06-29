# Obscura Chapters — 修改说明

## 改动内容（中文）

此库已从原始 [obscura-chapterselect](https://github.com/Hyperboid/obscura-chapterselect) 修改为**单 mod 多地图**模式。

### 原始行为

每个章节对应一个独立的 Kristal mod。选中章节后调用 `Kristal.loadMod(chapter.mod)` 切换到目标 mod。

### 修改后行为

所有章节在同一个 mod 内。选中章节后调用 `Game.world:loadMap(chapter.map)` 加载目标地图。

### 改动文件

1. **`scripts/objects/ChapterTransitionEffect.lua`**
   - 删除 `Kristal.loadMod()` / `Kristal.clearModState()` 逻辑
   - 改为 `Game.world:loadMap(self.chapter.map)` + `Game.fader:fadeIn()`

2. **`scripts/objects/ChapterSelect.lua`**
   - `handleChapter()`: `chapter.mod` → `chapter.map`
   - `loadChapters()`: 删除外部 mod 查找逻辑，改为检查当前 mod 的存档文件

### 章节配置方式

在 mod.json 的 config.obscurachapters.chapters 中用 `"map"` 而非 `"mod"`：

```json
{
  "image": "chapters/ch1",
  "name": "章节名称",
  "map": "room1",
  "sound": "ui_spooky_action"
}
```

---

以下是原始 README：

# OBSCURA CHAPTERS

Adds a chapter select menu, letting you have multiple mods in a TARGET_MOD build. See mod.json to configure just about everything you could want to.

## FAQ/PAQ

Q: Why's it called "Obscura" Chapters?  
A: Because it was made for DELTARUNE: ECLIPSE and, well, you know what they call when the moon obscures the sun? Yeah.

## Credits:

- Bor/Undertaled - The original Chapter Select mod
- Diamond Deltahedron - Pointing out countless accuracy issues
