param(
    [Parameter(Mandatory = $true)]
    [string]$RomPath
)

$ErrorActionPreference = 'Stop'

$emulatorDir = 'C:\Users\alexi\Documents\NDS\melonDS-1.1-windows-x86_64'
$emulator = Join-Path $emulatorDir 'melonDS.exe'
$configPath = Join-Path $emulatorDir 'melonDS.toml'

$logDir = Join-Path $env:LOCALAPPDATA 'D2K'
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logPath = Join-Path $logDir 'launch-melonds.log'
$homeRequestPath = Join-Path $logDir 'home-request'

function Write-Log {
    param([string]$Message)
    $line = "{0:yyyy-MM-ddTHH:mm:ss.fff}  {1}" -f (Get-Date), $Message
    Add-Content -LiteralPath $logPath -Value $line
}

Write-Log "===== launch-melonds start: rom=$RomPath ====="

$mpdScript = Join-Path $PSScriptRoot 'mpd.ps1'
try {
    & $mpdScript -Action Pause
    Write-Log 'MPD paused'
}
catch {
    Write-Log "MPD pause FAILED (non-fatal): $($_.Exception.Message)"
}

# This script's lifetime IS the game's lifetime as far as Pegasus is concerned:
# Pegasus tears down its whole QML scene before this runs and only rebuilds it
# once this script (and the process it launched) exits. Nothing below may ever
# let that happen early -- a cosmetic window-framing failure must never end the
# game, so only the emulator launch and its own exit are allowed to be fatal.

try {
    if (-not (Test-Path -LiteralPath $emulator -PathType Leaf)) {
        throw "melonDS was not found at $emulator"
    }

    if (-not (Test-Path -LiteralPath $RomPath -PathType Leaf)) {
        throw "ROM was not found at $RomPath"
    }

    try {
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
        Write-Log "Config patched OK"
    }
    catch {
        # A config-patch failure is cosmetic (wrong window size/position at worst),
        # not fatal -- melonDS still runs the game. Log and carry on.
        Write-Log "Config patch FAILED (non-fatal): $($_.Exception.Message)"
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

    // GetWindowLongPtrW/SetWindowLongPtrW are not exported by the 32-bit
    // user32.dll at all (on Win32 they are a compile-time macro that expands
    // to the plain, non-Ptr functions -- there is no such DLL entry point to
    // call). pegasus-fe.exe is itself a 32-bit executable, so the
    // powershell.exe it launches is the WOW64-redirected 32-bit PowerShell,
    // and every call here was throwing "Impossible de trouver le point
    // d'entree" and silently skipping the whole frame -- the actual cause of
    // melonDS staying at its small saved size. The plain functions carry a
    // 32-bit style value regardless of process bitness, so they are correct
    // (and exported) on both architectures.
    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    private static extern int GetWindowLong(IntPtr window, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")]
    private static extern int SetWindowLong(IntPtr window, int index, int value);

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
    private const int WindowChrome = 0x00CC0000;
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
        int style = GetWindowLong(window, GwlStyle) & ~WindowChrome;
        SetWindowLong(window, GwlStyle, style);
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
    try {
        [D2KWindows]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
    }
    catch {
        Write-Log "SetProcessDpiAwarenessContext FAILED (non-fatal): $($_.Exception.Message)"
    }

    # Process.Start either returns a real process object or throws -- unlike
    # Start-Process -PassThru, which can hand back a stale/incomplete object on
    # some failure paths. A null or bad $process here must be a hard failure:
    # everything below assumes it is real.
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $emulator
    $startInfo.Arguments = '"{0}"' -f $RomPath
    $startInfo.WorkingDirectory = $emulatorDir
    $startInfo.UseShellExecute = $false

    $process = [System.Diagnostics.Process]::Start($startInfo)
    if (-not $process) {
        throw "Failed to start melonDS process"
    }
    Write-Log "melonDS started: pid=$($process.Id)"

    try {
        # This is the whole game session, not just a startup-settling window:
        # the loop keeps correcting the window layout for as long as it is
        # unstable, and on every tick also checks the Home seam so a request
        # dropped at any point during play is honored quickly. WaitForExit is
        # no longer a separate blocking call -- the loop itself IS the wait,
        # so a Home-triggered close is noticed immediately rather than only
        # after some earlier fixed deadline.
        $consecutiveStable = 0
        $stableTarget = 5
        $layoutSettled = $false

        while (-not $process.HasExited) {
            if (-not $layoutSettled) {
                try {
                    if ([D2KWindows]::CheckD2KLayout($process.Id)) {
                        $consecutiveStable += 1
                        if ($consecutiveStable -ge $stableTarget) {
                            $layoutSettled = $true
                            Write-Log "Layout settled after $consecutiveStable consecutive stable checks"
                        }
                    }
                    else {
                        $consecutiveStable = 0
                    }
                }
                catch {
                    Write-Log "CheckD2KLayout FAILED (non-fatal): $($_.Exception.Message)"
                    $layoutSettled = $true
                }
            }

            if (Test-Path -LiteralPath $homeRequestPath) {
                Write-Log "Home request detected -- closing melonDS"
                Remove-Item -LiteralPath $homeRequestPath -Force -ErrorAction SilentlyContinue

                try {
                    $process.CloseMainWindow() | Out-Null
                }
                catch {
                    Write-Log "CloseMainWindow FAILED (non-fatal): $($_.Exception.Message)"
                }

                if (-not $process.WaitForExit(3000)) {
                    Write-Log "melonDS did not exit gracefully -- killing"
                    try { $process.Kill() } catch { Write-Log "Kill FAILED: $($_.Exception.Message)" }
                }
                break
            }

            Start-Sleep -Milliseconds 150
        }

        $process.WaitForExit()
        Write-Log "melonDS exited: code=$($process.ExitCode)"
    }
    finally {
        if (-not $process.HasExited) {
            Write-Log "Ensuring melonDS process is closed before returning"
            try { $process.CloseMainWindow() | Out-Null } catch {}
            if (-not $process.WaitForExit(2000)) {
                try { $process.Kill() } catch {}
            }
        }
    }

    Write-Log "===== launch-melonds end (ok) ====="
}
catch {
    Write-Log "FATAL: $($_.Exception.Message)"
    Write-Log $_.ScriptStackTrace
    Write-Log "===== launch-melonds end (error, suppressed) ====="
}

try {
    & $mpdScript -Action Resume
    Write-Log 'MPD resumed'
}
catch {
    Write-Log "MPD resume FAILED (non-fatal): $($_.Exception.Message)"
}

# Regardless of what happened above, this script must exit cleanly (code 0) so
# Pegasus never treats a cosmetic failure here as "the game crashed" and skips
# straight back to the menu while melonDS is still on screen -- that was the
# original bug. The real game process's own lifetime is what Pegasus should be
# timing itself against, and by this point it has already ended.
exit 0
