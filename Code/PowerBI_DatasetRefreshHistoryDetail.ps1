<#
.Synopsis
	
.Description
	
#>
param(
    [Alias('TargetFolder')]
    [string] $Path = "C:\Users\christopher.small\Accenture Federal Services\ADAP - PowerShell Results",
    [bool] $Json = $true,
    [string] $JsonFile = 'WorkspaceDatasetRefreshHistoryDetail.json', # 'Log_' + (Get-Date).ToString("yyy_MM_dd_hh_mm_ss") + '.json'
    [string] $MyJsonFile = 'MyWorkspaceDatasetRefreshHistoryDetail.json', # 'Log_' + (Get-Date).ToString("yyy_MM_dd_hh_mm_ss") + '.json'
    [string] $AllJsonFile = 'AllWorkspaceDatasetRefreshHistoryDetail.json', # 'Log_' + (Get-Date).ToString("yyy_MM_dd_hh_mm_ss") + '.json'
    [bool] $Csv = $true,
    [string] $CsvFile = 'WorkspaceDatasetRefreshHistoryDetail.csv', # 'Log_' + (Get-Date).ToString("yyy_MM_dd_hh_mm_ss") + '.csv'
    [string] $MyCsvFile = 'MyWorkspaceDatasetRefreshHistoryDetail.csv', # 'Log_' + (Get-Date).ToString("yyy_MM_dd_hh_mm_ss") + '.csv'
    [string] $AllCsvFile = 'AllWorkspaceDatasetRefreshHistoryDetail.csv', # 'Log_' + (Get-Date).ToString("yyy_MM_dd_hh_mm_ss") + '.csv'
    [bool] $Dedicated = $false,
    [bool] $AdminMode = $false,
    [string] $WorkspaceName,
    [string] $DatasetName,
    [ValidateSet('All', 'Today')]
    [string] $Scope = 'All',
    [int] $Top
)

# ==================================================================
#region Functions
# ==================================================================
# 
function Get-DetailValue($details, $key)
{
    foreach ($detail in $details)
    {
        if ($detail.code -eq $key)
        {
            return $detail.detail.value
        }
    }
}

# 
function Get-RefreshHistory
{
    param
    (
        [Microsoft.PowerBI.Common.Api.Workspaces.Workspace] $Workspace,

        [Microsoft.PowerBI.Common.Api.Datasets.Dataset] $Dataset,

        [int] $Top,

        [ValidateSet('All','Today')]
        [string] $Scope
    )

    # get url
    $url = "groups/$($Workspace.id)/datasets/$($Dataset.Id)/refreshes"
    Write-Verbose "Get-RefreshHistory:Workspace:$($Workspace.Name);Dataset:$($Dataset.Name)"
    Write-Verbose "Get-RefreshHistory:Url:$url"
    if ($scope)
    {
        # get history objects collection based on scope 'All' - all records, 'Today' - todays redreshes
        $history = ((Invoke-PowerBIRestMethod -Url $url -Method Get) |
            ConvertFrom-Json).value |
            Where-Object { ($scope -eq "all") -or (($scope -eq "today") -and ($_.startTime.SubString(0, 10) -eq ((Get-Date).ToString("yyyy-MM-dd"))))}
            Sort-Object -Descending -Property timeStart
    }
    elseif ($Top)
    {
        # get history objects collection based on Top claus like ODATA/SQL
        $history = ((Invoke-PowerBIRestMethod -Url $url -Method Get) |
            ConvertFrom-Json).value |
            Sort-Object -Descending -Property timeStart |
            Select-Object -First $Top
    }
    return $history
}

