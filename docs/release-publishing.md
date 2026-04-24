# Publishing Hestia GitHub Releases

This project keeps generated release binaries out of git. Files under `releases/`
are uploaded as GitHub Release assets.

## 1. Install GitHub CLI

Windows:

```powershell
winget install --id GitHub.cli
```

macOS:

```bash
brew install gh
```

Linux:

```bash
sudo apt install gh
```

If your distro does not package `gh`, use the official instructions:
https://github.com/cli/cli#installation

## 2. Authenticate

```bash
gh auth login
gh auth status
```

Choose GitHub.com, HTTPS, and browser authentication unless your environment
requires another flow.

## 3. Check Local Assets

For `v4.0.0_1`, these files must exist locally:

```text
releases/hestia-4.0.0_1-android.apk
releases/hestia-4.0.0_1-windows-setup.exe
releases/hestia-4.0.0_1-windows-portable.zip
releases/hestia-4.0.0_1-web-static.zip
releases/hestia-4.0.0_1-backend.zip
releases/hestia-4.0.0_1-landing.zip
releases/4.0.0-checksums.txt
releases/latest.json
```

Do not run `git add releases/`. These files are ignored intentionally.

## 4. Create And Push The Tag

Create the tag from the commit you want to publish:

```bash
git status
git tag v4.0.0_1
git push origin v4.0.0_1
```

If the tag already exists locally, inspect it before changing anything:

```bash
git show v4.0.0_1
```

## 5. Upload Assets

Bash:

```bash
./scripts/publish_release.sh v4.0.0_1
```

PowerShell:

```powershell
pwsh -File scripts/publish_release.ps1 v4.0.0_1
```

The scripts:

- verify `gh` is available
- verify every required local file exists
- create the GitHub Release if it does not exist
- upload assets with `gh release upload`
- keep local files in place
- do not commit release binaries

## 6. Verify The Release Page

Open the release page:

```bash
gh release view v4.0.0_1 --web
```

Confirm that all eight assets are present:

- Android APK
- Windows installer
- Windows portable ZIP
- Web static ZIP
- Backend ZIP
- Landing/site ZIP
- Checksums text file
- `latest.json`

Also download `4.0.0-checksums.txt` and compare at least one asset locally:

```bash
sha256sum releases/hestia-4.0.0_1-windows-setup.exe
```

On Windows PowerShell:

```powershell
Get-FileHash releases\hestia-4.0.0_1-windows-setup.exe -Algorithm SHA256
```
