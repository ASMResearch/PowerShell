<#
.Synopsis
	
.Description
	
#>
param(
    [string] $ResultsPath = "C:\Users\christopher.small\Accenture Federal Services\ADAP - PowerShell Results",
    [string] $myWorkspaceID = "MyWorkspace",
    [string] $MicrosoftPowerBIMgmtName = "MicrosoftPowerBIMgmt",
    [string] $OnPremisesDataGatewayHAMgmtName = "OnPremisesDataGatewayHAMgmt",
    [string] $OnPremisesDataGatewayHAMgmtPath = "C:\Program Files\On-premises data gateway\OnPremisesDataGatewayHAMgmt.psm1"
)

# ==================================================================
#region Helper Functions 
# ==================================================================
function Assert-ModuleExists([string]$ModuleName) {
    $module = Get-Module $ModuleName -ListAvailable -ErrorAction SilentlyContinue
    if (!$module) {
        Write-Host "Installing module $ModuleName ..."
        Install-Module -Name $ModuleName -Force -Scope CurrentUser
        Write-Host "Module installed"
    }
    elseif ($module.Version -ne '1.0.0' -and $module.Version -le '1.0.410') {
        Write-Host "Updating module $ModuleName ..."
        Update-Module -Name $ModuleName -Force -ErrorAction Stop
        Write-Host "Module updated"
    }
}

#endregion

# ==================================================================
#region MicrosoftPowerBIMgmt install check
# ==================================================================
# 
If (!(Get-InstalledModule -Name $MicrosoftPowerBIMgmtName)) # check if MicrosoftPowerBIMgmt installed
{
    # install MicrosoftPowerBIMgmt
    Install-Module -Name $MicrosoftPowerBIMgmtName
}
# MicrosoftPowerBIMgmt import check
If (!(Get-Module -Name $MicrosoftPowerBIMgmtName)) # check if MicrosoftPowerBIMgmt imported
{
    # import MicrosoftPowerBIMgmt
    Import-Module -Name $MicrosoftPowerBIMgmtName
}
# OnPremisesDataGatewayHAMgmt import check
If (!(Get-Module -Name $OnPremisesDataGatewayHAMgmtName)) # check if OnPremisesDataGatewayHAMgmt imported
{
    # import OnPremisesDataGatewayHAMgmt
    Import-Module $OnPremisesDataGatewayHAMgmtPath
}

#endregion

# ==================================================================
#region Authenticate user - login to Power BI
# ==================================================================
# 
Connect-PowerBIServiceAccount | Out-Null

#endregion

# ==================================================================
#region Get Apps 
# ==================================================================
# create empty array
$allApps = @()
$allAppReports = @()
$allAppDashboards = @()

# get all apps
$apps = ((Invoke-PowerBIRestMethod -Url "apps" -Method Get) | ConvertFrom-Json).value
$allApps = $apps

# go thru apps
foreach ($app in $apps)
{
    # Apps - Get Reports
    $appReports = ((Invoke-PowerBIRestMethod -Url "apps/$($app.id)/reports" -Method Get) | ConvertFrom-Json).value
    $allAppReports = $allAppReports + $appReports

    # Apps - Get Dashboards
    $appDashboards = ((Invoke-PowerBIRestMethod -Url "apps/$($app.id)/dashboards" -Method Get) | ConvertFrom-Json).value
    $allAppDashboards = $allAppDashboards + $appDashboards
}

# create CSV files
$allApps | Export-Csv -Path $ResultsPath\Apps.csv -Delimiter ";" -NoTypeInformation
$allAppReports | Export-Csv -Path $ResultsPath\AppReports.csv -Delimiter ";" -NoTypeInformation
$allAppDashboards | Export-Csv -Path $ResultsPath\AppDashboards.csv -Delimiter ";" -NoTypeInformation

# create JSON files
$allApps | ConvertTo-Json -Depth 4 | Out-File -FilePath $ResultsPath\Apps.json -Force
$allAppReports | ConvertTo-Json -Depth 4 | Out-File -FilePath $ResultsPath\AppReportss.json -Force
$allAppDashboards | ConvertTo-Json -Depth 4 | Out-File -FilePath $ResultsPath\AppDashboards.json -Force

#endregion

# ==================================================================
#region Get Power BI Objects (My Workspace)
# ==================================================================
# create empty array
$myReports = @()
$myDashboards = @()
$myDatasets = @()
$myDsParameters = @()
$myDsDatasources = @()
$myDsRefreshHistory = @()
$myDsGateways = @()

# get my reports
$myReports = ((Invoke-PowerBIRestMethod -Url "reports" -Method Get) | ConvertFrom-Json).value
$myReports | ForEach-Object{$_ | 
    Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $myWorkspaceID
}