# 
function Get-MyRefreshHistory
{
    param
    (

        [Microsoft.PowerBI.Common.Api.Datasets.Dataset] $Dataset,

        [int] $Top,

        [ValidateSet('All','Today')]
        [string] $Scope
    )

    # get url
    $url = "datasets/$($Dataset.Id)/refreshes"
    Write-Verbose "Get-MyRefreshHistory:Dataset:$($Dataset.Name)"
    Write-Verbose "Get-MyRefreshHistory:Url:$url"
    if ($scope)
    {
        # get history objects collection based on scope 'All' - all records, 'Today' - todays redreshes
        $history = ((Invoke-PowerBIRestMethod -Url $url -Method Get) |
            ConvertFrom-Json).value |
            Where-Object { ($scope -eq "all") -or (($scope -eq "today") -and ($_.startTime.SubString(0, 10) -eq ((Get-Date).ToString("yyyy-MM-dd"))))}
            Sort-Object -Descending -Property timeStart
    }
    elseif ($Top)
    {
        # get history objects collection based on Top claus like ODATA/SQL
        $history = ((Invoke-PowerBIRestMethod -Url $url -Method Get) |
            ConvertFrom-Json).value |
            Sort-Object -Descending -Property timeStart |
            Select-Object -First $Top
    }
    return $history
}

#endregion

# ==================================================================
#region check if Path does exist
# ==================================================================
# 
if (!(Test-Path -Path $Path))
{
    throw "Path '$Path' not found"
}
else
{
    Write-Host "Log files will be stored in folder '$Path' ..."
}

#endregion

# ==================================================================
#region Authenticate user - login to Power BI
# ==================================================================
# 
Connect-PowerBIServiceAccount | Out-Null

#endregion

# ==================================================================
#region History
# ==================================================================
# 
if ($WorkspaceName) # check if WorkspaceName set
{
    # get special workspace
    $workspaces = @(Get-PowerBIWorkspace -Name $WorkspaceName)
}
elseif ($Dedicated) # only workspaces in capacity
{
    $workspaces = Get-PowerBIWorkspace |
        Where-Object { $_.IsOnDedicatedCapacity -and (!$_.IsReadOnly)}
}
else # get all workspaces
{
    if ($AdminMode) # if admin Mode all workspaces will be retrieved
    {
        $workspaces = Get-PowerBIWorkspace -Scope Organization |
            Where-Object { (!$_.IsReadOnly) } 
    } 
    else # only workspaces I am admin
    {   
        $workspaces = Get-PowerBIWorkspace |
            Where-Object { (!$_.IsReadOnly) }
    }
}

# create empty history array
$historyItems = @()

# go thru workspaces
foreach ($ws in $workspaces)
{
    Write-Verbose "Workspace: $($ws.name)"
    if ($DatasetName) # special dataset
    {
        # get special dataset
        $datasets = @(Get-PowerBIDataset -Workspace $ws |
            Where-Object { $_.Name -eq $DatasetName })
    }
    else
    {
        # get all datasets in workspace
        $datasets = Get-PowerBIDataset -Workspace $ws
    }

    # check for a valid dataset otherwise use next workspace
    if (!$datasets)
    { 
        Write-Host "No dataset(s) found in Workpace '$($ws.Name)' for '$DatasetName'" -ForegroundColor Red
        continue
    }

    # filter out 'report usage metrics model' dataset - always there
    foreach ($ds in ($datasets | Where-Object { $_.Name -ne "Report Usage Metrics Model"}) )
    {
        Write-Verbose "Dataset: $($ds.Name)"
        # successful refreshes
        $historyItems += Get-RefreshHistory -Workspace $ws -Dataset $ds -Scope $Scope -Top $Top | 
            Where-Object {$_.serviceExceptionJSON} |
            Select-Object -Property id, refreshType, startTime, endTime, status, serviceExceptionJson, `
                @{n='WorkspaceName';e={$ws.Name}}, @{n='WorkspaceId';e={$ws.Id}}, @{n='DatasetName';e={$ds.Name}}, @{n='DatasetId';e={$ds.Id}},`
                @{n='ErrorCode';e={""}}, @{n='ClusterUri';e={""}}, @{n='ActivityId';e={""}}, @{n='RequestId';e={""}}, @{n='Timestamp';e={""}}
        
        # failing refreshes
        $historyItems += Get-RefreshHistory -Workspace $ws -Dataset $ds -Scope $Scope -Top $Top | 
            Where-Object {-not ($_.serviceExceptionJSON)} |
            Select-Object -Property id, refreshType, startTime, endTime, status, @{n='serviceExceptionJson';e={$null}},`
                @{n='WorkspaceName';e={$ws.Name}}, @{n='WorkspaceId';e={$ws.Id}}, @{n='DatasetName';e={$ds.Name}}, @{n='DatasetId';e={$ds.Id}},`
                @{n='ErrorCode';e={""}}, @{n='ClusterUri';e={""}}, @{n='ActivityId';e={""}}, @{n='RequestId';e={""}}, @{n='Timestamp';e={""}}
    }

}

