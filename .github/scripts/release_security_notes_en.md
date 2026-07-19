<!-- KRISIS-KNIGHTMARE-SHA256-SECURITY-EN-START -->
### How to Confirm That Your Download Has Not Been Tampered With

**SHA-256 verification is an important way to confirm download integrity and detect tampering.** A file can have the expected name and size while its contents are corrupted, replaced, or repackaged by a third party. Comparing a locally calculated hash with the value in the official `SHA256SUMS` file can reveal these problems before you run the game, so you do not run a file that differs from the official release asset.

GitHub Releases, GameBanana, and Gamejolt are all official distribution sources for this game; only GitHub Releases is currently available, and the GameBanana and Gamejolt pages are coming soon. Download the game from an official source; for now, download the game package and `SHA256SUMS` together from this repository's official GitHub Release. The mod package, `krisis-knightmare-mod.zip`, can be checked with the same manifest. A hash cannot prevent a file from being tampered with, and it is not a digital signature that can independently prove the publisher's identity. However, when `SHA256SUMS` comes from a trusted official Release, a matching value means the downloaded file contents match the official release asset.

#### Windows (using built-in PowerShell)

1. Put `SHA256SUMS` and the game file you want to check in the same folder.
2. Enter `powershell` in File Explorer's address bar, press Enter, and run:

   ```powershell
   (Get-FileHash .\krisis-knightmare-release-win64.zip -Algorithm SHA256).Hash
   ```

   Replace the example filename with the name of the file you downloaded.
3. Compare the 64-character output with the value before the matching filename in `SHA256SUMS`.

A complete match means the file matches the official release asset. If it does not match, do not run the file; delete it and download it again from the official Release.

#### Linux / macOS

Put `SHA256SUMS` and the game files listed in it in the same directory, then run:

```bash
# Linux
sha256sum -c SHA256SUMS

# macOS
shasum -a 256 -c SHA256SUMS
```

`OK` means verification passed. If a file shows `FAILED`, do not run it; download it again.
<!-- KRISIS-KNIGHTMARE-SHA256-SECURITY-EN-END -->
