# AZ104-Custom-RBAC-Roles.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: PowerShell script that inventories creates custom RBAC roles for Azure resources.
# Blog: https://johnnymeintel.com

# Connect to Azure and set subscription context
Connect-AzAccount
Set-AzContext -SubscriptionId "d4e2e78f-2a06-4c3b-88c3-0e71b39dfc10"

# Ensure resource group exists
$rgName = "AZ104-Practice-RG"
$rgLocation = "eastus"  # Change as needed
if (-not (Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $rgName -Location $rgLocation
    Write-Host "Created resource group: $rgName" -ForegroundColor Green
} else {
    Write-Host "Resource group $rgName already exists" -ForegroundColor Yellow
}

# Create Network Monitor role
Write-Host "Creating Network Monitor role..." -ForegroundColor Cyan
$networkMonitor = Get-AzRoleDefinition -Name "Reader"
$networkMonitor.Id = $null
$networkMonitor.Name = "Network Monitor"
$networkMonitor.Description = "Can monitor network resources but not modify them"
$networkMonitor.Actions.Clear()
$networkMonitor.Actions.Add("Microsoft.Network/*/read")
$networkMonitor.Actions.Add("Microsoft.Insights/alertRules/*")
$networkMonitor.Actions.Add("Microsoft.Resources/subscriptions/resourceGroups/read")
$networkMonitor.NotActions.Clear()
$networkMonitor.AssignableScopes.Clear()
$networkMonitor.AssignableScopes.Add("/subscriptions/d4e2e78f-2a06-4c3b-88c3-0e71b39dfc10/resourceGroups/$rgName")
New-AzRoleDefinition -Role $networkMonitor

# Create Storage Contributor role
Write-Host "Creating Storage Contributor role..." -ForegroundColor Cyan
$storageContributor = Get-AzRoleDefinition -Name "Reader"
$storageContributor.Id = $null
$storageContributor.Name = "Storage Contributor"
$storageContributor.Description = "Can manage storage accounts but not delete them"
$storageContributor.Actions.Clear()
$storageContributor.Actions.Add("Microsoft.Storage/storageAccounts/*")
$storageContributor.Actions.Add("Microsoft.Resources/subscriptions/resourceGroups/read")
$storageContributor.NotActions.Clear()
$storageContributor.NotActions.Add("Microsoft.Storage/storageAccounts/delete")
$storageContributor.AssignableScopes.Clear()
$storageContributor.AssignableScopes.Add("/subscriptions/d4e2e78f-2a06-4c3b-88c3-0e71b39dfc10/resourceGroups/$rgName")
New-AzRoleDefinition -Role $storageContributor

# Create DevSecOps Engineer role
Write-Host "Creating DevSecOps Engineer role..." -ForegroundColor Cyan
$devSecOps = Get-AzRoleDefinition -Name "Reader"
$devSecOps.Id = $null
$devSecOps.Name = "DevSecOps Engineer"
$devSecOps.Description = "Combined permissions for development and security operations"
$devSecOps.Actions.Clear()
$devSecOps.Actions.Add("Microsoft.Compute/*/read")
$devSecOps.Actions.Add("Microsoft.Network/*/read")
$devSecOps.Actions.Add("Microsoft.Storage/*/read")
$devSecOps.Actions.Add("Microsoft.Security/*")
$devSecOps.Actions.Add("Microsoft.Insights/alertRules/*")
$devSecOps.Actions.Add("Microsoft.Resources/subscriptions/resourceGroups/read")
$devSecOps.NotActions.Clear()
$devSecOps.AssignableScopes.Clear()
$devSecOps.AssignableScopes.Add("/subscriptions/d4e2e78f-2a06-4c3b-88c3-0e71b39dfc10/resourceGroups/$rgName")
New-AzRoleDefinition -Role $devSecOps

Write-Host "All custom RBAC roles created successfully!" -ForegroundColor Green