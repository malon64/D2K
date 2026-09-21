param(
    [ValidateSet('dreamcast', 'ps1', 'n64', 'gamecube', '3ds')]
    [string]$Console,

    [string]$RomPath,

    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

function Get-EmulatorArguments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$System,

        [Parameter(Mandatory = $true)]
        [string]$Rom
    )

    # Windows paths cannot contain a quote. Keeping the ROM as the final quoted
    # argument makes Pegasus paths with spaces safe for every supported emulator.
    $quotedRom = '"{0}"' -f $Rom
    switch ($System) {
        'dreamcast' { return $quotedRom }
        'ps1' { return "-batch -fastboot -- $quotedRom" }
        'n64' { return ('--system "Nintendo 64" --no-file-prompt {0}' -f $quotedRom) }
        'gamecube' { return "--batch --exec $quotedRom" }
        '3ds' { return $quotedRom }
    }
}

if (-not $SelfTest -and (-not $Console -or -not $RomPath)) {
    throw 'Usage: launch-emulator.ps1 -Console dreamcast|ps1|n64|gamecube|3ds -RomPath <path>'
}

$emulators = @{
    dreamcast = 'C:\Users\alexi\Downloads\flycast-master\build\Debug\flycast.exe'
    ps1 = Join-Path $env:LOCALAPPDATA 'Programs\DuckStation\duckstation-qt-x64-ReleaseLTCG.exe'
    n64 = 'C:\Program Files (x86)\ares-v148\ares.exe'
    gamecube = 'C:\Program Files (x86)\Dolphin-x64\Dolphin.exe'
    '3ds' = 'C:\Program Files\Azahar\azahar.exe'
}

$emulator = $emulators[$Console]
$logDir = Join-Path $env:LOCALAPPDATA 'D2K'
$logPath = Join-Path $logDir "launch-$Console.log"
$homeRequestPath = Join-Path $logDir 'home-request'

