<#
.SYNOPSIS
    Extracts embedded cover art from a downloaded playlist archive and files it
    against the matching tracks in library/consoles/music/.

.DESCRIPTION
    The D2K music files carry no ID3 tags of their own, so there is no artwork to
    show in the theme. Archives downloaded from playlist sites do carry tagged
    copies of the same songs; this script lifts the APIC artwork out of those and
    writes it to covers/<slug>.jpg, where build-music-metadata.ps1 already picks
    it up as assets.boxFront.

    Only the artwork is taken. The audio in the archive is ignored, so the
    library keeps its own higher-quality files.

    Matching is done on normalised artist and title rather than filename, because
    the two sources disagree about both: the archive writes multi-artist fields
    slash-separated ("Carl Chaste/Toriline") and drops the qualifiers the library
    keeps in its filenames ("About U" vs "About U (feat. Toriline)").

.PARAMETER Source
    The playlist archive to read artwork from, or a folder of already-extracted
    tagged mp3 files.

.PARAMETER LibraryRoot
    The library directory. Defaults to <repo>/library.

.PARAMETER WhatIf
    Report the matches without writing any files.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Zip')]
    [string] $Source,
    [string] $LibraryRoot
)

$ErrorActionPreference = 'Stop'

if (-not $LibraryRoot) {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $LibraryRoot = Join-Path $repoRoot 'library'
}
if (-not (Test-Path -LiteralPath $Source)) { throw "Source not found: $Source" }

$musicDir  = Join-Path $LibraryRoot 'consoles/music'
$tracksDir = Join-Path $musicDir 'tracks'
$coversDir = Join-Path $musicDir 'covers'
if (-not (Test-Path -LiteralPath $tracksDir)) { throw "No tracks directory at $tracksDir" }

Add-Type -AssemblyName System.IO.Compression.FileSystem

Add-Type -TypeDefinition @'
using System; using System.IO; using System.Text;
public class Art { public string Title="", Artist=""; public byte[] Picture; public string Mime=""; }
public static class ArtReader {
  const char BOM=(char)0xFEFF;
  static int SS(byte[] b,int o){ return (b[o]&0x7f)<<21|(b[o+1]&0x7f)<<14|(b[o+2]&0x7f)<<7|(b[o+3]&0x7f); }
  static int BE(byte[] b,int o){ return b[o]<<24|b[o+1]<<16|b[o+2]<<8|b[o+3]; }
  static string Dec(byte[] d,int s,int l,byte e){
    if(l<=0) return "";
    switch(e){
      case 0: return Encoding.GetEncoding(28591).GetString(d,s,l).Trim('\0').Trim();
      case 1: return Encoding.Unicode.GetString(d,s,l).Trim(BOM,'\0').Trim();
      case 2: return Encoding.BigEndianUnicode.GetString(d,s,l).Trim(BOM,'\0').Trim();
      default: return Encoding.UTF8.GetString(d,s,l).Trim('\0').Trim();
    }
  }
  static int TermLen(byte e){ return (e==1||e==2)?2:1; }
  static int FindTerm(byte[] d,int s,int e,byte enc){
    int step=TermLen(enc);
    for(int i=s;i+step<=e;i+=step){ bool z=true; for(int k=0;k<step;k++) if(d[i+k]!=0){z=false;break;} if(z) return i; }
    return e;
  }
  public static Art Read(string path){
    var r=new Art();
    using(var fs=File.OpenRead(path)){
      var h=new byte[10]; if(fs.Read(h,0,10)!=10) return r;
      if(!(h[0]=='I'&&h[1]=='D'&&h[2]=='3')) return r;
      int major=h[3], size=SS(h,6);
      var tag=new byte[size]; int got=0;
      while(got<size){ int n=fs.Read(tag,got,size-got); if(n<=0) break; got+=n; }
      int p=0;
      while(p+10<=size){
        string id=Encoding.ASCII.GetString(tag,p,4); if(id[0]=='\0') break;
        int fl=(major>=4)?SS(tag,p+4):BE(tag,p+4);
        if(fl<=0||p+10+fl>size) break;
        int d0=p+10, dEnd=d0+fl;
        if(id=="APIC"){
          byte enc=tag[d0];
          int mEnd=FindTerm(tag,d0+1,dEnd,0);
          string mime=Encoding.ASCII.GetString(tag,d0+1,mEnd-(d0+1));
          int q=mEnd+1+1;
          int dsc=FindTerm(tag,q,dEnd,enc);
          q=dsc+TermLen(enc);
          int len=dEnd-q;
          if(len>0 && (r.Picture==null || len>r.Picture.Length)){
            r.Picture=new byte[len]; Array.Copy(tag,q,r.Picture,0,len); r.Mime=mime;
          }
        } else if(id[0]=='T'){
          string v=Dec(tag,d0+1,fl-1,tag[d0]);
          if(id=="TIT2") r.Title=v; else if(id=="TPE1") r.Artist=v;
        }
        p+=10+fl;
      }
    }
    return r;
  }
}
'@

