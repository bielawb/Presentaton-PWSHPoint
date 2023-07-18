Install-Module -AllowClobber -Force -SkipPublisherCheck -Name ISESteroids
Start-Steroids
$xamlFile = $psISE.CurrentFile.FullPath -replace '\.ps1$', '.xaml'
Set-Content -Path $xamlFile -Value @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
    <Grid Margin="10,40,10,10">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <TextBlock FontSize="100" TextAlignment="Center" VerticalAlignment="Center" FontFamily="Consolas">
            <TextBlock.Effect>
                <DropShadowEffect Direction="-45" Color="#FFc2C2C2" ShadowDepth="10" BlurRadius="14" />
            </TextBlock.Effect>
            PowerShell<LineBreak/>Rocks!
        </TextBlock>
        <Image Grid.Column="1" Source="Media/PWSHPoint.jpg">
            <Image.Effect>
                <DropShadowEffect Direction="-45" Color="#FFB6C2CB" ShadowDepth="10" BlurRadius="14" />
            </Image.Effect>
        </Image>
    </Grid>
</Window>
'@ -Encoding UTF8

#region Helper functions
function Show-PresentationItem {
    param (
        [ValidateScript(
                {
                    Test-Path -Path $_ -PathType Leaf
                }
        )]
        [ValidatePattern('\.(jpg|png)$')]
        [Parameter(Mandatory)]
        [string]$Path,
        [int]$Width = 200,
        [double]$Opacity = 0.4,
        [string]$Text = 'This is just a test'
    )

    try {
        $null = [Windows.Controls.TextBlock]::new()
    } catch {
        Add-Type -AssemblyName PresentationFramework
    }

    $info = [hashtable]::Synchronized(@{})
    $info.Path = Convert-Path -Path $Path
    $info.Width = $Width
    $info.Opacity = $Opacity
    $info.TextValue = $Text

    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.ApartmentState = 'STA'
    $newRunspace.ThreadOptions = 'ReuseThread'
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable(
        'syncHash',
        $info
    )
    $psCmd = [PowerShell]::Create().AddScript({
            [xml]$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Width="600" Title="GuiTrick" SizeToContent="WidthAndHeight" 
    Name="Window" WindowStyle="None" AllowsTransparency="True"
    Background="Transparent" Topmost="True"
>
    <Border CornerRadius="25" Background="White" Opacity="$($syncHash.Opacity)" Name="Frame">
        <Grid Background="Transparent">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Image Width="$($syncHash.Width)" Name="Logo">
                <Image.Source>
                    <BitmapImage UriSource="$($syncHash.Path)" />
                </Image.Source>
            </Image>
            <TextBlock
                Grid.Column="1"
                Name="Text"
                Text="$($syncHash.TextValue)"
                FontSize="35"
                FontFamily="Consolas"
                VerticalAlignment="Center"
                Margin="20,20,20,20"
            />
        </Grid>
    </Border>
</Window>
"@
            $reader = [Xml.XmlNodeReader]::new($xaml)
            $syncHash.Logo = [Windows.Markup.XamlReader]::Load($reader)
            $syncHash.Image = $syncHash.Logo.FindName('Logo')
            $syncHash.Text = $syncHash.Logo.FindName('Text')
            $syncHash.Frame = $syncHash.Logo.FindName('Frame')
            $syncHash.Logo.Add_MouseRightButtonDown({$this.Close()})
            $syncHash.Logo.Add_MouseLeftButtonDown({$this.DragMove()})
            $syncHash.Logo.ShowDialog() | Out-Null
    })
    $psCmd.Runspace = $newRunspace
    $null = $psCmd.BeginInvoke()
    $info
}

function Update-Logo {

    <#
            .Synopsis
            Updates logo created with Show-Logo function.
  
            .Example
            Update-Logo -Script { $logo.Image.Width = 150 }
            Modifies 'Width' property of Image to 150.
    #>
  
    param (
        [Parameter(Mandatory)]
        [action]$Script,
        [Parameter(Mandatory)]
        [hashtable]$Logo,
        [string]$Property = 'Image',
        [System.Windows.Threading.DispatcherPriority]$Priority = 'Normal'
    )
    $Logo.$Property.Dispatcher.Invoke(
        $Priority,
        $Script
    )
}

function Show-Slide {
    [CmdletBinding(DefaultParameterSetName = 'slide')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'text')]
        [String]$Text,
        [String]$Path = '.\Prague23.png',
        [Int]$Total = 3,
        [Parameter(ParameterSetName = 'text')]
        [Int]$Current = 1,
        [Parameter(Mandatory, ParameterSetName = 'slide')]
        [hashtable]$Slide,
        [Int]$ScreenWidth = [Windows.SystemParameters]::PrimaryScreenWidth,
        [Int]$ScreenHeight = [Windows.SystemParameters]::PrimaryScreenHeight,
        [Int]$Width = 200,
        [switch]$PassThru
    )

    if ($Slide) {
        $Text = $Slide.Text
        $Current = $Slide.Number
        $Path = $Slide.Path
    }
    # Normalize path for dotnet
    $Path = Resolve-Path -LiteralPath $Path
    $logo = Show-PresentationItem -Text $Text -Path $Path -Width $Width
    $top = [math]::Floor(($ScreenHeight * $Current)/ ($Total + 2))
    do {
        Start-Sleep -Milliseconds 20
    } until ($logo.Logo.IsVisible)
    if ($PassThru) {
        $logo
    }
    $null = Update-Logo -Logo $logo -Script { $logo.Logo.Top = $top }
    $null = Update-Logo -Logo $logo -Script { $logo.Logo.Left = $ScreenWidth -20 - $logo.Logo.Width }
    
}
#endregion
$logoPath = $psISE.CurrentFile.FullPath | Split-Path | Join-Path -ChildPath Media\PWSHPoint.jpg
$mySlide = Show-Slide -Path $logoPath -Width 400 -Text 'This is just a demo!' -PassThru

Update-Logo -Logo $mySlide -Script { $mySlide.Frame.Opacity = 0.8 }
Update-Logo -Logo $mySlide -Script { $mySlide.Text.Text = 'Boom!' }
Update-Logo -Logo $mySlide -Script { $mySlide.Text.FontSize = 300 }
Update-Logo -Logo $mySlide -Script { $mySlide.Text.FontFamily = 'Monotype Corsiva' }
(30..10).ForEach{ Update-Logo -Logo $mySlide -Script { $mySlide.Text.FontSize = ($_ * 10) } }
(1..3).ForEach{ Update-Logo -Logo $mySlide -Script { $mySlide.Text.FontSize = ($_ * 100) } }
Update-Logo -Logo $mySlide -Script { $mySlide.Image.Margin = '10,10,10,10' }