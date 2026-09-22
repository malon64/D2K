<#
.SYNOPSIS
    Builds library/consoles/music/metadata.pegasus.txt from the ID3 tags of the
    files in library/consoles/music/tracks/.

.DESCRIPTION
    Pegasus only indexes a console directory that contains a metadata.pegasus.txt
    (see setup.ps1 and scripts/linux/install.sh), so without this file there is no
    "music" collection for the theme to bind to.

    For every readable .mp3 the script reads TIT2 (title), TPE1 (artist),
    TALB (album), TCON (genre), TDRC/TYER (year) and TLEN (length), extracts the
    embedded APIC cover art to covers/, and writes one `game:` entry per track.
    Track length has no dedicated Pegasus field, so it is written to `summary:`
    as m:ss and read back in QML as game.summary.

    Re-run this whenever tracks are added or removed. It rewrites the metadata
    file and any covers it can extract; it never touches the audio files.

.PARAMETER LibraryRoot
    The library directory. Defaults to <repo>/library.

.PARAMETER WhatIf
    Report what would be written without writing anything.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $LibraryRoot
)

$ErrorActionPreference = 'Stop'

if (-not $LibraryRoot) {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $LibraryRoot = Join-Path $repoRoot 'library'
}

$musicDir  = Join-Path $LibraryRoot 'consoles/music'
$tracksDir = Join-Path $musicDir 'tracks'
$coversDir = Join-Path $musicDir 'covers'
$outFile   = Join-Path $musicDir 'metadata.pegasus.txt'

if (-not (Test-Path -LiteralPath $tracksDir)) {
    throw "No tracks directory at $tracksDir. Pass -LibraryRoot if your library lives elsewhere."
}

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

public class Id3 {
    public string Title, Artist, Album, Genre, Year;
    public int DurationMs;
    public byte[] Picture;
    public string PictureMime;
    public string Error;
}

public static class Id3Reader {

    const char BOM = (char)0xFEFF;

    static int SynchSafe(byte[] b, int o) {
        return (b[o] & 0x7f) << 21 | (b[o+1] & 0x7f) << 14 | (b[o+2] & 0x7f) << 7 | (b[o+3] & 0x7f);
    }
    static int BE32(byte[] b, int o) {
        return b[o] << 24 | b[o+1] << 16 | b[o+2] << 8 | b[o+3];
    }

    static string Decode(byte[] d, int start, int len, byte enc) {
        if (len <= 0) return "";
        switch (enc) {
            case 0: return Encoding.GetEncoding(28591).GetString(d, start, len).TrimEnd('\0').Trim();
            case 1: return Encoding.Unicode.GetString(d, start, len).Trim(BOM, '\0').Trim();
            case 2: return Encoding.BigEndianUnicode.GetString(d, start, len).Trim(BOM, '\0').Trim();
            default: return Encoding.UTF8.GetString(d, start, len).TrimEnd('\0').Trim();
        }
    }

    // Length of the terminator for a given text encoding (UTF-16 uses two bytes).
    static int TermLen(byte enc) { return (enc == 1 || enc == 2) ? 2 : 1; }

    static int FindTerm(byte[] d, int start, int end, byte enc) {
        int step = TermLen(enc);
        for (int i = start; i + step <= end; i += step) {
            bool zero = true;
            for (int k = 0; k < step; k++) if (d[i + k] != 0) { zero = false; break; }
            if (zero) return i;
        }
        return end;
    }