# add additional infos for failing refreshes
for ($i=0; $i -lt $historyItems.Length; $i++)
{
    if ($historyItems[$i].serviceExceptionJson)
    {
        # convert serviceException JSON into object
        $historyObject = ($historyItems[$i].serviceExceptionJson | ConvertFrom-Json)

        # fill the predefined error entries
        $historyItems[$i].ErrorCode = $historyObject.error.code
        $historyItems[$i].ClusterUri = Get-DetailValue -details $historyObject.error.'pbi.error'.details  -key "ClusterUriText"
        $historyItems[$i].ActivityId = Get-DetailValue -details $historyObject.error.'pbi.error'.details  -key "ActivityIdText"
        $historyItems[$i].RequestId = Get-DetailValue -details $historyObject.error.'pbi.error'.details  -key "RequestIdText"
        $historyItems[$i].Timestamp = Get-DetailValue -details $historyObject.error.'pbi.error'.details  -key "TimestampText"
    }
}

# create CSV file - remove serviceException column
if ($Csv) 
{
    $csvFilePath = "$Path\$CsvFile"
    $historyItems |
        Select-Object -Property id, refreshType, startTime, endTime, status, WorkspaceName,  WorkspaceId, DatasetName, DatasetId,`ErrorCode, ClusterUri,ActivityId,RequestId, Timestamp |
        Export-Csv -Path $csvFilePath -Delimiter ";" -Force -NoTypeInformation
    Write-Host "CSV log file '$csvFilePath' createds"
}

# create JSON file
if ($Json)
{
    $jsonFilePath = "$Path\$JsonFile"
    $historyItems |
        ConvertTo-Json -Depth 4 |
        Out-File -FilePath $jsonFilePath -Force
    Write-Host "JSON log file '$jsonFilePath' created"
}

#endregion

# ==================================================================
#region My History
# ==================================================================
# create empty history array
$myHistoryItems = @()

# 
if ($DatasetName) # special dataset
{
    # get special dataset
    $datasets = @(Get-PowerBIDataset -Scope Individual |
        Where-Object { $_.Name -eq $DatasetName })
}
else
{
    # get all datasets in MyWorkspace
    $datasets = Get-PowerBIDataset -Scope Individual
}

# check for a valid dataset
if (!$datasets)
{ 
    Write-Host "No dataset(s) found in My Workpace for '$DatasetName'" -ForegroundColor Red
    continue
}

# filter out 'report usage metrics model' dataset - always there
foreach ($ds in $datasets)
{
	Write-Verbose "Dataset: $($ds.Name)"
	# successful refreshes
	$myHistoryItems += Get-MyRefreshHistory -Dataset $ds -Scope $Scope -Top $Top


    Write-Verbose "Dataset: $($ds.Name)"
    # successful refreshes
    $myHistoryItems += Get-MyRefreshHistory -Dataset $ds -Scope $Scope -Top $Top | 
        Where-Object {$_.serviceExceptionJSON} |
        Select-Object -Property id, refreshType, startTime, endTime, status, serviceExceptionJson, `
            @{n='WorkspaceName';e={'MyWorkspace'}}, @{n='WorkspaceId';e={'MyWorkspace'}}, @{n='DatasetName';e={$ds.Name}}, @{n='DatasetId';e={$ds.Id}},`
            @{n='ErrorCode';e={""}}, @{n='ClusterUri';e={""}}, @{n='ActivityId';e={""}}, @{n='RequestId';e={""}}, @{n='Timestamp';e={""}}
        
    # failing refreshes
    $myHistoryItems += Get-MyRefreshHistory -Dataset $ds -Scope $Scope -Top $Top | 
        Where-Object {-not ($_.serviceExceptionJSON)} |
        Select-Object -Property id, refreshType, startTime, endTime, status, @{n='serviceExceptionJson';e={$null}},`
            @{n='WorkspaceName';e={'MyWorkspace'}}, @{n='WorkspaceId';e={'MyWorkspace'}}, @{n='DatasetName';e={$ds.Name}}, @{n='DatasetId';e={$ds.Id}},`
            @{n='ErrorCode';e={""}}, @{n='ClusterUri';e={""}}, @{n='ActivityId';e={""}}, @{n='RequestId';e={""}}, @{n='Timestamp';e={""}}
}

# add additional infos for failing refreshes
for ($i=0; $i -lt $myHistoryItems.Length; $i++)
{
    if ($myHistoryItems[$i].serviceExceptionJson)
    {
        # convert serviceException JSON into object
        $historyObject = ($myHistoryItems[$i].serviceExceptionJson | ConvertFrom-Json)

        # fill the predefined error entries
        $myHistoryItems[$i].ErrorCode = $historyObject.error.code
        $myHistoryItems[$i].ClusterUri = Get-DetailValue -details $historyObject.error.'pbi.error'.details  -key "ClusterUriText"
        $myHistoryItems[$i].ActivityId = Get-DetailValue -details $historyObject.error.'pbi.error'.details  -key "ActivityIdText"
        $myHistoryItems[$i].RequestId = Get-DetailValue -details $historyObject.error.'pbi.error'.details  -key "RequestIdText"
        $myHistoryItems[$i].Timestamp = Get-DetailValue -details $historyObject.error.'pbi.error'.details  -key "TimestampText"
    }
}

# create CSV file - remove serviceException column
if ($Csv) 
{
    $csvFilePath = "$Path\$MyCsvFile"
    $myHistoryItems |
        Select-Object -Property id, refreshType, startTime, endTime, status, WorkspaceName,  WorkspaceId, DatasetName, DatasetId,`ErrorCode, ClusterUri,ActivityId,RequestId, Timestamp |
        Export-Csv -Path $csvFilePath -Delimiter ";" -Force -NoTypeInformation
    Write-Host "CSV log file '$csvFilePath' createds"
}

