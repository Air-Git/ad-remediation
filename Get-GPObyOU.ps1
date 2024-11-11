<#PSScriptInfo

.VERSION 1.0

.GUID aa90b075-c88d-4020-8baa-eca01e30ffca

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
A script to list the GPOs that are linked to a specified OU and provide high-level details of each GPO.
The OU distinguished name and the name of the output report are hard-coded in the script. Edit them before running.

#>

$fileDate = Get-Date -Format ddMMyy
$OuDn = "[supply the Distinguished Name of the OU i.e. in the format ou=MyOU,dc=contoso,dc=com]"

$Gpos = Get-GPInheritance -Target $OuDn
# You can do this for all GPOs ("inherited") or just the directly linked GPOs. Select which one you want, below, not both
# $links = $Gpos.InheritedGpoLinks
$links = $Gpos.GpoLinks

if ($links) {
    $links.ForEach( {
            try {
                $GpoSummary = Get-GPO -Guid $_.GpoId | Sort-Object DisplayName
            }
            catch [System.Runtime.InteropServices.COMException] {
                Write-Output "Error getting the GPO with GUID: $_"
            }
            catch {} 

            if ($GpoSummary) {
                # Summary from Get-GPO
                $GpoName = $GpoSummary.DisplayName
                $GpoStatus = $GpoSummary.GpoStatus
                $GpoGuid = $_.GpoId 
                $GpoCreateDate = Get-Date $GpoSummary.CreationTime -Format dd/MM/yyyy
                $GpoWmi = $GpoSummary.WmiFilter.Name

                # Permissions from Get-GPPermission
                $GpoApply = (Get-GPPermission -Guid $_.GpoId  -All -ErrorAction SilentlyContinue | Where-Object { $_.Permission -eq 'GpoApply' }).Trustee.Name -join '; '
                $GpoDeny = (Get-GPPermission -Guid $_.GpoId  -All -ErrorAction SilentlyContinue | Where-Object { $_.Permission -eq 'GpoDeny' }).Trustee.Name -join '; '
                [pscustomobject]@{
                    'Name'          = $GpoName
                    'Guid'          = $GpoGuid
                    'Status'        = $GpoStatus
                    'Creation Date' = $GpoCreateDate
                    'Enabled'       = $_.Enabled
                    'Enforced'      = $_.Enforced
                    'Order'         = $_.Order
                    'Applied'       = $GpoApply
                    'Denied'        = $GpoDeny
                    'WMI Filter'    = $GpoWmi
                }
            }
        }) | Export-Csv -Path "C:\Temp\GpoByOu_$FileDate.csv" -NoTypeInformation
}
