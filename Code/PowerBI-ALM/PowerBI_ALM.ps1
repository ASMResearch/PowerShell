# ==================================================================
# PART 1: Set parameters, verify Power BI modules are installed
#         and authenticate user.
# ==================================================================
# Parameters - look into using param(
param(
    [string] $myWorkspaceID = "MyWorkspace",
    [string] $xPath = "$($HOME)\Documents\PowerShellResults",
    [string] $prmExecutionPolicy = "Unrestricted",
    [string] $prmMicrosoftPowerBIMgmt = "MicrosoftPowerBIMgmt",
    [string] $prmOnPremisesDataGatewayHAMgmtName = "OnPremisesDataGatewayHAMgmt",
    [string] $prmOnPremisesDataGatewayHAMgmtPath = "C:\Program Files\On-premises data gateway\OnPremisesDataGatewayHAMgmt.psm1"
)

# Function Assert-ModuleExists - test function -> Assert-ModuleExists -ModuleName "MicrosoftPowerBIMgmt"
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

# ExecutionPolicy Unrestricted check
If ((Get-ExecutionPolicy) -ne $prmExecutionPolicy) # check if ExecutionPolicy is set to Unrestricted
{
    Set-ExecutionPolicy -ExecutionPolicy $prmExecutionPolicy -Force
}

# MicrosoftPowerBIMgmt install check
If (!(Get-InstalledModule -Name $prmMicrosoftPowerBIMgmt)) # check if MicrosoftPowerBIMgmt installed
{
    # install MicrosoftPowerBIMgmt
    Install-Module -Name $prmMicrosoftPowerBIMgmt
}

# MicrosoftPowerBIMgmt import check
If (!(Get-Module -Name $prmMicrosoftPowerBIMgmt)) # check if MicrosoftPowerBIMgmt imported
{
    # import MicrosoftPowerBIMgmt
    Import-Module -Name $prmMicrosoftPowerBIMgmt
}
# OnPremisesDataGatewayHAMgmt import check
If (!(Get-Module -Name $prmOnPremisesDataGatewayHAMgmtName)) # check if OnPremisesDataGatewayHAMgmt imported
{
    # import OnPremisesDataGatewayHAMgmt
    Import-Module $prmOnPremisesDataGatewayHAMgmtPath
}

# Authenticate user - login to Power BI
Connect-PowerBIServiceAccount | Out-Null

# ==================================================================
# PART 2: Get MyWorkspace Power BI Objects 
# ==================================================================
# create empty array
$myApps = @()
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
# 
$myReports | Export-Csv -Path $HOME\Documents\PowerShellResults\MyWorkspaceReports.csv -Delimiter ";" -NoTypeInformation
$myDashboards | Export-Csv -Path $HOME\Documents\PowerShellResults\MyWorkspaceDashboards.csv -Delimiter ";" -NoTypeInformation
$myDatasets | Export-Csv -Path $HOME\Documents\PowerShellResults\MyWorkspaceDatasets.csv -Delimiter ";" -NoTypeInformation
$myDsParameters | Export-Csv -Path $HOME\Documents\PowerShellResults\MyWorkspaceDatasetParameters.csv -Delimiter ";" -NoTypeInformation
$myDsDatasources | Export-Csv -Path $HOME\Documents\PowerShellResults\MyWorkspaceDatasetDatasources.csv -Delimiter ";" -NoTypeInformation
$myDsRefreshHistory | Export-Csv -Path $HOME\Documents\PowerShellResults\MyWorkspaceDatasetRefreshHistory.csv -Delimiter ";" -NoTypeInformation
$myDsGateways | Export-Csv -Path $HOME\Documents\PowerShellResults\MyWorkspaceDatasetGateways.csv -Delimiter ";" -NoTypeInformation

# ==================================================================
# PART 2: Get Apps 
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
    $appReports | ForEach-Object{
	    $_ | Add-Member -MemberType NoteProperty -Name "App Id" -Value $app.id
    }
    $allAppReports = $allAppReports + $appReports

    # Apps - Get Dashboards
    $appDashboards = ((Invoke-PowerBIRestMethod -Url "apps/$($app.id)/dashboards" -Method Get) | ConvertFrom-Json).value
    $appDashboards | ForEach-Object{
	    $_ | Add-Member -MemberType NoteProperty -Name "App Id" -Value $app.id
    }
    $allAppDashboards = $allAppDashboards + $appDashboards
}
# 
$allApps | Export-Csv -Path $HOME\Documents\PowerShellResults\Apps.csv -Delimiter ";" -NoTypeInformation
$allAppReports | Export-Csv -Path $HOME\Documents\PowerShellResults\AppReports.csv -Delimiter ";" -NoTypeInformation
$allAppDashboards | Export-Csv -Path $HOME\Documents\PowerShellResults\AppDashboards.csv -Delimiter ";" -NoTypeInformation

# ==================================================================
# PART 3: Get Power BI Objects By Groups (Workspaces)
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
# 
$allWorkspaces | Export-Csv -Path $HOME\Documents\PowerShellResults\Workspaces.csv -Delimiter ";" -NoTypeInformation
$allWsUsers | Export-Csv -Path $HOME\Documents\PowerShellResults\WorkspaceUsers.csv -Delimiter ";" -NoTypeInformation
$allWsReports | Export-Csv -Path $HOME\Documents\PowerShellResults\WorkspaceReports.csv -Delimiter ";" -NoTypeInformation
$allWsDashboards | Export-Csv -Path $HOME\Documents\PowerShellResults\WorkspaceDashboards.csv -Delimiter ";" -NoTypeInformation
$allWsDatasets | Export-Csv -Path $HOME\Documents\PowerShellResults\WorkspaceDatasets.csv -Delimiter ";" -NoTypeInformation
$allWsDsParameters | Export-Csv -Path $HOME\Documents\PowerShellResults\WorkspaceDatasetParameters.csv -Delimiter ";" -NoTypeInformation
$allWsDsDatasources | Export-Csv -Path $HOME\Documents\PowerShellResults\WorkspaceDatasetDatasources.csv -Delimiter ";" -NoTypeInformation
$allWsDsRefreshHistory | Export-Csv -Path $HOME\Documents\PowerShellResults\WorkspaceDatasetRefreshHistory.csv -Delimiter ";" -NoTypeInformation
$allWsDsGateways | Export-Csv -Path $HOME\Documents\PowerShellResults\WorkspaceDatasetGateways.csv -Delimiter ";" -NoTypeInformation
$allWsDataflows | Export-Csv -Path $HOME\Documents\PowerShellResults\WorkspaceDataflows.csv -Delimiter ";" -NoTypeInformation
$allWsDfDatasources | Export-Csv -Path $HOME\Documents\PowerShellResults\WorkspaceDataflowDatasources.csv -Delimiter ";" -NoTypeInformation

# ==================================================================
# PART 3: Get Gateways 
# ==================================================================
# STEP 2.1: Gateways
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
# 
$allGateways | Export-Csv -Path $HOME\Documents\PowerShellResults\Gateways.csv -Delimiter ";" -NoTypeInformation
$allGwDatasources | Export-Csv -Path $HOME\Documents\PowerShellResults\GatewayDatasources.csv -Delimiter ";" -NoTypeInformation
$allGwDtsUsers | Export-Csv -Path $HOME\Documents\PowerShellResults\GatewayDatasourceUsers.csv -Delimiter ";" -NoTypeInformation

# 
Write-Host "Complete"