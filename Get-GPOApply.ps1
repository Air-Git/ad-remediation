<#PSScriptInfo

.VERSION 1.0

.GUID 28947f3f-5121-4bd9-850b-d07e73d83907

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
A script to show who has GPO Apply permissions for each GPO.
The aim is to spot GPOs that apply to either very few, or no accounts, or only to deleted accounts (unknownSID).
Because a GPO permission may have multiple trustees, each trustee is shown on a separate line of the report.
The name of the output report is hard-coded in the script. Edit it before running.

#>

$fileDate = Get-Date -Format ddMMyy
$Gpos = Get-GPO -All | Where-Object { $_.GpoStatus -ne "AllSettingsDisabled" } | Sort-Object DisplayName
$Gpos | ForEach-Object {
    $GpoName = $_.DisplayName
    $GpoStatus = $_.GpoStatus
    [xml]$GpoReport = Get-GPOReport -Guid $_.Id -ReportType Xml
    $links = $GpoReport.GPO.LinksTo.SOMPath
    $apply = Get-GPPermission -Guid $_.Id -All | Where-Object { $_.Permission -eq 'GpoApply' }
    $AU = $false
    $onlyUnknownSID = $true
    $apply | ForEach-Object {
        if ($_.Trustee.Name -eq 'Authenticated Users' -or $_.Trustee.Name -eq 'Domain Computers') { $AU = $true }
        if ($null -ne $_.Trustee.Name) { $onlyUnknownSID = $false }
    }
    $apply | ForEach-Object {
        [pscustomobject]@{
            'Name'         = $GpoName
            'Status'       = $GpoStatus
            'Links'        = $links -join '; '
            'Trustee'      = $_.Trustee.Name
            'All'          = $AU
            'Only Unknown' = $onlyUnknownSID
        }
    }
} | Export-Csv "C:\Temp\GPOApply_$fileDate.Csv" -NoTypeInformation