    public static Id3 Read(string path) {
        var r = new Id3();
        try {
            var fi = new FileInfo(path);
            if (fi.Length == 0) { r.Error = "empty file"; return r; }

            using (var fs = File.OpenRead(path)) {
                var hdr = new byte[10];
                if (fs.Read(hdr, 0, 10) != 10) { r.Error = "too short"; return r; }

                if (hdr[0] == 'I' && hdr[1] == 'D' && hdr[2] == '3') {
                    int major = hdr[3];
                    int tagSize = SynchSafe(hdr, 6);
                    var tag = new byte[tagSize];
                    ReadFull(fs, tag, tagSize);

                    int p = 0;
                    // skip an extended header when present
                    if ((hdr[5] & 0x40) != 0 && tagSize > 4) {
                        p += (major >= 4) ? SynchSafe(tag, 0) : BE32(tag, 0) + 4;
                    }

                    while (p + 10 <= tagSize) {
                        string id = Encoding.ASCII.GetString(tag, p, 4);
                        if (id[0] == '\0') break;
                        int size = (major >= 4) ? SynchSafe(tag, p + 4) : BE32(tag, p + 4);
                        if (size <= 0 || p + 10 + size > tagSize) break;
                        int d0 = p + 10, dEnd = d0 + size;

                        if (id == "APIC") {
                            byte enc = tag[d0];
                            int mEnd = FindTerm(tag, d0 + 1, dEnd, 0);
                            r.PictureMime = Encoding.ASCII.GetString(tag, d0 + 1, mEnd - (d0 + 1));
                            int q = mEnd + 1;          // past mime terminator
                            q += 1;                    // picture type byte
                            int dscEnd = FindTerm(tag, q, dEnd, enc);
                            q = dscEnd + TermLen(enc); // past description terminator
                            int picLen = dEnd - q;
                            if (picLen > 0 && (r.Picture == null || picLen > r.Picture.Length)) {
                                r.Picture = new byte[picLen];
                                Array.Copy(tag, q, r.Picture, 0, picLen);
                            }
                        } else if (id[0] == 'T') {
                            string v = Decode(tag, d0 + 1, size - 1, tag[d0]);
                            switch (id) {
                                case "TIT2": r.Title  = v; break;
                                case "TPE1": r.Artist = v; break;
                                case "TALB": r.Album  = v; break;
                                case "TCON": r.Genre  = v; break;
                                case "TDRC": case "TYER": r.Year = v; break;
                                case "TLEN":
                                    int ms; if (int.TryParse(v.Trim(), out ms)) r.DurationMs = ms;
                                    break;
                            }
                        }
                        p += 10 + size;
                    }
                }

                // Fall back to the audio stream itself when TLEN is absent or bogus:
                // a Xing/Info frame count when present, otherwise a CBR estimate.
                if (r.DurationMs <= 0) r.DurationMs = StreamDuration(fs);
            }
        } catch (Exception ex) { r.Error = ex.Message; }
        return r;
    }

    static void ReadFull(Stream s, byte[] buf, int count) {
        int got = 0;
        while (got < count) {
            int n = s.Read(buf, got, count - got);
            if (n <= 0) break;
            got += n;
        }
    }

    static readonly int[] RatesV1 = { 44100, 48000, 32000, 0 };
    static readonly int[] RatesV2 = { 22050, 24000, 16000, 0 };
    static readonly int[] RatesV25 = { 11025, 12000, 8000, 0 };

    // kbps by bitrate index; MPEG1 Layer III, then MPEG2/2.5 Layer III.
    static readonly int[] BitrateV1L3 = { 0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,0 };
    static readonly int[] BitrateV2L3 = { 0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0 };