if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    Add-Content -LiteralPath $logPath -Value ("{0:yyyy-MM-ddTHH:mm:ss.fff}  {1}" -f (Get-Date), $Message)
}

Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class D2KEmulatorWindows
{
    private delegate bool EnumWindowsProc(IntPtr window, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr parameter);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr window);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr window, StringBuilder text, int maxCount);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    private static extern int GetWindowLong(IntPtr window, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")]
    private static extern int SetWindowLong(IntPtr window, int index, int value);

    [DllImport("user32.dll")]
    private static extern bool SetMenu(IntPtr window, IntPtr menu);

    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr window, IntPtr insertAfter, int x, int y, int width, int height, uint flags);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr window, int command);

    [DllImport("user32.dll")]
    private static extern bool GetClientRect(IntPtr window, out RECT rect);

    [DllImport("user32.dll")]
    private static extern bool ClientToScreen(IntPtr window, ref POINT point);

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int index);

    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr value);

    public static bool IsSecondaryTitle(string title)
    {
        return title != null &&
            (title.IndexOf("secondary", StringComparison.OrdinalIgnoreCase) >= 0 ||
             title.IndexOf("second", StringComparison.OrdinalIgnoreCase) >= 0 ||
             title.IndexOf("bottom", StringComparison.OrdinalIgnoreCase) >= 0);
    }

    public static bool IsPrimaryTitle(string title)
    {
        return title != null &&
            (title.IndexOf("primary", StringComparison.OrdinalIgnoreCase) >= 0 ||
             title.IndexOf("princip", StringComparison.OrdinalIgnoreCase) >= 0);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int L, T, R, B; }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT { public int X, Y; }

    private sealed class Window
    {
        public IntPtr Handle;
        public string Title;
        public int Area;
    }

    private const int PanelWidth = 800;
    private const int PanelHeight = 480;
    private const int TitleBar = 58;
    private const int Hinge = 32;
    private const int GwlStyle = -16;
    private const int WindowChrome = 0x00CC0000;
    private const uint SwpNoZOrder = 0x0004;
    private const uint SwpNoActivate = 0x0010;
    private const uint SwpFrameChanged = 0x0020;
    private const int SwHide = 0;

    private static List<Window> WindowsForProcess(int processId)
    {
        var windows = new List<Window>();
        EnumWindows(delegate(IntPtr window, IntPtr ignored) {
            uint owner;
            GetWindowThreadProcessId(window, out owner);
            if (owner != processId || !IsWindowVisible(window))
                return true;

            RECT rect;
            if (!GetClientRect(window, out rect) || rect.R <= 0 || rect.B <= 0)
                return true;

            var text = new StringBuilder(256);
            GetWindowText(window, text, text.Capacity);
            windows.Add(new Window { Handle = window, Title = text.ToString(), Area = rect.R * rect.B });
            return true;
        }, IntPtr.Zero);
        return windows;
    }

    private static void Frame(Window window, int x, int y)
    {
        int style = GetWindowLong(window.Handle, GwlStyle) & ~WindowChrome;
        SetWindowLong(window.Handle, GwlStyle, style);
        SetMenu(window.Handle, IntPtr.Zero);
        SetWindowPos(window.Handle, IntPtr.Zero, x, y, PanelWidth, PanelHeight,
                     SwpNoZOrder | SwpNoActivate | SwpFrameChanged);
    }

    private static void Hide(Window window)
    {
        ShowWindow(window.Handle, SwHide);
    }

    private static bool Matches(Window window, int x, int y)
    {
        RECT rect;
        POINT origin = new POINT();
        GetClientRect(window.Handle, out rect);
        ClientToScreen(window.Handle, ref origin);
        return origin.X == x && origin.Y == y && rect.R == PanelWidth && rect.B == PanelHeight;
    }

    private static Window Largest(IEnumerable<Window> windows)
    {
        Window largest = null;
        foreach (var window in windows)
            if (largest == null || window.Area > largest.Area)
                largest = window;
        return largest;
    }

    private static void Layout(out int left, out int top, out int bottom)
    {
        int screenWidth = GetSystemMetrics(0);
        int screenHeight = GetSystemMetrics(1);
        int stackHeight = PanelHeight * 2 + TitleBar + Hinge;
        left = (int)Math.Round((screenWidth - PanelWidth) / 2.0);
        top = (int)Math.Round(Math.Max(40.0, (screenHeight - stackHeight) / 2.0));
        bottom = top + PanelHeight + TitleBar + Hinge;
    }

    public static bool CheckSingleLayout(int processId)
    {
        int left, top, bottom;
        Layout(out left, out top, out bottom);
        var window = Largest(WindowsForProcess(processId));
        if (window == null)
            return false;
        if (!Matches(window, left, top))
            Frame(window, left, top);
        return Matches(window, left, top);
    }

    public static bool CheckAzaharLayout(int processId)
    {
        int left, top, bottom;
        Layout(out left, out top, out bottom);
        var windows = WindowsForProcess(processId);
        Window secondary = null;
        Window primary = null;
        var primaryCandidates = new List<Window>();

        foreach (var window in windows) {
            if (IsSecondaryTitle(window.Title)) {
                secondary = window;
            } else if (IsPrimaryTitle(window.Title)) {
                primary = window;
            } else if (!String.Equals(window.Title, "Azahar", StringComparison.OrdinalIgnoreCase)) {
                primaryCandidates.Add(window);
            }
        }

        if (primary == null)
            primary = Largest(primaryCandidates);
        if (primary == null || secondary == null)
            return false;

        foreach (var window in primaryCandidates)
            if (window.Handle != primary.Handle)
                Hide(window);

        if (!Matches(primary, left, top))
            Frame(primary, left, top);
        if (!Matches(secondary, left, bottom))
            Frame(secondary, left, bottom);
        return Matches(primary, left, top) && Matches(secondary, left, bottom);
    }
}
'@

