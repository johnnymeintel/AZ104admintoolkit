# Azure Container Management PowerShell script
# For AZ-104 exam preparation

# Connect to Azure (uncomment if not already authenticated)
# Connect-AzAccount

# Variables - modify these as needed
$resourceGroupName = "az104-containers-rg"
$location = "eastus"
$containerName = "mycontainer"
$dnsNameLabel = "az104container$((Get-Random -Maximum 99999))"
$imageName = "mcr.microsoft.com/azuredocs/aci-helloworld"

# Create resource group if it doesn't exist
if (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $resourceGroupName -Location $location
    Write-Output "Resource group '$resourceGroupName' created."
}

# Create container instance
Write-Output "Creating container instance '$containerName'..."
$container = New-AzContainerGroup `
    -ResourceGroupName $resourceGroupName `
    -Name $containerName `
    -Image $imageName `
    -DnsNameLabel $dnsNameLabel `
    -OsType Linux `
    -IpAddressType Public `
    -Port 80 `
    -Cpu 1 `
    -MemoryInGB 1

# Get container details
Write-Output "Container created. Details:"
Write-Output "FQDN: $($container.Fqdn)"
Write-Output "IP Address: $($container.IpAddress)"
Write-Output "Status: $($container.ProvisioningState)"

# List all containers in resource group
Write-Output "`nAll containers in resource group '$resourceGroupName':"
Get-AzContainerGroup -ResourceGroupName $resourceGroupName | Format-Table Name, Status, IPAddress, Fqdn

# Get container logs
Write-Output "`nRetrieving logs for container '$containerName':"
Get-AzContainerInstanceLog -ResourceGroupName $resourceGroupName -ContainerGroupName $containerName

# Get container metrics (CPU/Memory usage)
Write-Output "`nRetrieving metrics for container '$containerName':"
$metrics = Get-AzMetric -ResourceId $container.Id -MetricName "CpuUsage","MemoryUsage" -DetailedOutput
$metrics | Format-Table Name, Unit, Average, Maximum

# Optional - Create container with environment variables and volume mount
function Create-ContainerWithVolume {
    # Create Azure file share for persistent storage
    $storageAccountName = "contstore$((Get-Random -Maximum 999999))"
    $fileShareName = "containershare"
    
    Write-Output "Creating storage account and file share for volume mounting..."
    $storageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroupName `
        -Name $storageAccountName -Location $location -SkuName Standard_LRS
    
    $storageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName `
        -Name $storageAccountName)[0].Value
    
    $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName `
        -StorageAccountKey $storageKey
    
    New-AzStorageShare -Name $fileShareName -Context $storageContext
    
    # Create container with volume mount
    $envVars = @{"WEBSITE_SITE_NAME"="MyContainer"; "ENV_TYPE"="Development"}
    
    $volumeConfig = @{
        ShareName = $fileShareName
        MountPath = "/data"
        StorageAccountName = $storageAccountName
        StorageAccountKey = $storageKey
    }
    
    $advancedContainer = New-AzContainerGroup `
        -ResourceGroupName $resourceGroupName `
        -Name "advanced-container" `
        -Image $imageName `
        -DnsNameLabel "advanced$((Get-Random -Maximum 99999))" `
        -OsType Linux `
        -IpAddressType Public `
        -Port 80 `
        -Cpu 1 `
        -MemoryInGB 1 `
        -EnvironmentVariable $envVars `
        -AzureFileVolumeShareName $volumeConfig.ShareName `
        -AzureFileVolumeAccountName $volumeConfig.StorageAccountName `
        -AzureFileVolumeAccountKey $volumeConfig.StorageAccountKey `
        -AzureFileVolumeMountPath $volumeConfig.MountPath
    
    Write-Output "Advanced container created with volume mount and environment variables."
    Write-Output "FQDN: $($advancedContainer.Fqdn)"
}

# Function to restart a container
function Restart-AzureContainer {
    param($resourceGroupName, $containerName)
    
    Write-Output "Restarting container '$containerName'..."
    Restart-AzContainerGroup -ResourceGroupName $resourceGroupName -Name $containerName
    Write-Output "Container restarted."
}

# Function to clean up resources
function Remove-ContainerResources {
    param($resourceGroupName)
    
    Write-Output "Cleaning up resources..."
    Remove-AzResourceGroup -Name $resourceGroupName -Force
    Write-Output "Resources deleted."
}

# Uncomment the following lines to use additional functions
# Create-ContainerWithVolume
# Restart-AzureContainer -resourceGroupName $resourceGroupName -containerName $containerName
# Remove-ContainerResources -resourceGroupName $resourceGroupName

Write-Output "`nScript completed. Container is running at http://$($container.Fqdn)"