    // Locate the first MPEG audio frame and derive the duration from it: a
    // Xing/Info frame count when the encoder wrote one, otherwise a constant
    // bitrate estimate over the remaining bytes. These files are 320kbps CBR
    // with no VBR header, so the CBR path is the one that actually runs.
    static int StreamDuration(Stream fs) {
        try {
            fs.Seek(0, SeekOrigin.Begin);
            int window = (int)Math.Min(fs.Length, 2 * 1024 * 1024);
            var buf = new byte[window];
            ReadFull(fs, buf, window);

            for (int i = 0; i + 4 < window; i++) {
                if (buf[i] != 0xFF || (buf[i+1] & 0xE0) != 0xE0) continue;
                int verBits = (buf[i+1] >> 3) & 0x03;   // 3 = MPEG1, 2 = MPEG2, 0 = MPEG2.5
                int layer   = (buf[i+1] >> 1) & 0x03;   // 1 = Layer III
                int rateIdx = (buf[i+2] >> 2) & 0x03;
                int brIdx   = (buf[i+2] >> 4) & 0x0F;
                if (layer != 1 || verBits == 1 || rateIdx == 3) continue;
                if (brIdx == 0 || brIdx == 15) continue;

                int rate = verBits == 3 ? RatesV1[rateIdx] : verBits == 2 ? RatesV2[rateIdx] : RatesV25[rateIdx];
                if (rate == 0) continue;
                int samplesPerFrame = verBits == 3 ? 1152 : 576;

                int mode = (buf[i+3] >> 6) & 0x03;
                int sideInfo = verBits == 3 ? (mode == 3 ? 17 : 32) : (mode == 3 ? 9 : 17);
                int tagAt = i + 4 + sideInfo;

                if (tagAt + 12 <= window) {
                    string marker = Encoding.ASCII.GetString(buf, tagAt, 4);
                    if (marker == "Xing" || marker == "Info") {
                        int flags = BE32(buf, tagAt + 4);
                        if ((flags & 0x01) != 0) {
                            int frames = BE32(buf, tagAt + 8);
                            if (frames > 0) return (int)((double)frames * samplesPerFrame / rate * 1000.0);
                        }
                    }
                }

                int kbps = verBits == 3 ? BitrateV1L3[brIdx] : BitrateV2L3[brIdx];
                if (kbps <= 0) continue;
                long audioBytes = fs.Length - i;
                if (HasId3v1(fs)) audioBytes -= 128;
                if (audioBytes <= 0) continue;
                return (int)((double)audioBytes * 8.0 / (kbps * 1000.0) * 1000.0);
            }
        } catch { }
        return 0;
    }

    static bool HasId3v1(Stream fs) {
        try {
            if (fs.Length < 128) return false;
            long back = fs.Position;
            fs.Seek(-128, SeekOrigin.End);
            var t = new byte[3];
            ReadFull(fs, t, 3);
            fs.Seek(back, SeekOrigin.Begin);
            return t[0] == 'T' && t[1] == 'A' && t[2] == 'G';
        } catch { return false; }
    }
}
'@

function Get-Slug([string] $text) {
    $s = $text.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($c in $s.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
    }
    $out = ($sb.ToString() -replace '[^A-Za-z0-9]+', '-').Trim('-').ToLowerInvariant()
    if (-not $out) { $out = 'track' }
    return $out
}

function Format-Duration([int] $ms) {
    if ($ms -le 0) { return $null }
    $t = [TimeSpan]::FromMilliseconds($ms)
    # [int] rounds to nearest, which turns 3:39 into 4:39 - floor explicitly.
    return ('{0}:{1:D2}' -f [int][Math]::Floor($t.TotalMinutes), $t.Seconds)
}

# ---------------------------------------------------------------- scan tracks

$files = Get-ChildItem -LiteralPath $tracksDir -Filter *.mp3 -File | Sort-Object Name
Write-Host ("Scanning {0} file(s) in {1}" -f $files.Count, $tracksDir)

$entries = @()
$skipped = @()

