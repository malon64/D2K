param(
    [Parameter(Mandatory = $true)]
    [string]$RomPath
)

$ErrorActionPreference = 'Stop'

$emulatorDir = 'C:\Users\alexi\Documents\NDS\melonDS-1.1-windows-x86_64'
$emulator = Join-Path $emulatorDir 'melonDS.exe'
$configPath = Join-Path $emulatorDir 'melonDS.toml'

if (-not (Test-Path -LiteralPath $emulator -PathType Leaf)) {
    throw "melonDS was not found at $emulator"
}

if (-not (Test-Path -LiteralPath $RomPath -PathType Leaf)) {
    throw "ROM was not found at $RomPath"
}

$config = Get-Content -LiteralPath $configPath -Raw
$window1 = [regex]::Match($config, '(?ms)^\[Instance0\.Window1\]\r?\n.*?(?=^\[|\z)')
if (-not $window1.Success) {
    throw "[Instance0.Window1] was not found in $configPath"
}

$updatedWindow1 = [regex]::Replace($window1.Value, '(?m)^Enabled\s*=\s*\w+\s*$', 'Enabled = true')
if ($updatedWindow1 -eq $window1.Value) {
    throw "Window 1 has no Enabled setting in $configPath"
}

if ($updatedWindow1 -ne $window1.Value) {
    [System.IO.File]::WriteAllText(
        $configPath,
        $config.Replace($window1.Value, $updatedWindow1),
        [System.Text.UTF8Encoding]::new($false)
    )
}

Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class D2KWindows
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

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern IntPtr GetWindowLongPtr(IntPtr window, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")]
    private static extern IntPtr SetWindowLongPtr(IntPtr window, int index, IntPtr value);

    [DllImport("user32.dll")]
    private static extern bool SetMenu(IntPtr window, IntPtr menu);

    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr window, IntPtr insertAfter, int x, int y, int width, int height, uint flags);

    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr value);

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int index);

    // Mirrors the preview geometry in pegasus/themes/d2k/theme.qml so melonDS
    // lands on exactly the rectangles Pegasus was using. Both target panels are
    // 800x480: a Waveshare 5-inch HDMI on top and a 4-DSI-TOUCH-A rotated to
    // landscape below. These windows are stripped of their chrome, so the
    // window rectangle is the client area; TitleBar only reserves the space the
    // Pegasus lower window's caption occupies between the two panels.
    private const int PanelWidth = 800;
    private const int PanelHeight = 480;
    private const int TitleBar = 58;
    private const int Hinge = 32;

    private const int GwlStyle = -16;
    private const long WindowChrome = 0x00CC0000L;
    private const uint SwpNoZOrder = 0x0004;
    private const uint SwpNoActivate = 0x0010;
    private const uint SwpFrameChanged = 0x0020;

    private static List<IntPtr> WindowsForProcess(int processId)
    {
        var windows = new List<IntPtr>();
        EnumWindows(delegate(IntPtr window, IntPtr ignored) {
            uint owner;
            GetWindowThreadProcessId(window, out owner);
            if (owner == processId && IsWindowVisible(window))
                windows.Add(window);
            return true;
        }, IntPtr.Zero);
        return windows;
    }

    private static string Title(IntPtr window)
    {
        var text = new StringBuilder(256);
        GetWindowText(window, text, text.Capacity);
        return text.ToString();
    }

    private static void Frame(IntPtr window, int x, int y, int width, int height)
    {
        var style = GetWindowLongPtr(window, GwlStyle).ToInt64() & ~WindowChrome;
        SetWindowLongPtr(window, GwlStyle, new IntPtr(style));
        SetMenu(window, IntPtr.Zero);
        SetWindowPos(window, IntPtr.Zero, x, y, width, height, SwpNoZOrder | SwpNoActivate | SwpFrameChanged);
    }

    public static bool ApplyD2KLayout(int processId)
    {
        bool topFound = false;
        bool bottomFound = false;

        int screenWidth = GetSystemMetrics(0);
        int screenHeight = GetSystemMetrics(1);
        int stackHeight = PanelHeight * 2 + TitleBar + Hinge;
        int left = (int)Math.Round((screenWidth - PanelWidth) / 2.0);
        int top = (int)Math.Round(Math.Max(40.0, (screenHeight - stackHeight) / 2.0));
        int bottom = top + PanelHeight + TitleBar + Hinge;

        foreach (var window in WindowsForProcess(processId)) {
            var title = Title(window);
            if (title.Contains("[w1]")) {
                Frame(window, left, top, PanelWidth, PanelHeight);
                topFound = true;
            }
            else if (title.Contains("[w2]")) {
                Frame(window, left, bottom, PanelWidth, PanelHeight);
                bottomFound = true;
            }
        }

        return topFound && bottomFound;
    }
}
'@

# Use physical desktop pixels so the two borderless emulator windows match the
# Pegasus 800x480 previews, matching the target Waveshare panels.
[D2KWindows]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

$process = Start-Process -FilePath $emulator -ArgumentList ('"{0}"' -f $RomPath) -WorkingDirectory $emulatorDir -PassThru
$deadline = [DateTime]::UtcNow.AddSeconds(10)
while ([DateTime]::UtcNow -lt $deadline -and -not $process.HasExited) {
    if ([D2KWindows]::ApplyD2KLayout($process.Id)) {
        break
    }
    Start-Sleep -Milliseconds 100
}

$process.WaitForExit()
