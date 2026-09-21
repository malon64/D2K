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

# Patched line by line rather than by regex-slicing the raw text: an earlier
# version of this script extracted each [Instance0.WindowN] section as a
# substring and spliced a modified copy back in, which on at least one run
# ate the newline between a section's last line and the next section's
# header, gluing them together (e.g. "Enabled = true[Instance0.Firmware]")
# and corrupting the file for every launch after that. Operating on the line
# array instead makes that class of corruption structurally impossible: every
# line keeps its own boundary no matter what gets rewritten.
$lines = Get-Content -LiteralPath $configPath
$currentSection = ''
$window1Seen = $false
$window1EnabledSeen = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    if ($line -match '^\[(.+)\]\s*$') {
        $currentSection = $Matches[1]
        continue
    }

    if ($currentSection -eq 'Instance0.Window1') {
        $window1Seen = $true

        # Window 1 starts disabled by default and melonDS re-disables it
        # whenever its own window is closed on its own (rather than the whole
        # app exiting), so this re-enables it before every launch. Leaving an
        # already-true value alone (rather than treating "no change needed"
        # as an error) matters because that is also the steady state after
        # any successful prior run.
        if ($line -match '^Enabled\s*=\s*\w+\s*$') {
            $window1EnabledSeen = $true
            $lines[$i] = 'Enabled = true'
        }
    }

    # melonDS saves each window's position and size to a Qt Geometry blob on
    # exit and restores it on the next launch, after this script's own
    # SetWindowPos call -- silently undoing it. Blank the saved blob (rather
    # than deleting the line, which is what previously required the fragile
    # section-slicing this replaced) so melonDS has nothing to restore,
    # leaving CheckD2KLayout below as the only thing that ever sets geometry.
    if ($currentSection -match '^Instance0\.Window[0-3]$' -and $line -match '^Geometry\s*=') {
        $lines[$i] = 'Geometry = ""'
    }
}

if (-not $window1Seen) {
    throw "[Instance0.Window1] was not found in $configPath"
}
if (-not $window1EnabledSeen) {
    throw "Window 1 has no Enabled setting in $configPath"
}

# Set-Content's utf8 encoding writes a BOM, which the original WriteAllText
# call deliberately avoided; match that here since a BOM at the top of a TOML
# file is exactly the kind of thing that could silently break melonDS's parser.
[System.IO.File]::WriteAllLines($configPath, $lines, [System.Text.UTF8Encoding]::new($false))

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
    private static extern bool GetClientRect(IntPtr window, out RECT rect);

    [DllImport("user32.dll")]
    private static extern bool ClientToScreen(IntPtr window, ref POINT point);

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int L, T, R, B; }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT { public int X, Y; }

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

    private static bool Matches(IntPtr window, int x, int y, int width, int height)
    {
        RECT client;
        GetClientRect(window, out client);
        POINT origin = new POINT();
        ClientToScreen(window, ref origin);
        return origin.X == x && origin.Y == y && client.R == width && client.B == height;
    }

    // Finds both D2K windows for the process, forces any mismatched one back to
    // its target rectangle, and reports whether both were found and already
    // matched before this call (i.e. nothing needed correcting). melonDS loads
    // its BIOS, firmware and ROM before it settles, and its own startup layout
    // logic can still resize a window well after it first appears, silently
    // undoing an earlier fix -- so the caller polls this until it comes back
    // stable, rather than stopping at the first time both windows exist.
    public static bool CheckD2KLayout(int processId)
    {
        bool topFound = false;
        bool bottomFound = false;
        bool stable = true;

        int screenWidth = GetSystemMetrics(0);
        int screenHeight = GetSystemMetrics(1);
        int stackHeight = PanelHeight * 2 + TitleBar + Hinge;
        int left = (int)Math.Round((screenWidth - PanelWidth) / 2.0);
        int top = (int)Math.Round(Math.Max(40.0, (screenHeight - stackHeight) / 2.0));
        int bottom = top + PanelHeight + TitleBar + Hinge;

        foreach (var window in WindowsForProcess(processId)) {
            var title = Title(window);
            if (title.Contains("[w1]")) {
                topFound = true;
                if (!Matches(window, left, top, PanelWidth, PanelHeight)) {
                    stable = false;
                    Frame(window, left, top, PanelWidth, PanelHeight);
                }
            }
            else if (title.Contains("[w2]")) {
                bottomFound = true;
                if (!Matches(window, left, bottom, PanelWidth, PanelHeight)) {
                    stable = false;
                    Frame(window, left, bottom, PanelWidth, PanelHeight);
                }
            }
        }

        return topFound && bottomFound && stable;
    }
}
'@

# Use physical desktop pixels so the two borderless emulator windows match the
# Pegasus 800x480 previews, matching the target Waveshare panels.
[D2KWindows]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

$process = Start-Process -FilePath $emulator -ArgumentList ('"{0}"' -f $RomPath) -WorkingDirectory $emulatorDir -PassThru

# Keep correcting the window layout until it has read back correct on several
# consecutive checks, rather than stopping at the first time both windows
# exist. melonDS loads its BIOS, firmware and ROM before it settles, and its
# own startup layout logic can resize a window well after it first appears,
# silently undoing an earlier fix; how long that takes varies run to run.
$deadline = [DateTime]::UtcNow.AddSeconds(15)
$consecutiveStable = 0
$stableTarget = 5
while ([DateTime]::UtcNow -lt $deadline -and -not $process.HasExited -and $consecutiveStable -lt $stableTarget) {
    if ([D2KWindows]::CheckD2KLayout($process.Id)) {
        $consecutiveStable += 1
    }
    else {
        $consecutiveStable = 0
    }
    Start-Sleep -Milliseconds 150
}

$process.WaitForExit()