# ------------------------------------------------------------------- helpers

function Remove-Diacritics([string] $t) {
    $s = $t.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($c in $s.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
    }
    return $sb.ToString()
}

function Get-Slug([string] $text) {
    $out = ((Remove-Diacritics $text) -replace '[^A-Za-z0-9]+', '-').Trim('-').ToLowerInvariant()
    if (-not $out) { $out = 'track' }
    return $out
}

# Comparison key: diacritics and punctuation removed, lowercased.
function Get-Key([string] $text) {
    return ((Remove-Diacritics $text) -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
}

# Drop the qualifiers the two sources disagree about: (feat. x), (Remix),
# (Original Version), [Deep Down] and so on.
function Get-CoreTitle([string] $title) {
    return (($title -replace '\s*[\(\[][^\)\]]*[\)\]]', '')).Trim()
}

# "Miss Bashful x SITA" / "Miss Bashful/SITA" -> "Miss Bashful"
function Get-PrimaryArtist([string] $artist) {
    # @() matters: a single-element -split returns a string, and indexing a
    # string yields a [char], which has no .Trim().
    $a = @($artist -split '\s*/\s*|\s+x\s+|\s*,\s*|\s*&\s*|\s+feat\.?\s+' | Where-Object { $_ })
    if ($a.Count -gt 0) { return ([string]$a[0]).Trim() }
    return $artist
}

function Get-Similarity([string] $a, [string] $b) {
    if (-not $a -or -not $b) { return 0.0 }
    if ($a -eq $b) { return 1.0 }
    $n = $a.Length; $m = $b.Length
    $d = New-Object 'int[,]' ($n + 1), ($m + 1)
    for ($i = 0; $i -le $n; $i++) { $d[$i, 0] = $i }
    for ($j = 0; $j -le $m; $j++) { $d[0, $j] = $j }
    for ($i = 1; $i -le $n; $i++) {
        for ($j = 1; $j -le $m; $j++) {
            # PowerShell 5.1 will not parse arithmetic inside a 2-D index,
            # so every subscript expression is parenthesised.
            $cost = if ($a[($i - 1)] -eq $b[($j - 1)]) { 0 } else { 1 }
            $del = $d[($i - 1), $j] + 1
            $ins = $d[$i, ($j - 1)] + 1
            $sub = $d[($i - 1), ($j - 1)] + $cost
            $d[$i, $j] = [Math]::Min([Math]::Min($del, $ins), $sub)
        }
    }
    return 1.0 - ($d[$n, $m] / [double][Math]::Max($n, $m))
}

# -------------------------------------------------------------- read archive

# A folder is read in place; only an archive gets staged (and cleaned up after).
$staging = $null
if (Test-Path -LiteralPath $Source -PathType Container) {
    $readFrom = $Source
} else {
    $staging = Join-Path ([IO.Path]::GetTempPath()) ('d2k-art-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    [IO.Compression.ZipFile]::ExtractToDirectory($Source, $staging)
    $readFrom = $staging
}

try {
    # Not $source: that would collide with the [string]$Source parameter and be
    # coerced straight back to a string.
    $incoming = @()
    foreach ($f in Get-ChildItem -LiteralPath $readFrom -Filter *.mp3 -File -Recurse) {
        $a = [ArtReader]::Read($f.FullName)
        if (-not $a.Picture -or $a.Picture.Length -eq 0) { continue }
        $core = Get-CoreTitle $a.Title
        $incoming += [pscustomobject]@{
            Title     = $a.Title
            Artist    = $a.Artist
            TitleKey  = Get-Key $core
            ArtistKey = Get-Key (Get-PrimaryArtist $a.Artist)
            Picture   = $a.Picture
            Mime      = $a.Mime
        }
    }
    Write-Host ("Archive: {0} track(s) carrying artwork" -f $incoming.Count)

    # ------------------------------------------------------- read the library

    $library = @()
    foreach ($f in Get-ChildItem -LiteralPath $tracksDir -Filter *.mp3 -File -Recurse | Sort-Object Name) {
        if ($f.Length -eq 0) { continue }
        $stem = [IO.Path]::GetFileNameWithoutExtension($f.Name)
        $split = $stem -split ' - ', 2
        $artist = if ($split.Count -eq 2) { $split[0].Trim() } else { '' }
        $title  = if ($split.Count -eq 2) { $split[1].Trim() } else { $stem }
        $library += [pscustomobject]@{
            File      = $f
            Title     = $title
            Artist    = $artist
            TitleKey  = Get-Key (Get-CoreTitle $title)
            ArtistKey = Get-Key (Get-PrimaryArtist $artist)
            Slug      = Get-Slug "$artist $title"
        }
    }
    Write-Host ("Library: {0} playable track(s)" -f $library.Count)
    Write-Host ''

    # -------------------------------------------------------------- match

    $matched = 0
    $report = @()
    foreach ($lib in $library) {
        $best = $null; $bestScore = 0.0
        foreach ($src in $incoming) {
            if ($src.ArtistKey -ne $lib.ArtistKey) { continue }
            $score = Get-Similarity $lib.TitleKey $src.TitleKey
            if ($lib.TitleKey -and $src.TitleKey) {
                if ($lib.TitleKey.Contains($src.TitleKey) -or $src.TitleKey.Contains($lib.TitleKey)) {
                    $score = [Math]::Max($score, 0.95)
                }
            }
            if ($score -gt $bestScore) { $bestScore = $score; $best = $src }
        }

        if ($best -and $bestScore -ge 0.85) {
            $ext = if ($best.Mime -match 'png') { 'png' } else { 'jpg' }
            $rel = "covers/$($lib.Slug).$ext"
            if ($PSCmdlet.ShouldProcess($rel, 'write cover')) {
                if (-not (Test-Path -LiteralPath $coversDir)) { New-Item -ItemType Directory -Path $coversDir -Force | Out-Null }
                [IO.File]::WriteAllBytes((Join-Path $musicDir $rel), $best.Picture)
            }
            $matched++
            $report += [pscustomobject]@{
                Track  = "$($lib.Artist) - $($lib.Title)"
                Art    = '{0} KB' -f [int]($best.Picture.Length / 1KB)
                Match  = '{0:P0}' -f $bestScore
                Source = $best.Title
            }
        } else {
            $report += [pscustomobject]@{
                Track  = "$($lib.Artist) - $($lib.Title)"
                Art    = '-'
                Match  = ''
                Source = ''
            }
        }
    }

    $report | Format-Table -AutoSize
    Write-Host ("Covers written : {0}/{1}" -f $matched, $library.Count)
    $missing = @($report | Where-Object { $_.Art -eq '-' })
    if ($missing.Count -gt 0) {
        Write-Host ''
        Write-Host ("Still without artwork ({0}):" -f $missing.Count)
        foreach ($m in $missing) { Write-Host "  $($m.Track)" }
    }
    Write-Host ''
    Write-Host 'Next: scripts/windows/build-music-metadata.ps1 to wire the covers into metadata.pegasus.txt.'
}
finally {
    # Only clean up a staging folder this script created; never the caller's.
    if ($staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue }
}
