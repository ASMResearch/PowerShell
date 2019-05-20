<#
.Synopsis
	
.Description
	
#>
param(
    [string] $ResultsPath = "C:\Users\christopher.small\Accenture Federal Services\ADAP - PowerShell Results",
    [string] $ExecutionPolicy = "Unrestricted",
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
#region ExecutionPolicy Unrestricted check
# ==================================================================
# 
If ((Get-ExecutionPolicy) -ne $ExecutionPolicy) # check if ExecutionPolicy is set to Unrestricted
{
    Set-ExecutionPolicy -ExecutionPolicy $ExecutionPolicy -Force
}

#endregion

# ==================================================================
#region OnPremisesDataGatewayHAMgmt install check
# ==================================================================
# 
If (!(Get-Module -Name $OnPremisesDataGatewayHAMgmtName)) # check if OnPremisesDataGatewayHAMgmt imported
{
    # import OnPremisesDataGatewayHAMgmt
    Import-Module $OnPremisesDataGatewayHAMgmtPath
}

#endregion

# ==================================================================
#region Authenticate user - login to Power BI
# ==================================================================
# Login to Azure using EmailAddress
Login-OnPremisesDataGateway -EmailAddress christopher.small@asmr.com # Current backend is:  https://wabi-us-east2-redirect.analysis.windows.net/

#endregion

# ==================================================================
#region Get Gateway Clusters
# ==================================================================
# create empty array
$unpackedGateways = @()

# get all gateway clusters
$allGatewayClusters = Get-OnPremisesDataGatewayClusters

# go thru gateway clusters
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

#endregion

# ==================================================================
#region Get Gateway Clusters
# ==================================================================
# create empty array
$allClusterGateways = @()

# go thru gateway clusters
foreach($cluster in $allGatewayClusters)
{
    $gateways = Get-OnPremisesDataClusterGateways -ClusterObjectId $cluster.objectId
	$gateways | ForEach-Object{
		$_ | Add-Member -MemberType NoteProperty -Name "Cluster ObjectId" -Value $cluster.objectId
    }
	$gateways | ForEach-Object{
		$_ | Add-Member -MemberType NoteProperty -Name "Cluster Name" -Value $cluster.name
    }
	$allClusterGateways = $allClusterGateways + $gateways
}

#endregion

# ==================================================================
#region Export-Csv
# ==================================================================
# GatewayClusters
$unpackedGateways | Export-Csv -Path $ResultsPath\GatewayClusters.csv -Delimiter ";" -NoTypeInformation

# ClusterGateways
$allClusterGateways | Export-Csv -Path $ResultsPath\ClusterGateways.csv -Delimiter ";" -NoTypeInformation

#endregion