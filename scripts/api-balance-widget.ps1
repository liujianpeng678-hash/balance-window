# API 余额监控悬浮窗（WPF 置顶半透明小组件，缩略/展开 + 一键充值）
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File api-balance-widget.ps1
$hbFile = 'C:\CodexTemp\widget-heartbeat.log'
$lockFile = 'D:\deepseek\scripts\widget.lock'
if (Test-Path $lockFile) {
  $old = Get-Content $lockFile -ErrorAction SilentlyContinue
  if ($old -and (Get-Process -Id ([int]$old) -ErrorAction SilentlyContinue)) { exit }
}
Set-Content $lockFile $PID
Add-Content $hbFile ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' started pid=' + $PID)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$checkScript = 'D:\deepseek\scripts\check-api-balance.ps1'
$stateFile = 'D:\deepseek\scripts\balance-state.json'
$logFile = 'D:\deepseek\scripts\balance-watch.log'

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="API 状态监控" Width="400" Height="320" WindowStyle="None"
        AllowsTransparency="True" Background="Transparent" Topmost="True"
        ResizeMode="NoResize" ShowInTaskbar="False" WindowStartupLocation="CenterScreen">
  <Grid>
    <Border x:Name="FullGrid" Background="#E8232730" CornerRadius="14" BorderBrush="#4A5568" BorderThickness="1">
      <Border.ContextMenu>
        <ContextMenu>
          <MenuItem x:Name="MToggle" Header="缩略/展开"/>
          <MenuItem x:Name="MRefresh" Header="立即刷新"/>
          <MenuItem x:Name="MDS" Header="DeepSeek 充值"/>
          <MenuItem x:Name="MLog" Header="打开日志"/>
          <MenuItem x:Name="MTop" Header="保持置顶" IsCheckable="True" IsChecked="True"/>
          <Separator/>
          <MenuItem x:Name="MExit" Header="退出"/>
        </ContextMenu>
      </Border.ContextMenu>
      <Grid Margin="14">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <DockPanel Grid.Row="0">
          <TextBlock Text="API 余额监控" Foreground="#FFFFFF" FontSize="14" FontWeight="Bold"/>
          <TextBlock Text="双击缩略" Foreground="#6B7280" FontSize="9" VerticalAlignment="Center" Margin="0,0,8,0" DockPanel.Dock="Right"/>
          <TextBlock x:Name="TimeText" DockPanel.Dock="Right" Foreground="#9CA3AF" FontSize="10" VerticalAlignment="Center"/>
        </DockPanel>
        <Border x:Name="AlertBox" Grid.Row="1" Background="#33EF4444" CornerRadius="6" Margin="0,8,0,0" Padding="8,4" Visibility="Collapsed">
          <TextBlock x:Name="AlertText" Foreground="#FCA5A5" FontSize="11" TextWrapping="Wrap"/>
        </Border>
        <StackPanel x:Name="BalanceBox" Grid.Row="2" Margin="0,12,0,4"/>
        <StackPanel x:Name="Rows" Grid.Row="3" Margin="0,4,0,0"/>
        <TextBlock Grid.Row="4" Text="点「充值↗」直达充值页 · 右键菜单 · 双击缩略/展开" Foreground="#6B7280" FontSize="9"/>
      </Grid>
    </Border>
    <Border x:Name="MiniGrid" Background="#E8232730" CornerRadius="20" BorderBrush="#4A5568" BorderThickness="1"
            Visibility="Collapsed" Height="40" Width="250">
      <Border.ContextMenu>
        <ContextMenu>
          <MenuItem x:Name="MToggleM" Header="缩略/展开"/>
          <MenuItem x:Name="MRefreshM" Header="立即刷新"/>
          <MenuItem x:Name="MDSM" Header="DeepSeek 充值"/>
          <MenuItem x:Name="MLogM" Header="打开日志"/>
          <MenuItem x:Name="MTopM" Header="保持置顶" IsCheckable="True" IsChecked="True"/>
          <Separator/>
          <MenuItem x:Name="MExitM" Header="退出"/>
        </ContextMenu>
      </Border.ContextMenu>
      <StackPanel Orientation="Horizontal" Margin="16,0">
        <Ellipse x:Name="MiniDot" Width="10" Height="10" Fill="#4ADE80" VerticalAlignment="Center" Margin="0,0,8,0"/>
        <TextBlock x:Name="MiniText" Text="¥--" Foreground="#FFFFFF" FontSize="16" FontWeight="Bold" VerticalAlignment="Center"/>
        <TextBlock x:Name="MiniWarn" Text="" Foreground="#F87171" FontSize="12" FontWeight="Bold" VerticalAlignment="Center" Margin="6,0,0,0"/>
        <TextBlock x:Name="MiniTopup" Text="充值" Foreground="#60A5FA" FontSize="12" FontWeight="Bold" VerticalAlignment="Center" Margin="12,0,0,0" Cursor="Hand" ToolTip="DeepSeek 充值页"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
