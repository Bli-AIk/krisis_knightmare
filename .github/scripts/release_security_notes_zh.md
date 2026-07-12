<!-- KRISIS-KNIGHTMARE-SHA256-SECURITY-ZH-START -->
### 如何确认下载的游戏版本未被篡改

**SHA-256 哈希校验是确认下载文件安全性的重要步骤。** 文件即使名称和大小看起来正常，内容也可能已经损坏、被替换或被第三方重新打包。将本地计算出的哈希值与官方 `SHA256SUMS` 中的值比较，可以在运行游戏前发现这些问题，避免运行与官方发布版本不一致的文件。

请从本仓库官方 GitHub Release 同时下载游戏包和 `SHA256SUMS`。哈希值不能阻止文件被篡改，也不能单独证明发布者身份；但只要 `SHA256SUMS` 来自可信的官方 Release，校验值一致就表示你下载的文件内容与官方发布资产一致。

#### Windows（使用系统自带 PowerShell）

1. 将 `SHA256SUMS` 和要检查的游戏文件放在同一文件夹。
2. 在资源管理器地址栏输入 `powershell` 并回车，运行：

   ```powershell
   (Get-FileHash .\krisis-knightmare-release-win64.zip -Algorithm SHA256).Hash
   ```

   将示例文件名替换为实际下载的文件名。
3. 将输出的 64 位字符串与 `SHA256SUMS` 中同名文件前面的值比较。

完全一致表示文件与官方发布版本一致；不一致时不要运行文件，请删除后重新从官方 Release 下载。

#### Linux / macOS

将 `SHA256SUMS` 和清单中的游戏文件放在同一目录后运行：

```bash
# Linux
sha256sum -c SHA256SUMS

# macOS
shasum -a 256 -c SHA256SUMS
```

显示 `OK` 表示校验通过。出现 `FAILED` 时不要运行文件，请重新下载。
<!-- KRISIS-KNIGHTMARE-SHA256-SECURITY-ZH-END -->
