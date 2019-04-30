CREATE TABLE dbo.PBI_GatewayClusters (
	GateWayId varchar(150), 
	GatewayObjectId varchar(150),
	GatewayName varchar(255), 
	GatewayStatus varchar(150),
	IsAnchorGateway bit, 
	GatewayClusterStatus varchar(150), 
	GatewayPublicKey text, 
	GatewayVersion varchar(150), 
	GatewayVersionStatus varchar(150),
	ExpiryDate date null, 
	GatewayContactInformation varchar(255), 
	GatewayMachine varchar(150), 
	ObjectId varchar(255), 
	Name varchar(255), 
	Description text, 
	Permission text, 
	VersionStatus varchar(255), 
	LoadBalancingType varchar(255)

)


INSERT INTO AERA.dbo.PBI_GatewayClusters (GateWayId, GatewayObjectId, GatewayName, GatewayStatus, IsAnchorGateway, GatewayClusterStatus, GatewayPublicKey, GatewayVersion, GatewayVersionStatus, ExpiryDate, GatewayContactInformation, GatewayMachine, ObjectId, Name, Description, Permission, VersionStatus, LoadBalancingType) VALUES (@GateWayId, @GatewayObjectId, @GatewayName, @GatewayStatus, @IsAnchorGateway, @GatewayClusterStatus, @GatewayPublicKey, @GatewayVersion, @GatewayVersionStatus, @ExpiryDate, @GatewayContactInformation, @GatewayMachine, @ObjectId, @Name, @Description, @Permission, @VersionStatus, @LoadBalancingType);
 
 
 CREATE TABLE dbo.PBI_ClusterGateways (
	GateWayId varchar(150), 
	GatewayObjectId varchar(150),
	GatewayName varchar(255), 
	IsAnchorGateway bit, 
	GatewayStatus varchar(150),
	GatewayVersion varchar(150), 
	GatewayUpgradeState varchar(255), 
	GatewayClusterStatus varchar(150), 
	GatewayMachine varchar(255), 
	ClusterObjectId varchar(255), 
	ClusterName varchar(255) 
 )
 
 INSERT INTO AERA.dbo.PBI_ClusterGateways (GateWayId, GatewayObjectId, GatewayName, IsAnchorGateway, GatewayStatus, GatewayVersion, GatewayUpgradeState, GatewayClusterStatus, GatewayMachine, ClusterObjectId, ClusterName) Values (@GateWayId, @GatewayObjectId, @GatewayName, @IsAnchorGateway, @GatewayStatus, @GatewayVersion, @GatewayUpgradeState, @GatewayClusterStatus, @GatewayMachine, @ClusterObjectId, @ClusterName)