'@
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)
$reader.Close()
$fullGrid = $window.FindName('FullGrid')
$miniGrid = $window.FindName('MiniGrid')
$rows = $window.FindName('Rows')
$balanceBox = $window.FindName('BalanceBox')
$alertBox = $window.FindName('AlertBox')
$alertText = $window.FindName('AlertText')
$timeText = $window.FindName('TimeText')
$miniDot = $window.FindName('MiniDot')
$miniText = $window.FindName('MiniText')
$miniWarn = $window.FindName('MiniWarn')
$miniTopup = $window.FindName('MiniTopup')
$mToggle = $window.FindName('MToggle')
$mRefresh = $window.FindName('MRefresh')
$mDS = $window.FindName('MDS')
$mLog = $window.FindName('MLog')
$mTop = $window.FindName('MTop')
$mExit = $window.FindName('MExit')
$mToggleM = $window.FindName('MToggleM')
$mRefreshM = $window.FindName('MRefreshM')
$mDSM = $window.FindName('MDSM')
$mLogM = $window.FindName('MLogM')
$mTopM = $window.FindName('MTopM')
$mExitM = $window.FindName('MExitM')

$script:lastStamp = 0
$script:checking = $false
$script:collapsed = $false
$script:lastClick = 0
$script:dsUrl = 'https://platform.deepseek.com/top_up'

function New-UrlHandler($url) {
  { Start-Process $url }.GetNewClosure()
}

function Open-Url($url) {
  if ($url) { Start-Process $url }
}

function Start-Check {
  $script:checking = $true
  $timeText.Text = '检查中...'
  Start-Process powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$checkScript,'-Threshold','5') -WindowStyle Hidden | Out-Null
}

function Toggle-Mini {
  $script:collapsed = -not $script:collapsed
  if ($script:collapsed) {
    $fullGrid.Visibility = [System.Windows.Visibility]::Collapsed
    $miniGrid.Visibility = [System.Windows.Visibility]::Visible
    $window.Width = 250
    $window.Height = 44
  } else {
    $fullGrid.Visibility = [System.Windows.Visibility]::Visible
    $miniGrid.Visibility = [System.Windows.Visibility]::Collapsed
    $window.Width = 400
    $window.Height = 320
  }
}

