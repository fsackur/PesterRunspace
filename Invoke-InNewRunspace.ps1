<#
    .SYNOPSIS
    When called at the top of a script, re-invokes that script in a separate runspace.

    .DESCRIPTION
    When testing, it's often important to run in a fresh environment and, if testing
    classes, to run in a separate AppDomain. This script achieves that.

    At the top of your pester script, add the following code:

        if (Invoke-InNewRunspace.ps1) {return}

    Adjust the path to Invoke-InNewRunspace.ps1 to suit your layout.
#>

if ([runspace]::DefaultRunspace.Name -notmatch 'Pester')
{
    $ISS = [initialsessionstate]::CreateDefault()
       
    $RS = [runspacefactory]::CreateRunspace($Host, $ISS)
    $RS.Name = "Pester" + [datetime]::Now.ToString('s')
    
    $RS.Open()

    $PS = [Powershell]::Create()
    $PS.Runspace = $RS


    $null = $PS.
        AddScript('Write-Verbose "Running in runspace $([runspace]::DefaultRunspace.Name)" -Verbose').
        AddStatement().
        AddCommand("Set-Location").
        AddParameter('Path', $PWD.Path).
        AddStatement().
        AddCommand('Import-Module').
        AddParameter('Name', 'Pester')

    $PS.Invoke()
    $PS.Commands.Clear()


    $TestBreakpoints = Get-PSBreakpoint | Where-Object {$_.Script -eq $Frame.InvocationInfo.MyCommand.Source}
    $TestBreakpoints | ForEach-Object {
        $null = $PS.
            AddCommand('Set-PSBreakpoint').
            AddParameter('Script', $_.Script).
            AddParameter('Line', $_.Line)
    }

    Get-Variable *Preference |
        Where-Object {$_.Name -notmatch '^WhatIf|^Confirm'} |
        ForEach-Object {
        $null = $PS.
            AddScript("`$$($_.Name) = '$($_.Value)'")
    }

    try
    {
        $PS.Invoke()
        $PS.Commands.Clear()
    }
    catch
    {
        if ($_ -notmatch 'No commands are specified')
        {
            throw
        }
    }


    $Frame = (Get-PSCallStack)[1] #| Out-String | Write-Host
    $Invocation = $Frame.InvocationInfo.MyCommand.Source
    
    $null = $PS.AddScript($Invocation)

    
    $PS.Invoke()

    
    $PS.Streams.Error       | ForEach-Object {Write-Error $_}
    $PS.Streams.Warning     | ForEach-Object {Write-Warning $_}
    $PS.Streams.Verbose     | ForEach-Object {Write-Verbose $_}
    $PS.Streams.Debug       | ForEach-Object {Write-Debug $_}
    $PS.Streams.Information | ForEach-Object {Write-Information $_}

    $PS.Dispose()


    return $true
}
else
{
    return $false
}