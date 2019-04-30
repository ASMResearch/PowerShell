
## ---------------
# Parameters
$prmExecutionPolicy = "Unrestricted"
$prmMicrosoftPowerBIMgmt = "MicrosoftPowerBIMgmt"
$prmOnPremisesDataGatewayHAMgmtName = "OnPremisesDataGatewayHAMgmt"
$prmOnPremisesDataGatewayHAMgmtPath = "C:\Program Files\On-premises data gateway\OnPremisesDataGatewayHAMgmt.psm1"
$sqlConnectionString = "Server=S1ASMSDB-01;Integrated Security=true;Initial Catalog=AERA;Connection Timeout=60"

$transcriptFilePath = ".\"
$transcriptFileName = "onPreMGatewayMgmtALM-" + [DateTime]::Now.ToString("yyyyMMdd-HHmmss")  + ".txt"
$transcriptFullPath = $transcriptFilePath + $transcriptFileName
Start-Transcript $transcriptFullPath


# Variables
$varStartingLocation = Get-Location

# ExecutionPolicy Unrestricted check
If ((Get-ExecutionPolicy) -ne $prmExecutionPolicy) # check if ExecutionPolicy is set to Unrestricted
{
    Set-ExecutionPolicy -ExecutionPolicy $prmExecutionPolicy -Force
}

# OnPremisesDataGatewayHAMgmt import check
If (!(Get-Module -Name $prmOnPremisesDataGatewayHAMgmtName)) # check if OnPremisesDataGatewayHAMgmt imported
{
    # import OnPremisesDataGatewayHAMgmt
    Import-Module $prmOnPremisesDataGatewayHAMgmtPath
}

# Login to Azure using EmailAddress
Login-OnPremisesDataGateway -EmailAddress christopher.small@asmr.com # Current backend is:  https://wabi-us-east2-redirect.analysis.windows.net/

# Get the list of gateway clusters and save to .csv
$allGatewayClusters = Get-OnPremisesDataGatewayClusters
$unpackedGateways = @()
foreach($cluster in $allGatewayClusters)
{
    foreach($gateway in $cluster.gateways | ConvertFrom-Json) 
    {
        foreach($property in $cluster.PSObject.Properties)
        {
            if($property.Name -ne "gateways" -and $property.Name -ne "expiryDate") 
            {
                $gateway | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
            }
        }

        $unpackedGateways += $gateway

    }
    
}

Write-Host "Writing Cluster Gateways to AERA"

try {
	$sqlConn = New-Object System.Data.SqlClient.SqlConnection
	$sqlConn.ConnectionString = $sqlConnectionString
	$sqlConn.Open()
	
	$removeCurrentDataQuery = "DELETE FROM AERA.dbo.PBI_GatewayClusters"
	
	$sqlcmd = New-Object System.Data.SqlClient.SqlCommand
	$sqlcmd.Connection = $sqlConn
	$sqlcmd.CommandText = $removeCurrentDataQuery
	$sqlcmd.ExecuteNonQuery() 
	
    Write-Host "Removed prior data from PBI_GatewayClusters"
	
	$insertCommand = "INSERT INTO AERA.dbo.PBI_GatewayClusters (GateWayId, GatewayObjectId, GatewayName, GatewayStatus, IsAnchorGateway, GatewayClusterStatus, GatewayPublicKey, GatewayVersion, GatewayVersionStatus, ExpiryDate, GatewayContactInformation, GatewayMachine, ObjectId, Name, Description, Permission, VersionStatus, LoadBalancingType) VALUES (@GateWayId, @GatewayObjectId, @GatewayName, @GatewayStatus, @IsAnchorGateway, @GatewayClusterStatus, @GatewayPublicKey, @GatewayVersion, @GatewayVersionStatus, @ExpiryDate, @GatewayContactInformation, @GatewayMachine, @ObjectId, @Name, @Description, @Permission, @VersionStatus, @LoadBalancingType);"
	
	
	foreach($gateway in $unpackedGateways) 
	{
        $sqlcmd = New-Object System.Data.SqlClient.SqlCommand
	    $sqlcmd.Connection = $sqlConn
	    $sqlcmd.CommandText = $insertCommand
        $sqlcmd.Parameters.AddWithValue("@GateWayId", $gateway.gatewayId + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayObjectId", $gateway.gatewayObjectId + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayName", $gateway.gatewayName + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayStatus", $gateway.gatewayStatus + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@IsAnchorGateway", $gateway.isAnchorGateway  ) | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayClusterStatus", $gateway.gatewayClusterStatus + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayPublicKey", $gateway.gatewayPublicKey + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayVersion", $gateway.gatewayVersion + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayVersionStatus", $gateway.gatewayVersionStatus + "") | Out-Null
        
        if(!$gateway.expiryDate) 
        {
            $sqlcmd.Parameters.AddWithValue("@ExpiryDate", [DBNull]::Value) | Out-Null
        }
        else 
        {
             $sqlcmd.Parameters.AddWithValue("@ExpiryDate", $gateway.expiryDate) | Out-Null
        }

        
        $sqlcmd.Parameters.AddWithValue("@GatewayContactInformation", $gateway.gatewayContactInformation + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayMachine", $gateway.gatewayMachine + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@ObjectId", $gateway.objectId + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@Name", $gateway.name + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@Description", $gateway.description + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@Permission", $gateway.permission + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@VersionStatus", $gateway.versionStatus + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@LoadBalancingType", $gateway.loadBalancingType + "") | Out-Null
		   
		$sqlcmd.ExecuteNonQuery() | Out-Null
	}
	
} catch { 
	Write-Host "SQL Failure writing PBI_GatewayClusters"
	Write-Host $_
    $sqlConn.Close()
}
 