# get my dashboards
$myDashboards = ((Invoke-PowerBIRestMethod -Url "dashboards" -Method Get) | ConvertFrom-Json).value
$myDashboards | ForEach-Object{$_ | 
    Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $myWorkspaceID
}
# get my datasets
$myDatasets = ((Invoke-PowerBIRestMethod -Url "datasets" -Method Get) | ConvertFrom-Json).value
$myDatasets | ForEach-Object{$_ | 
    Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $myWorkspaceID
}
# go thru datasets in my workspace
foreach ($ds in $myDatasets)
    {
        # Datasets - Get Parameters
        $dsParameters = ((Invoke-PowerBIRestMethod -Url "datasets/$($ds.id)/parameters" -Method Get) | ConvertFrom-Json).value
        $dsParameters | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Dataset Id" -Value $ds.id
        }
        $dsParameters | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $myWorkspaceID
        }
        $myDsParameters = $myDsParameters + $dsParameters

        # Datasets - Get Datasources
        $dsDatasources = ((Invoke-PowerBIRestMethod -Url "datasets/$($ds.id)/datasources" -Method Get) | ConvertFrom-Json).value
        $dsDatasources | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Dataset Id" -Value $ds.id
        }
        $dsDatasources | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $myWorkspaceID
        }
        $myDsDatasources = $myDsDatasources + $dsDatasources

        # Datasets - Get Refresh History
        $dsRefreshHistory = ((Invoke-PowerBIRestMethod -Url "datasets/$($ds.id)/refreshes" -Method Get) | ConvertFrom-Json).value
        $dsRefreshHistory | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Dataset Id" -Value $ds.id
        }
        $dsRefreshHistory | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $myWorkspaceID
        }
        $myDsRefreshHistory = $myDsRefreshHistory + $dsRefreshHistory

        # Datasets - Discover Gateways
        $dsGateways = ((Invoke-PowerBIRestMethod -Url "datasets/$($ds.id)/Default.DiscoverGateways" -Method Get) | ConvertFrom-Json).value
        $dsGateways | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Dataset Id" -Value $ds.id
        }
        $dsGateways | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $myWorkspaceID
        }
        $myDsGateways = $myDsGateways + $dsGateways
    }

#endregion


# ==================================================================
#region Get Power BI Objects By Groups (Workspaces)
# ==================================================================
# create empty array
$allWorkspaces = @()
$allWsUsers = @()
$allWsReports = @()
$allWsDashboards = @()
$allWsDatasets = @()
$allWsDsParameters = @()
$allWsDsDatasources = @()
$allWsDsRefreshHistory = @()
$allWsDsGateways = @()
$allWsDataflows = @()
$allWsDfDatasources = @()

# get all workspaces
$workspaces = ((Invoke-PowerBIRestMethod -Url "groups" -Method Get) | ConvertFrom-Json).value
$allWorkspaces = $workspaces