# create JSON file
if ($Json)
{
    $jsonFilePath = "$Path\$MyJsonFile"
    $myHistoryItems |
        ConvertTo-Json -Depth 4 |
        Out-File -FilePath $jsonFilePath -Force
    Write-Host "JSON log file '$jsonFilePath' created"
}

#endregion

# ==================================================================
#region Combined
# ==================================================================
# create empty history array
$allHistoryItems = @()

# 
$allHistoryItems = $historyItems + $myHistoryItems

# create CSV file - remove serviceException column
if ($Csv) 
{
    $csvFilePath = "$Path\$AllCsvFile"
    $allHistoryItems |
        Select-Object -Property id, refreshType, startTime, endTime, status, WorkspaceName,  WorkspaceId, DatasetName, DatasetId,`ErrorCode, ClusterUri,ActivityId,RequestId, Timestamp |
        Export-Csv -Path $csvFilePath -Delimiter ";" -Force -NoTypeInformation
    Write-Host "CSV log file '$csvFilePath' created"
}

# create JSON file
if ($Json)
{
    $jsonFilePath = "$Path\$AllJsonFile"
    $allHistoryItems |
        ConvertTo-Json -Depth 4 |
        Out-File -FilePath $jsonFilePath -Force
    Write-Host "JSON log file '$jsonFilePath' created"
}

#endregion
