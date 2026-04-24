param(
  [switch]$SkipPubGet,
  [switch]$PackageExistingBuild
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root
. (Join-Path $PSScriptRoot "common.ps1")

$Version = ((Select-String -Path "pubspec.yaml" -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value).Trim()
$SafeVersion = $Version -replace "\+", "_"
$DistDir = Join-Path $Root "dist"
$ReleaseDir = Join-Path $Root "releases"
$PackageDir = Join-Path $DistDir "hestia-windows"
$Archive = Join-Path $ReleaseDir "hestia-$SafeVersion-windows-portable.zip"
$Installer = Join-Path $ReleaseDir "hestia-$SafeVersion-windows-setup.exe"

New-Item -ItemType Directory -Force -Path $DistDir, $ReleaseDir | Out-Null
if (Test-Path $PackageDir) {
  Remove-Item -Recurse -Force $PackageDir
}

$VsWhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $VsWhere) {
  $ActiveVs = & $VsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if ($ActiveVs) {
    $AtlHeaders = Get-ChildItem -Path $ActiveVs -Recurse -Filter "atlbase.h" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $AtlHeaders) {
      throw "Windows build requires ATL/MFC headers in the active Visual Studio toolchain: $ActiveVs. Install the C++ ATL/MFC component for that MSVC toolset, then rerun this script."
    }
  }
}

if (-not $PackageExistingBuild) {
  if (-not $SkipPubGet) {
    Invoke-FlutterChecked @("pub", "get")
  }

  Invoke-FlutterChecked @("build", "windows", "--release", "--no-pub")
}

$BuildDir = Join-Path $Root "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $BuildDir "hestia.exe"))) {
  throw "Windows build output was not found at $BuildDir"
}

Copy-Item -Recurse -Force $BuildDir $PackageDir

if (Test-Path $Archive) {
  Remove-Item -Force $Archive
}
Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $Archive
Write-Host "Windows portable archive ready: $Archive"

$InnoCandidates = @(
  (Get-Command "iscc.exe" -ErrorAction SilentlyContinue).Source,
  (Join-Path ([Environment]::GetFolderPath("ProgramFilesX86")) "Inno Setup 6\ISCC.exe"),
  (Join-Path ([Environment]::GetFolderPath("ProgramFiles")) "Inno Setup 6\ISCC.exe")
) | Where-Object { $_ -and (Test-Path $_) }