function Update-Widget {
  if (-not (Test-Path $stateFile)) { return }
  $fi = Get-Item $stateFile
  if ($fi.LastWriteTime.Ticks -le $script:lastStamp) { return }
  $script:lastStamp = $fi.LastWriteTime.Ticks
  $script:checking = $false
  try { $state = Get-Content $stateFile -Raw | ConvertFrom-Json } catch { return }
  Add-Content $hbFile ((Get-Date -Format 'HH:mm:ss') + ' render items=' + $state.items.Count)
  $timeText.Text = '更新于 ' + $state.updated
  $balanceBox.Children.Clear()
  $rows.Children.Clear()
  $alerts = @()
  $dsItem = $state.items | Where-Object { $_.api -eq 'DeepSeek' } | Select-Object -First 1
  $dsLevel = 'ok'
  $dsBalance = ''
  if ($dsItem) {
    $dsLevel = [string]$dsItem.level
    if ($dsItem.url) { $script:dsUrl = [string]$dsItem.url }
    $m = [regex]::Match([string]$dsItem.text, '¥([0-9.]+)')
    if ($m.Success) {
      $dsBalance = '¥' + $m.Groups[1].Value
      $balSp = New-Object System.Windows.Controls.StackPanel
      $balSp.Orientation = [System.Windows.Controls.Orientation]::Horizontal
      $label = New-Object System.Windows.Controls.TextBlock
      $label.Text = '剩余余额：'
      $label.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#9CA3AF'))
      $label.FontSize = 14
      $label.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
      $label.Margin = New-Object System.Windows.Thickness(0,0,6,4)
      $big = New-Object System.Windows.Controls.TextBlock
      $big.Text = $dsBalance
      $bigColor = switch ($dsLevel) { 'ok' { '#4ADE80' } 'warn' { '#FACC15' } default { '#F87171' } }
      $big.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($bigColor))
      $big.FontSize = 30
      $big.FontWeight = [System.Windows.FontWeights]::Bold
      [void]$balSp.Children.Add($label)
      [void]$balSp.Children.Add($big)
      $dsBtn = New-Object System.Windows.Controls.Button
      $dsBtn.Content = '充值↗'
      $dsBtn.Background = [System.Windows.Media.Brushes]::Transparent
      $dsBtn.BorderThickness = New-Object System.Windows.Thickness(0)
      $dsBtn.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#60A5FA'))
      $dsBtn.FontSize = 12
      $dsBtn.Cursor = [System.Windows.Input.Cursors]::Hand
      $dsBtn.Margin = New-Object System.Windows.Thickness(10,0,0,6)
      $dsBtn.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
      $dsBtn.ToolTip = $script:dsUrl
      $dsBtn.Add_Click((New-UrlHandler $script:dsUrl))
      [void]$balSp.Children.Add($dsBtn)
      [void]$balanceBox.Children.Add($balSp)
    }
  }
  foreach ($it in $state.items) {
    if ($it.api -eq 'DeepSeek') { continue }
    $level = [string]$it.level
    $dotColor = switch ($level) { 'ok' { '#4ADE80' } 'warn' { '#FACC15' } default { '#F87171' } }
    $textColor = switch ($level) { 'ok' { '#E5E7EB' } 'warn' { '#FDE68A' } default { '#FCA5A5' } }
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $sp.Margin = New-Object System.Windows.Thickness(0,3,0,3)
    $ellipse = New-Object System.Windows.Shapes.Ellipse
    $ellipse.Width = 8
    $ellipse.Height = 8
    $ellipse.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($dotColor))
    $ellipse.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $ellipse.Margin = New-Object System.Windows.Thickness(0,0,8,0)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = [string]$it.text
    $tb.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($textColor))
    $tb.FontSize = 12
    [void]$sp.Children.Add($ellipse)
    [void]$sp.Children.Add($tb)
    if ($it.url) {
      $u = [string]$it.url
      $btn = New-Object System.Windows.Controls.Button
      $btn.Content = '充值↗'
      $btn.Background = [System.Windows.Media.Brushes]::Transparent
      $btn.BorderThickness = New-Object System.Windows.Thickness(0)
      $btn.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#60A5FA'))
      $btn.FontSize = 11
      $btn.Cursor = [System.Windows.Input.Cursors]::Hand
      $btn.Margin = New-Object System.Windows.Thickness(10,0,0,0)
      $btn.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
      $btn.ToolTip = $u
      $btn.Add_Click((New-UrlHandler $u))
      [void]$sp.Children.Add($btn)
    }
    [void]$rows.Children.Add($sp)
    if ($level -ne 'ok') { $alerts += [string]$it.text }
  }
  if ($dsBalance -ne '') {
    $miniText.Text = $dsBalance
    $miniColor = switch ($dsLevel) { 'ok' { '#4ADE80' } 'warn' { '#FACC15' } default { '#F87171' } }
    $miniText.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($miniColor))
  }
  $dotFill = if ($alerts.Count -gt 0) { '#F87171' } else { '#4ADE80' }
  $miniDot.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($dotFill))
  if ($alerts.Count -gt 0) { $miniWarn.Text = '⚠' } else { $miniWarn.Text = '' }
  if ($alerts.Count -gt 0) {
    $alertText.Text = '⚠ ' + ($alerts -join '  ｜  ')
    $alertBox.Visibility = [System.Windows.Visibility]::Visible
  } else {
    $alertBox.Visibility = [System.Windows.Visibility]::Collapsed
  }
}

$renderTimer = New-Object System.Windows.Threading.DispatcherTimer
$renderTimer.Interval = [TimeSpan]::FromSeconds(2)
$renderTimer.Add_Tick({ Update-Widget })
$renderTimer.Start()

$refreshTimer = New-Object System.Windows.Threading.DispatcherTimer
$refreshTimer.Interval = [TimeSpan]::FromSeconds(300)
$refreshTimer.Add_Tick({ Start-Check })
$refreshTimer.Start()

$window.Add_MouseLeftButtonDown({
  $now = [Environment]::TickCount
  if (($now - $script:lastClick) -lt 400) { $script:lastClick = 0; Toggle-Mini } else { $script:lastClick = $now }
  try { $window.DragMove() } catch {}
})
$miniTopup.Add_MouseLeftButtonDown({ $e.Handled = $true; Open-Url $script:dsUrl })
$mToggle.Add_Click({ Toggle-Mini })
$mRefresh.Add_Click({ Start-Check })
$mDS.Add_Click({ Open-Url $script:dsUrl })
$mLog.Add_Click({ Start-Process notepad $logFile })
$mTop.Add_Click({ $window.Topmost = $mTop.IsChecked })
$mExit.Add_Click({ Remove-Item $lockFile -Force -ErrorAction SilentlyContinue; $window.Close() })
$mToggleM.Add_Click({ Toggle-Mini })
$mRefreshM.Add_Click({ Start-Check })
$mDSM.Add_Click({ Open-Url $script:dsUrl })
$mLogM.Add_Click({ Start-Process notepad $logFile })
$mTopM.Add_Click({ $window.Topmost = $mTopM.IsChecked })
$mExitM.Add_Click({ Remove-Item $lockFile -Force -ErrorAction SilentlyContinue; $window.Close() })

Add-Content $hbFile ((Get-Date -Format 'HH:mm:ss') + ' window-ready')
Start-Check
$window.ShowDialog() | Out-Null
Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