# go thru workspaces
foreach ($ws in $workspaces)
{
    # Groups - Get Group Users
    $wsUsers = ((Invoke-PowerBIRestMethod -Url "groups/$($ws.id)/users" -Method Get) | ConvertFrom-Json).value
    $wsUsers | ForEach-Object{
	    $_ | Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $ws.id
    }

    # Reports - Get Reports In Group
    $wsReports = ((Invoke-PowerBIRestMethod -Url "groups/$($ws.id)/reports" -Method Get) | ConvertFrom-Json).value
    $wsReports | ForEach-Object{
	    $_ | Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $ws.id
    }

    # Dashboards - Get Dashboards In Group
    $wsDashboards = ((Invoke-PowerBIRestMethod -Url "groups/$($ws.id)/dashboards" -Method Get) | ConvertFrom-Json).value
    $wsDashboards | ForEach-Object{
	    $_ | Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $ws.id
    }

    # Datasets - Get Datasets In Group
    $wsDatasets = ((Invoke-PowerBIRestMethod -Url "groups/$($ws.id)/datasets" -Method Get) | ConvertFrom-Json).value
    $wsDatasets | ForEach-Object{$_ | 
        Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $ws.id
    }

    # go thru datasets
    foreach ($ds in $wsDatasets)
    {
        # Datasets - Get Parameters In Group
        $wsDsParameters = ((Invoke-PowerBIRestMethod -Url "groups/$($ws.id)/datasets/$($ds.id)/parameters" -Method Get) | ConvertFrom-Json).value
        $wsDsParameters | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Dataset Id" -Value $ds.id
        }
        $wsDsParameters | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $ws.id
        }
        $allWsDsParameters = $allWsDsParameters + $wsDsParameters

        # Datasets - Get Datasources In Group
        $wsDsDatasources = ((Invoke-PowerBIRestMethod -Url "groups/$($ws.id)/datasets/$($ds.id)/datasources" -Method Get) | ConvertFrom-Json).value
        $wsDsDatasources | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Dataset Id" -Value $ds.id
        }
        $wsDsDatasources | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $ws.id
        }
        $allWsDsDatasources = $allWsDsDatasources + $wsDsDatasources

        # Datasets - Get Refresh History In Group
        $wsDsRefreshHistory = ((Invoke-PowerBIRestMethod -Url "groups/$($ws.id)/datasets/$($ds.id)/refreshes" -Method Get) | ConvertFrom-Json).value
        $wsDsRefreshHistory | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Dataset Id" -Value $ds.id
        }
        $wsDsRefreshHistory | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $ws.id
        }
        $allWsDsRefreshHistory = $allWsDsRefreshHistory + $wsDsRefreshHistory

        # Datasets - Discover Gateways In Group
        $wsDsGateways = ((Invoke-PowerBIRestMethod -Url "groups/$($ws.id)/datasets/$($ds.id)/Default.DiscoverGateways" -Method Get) | ConvertFrom-Json).value
        $wsDsGateways | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Dataset Id" -Value $ds.id
        }
        $wsDsGateways | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $ws.id
        }
        $allWsDsGateways = $allWsDsGateways + $wsDsGateways
    }

    # Dataflows - Get Dataflows
    $wsDataflows = ((Invoke-PowerBIRestMethod -Url "groups/$($ws.id)/dataflows" -Method Get) | ConvertFrom-Json).value
    $wsDataflows | ForEach-Object{$_ | 
        Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $ws.id
    }

    # go thru dataflows
    foreach ($df in $wsDataflows)
    {
        # Dataflows - Get Dataflow Data Sources
        $wsDfDatasources = ((Invoke-PowerBIRestMethod -Url "groups/$($ws.id)/dataflows/$($df.objectId)/datasources" -Method Get) | ConvertFrom-Json).value
        $wsDfDatasources | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Dataflow Id" -Value $df.objectId
        }
        $wsDfDatasources | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Workspace Id" -Value $ws.id
        }
        $allWsDfDatasources = $allWsDfDatasources + $wsDfDatasources
    }
    $allWsUsers = $allWsUsers + $wsUsers
    $allWsReports = $allWsReports + $wsReports
    $allWsDashboards = $allWsDashboards + $wsDashboards
    $allWsDatasets = $allWsDatasets + $wsDatasets
    $allWsDataflows = $allWsDataflows + $wsDataflows
}

#endregion

# ==================================================================
#region Get Gateways 
# ==================================================================
# create empty array
$allGateways = @()
$allGwDatasources = @()
$allGwDtsUsers = @()

# get all gateways
$gateways = ((Invoke-PowerBIRestMethod -Url "gateways" -Method Get) | ConvertFrom-Json).value
$allGateways = $gateways

# go thru gateways
foreach ($gw in $gateways)
{
    # Gateways - Get Datasources
    $gwDatasources = ((Invoke-PowerBIRestMethod -Url "gateways/$($gw.id)/datasources" -Method Get) | ConvertFrom-Json).value
    $gwDatasources | ForEach-Object{
	    $_ | Add-Member -MemberType NoteProperty -Name "Gateway Id" -Value $gw.id
    }

    # go thru datasources
    foreach ($dts in $gwDatasources)
    {
        # Datasets - Get Parameters In Group
        $gwDtsUsers = ((Invoke-PowerBIRestMethod -Url "gateways/$($gw.id)/datasources/$($dts.id)/users" -Method Get) | ConvertFrom-Json).value
        $gwDtsUsers | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Datasource Id" -Value $dts.id
        }
        $gwDtsUsers | ForEach-Object{$_ | 
            Add-Member -MemberType NoteProperty -Name "Gateway Id" -Value $gw.id
        }
        $allGwDtsUsers = $allGwDtsUsers + $gwDtsUsers
    }
    $allGwDatasources = $allGwDatasources + $gwDatasources
}

#endregion

# ==================================================================
#region Combine
# ==================================================================
# create empty array
$allReports = @()
$allDashboards = @()
$allDatasets = @()
$allDsParameters = @()
$allDsDatasources = @()
$allDsRefreshHistory = @()
$allDsGateways = @()

# combine my and allWs
$allReports = $myReports + $allWsReports
$allDashboards = $myDashboards + $allWsDashboards
$allDatasets = $myDatasets + $allWsDatasets
$allDsParameters = $myDsParameters + $allWsDsParameters
$allDsDatasources = $myDsDatasources + $allWsDsDatasources
$allDsRefreshHistory = $myDsRefreshHistory + $allWsDsRefreshHistory
$allDsGateways = $myDsGateways + $allWsDsGateways

#endregion