if ($InnoCandidates.Count -eq 0) {
  $CscCandidates = @(
    (Get-Command "csc.exe" -ErrorAction SilentlyContinue).Source,
    (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
    (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe")
  ) | Where-Object { $_ -and (Test-Path $_) }

  if ($CscCandidates.Count -eq 0) {
    Write-Warning "Inno Setup and csc.exe were not found. Install Inno Setup 6 to produce $Installer. The portable zip is still ready."
    exit 0
  }

  Write-Warning "Inno Setup was not found. Building a per-user setup.exe with csc.exe instead."

  $FallbackDir = Join-Path $DistDir "hestia-windows-setup-fallback"
  if (Test-Path $FallbackDir) {
    Remove-Item -Recurse -Force $FallbackDir
  }
  New-Item -ItemType Directory -Force -Path $FallbackDir | Out-Null

  $InstallerSource = Join-Path $FallbackDir "HestiaSetup.cs"
  $InstallerCode = @'
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;

namespace HestiaSetup
{
  internal static class Program
  {
    [STAThread]
    private static int Main()
    {
      try
      {
        string installRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Hestia");
        string startMenuDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Microsoft", "Windows", "Start Menu", "Programs", "Hestia");
        string desktopDir = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        string tempZip = Path.Combine(Path.GetTempPath(), "hestia-windows-portable-" + Guid.NewGuid().ToString("N") + ".zip");

        using (Stream payload = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))
        {
          if (payload == null)
          {
            throw new InvalidOperationException("Installer payload was not found.");
          }
          using (FileStream output = File.Create(tempZip))
          {
            payload.CopyTo(output);
          }
        }

        Directory.CreateDirectory(installRoot);
        foreach (string entry in Directory.GetFileSystemEntries(installRoot))
        {
          if (Directory.Exists(entry))
          {
            Directory.Delete(entry, true);
          }
          else
          {
            File.Delete(entry);
          }
        }

        ZipFile.ExtractToDirectory(tempZip, installRoot);
        File.Delete(tempZip);

        string exePath = Path.Combine(installRoot, "hestia.exe");
        Directory.CreateDirectory(startMenuDir);
        CreateShortcut(Path.Combine(startMenuDir, "Hestia.lnk"), exePath, installRoot);
        CreateShortcut(Path.Combine(desktopDir, "Hestia.lnk"), exePath, installRoot);
        Process.Start(new ProcessStartInfo { FileName = exePath, WorkingDirectory = installRoot, UseShellExecute = true });
        return 0;
      }
      catch (Exception ex)
      {
        System.Windows.Forms.MessageBox.Show(ex.Message, "Hestia setup failed", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
        return 1;
      }
    }

    private static void CreateShortcut(string shortcutPath, string targetPath, string workingDirectory)
    {
      IShellLinkW link = (IShellLinkW)new CShellLink();
      link.SetPath(targetPath);
      link.SetWorkingDirectory(workingDirectory);
      link.SetIconLocation(targetPath, 0);
      ((IPersistFile)link).Save(shortcutPath, true);
    }
  }

  [ComImport]
  [Guid("00021401-0000-0000-C000-000000000046")]
  internal class CShellLink
  {
  }

  [ComImport]
  [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  [Guid("000214F9-0000-0000-C000-000000000046")]
  internal interface IShellLinkW
  {
    void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszFile, int cchMaxPath, IntPtr pfd, uint fFlags);
    void GetIDList(out IntPtr ppidl);
    void SetIDList(IntPtr pidl);
    void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszName, int cchMaxName);
    void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
    void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszDir, int cchMaxPath);
    void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
    void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszArgs, int cchMaxPath);
    void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
    void GetHotkey(out short pwHotkey);
    void SetHotkey(short wHotkey);
    void GetShowCmd(out int piShowCmd);
    void SetShowCmd(int iShowCmd);
    void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszIconPath, int cchIconPath, out int piIcon);
    void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
    void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
    void Resolve(IntPtr hwnd, uint fFlags);
    void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
  }

  [ComImport]
  [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  [Guid("0000010b-0000-0000-C000-000000000046")]
  internal interface IPersistFile
  {
    void GetClassID(out Guid pClassID);
    void IsDirty();
    void Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, uint dwMode);
    void Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, bool fRemember);
    void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
    void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
  }
}
'@
  Set-Content -Path $InstallerSource -Value $InstallerCode -Encoding UTF8

  if (Test-Path $Installer) {
    Remove-Item -Force $Installer
  }
  $ResourceArg = "/resource:$Archive,payload.zip"
  & $CscCandidates[0] `
    /nologo `
    /target:winexe `
    /platform:anycpu `
    /out:$Installer `
    $ResourceArg `
    /reference:System.IO.Compression.dll `
    /reference:System.IO.Compression.FileSystem.dll `
    /reference:System.Windows.Forms.dll `
    $InstallerSource
  if ($LASTEXITCODE -ne 0) {
    throw "csc.exe failed with exit code $LASTEXITCODE"
  }
  if (Test-Path $Installer) {
    Write-Host "Windows installer ready: $Installer"
  } else {
    throw "Windows installer was not created at $Installer"
  }
  exit 0
}

$IssPath = Join-Path $DistDir "hestia-windows-installer.iss"
$IssContent = @"
[Setup]
AppId={{B15E27B5-3B42-4F55-8D6D-HESTIA000001}
AppName=Hestia
AppVersion=$Version
DefaultDirName={autopf}\Hestia
DefaultGroupName=Hestia
OutputDir=$ReleaseDir
OutputBaseFilename=hestia-$SafeVersion-windows-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes

[Files]
Source: "$PackageDir\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Hestia"; Filename: "{app}\hestia.exe"
Name: "{autodesktop}\Hestia"; Filename: "{app}\hestia.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\hestia.exe"; Description: "Launch Hestia"; Flags: nowait postinstall skipifsilent
"@
Set-Content -Path $IssPath -Value $IssContent -Encoding UTF8

& $InnoCandidates[0] $IssPath
if (Test-Path $Installer) {
  Write-Host "Windows installer ready: $Installer"
}
