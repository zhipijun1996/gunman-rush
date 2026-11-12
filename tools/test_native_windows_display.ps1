param([Parameter(Mandatory=$true)][string]$Game,[Parameter(Mandatory=$true)][string]$EvidencePath)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $EvidencePath | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class GameDisplay {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X,Y; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr window, out RECT rect);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr window, ref POINT point);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int command);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr window,int x,int y,int w,int h,bool repaint);
  [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr window);
}
'@
$stdout = Join-Path $EvidencePath 'startup.log'
$stderr = Join-Path $EvidencePath 'startup-error.log'
# Shipping production templates intentionally reject --path/--script/--main-pack.
# Exercise the exact EXE/PCK via its existing isolated room-review entry instead.
$process = Start-Process -FilePath $Game -WorkingDirectory (Split-Path $Game) -ArgumentList '--max-fps','60','--','--review=P-R22','--invincible=1' -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
$handle = [IntPtr]::Zero
$deadline = (Get-Date).AddSeconds(40)
while ($handle -eq [IntPtr]::Zero) {
  if ($process.WaitForExit(200)) { Get-Content $stdout,$stderr; throw 'Native game exited before showing its window' }
  if ((Get-Date) -gt $deadline) { $process.Kill(); throw 'Native window did not appear' }
  $process.Refresh(); $handle = $process.MainWindowHandle
}
[GameDisplay]::SetForegroundWindow($handle) | Out-Null
Start-Sleep -Milliseconds 2500
$samples = [System.Collections.Generic.List[object]]::new()
foreach ($stage in @('normal','maximized','restored','large_window')) {
  if ($stage -eq 'maximized') { [GameDisplay]::ShowWindow($handle,3) | Out-Null }
  else {
    [GameDisplay]::ShowWindow($handle,9) | Out-Null
    $width = if ($stage -eq 'large_window') { 1873 } else { 1296 }
    $height = if ($stage -eq 'large_window') { 1060 } else { 759 }
    [GameDisplay]::MoveWindow($handle,12,12,$width,$height,$true) | Out-Null
  }
  Start-Sleep -Milliseconds 750
  if (($stage -eq 'maximized') -ne [GameDisplay]::IsZoomed($handle)) { throw "OS did not apply $stage window state" }
  $previous = $null
  foreach ($frame in 0..11) {
    if ($process.HasExited) { Get-Content $stdout,$stderr; throw 'Game exited during display test' }
    $rect = New-Object GameDisplay+RECT
    $origin = New-Object GameDisplay+POINT
    if (-not [GameDisplay]::GetClientRect($handle,[ref]$rect) -or -not [GameDisplay]::ClientToScreen($handle,[ref]$origin)) { throw 'Cannot inspect real window client' }
    $client = [System.Drawing.Rectangle]::new($origin.X,$origin.Y,$rect.Right,$rect.Bottom)
    $bounds = [System.Drawing.Rectangle]::Intersect($client,[System.Windows.Forms.SystemInformation]::VirtualScreen)
    if ($bounds.Width -lt 320 -or $bounds.Height -lt 200) { throw 'No usable visible Windows client area' }
    $bitmap = [System.Drawing.Bitmap]::new($bounds.Width,$bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.CopyFromScreen($bounds.Location,[System.Drawing.Point]::Empty,$bounds.Size)
      $luminance = 0.0; $count = 0
      for ($y=16;$y -lt $bitmap.Height-16;$y+=32) {
        for ($x=16;$x -lt $bitmap.Width-16;$x+=32) {
          $color=$bitmap.GetPixel($x,$y);$luminance+=(.2126*$color.R+.7152*$color.G+.0722*$color.B)/255.0;$count++
        }
      }
      $mean=$luminance/$count
      if ($mean -lt .015 -or $mean -gt .98) { throw "$stage has an empty black/white presented frame" }
      if ($null -ne $previous -and [Math]::Abs($mean-$previous) -gt .18) { throw "$stage has a whole-frame brightness jump" }
      $previous=$mean
      $samples.Add(@{stage=$stage;client=@($rect.Right,$rect.Bottom);captured=@($bounds.Width,$bounds.Height);mean_luminance=$mean})
      if ($frame -in @(0,11)) { $bitmap.Save((Join-Path $EvidencePath "$stage-$frame.png")) }
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    Start-Sleep -Milliseconds 100
  }
}
if (-not $process.CloseMainWindow() -or -not $process.WaitForExit(15000)) { $process.Kill(); throw 'Native game did not close normally' }
Get-Content $stdout,$stderr
if ($process.ExitCode -ne 0) { throw "Windows graphical exit code $($process.ExitCode)" }
if (Select-String -Path $stdout,$stderr -Pattern 'SCRIPT ERROR:|^ERROR:|Parse Error:' -Quiet) { throw 'Windows graphical engine error' }
if (-not (Select-String -Path $stdout -Pattern 'ANGLE' -Quiet)) { throw 'Expected Windows ANGLE presentation backend was not selected' }
@{platform='Windows';room='P-R22';source='actual shipping EXE/PCK; existing isolated review entry';driver='ANGLE';samples=$samples;full_visual_playthrough='not-tested'} | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $EvidencePath 'report.json')
Write-Host "NATIVE WINDOWS DISPLAY: $($samples.Count) actual presented samples; 0 failures"