if ($SelfTest) {
    if ((Get-EmulatorArguments -System dreamcast -Rom 'C:\Games\Test Game.chd') -ne '"C:\Games\Test Game.chd"') {
        throw 'Dreamcast argument construction failed.'
    }
    if ((Get-EmulatorArguments -System ps1 -Rom 'C:\Games\Test Disc.cue') -ne '-batch -fastboot -- "C:\Games\Test Disc.cue"') {
        throw 'PS1 argument construction failed.'
    }
    if ((Get-EmulatorArguments -System n64 -Rom 'C:\Games\Test.z64') -notmatch '--system "Nintendo 64"') {
        throw 'N64 argument construction failed.'
    }
    if (-not [D2KEmulatorWindows]::IsSecondaryTitle('Fenêtre secondaire')) {
        throw 'Localized Azahar secondary-window detection failed.'
    }
    if (-not [D2KEmulatorWindows]::IsPrimaryTitle('Fenêtre principale')) {
        throw 'Localized Azahar primary-window detection failed.'
    }
    Write-Host 'launch-emulator self-test passed.'
    exit 0
}

Write-Log "===== launch-$Console start: rom=$RomPath ====="
$mpdScript = Join-Path $PSScriptRoot 'mpd.ps1'

try {
    try {
        & $mpdScript -Action Pause
        Write-Log 'MPD paused'
    }
    catch {
        Write-Log "MPD pause FAILED (non-fatal): $($_.Exception.Message)"
    }

    if (-not (Test-Path -LiteralPath $emulator -PathType Leaf)) {
        throw "$Console emulator was not found at $emulator"
    }
    if (-not (Test-Path -LiteralPath $RomPath -PathType Leaf)) {
        throw "ROM was not found at $RomPath"
    }

    try {
        [D2KEmulatorWindows]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
    }
    catch {
        Write-Log "SetProcessDpiAwarenessContext FAILED (non-fatal): $($_.Exception.Message)"
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $emulator
    $startInfo.Arguments = Get-EmulatorArguments -System $Console -Rom $RomPath
    $startInfo.WorkingDirectory = Split-Path -Parent $emulator
    $startInfo.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($startInfo)
    if ($null -eq $process) {
        throw "Failed to start $Console emulator"
    }
    Write-Log "$Console started: pid=$($process.Id)"

    $stableChecks = 0
    $layoutSettled = $false
    while (-not $process.HasExited) {
        if (-not $layoutSettled) {
            try {
                $stable = if ($Console -eq '3ds') {
                    [D2KEmulatorWindows]::CheckAzaharLayout($process.Id)
                }
                else {
                    [D2KEmulatorWindows]::CheckSingleLayout($process.Id)
                }
                if ($stable) {
                    $stableChecks += 1
                    if ($stableChecks -ge 5) {
                        $layoutSettled = $true
                        Write-Log 'Layout settled'
                    }
                }
                else {
                    $stableChecks = 0
                }
            }
            catch {
                Write-Log "Layout FAILED (non-fatal): $($_.Exception.Message)"
                $layoutSettled = $true
            }
        }

        if (Test-Path -LiteralPath $homeRequestPath) {
            Write-Log 'Home request detected -- closing emulator'
            Remove-Item -LiteralPath $homeRequestPath -Force -ErrorAction SilentlyContinue
            $process.CloseMainWindow() | Out-Null
            if (-not $process.WaitForExit(3000)) {
                Write-Log 'Emulator did not exit gracefully -- killing'
                $process.Kill()
            }
            break
        }

        Start-Sleep -Milliseconds 150
        $process.Refresh()
    }

    $process.WaitForExit()
    Write-Log "$Console exited: code=$($process.ExitCode)"
}
catch {
    Write-Log "FATAL: $($_.Exception.Message)"
    Write-Log $_.ScriptStackTrace
}
finally {
    try {
        & $mpdScript -Action Resume
        Write-Log 'MPD resumed'
    }
    catch {
        Write-Log "MPD resume FAILED (non-fatal): $($_.Exception.Message)"
    }
}

exit 0
