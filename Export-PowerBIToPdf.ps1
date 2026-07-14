<#
.SYNOPSIS
Abre um arquivo PBIX no Power BI Desktop e o exporta para PDF.

.DESCRIPTION
Automatiza a interface do Power BI Desktop usando a API de automacao do Windows.
O script precisa ser executado em uma sessao interativa do Windows, com a tela
desbloqueada.

.EXAMPLE
.\Export-PowerBIToPdf.ps1 -InputPath "C:\Relatorios\Vendas.pbix"

.EXAMPLE
.\Export-PowerBIToPdf.ps1 -InputPath "C:\Relatorios\Vendas.pbix" `
    -OutputPath "C:\Exports\Vendas.pdf" -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$InputPath,

    [Parameter(Position = 1)]
    [string]$OutputPath,

    [string]$PowerBIExecutable,

    [ValidateRange(0, 3600)]
    [int]$LoadDelaySeconds = 20,

    [ValidateRange(10, 7200)]
    [int]$TimeoutSeconds = 300,

    [switch]$Force,

    [switch]$ClosePowerBI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'Este script so pode ser executado no Windows com o Power BI Desktop instalado.'
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class PowerBIWindowHelper
{
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
'@

function Resolve-PowerBIExecutable {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        $resolved = Resolve-Path -LiteralPath $ExplicitPath -ErrorAction SilentlyContinue
        if (-not $resolved -or -not (Test-Path -LiteralPath $resolved.Path -PathType Leaf)) {
            throw "Executavel do Power BI nao encontrado: $ExplicitPath"
        }

        return $resolved.Path
    }

    $candidates = [System.Collections.Generic.List[string]]::new()

    $command = Get-Command 'PBIDesktop.exe' -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        $candidates.Add($command.Source)
    }

    if ($env:ProgramFiles) {
        $candidates.Add((Join-Path $env:ProgramFiles 'Microsoft Power BI Desktop\bin\PBIDesktop.exe'))
    }

    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($programFilesX86) {
        $candidates.Add((Join-Path $programFilesX86 'Microsoft Power BI Desktop\bin\PBIDesktop.exe'))
    }

    $registryPaths = @(
        'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\App Paths\PBIDesktop.exe',
        'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\App Paths\PBIDesktop.exe'
    )

    foreach ($registryPath in $registryPaths) {
        $key = Get-Item -LiteralPath $registryPath -ErrorAction SilentlyContinue
        if ($key) {
            $registryValue = $key.GetValue('')
            if ($registryValue) {
                $candidates.Add([string]$registryValue)
            }
        }
    }

    $getAppxPackage = Get-Command 'Get-AppxPackage' -ErrorAction SilentlyContinue
    if ($getAppxPackage) {
        $appxPackage = Get-AppxPackage -Name 'Microsoft.MicrosoftPowerBIDesktop' -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if ($appxPackage -and $appxPackage.InstallLocation) {
            $candidates.Add((Join-Path $appxPackage.InstallLocation 'bin\PBIDesktop.exe'))
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw @'
Nao foi possivel localizar o Power BI Desktop. Informe o caminho com
-PowerBIExecutable "C:\...\PBIDesktop.exe".
'@
}

function Get-FullOutputPath {
    param(
        [string]$RequestedPath,
        [string]$ResolvedInputPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return [IO.Path]::ChangeExtension($ResolvedInputPath, '.pdf')
    }

    if ([IO.Path]::GetExtension($RequestedPath) -ne '.pdf') {
        throw 'OutputPath precisa terminar com a extensao .pdf.'
    }

    if ([IO.Path]::IsPathRooted($RequestedPath)) {
        return [IO.Path]::GetFullPath($RequestedPath)
    }

    return [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $RequestedPath))
}

function Wait-PowerBIWindow {
    param(
        [int]$StartedProcessId,
        [string]$ReportName,
        [int]$Timeout
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($Timeout)

    while ([DateTime]::UtcNow -lt $deadline) {
        $windows = Get-Process -Name 'PBIDesktop' -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero }

        $window = $windows |
            Where-Object { $_.MainWindowTitle -like "*$ReportName*" } |
            Select-Object -First 1

        if (-not $window) {
            $window = $windows |
                Where-Object { $_.Id -eq $StartedProcessId } |
                Select-Object -First 1
        }

        if ($window) {
            return $window
        }

        Start-Sleep -Milliseconds 500
    }

    throw "O Power BI Desktop nao abriu a janela do relatorio em $Timeout segundos."
}

function Test-UiElementName {
    param(
        [string]$ActualName,
        [string]$ExpectedName,
        [switch]$AllowContains
    )

    if ([string]::IsNullOrWhiteSpace($ActualName)) {
        return $false
    }

    if ($ActualName.Equals($ExpectedName, [StringComparison]::CurrentCultureIgnoreCase)) {
        return $true
    }

    return $AllowContains -and
        ($ActualName.IndexOf($ExpectedName, [StringComparison]::CurrentCultureIgnoreCase) -ge 0)
}

function Find-UiElement {
    param(
        [System.Windows.Automation.AutomationElement]$Root,
        [string[]]$Names,
        [System.Windows.Automation.ControlType[]]$ControlTypes,
        [switch]$AllowContains,
        [string]$AutomationId
    )

    try {
        $elements = $Root.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            [System.Windows.Automation.Condition]::TrueCondition
        )
    }
    catch {
        return $null
    }

    # Procura correspondencias exatas primeiro para nao confundir, por exemplo,
    # "Exportar" com um botao "Exportar dados" de um visual.
    foreach ($expectedName in $Names) {
        foreach ($element in $elements) {
            try {
                if ($element.Current.IsOffscreen) {
                    continue
                }

                if ($AutomationId -and $element.Current.AutomationId -ne $AutomationId) {
                    continue
                }

                if ($ControlTypes.Count -gt 0 -and $element.Current.ControlType -notin $ControlTypes) {
                    continue
                }

                if ((Test-UiElementName -ActualName $element.Current.Name `
                        -ExpectedName $expectedName)) {
                    return $element
                }
            }
            catch {
                continue
            }
        }
    }

    if ($AllowContains) {
        foreach ($expectedName in $Names) {
            foreach ($element in $elements) {
                try {
                    if ($element.Current.IsOffscreen) {
                        continue
                    }

                    if ($AutomationId -and $element.Current.AutomationId -ne $AutomationId) {
                        continue
                    }

                    if ($ControlTypes.Count -gt 0 -and
                        $element.Current.ControlType -notin $ControlTypes) {
                        continue
                    }

                    if ((Test-UiElementName -ActualName $element.Current.Name `
                            -ExpectedName $expectedName -AllowContains)) {
                        return $element
                    }
                }
                catch {
                    continue
                }
            }
        }
    }

    if ($AutomationId) {
        foreach ($element in $elements) {
            try {
                if (-not $element.Current.IsOffscreen -and
                    $element.Current.AutomationId -eq $AutomationId -and
                    ($ControlTypes.Count -eq 0 -or $element.Current.ControlType -in $ControlTypes)) {
                    return $element
                }
            }
            catch {
                continue
            }
        }
    }

    return $null
}

function Wait-UiElement {
    param(
        [System.Windows.Automation.AutomationElement]$Root,
        [string[]]$Names,
        [System.Windows.Automation.ControlType[]]$ControlTypes = @(),
        [int]$Timeout = 20,
        [switch]$AllowContains,
        [string]$AutomationId
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($Timeout)

    while ([DateTime]::UtcNow -lt $deadline) {
        $element = Find-UiElement -Root $Root -Names $Names -ControlTypes $ControlTypes `
            -AllowContains:$AllowContains -AutomationId $AutomationId
        if ($element) {
            return $element
        }

        Start-Sleep -Milliseconds 300
    }

    return $null
}

function Invoke-UiElement {
    param(
        [System.Windows.Automation.AutomationElement]$Element,
        [switch]$PreferExpand
    )

    $pattern = $null

    if ($PreferExpand -and $Element.TryGetCurrentPattern(
            [System.Windows.Automation.ExpandCollapsePattern]::Pattern,
            [ref]$pattern
        )) {
        $pattern.Expand()
        return
    }

    if ($Element.TryGetCurrentPattern(
            [System.Windows.Automation.InvokePattern]::Pattern,
            [ref]$pattern
        )) {
        $pattern.Invoke()
        return
    }

    if ($Element.TryGetCurrentPattern(
            [System.Windows.Automation.SelectionItemPattern]::Pattern,
            [ref]$pattern
        )) {
        $pattern.Select()
        return
    }

    if ($Element.TryGetCurrentPattern(
            [System.Windows.Automation.ExpandCollapsePattern]::Pattern,
            [ref]$pattern
        )) {
        $pattern.Expand()
        return
    }

    if ($Element.TryGetCurrentPattern(
            [System.Windows.Automation.LegacyIAccessiblePattern]::Pattern,
            [ref]$pattern
        )) {
        $pattern.DoDefaultAction()
        return
    }

    throw "Nao foi possivel acionar o controle '$($Element.Current.Name)'."
}

function Get-TopLevelWindows {
    $desktop = [System.Windows.Automation.AutomationElement]::RootElement
    return $desktop.FindAll(
        [System.Windows.Automation.TreeScope]::Children,
        [System.Windows.Automation.Condition]::TrueCondition
    )
}

function Find-SaveDialog {
    param([int]$ProcessId)

    $dialogNames = @('Save As', 'Salvar como', 'Salvar Como')
    $editTypes = @([System.Windows.Automation.ControlType]::Edit)
    $buttonTypes = @([System.Windows.Automation.ControlType]::Button)

    foreach ($window in (Get-TopLevelWindows)) {
        try {
            if ($window.Current.IsOffscreen -or $window.Current.ProcessId -ne $ProcessId) {
                continue
            }

            $titleMatches = $dialogNames | Where-Object {
                Test-UiElementName -ActualName $window.Current.Name -ExpectedName $_
            }

            $fileNameEdit = Find-UiElement -Root $window -Names @(
                'File name:', 'File name', 'Nome do arquivo:', 'Nome do arquivo'
            ) -ControlTypes $editTypes -AutomationId '1001'

            $saveButton = Find-UiElement -Root $window -Names @(
                'Save', 'Salvar'
            ) -ControlTypes $buttonTypes

            if (($titleMatches -or $fileNameEdit) -and $saveButton) {
                return $window
            }
        }
        catch {
            continue
        }
    }

    return $null
}

function Test-PdfHeader {
    param([string]$Path)

    try {
        $stream = [IO.File]::Open(
            $Path,
            [IO.FileMode]::Open,
            [IO.FileAccess]::Read,
            [IO.FileShare]::ReadWrite
        )
        try {
            if ($stream.Length -lt 5) {
                return $false
            }

            $headerBytes = New-Object byte[] 5
            [void]$stream.Read($headerBytes, 0, 5)
            return [Text.Encoding]::ASCII.GetString($headerBytes) -eq '%PDF-'
        }
        finally {
            $stream.Dispose()
        }
    }
    catch {
        return $false
    }
}

function Find-TemporaryPdf {
    param(
        [DateTime]$NotBefore,
        [string]$DestinationPath
    )

    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) 'Power BI Desktop'
    if (-not (Test-Path -LiteralPath $temporaryRoot -PathType Container)) {
        return $null
    }

    $candidates = Get-ChildItem -LiteralPath $temporaryRoot -File -Recurse -Force `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LastWriteTimeUtc -ge $NotBefore -and
            -not $_.FullName.Equals($DestinationPath, [StringComparison]::OrdinalIgnoreCase)
        } |
        Sort-Object LastWriteTimeUtc -Descending

    foreach ($candidate in $candidates) {
        if (Test-PdfHeader -Path $candidate.FullName) {
            return $candidate
        }
    }

    return $null
}

function Wait-ExportArtifact {
    param(
        [int]$ProcessId,
        [DateTime]$NotBefore,
        [string]$DestinationPath,
        [int]$Timeout
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($Timeout)
    $lastCandidatePath = $null
    $lastCandidateLength = -1L
    $stableChecks = 0

    while ([DateTime]::UtcNow -lt $deadline) {
        $saveDialog = Find-SaveDialog -ProcessId $ProcessId
        if ($saveDialog) {
            return [PSCustomObject]@{
                Type  = 'SaveDialog'
                Value = $saveDialog
            }
        }

        $candidate = Find-TemporaryPdf -NotBefore $NotBefore `
            -DestinationPath $DestinationPath
        if ($candidate) {
            if ($candidate.FullName -eq $lastCandidatePath -and
                $candidate.Length -eq $lastCandidateLength) {
                $stableChecks++
            }
            else {
                $lastCandidatePath = $candidate.FullName
                $lastCandidateLength = $candidate.Length
                $stableChecks = 0
            }

            if ($stableChecks -ge 2) {
                return [PSCustomObject]@{
                    Type  = 'TemporaryPdf'
                    Value = $candidate
                }
            }
        }

        Start-Sleep -Seconds 1
    }

    throw @"
O Power BI nao gerou um PDF em $Timeout segundos. Verifique se o relatorio
terminou de carregar e aumente -LoadDelaySeconds ou -TimeoutSeconds.
"@
}

function ConvertTo-SendKeysLiteral {
    param([string]$Text)

    $builder = [Text.StringBuilder]::new()
    foreach ($character in $Text.ToCharArray()) {
        if ('+^%~(){}'.Contains([string]$character)) {
            [void]$builder.Append('{')
            [void]$builder.Append($character)
            [void]$builder.Append('}')
        }
        else {
            [void]$builder.Append($character)
        }
    }

    return $builder.ToString()
}

function Set-SaveDialogPath {
    param(
        [System.Windows.Automation.AutomationElement]$Dialog,
        [string]$Path
    )

    $edit = Wait-UiElement -Root $Dialog -Names @(
        'File name:', 'File name', 'Nome do arquivo:', 'Nome do arquivo'
    ) -ControlTypes @([System.Windows.Automation.ControlType]::Edit) `
        -AutomationId '1001' -Timeout 10

    if (-not $edit) {
        throw 'O campo de nome do arquivo nao foi encontrado na janela Salvar como.'
    }

    $valuePattern = $null
    if ($edit.TryGetCurrentPattern(
            [System.Windows.Automation.ValuePattern]::Pattern,
            [ref]$valuePattern
        )) {
        $valuePattern.SetValue($Path)
        return
    }

    $edit.SetFocus()
    [System.Windows.Forms.SendKeys]::SendWait('^a')
    [System.Windows.Forms.SendKeys]::SendWait((ConvertTo-SendKeysLiteral -Text $Path))
}

function Confirm-OverwriteIfNeeded {
    param(
        [switch]$ShouldConfirm,
        [int]$ProcessId,
        [int]$Timeout = 10
    )

    if (-not $ShouldConfirm) {
        return
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($Timeout)
    $buttonTypes = @([System.Windows.Automation.ControlType]::Button)

    while ([DateTime]::UtcNow -lt $deadline) {
        foreach ($window in (Get-TopLevelWindows)) {
            try {
                if ($window.Current.ProcessId -ne $ProcessId) {
                    continue
                }

                $yesButton = Find-UiElement -Root $window -Names @(
                    'Yes', 'Sim'
                ) -ControlTypes $buttonTypes

                if ($yesButton) {
                    Invoke-UiElement -Element $yesButton
                    return
                }
            }
            catch {
                continue
            }
        }

        Start-Sleep -Milliseconds 300
    }
}

function Wait-PdfFile {
    param(
        [string]$Path,
        [object]$PreviousWriteTime,
        [int]$Timeout
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($Timeout)
    $lastLength = -1L
    $stableChecks = 0

    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $file = Get-Item -LiteralPath $Path
            $isNewVersion = $null -eq $PreviousWriteTime -or
                $file.LastWriteTimeUtc -gt ([DateTime]$PreviousWriteTime)

            if ($isNewVersion -and $file.Length -gt 4) {
                if ($file.Length -eq $lastLength) {
                    $stableChecks++
                }
                else {
                    $stableChecks = 0
                    $lastLength = $file.Length
                }

                if ($stableChecks -ge 2) {
                    if (Test-PdfHeader -Path $Path) {
                        return $file
                    }
                }
            }
        }

        Start-Sleep -Seconds 1
    }

    throw "O PDF nao foi criado em $Timeout segundos: $Path"
}

$resolvedInput = Resolve-Path -LiteralPath $InputPath -ErrorAction SilentlyContinue
if (-not $resolvedInput -or -not (Test-Path -LiteralPath $resolvedInput.Path -PathType Leaf)) {
    throw "Arquivo PBIX nao encontrado: $InputPath"
}

$inputFullPath = $resolvedInput.Path
if ([IO.Path]::GetExtension($inputFullPath) -ne '.pbix') {
    throw 'InputPath precisa apontar para um arquivo .pbix.'
}

$outputFullPath = Get-FullOutputPath -RequestedPath $OutputPath `
    -ResolvedInputPath $inputFullPath
$outputDirectory = Split-Path -Parent $outputFullPath

if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$previousWriteTime = $null
if (Test-Path -LiteralPath $outputFullPath -PathType Leaf) {
    if (-not $Force) {
        throw "O arquivo de destino ja existe. Use -Force para substitui-lo: $outputFullPath"
    }

    $previousWriteTime = (Get-Item -LiteralPath $outputFullPath).LastWriteTimeUtc
}

$powerBIPath = Resolve-PowerBIExecutable -ExplicitPath $PowerBIExecutable
$reportName = [IO.Path]::GetFileNameWithoutExtension($inputFullPath)
$quotedInputPath = '"{0}"' -f $inputFullPath.Replace('"', '\"')

Write-Host "Abrindo '$inputFullPath' no Power BI Desktop..."
$startedProcess = Start-Process -FilePath $powerBIPath -ArgumentList $quotedInputPath -PassThru
$powerBIProcess = Wait-PowerBIWindow -StartedProcessId $startedProcess.Id `
    -ReportName $reportName -Timeout $TimeoutSeconds

[void][PowerBIWindowHelper]::ShowWindowAsync($powerBIProcess.MainWindowHandle, 9)
[void][PowerBIWindowHelper]::SetForegroundWindow($powerBIProcess.MainWindowHandle)

if ($LoadDelaySeconds -gt 0) {
    Write-Host "Aguardando $LoadDelaySeconds segundos para o carregamento do relatorio..."
    Start-Sleep -Seconds $LoadDelaySeconds
}

$root = [System.Windows.Automation.AutomationElement]::FromHandle(
    $powerBIProcess.MainWindowHandle
)

$fileMenu = Wait-UiElement -Root $root -Names @('File', 'Arquivo') `
    -AllowContains -Timeout 15

if ($fileMenu) {
    Invoke-UiElement -Element $fileMenu
}
else {
    [System.Windows.Forms.SendKeys]::SendWait('%f')
}

$exportMenu = Wait-UiElement -Root $root -Names @('Export', 'Exportar') `
    -AllowContains -Timeout 15
if (-not $exportMenu) {
    throw "O menu 'Exportar' nao foi encontrado. Verifique o idioma e a versao do Power BI."
}

Invoke-UiElement -Element $exportMenu -PreferExpand

$pdfMenu = Wait-UiElement -Root $root -Names @(
    'Export to PDF', 'Exportar para PDF', 'PDF'
) -AllowContains -Timeout 15
if (-not $pdfMenu) {
    throw "A opcao 'Exportar para PDF' nao foi encontrada."
}

$exportStartedAt = [DateTime]::UtcNow.AddSeconds(-2)
Invoke-UiElement -Element $pdfMenu

Write-Host 'Aguardando a conclusao da exportacao...'
$artifact = Wait-ExportArtifact -ProcessId $powerBIProcess.Id `
    -NotBefore $exportStartedAt -DestinationPath $outputFullPath `
    -Timeout $TimeoutSeconds

if ($artifact.Type -eq 'SaveDialog') {
    $saveDialog = $artifact.Value
    $saveDialog.SetFocus()
    Set-SaveDialogPath -Dialog $saveDialog -Path $outputFullPath

    $saveButton = Wait-UiElement -Root $saveDialog -Names @('Save', 'Salvar') `
        -ControlTypes @([System.Windows.Automation.ControlType]::Button) -Timeout 10
    if (-not $saveButton) {
        throw "O botao 'Salvar' nao foi encontrado."
    }

    Invoke-UiElement -Element $saveButton
    Confirm-OverwriteIfNeeded -ShouldConfirm:($Force -and $null -ne $previousWriteTime) `
        -ProcessId $powerBIProcess.Id

    $pdfFile = Wait-PdfFile -Path $outputFullPath `
        -PreviousWriteTime $previousWriteTime -Timeout $TimeoutSeconds
}
else {
    Copy-Item -LiteralPath $artifact.Value.FullName -Destination $outputFullPath -Force
    $pdfFile = Wait-PdfFile -Path $outputFullPath -PreviousWriteTime $null `
        -Timeout $TimeoutSeconds
}

if ($ClosePowerBI) {
    $powerBIProcess.Refresh()
    if (-not $powerBIProcess.HasExited) {
        [void]$powerBIProcess.CloseMainWindow()
    }
}

Write-Host "PDF exportado com sucesso: $($pdfFile.FullName)"