Write-Host "Finished writing" $unpackedGateways.Count "records to AERA.dbo.PBI_GatewayClusters"

$sqlConn.Close()

# Get the list of gateways within each cluster and save to .csv
Write-Host "Write gateways for each cluster"
$allClusterGateways = @()

foreach($cluster in $allGatewayClusters)
{
    # 
    $gateways = Get-OnPremisesDataClusterGateways -ClusterObjectId $cluster.objectId
    # 
	$gateways | ForEach-Object{
		$_ | Add-Member -MemberType NoteProperty -Name "clusterObjectId" -Value $cluster.objectId
    }
    # 
	$gateways | ForEach-Object{
		$_ | Add-Member -MemberType NoteProperty -Name "clusterName" -Value $cluster.name
    }
    # 
	$allClusterGateways = $allClusterGateways + $gateways
}
	
try
{	
    $sqlConn = New-Object System.Data.SqlClient.SqlConnection
    $sqlConn.ConnectionString = $sqlConnectionString
    $sqlConn.Open()
	
    $emptyClusterGatewaysQuery = "DELETE FROM AERA.dbo.PBI_ClusterGateways"
	
    $sqlcmd = New-Object System.Data.SqlClient.SqlCommand
    $sqlcmd.Connection = $sqlConn
    $sqlcmd.CommandText = $emptyClusterGatewaysQuery
    $sqlcmd.ExecuteNonQuery() 
	
    Write-Host "Removed prior data from PBI_ClusterGateways"
	
    $insertCommand = "INSERT INTO AERA.dbo.PBI_ClusterGateways (GateWayId, GatewayObjectId, GatewayName, IsAnchorGateway, GatewayStatus, GatewayVersion, GatewayUpgradeState, GatewayClusterStatus, GatewayMachine, ClusterObjectId, ClusterName) Values (@GateWayId, @GatewayObjectId, @GatewayName, @IsAnchorGateway, @GatewayStatus, @GatewayVersion, @GatewayUpgradeState, @GatewayClusterStatus, @GatewayMachine, @ClusterObjectId, @ClusterName);"

	foreach($gateway in $allClusterGateways) 
	{
        $sqlcmd = New-Object System.Data.SqlClient.SqlCommand
	    $sqlcmd.Connection = $sqlConn
	    $sqlcmd.CommandText = $insertCommand

        $sqlcmd.Parameters.AddWithValue("@GateWayId", $gateway.gatewayId + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayObjectId", $gateway.gatewayObjectId + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayName", $gateway.gatewayName + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@IsAnchorGateway", $gateway.isAnchorGateway  ) | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayStatus", $gateway.gatewayStatus + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayVersion", $gateway.gatewayVersion + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayUpgradeState", $gateway.gatewayUpgradeState + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayClusterStatus", $gateway.gatewayClusterStatus + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@GatewayMachine", $gateway.gatewayMachine + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@ClusterObjectId", $gateway.clusterObjectId + "") | Out-Null
        $sqlcmd.Parameters.AddWithValue("@ClusterName", $gateway.clusterName + "") | Out-Null
         
		   
		$sqlcmd.ExecuteNonQuery() | Out-Null
	}
	
} catch { 
	Write-Host "SQL Failure writing to PBI_ClusterGateways"
	Write-Host $_
    $sqlConn.Close()
}
 
Write-Host "Finished writing" $allClusterGateways.Count "records to AERA.dbo.PBI_ClusterGateways"

$sqlConn.Close() 
 
Write-Host "Complete"
Stop-Transcript
