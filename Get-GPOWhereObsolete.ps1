<#PSScriptInfo

.VERSION 1.0

.GUID 4defc90d-eb61-4007-bf2a-29d7fe5b1405

.AUTHOR Anthony Yates

.COMPANYNAME Airdesk Services

.COPYRIGHT 2024 Anthony Yates

.TAGS Active Directory

.LICENSEURI https://github.com/Air-Git/ad-remediation/blob/main/LICENSE

.PROJECTURI https://github.com/Air-Git/ad-remediation/tree/main

.ICONURI

.EXTERNALMODULEDEPENDENCIES Group Policy

.REQUIREDSCRIPTS None

.EXTERNALSCRIPTDEPENDENCIES None

.RELEASENOTES

.PRIVATEDATA

#>

<#

.DESCRIPTION
A script to list all the GPOs in the domain and show whether they are in use or not.
The WMI filters and the name of the output report are hard-coded in the script. Edit them before running.

#>

$fileDate = Get-Date -Format ddMMyy
$GPOs = Get-GPO -All | Sort-Object DisplayName
$GPOs | ForEach-Object {
    $link = $null
    $linkEnabled = $null
    $apply = $null
    # Summary from Get-GPO
    $name = $_.DisplayName
    $status = $_.GpoStatus
    $Guid = $_.Id
    $date = Get-Date $_.CreationTime -Format dd/MM/yyyy
    $Wmi = $_.WmiFilter.Name
    # Supply the text strings for your WMI filters here. You can see all WMI filters in the Group Policy Management Console
    $obsoleteWmi = @("WinXP", "Win7", "Win7 or Win8.1", "Win8.1", "Win10 1607")
    if ($Wmi -in $obsoleteWmi) {
        $WmiObsolete = $true
    }
    else { $wmiObsolete = $false }
    # Links from Get-GPOReport
    $report = [xml](Get-GPOReport -Guid $_.Id -ReportType xml)
    $link = $report.Gpo.LinksTo
    $linkEnabled = $report.Gpo.LinksTo.Enabled | Where-Object { $_ -eq $true }
    # Permissions from Get-GPPermission
    $apply = Get-GPPermission -Guid $_.Id -All | Where-Object { $_.Permission -eq 'GpoApply' }
    [pscustomobject]@{
        'Name'          = $name
        'Guid'          = $Guid
        'Status'        = $status
        'Creation Date' = $date
        'Link Exists'   = !([string]::IsNullorEmpty($link))
        'Link Enabled'  = !([string]::IsNullorEmpty($linkEnabled))
        'Applied'       = !([string]::IsNullorEmpty($apply))
        'WMI Filter'    = $wmi
        'WMI Obsolete'  = $WmiObsolete
    }
} | Export-Csv "C:\Temp\GPOWhereObsolete_$fileDate.csv" -NoTypeInformation