foreach ($f in $files) {
    $tag = [Id3Reader]::Read($f.FullName)

    if ($tag.Error) {
        $skipped += [pscustomobject]@{ Name = $f.Name; Reason = $tag.Error }
        continue
    }

    # Fall back to the "<artist> - <title>" filename convention when tags are thin.
    $title  = $tag.Title
    $artist = $tag.Artist
    if (-not $title -or -not $artist) {
        $stem = [IO.Path]::GetFileNameWithoutExtension($f.Name)
        $split = $stem -split ' - ', 2
        if (-not $artist -and $split.Count -eq 2) { $artist = $split[0].Trim() }
        if (-not $title) { $title = if ($split.Count -eq 2) { $split[1].Trim() } else { $stem } }
    }

    $slug = Get-Slug ("$artist $title")
    $cover = $null

    # These files carry no ID3 art, so the usual path is a cover dropped into
    # covers/<slug>.png|jpg by hand. An embedded APIC, if one ever appears,
    # takes precedence and is extracted over it.
    foreach ($ext in 'png', 'jpg', 'jpeg') {
        $candidate = Join-Path $coversDir "$slug.$ext"
        if (Test-Path -LiteralPath $candidate) { $cover = "covers/$slug.$ext"; break }
    }

    if ($tag.Picture -and $tag.Picture.Length -gt 0) {
        $ext = if ($tag.PictureMime -match 'png') { 'png' } else { 'jpg' }
        $coverRel = "covers/$slug.$ext"
        $coverAbs = Join-Path $musicDir $coverRel
        if ($PSCmdlet.ShouldProcess($coverRel, 'write cover')) {
            if (-not (Test-Path -LiteralPath $coversDir)) { New-Item -ItemType Directory -Path $coversDir -Force | Out-Null }
            [IO.File]::WriteAllBytes($coverAbs, $tag.Picture)
        }
        $cover = $coverRel
    }

    $entries += [pscustomobject]@{
        Title    = $title
        Artist   = $artist
        Album    = $tag.Album
        Genre    = $tag.Genre
        Year     = $tag.Year
        Duration = Format-Duration $tag.DurationMs
        File     = "tracks/$($f.Name)"
        Cover    = $cover
    }
}

# ------------------------------------------------------------------- emit file

$sb = New-Object Text.StringBuilder
[void]$sb.AppendLine('collection: Music')
[void]$sb.AppendLine('shortname: music')
[void]$sb.AppendLine('description: Local D2K music library. Playback is handled by MPD; the theme only selects tracks.')
[void]$sb.AppendLine()
[void]$sb.AppendLine('# Generated by scripts/windows/build-music-metadata.ps1 - do not edit by hand.')
[void]$sb.AppendLine('# summary: holds the track length as m:ss (Pegasus has no duration field).')
[void]$sb.AppendLine()

foreach ($e in $entries) {
    [void]$sb.AppendLine("game: $($e.Title)")
    [void]$sb.AppendLine("file: $($e.File)")
    if ($e.Artist)   { [void]$sb.AppendLine("developer: $($e.Artist)") }
    if ($e.Album)    { [void]$sb.AppendLine("publisher: $($e.Album)") }
    if ($e.Genre)    { [void]$sb.AppendLine("genre: $($e.Genre)") }
    if ($e.Year -and $e.Year -match '(\d{4})') { [void]$sb.AppendLine("release: $($Matches[1])") }
    if ($e.Duration) { [void]$sb.AppendLine("summary: $($e.Duration)") }
    if ($e.Cover)    { [void]$sb.AppendLine("assets.boxFront: $($e.Cover)") }
    [void]$sb.AppendLine()
}

if ($PSCmdlet.ShouldProcess($outFile, 'write metadata')) {
    [IO.File]::WriteAllText($outFile, $sb.ToString(), (New-Object Text.UTF8Encoding($false)))
}

# --------------------------------------------------------------------- report

Write-Host ''
$entries | Select-Object @{n='#';e={[array]::IndexOf($entries,$_)+1}}, Title, Artist, Duration,
    @{n='Cover';e={ if ($_.Cover) { 'yes' } else { '-' } }} | Format-Table -AutoSize

Write-Host ("Wrote {0} track(s) to {1}" -f $entries.Count, $outFile)
$withCover = @($entries | Where-Object { $_.Cover }).Count
$noDuration = @($entries | Where-Object { -not $_.Duration }).Count
Write-Host ("  covers extracted : {0}/{1}" -f $withCover, $entries.Count)
if ($noDuration -gt 0) { Write-Warning ("  {0} track(s) have no readable duration" -f $noDuration) }

if ($skipped.Count -gt 0) {
    Write-Host ''
    Write-Warning ("Skipped {0} file(s):" -f $skipped.Count)
    $skipped | Format-Table -AutoSize
}