# ==================================================================
#region Export-Csv
# ==================================================================
# Apps
$allApps | Export-Csv -Path $ResultsPath\Apps.csv -Delimiter ";" -NoTypeInformation
$allAppReports | Export-Csv -Path $ResultsPath\AppReports.csv -Delimiter ";" -NoTypeInformation
$allAppDashboards | Export-Csv -Path $ResultsPath\AppDashboards.csv -Delimiter ";" -NoTypeInformation

# Power BI Objects (My Workspace)
$myReports | Export-Csv -Path $ResultsPath\MyWorkspaceReports.csv -Delimiter ";" -NoTypeInformation
$myDashboards | Export-Csv -Path $ResultsPath\MyWorkspaceDashboards.csv -Delimiter ";" -NoTypeInformation
$myDatasets | Export-Csv -Path $ResultsPath\MyWorkspaceDatasets.csv -Delimiter ";" -NoTypeInformation
$myDsParameters | Export-Csv -Path $ResultsPath\MyWorkspaceDatasetParameters.csv -Delimiter ";" -NoTypeInformation
$myDsDatasources | Export-Csv -Path $ResultsPath\MyWorkspaceDatasetDatasources.csv -Delimiter ";" -NoTypeInformation
$myDsRefreshHistory | Export-Csv -Path $ResultsPath\MyWorkspaceDatasetRefreshHistory.csv -Delimiter ";" -NoTypeInformation
$myDsGateways | Export-Csv -Path $ResultsPath\MyWorkspaceDatasetGateways.csv -Delimiter ";" -NoTypeInformation

# Power BI Objects By Groups (Workspaces)
$allWorkspaces | Export-Csv -Path $ResultsPath\Workspaces.csv -Delimiter ";" -NoTypeInformation
$allWsUsers | Export-Csv -Path $ResultsPath\WorkspaceUsers.csv -Delimiter ";" -NoTypeInformation
$allWsReports | Export-Csv -Path $ResultsPath\WorkspaceReports.csv -Delimiter ";" -NoTypeInformation
$allWsDashboards | Export-Csv -Path $ResultsPath\WorkspaceDashboards.csv -Delimiter ";" -NoTypeInformation
$allWsDatasets | Export-Csv -Path $ResultsPath\WorkspaceDatasets.csv -Delimiter ";" -NoTypeInformation
$allWsDsParameters | Export-Csv -Path $ResultsPath\WorkspaceDatasetParameters.csv -Delimiter ";" -NoTypeInformation
$allWsDsDatasources | Export-Csv -Path $ResultsPath\WorkspaceDatasetDatasources.csv -Delimiter ";" -NoTypeInformation
$allWsDsRefreshHistory | Export-Csv -Path $ResultsPath\WorkspaceDatasetRefreshHistory.csv -Delimiter ";" -NoTypeInformation
$allWsDsGateways | Export-Csv -Path $ResultsPath\WorkspaceDatasetGateways.csv -Delimiter ";" -NoTypeInformation
$allWsDataflows | Export-Csv -Path $ResultsPath\WorkspaceDataflows.csv -Delimiter ";" -NoTypeInformation
$allWsDfDatasources | Export-Csv -Path $ResultsPath\WorkspaceDataflowDatasources.csv -Delimiter ";" -NoTypeInformation
# Json
$allWsDataflows | ConvertTo-Json -Depth 4 | Out-File -FilePath $ResultsPath\WorkspaceDataflows.json -Force

# Gateways
$allGateways | Export-Csv -Path $ResultsPath\Gateways.csv -Delimiter ";" -NoTypeInformation
$allGwDatasources | Export-Csv -Path $ResultsPath\GatewayDatasources.csv -Delimiter ";" -NoTypeInformation
$allGwDtsUsers | Export-Csv -Path $ResultsPath\GatewayDatasourceUsers.csv -Delimiter ";" -NoTypeInformation

# Combined
$allReports | Export-Csv -Path $ResultsPath\allReports.csv -Delimiter ";" -NoTypeInformation
$allDashboards | Export-Csv -Path $ResultsPath\allDashboards.csv -Delimiter ";" -NoTypeInformation
$allDatasets | Export-Csv -Path $ResultsPath\allDatasets.csv -Delimiter ";" -NoTypeInformation
$allDsParameters | Export-Csv -Path $ResultsPath\allDsParameters.csv -Delimiter ";" -NoTypeInformation
$allDsDatasources | Export-Csv -Path $ResultsPath\allDsDatasources.csv -Delimiter ";" -NoTypeInformation
$allDsRefreshHistory | Export-Csv -Path $ResultsPath\allDsRefreshHistory.csv -Delimiter ";" -NoTypeInformation
$allDsGateways | Export-Csv -Path $ResultsPath\allDsGateways.csv -Delimiter ";" -NoTypeInformation

#endregion

# 
Write-Host "Complete"