# AZ104-Custom-RBAC-Roles.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: PowerShell script that creates custom RBAC (Role-Based Access Control) roles for Azure resources.
# Blog: https://johnnymeintel.com

# Connects to your Azure account - this will open a browser window for you to sign in
Connect-AzAccount

# Sets which Azure subscription to use for the commands that follow
# The long string is the subscription ID - you should replace this with your own subscription ID
Set-AzContext -SubscriptionId "d4e2e78f-2a06-4c3b-88c3-0e71b39dfc10"

# Creates a variable to store the resource group name we'll be using
$rgName = "AZ104-Practice-RG"

# Creates a variable for the Azure datacenter location (East US in this case)
$rgLocation = "eastus"  # Change as needed

# Checks if the resource group already exists
# "-not" means "if the following is NOT true"
# ErrorAction SilentlyContinue means "don't show an error if the resource group isn't found"
if (-not (Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue)) {
    # If the resource group doesn't exist, create it with the specified name and location
    New-AzResourceGroup -Name $rgName -Location $rgLocation
    # Display a message in green text saying the resource group was created
    Write-Host "Created resource group: $rgName" -ForegroundColor Green
} else {
    # If the resource group already exists, display a yellow message
    Write-Host "Resource group $rgName already exists" -ForegroundColor Yellow
}

# Display a message that we're creating the Network Monitor role
Write-Host "Creating Network Monitor role..." -ForegroundColor Cyan

# Start by copying the built-in Reader role as a template
$networkMonitor = Get-AzRoleDefinition -Name "Reader"

# Clear the ID so Azure knows this is a new role, not an update to an existing one
$networkMonitor.Id = $null

# Set the name for our new custom role
$networkMonitor.Name = "Network Monitor"

# Add a description explaining what this role can do
$networkMonitor.Description = "Can monitor network resources but not modify them"

# Clear any permissions that came from the Reader role
$networkMonitor.Actions.Clear()

# Add specific permissions - in this case, read-only access to all network resources
# The asterisk (*) is a wildcard that means "all"
$networkMonitor.Actions.Add("Microsoft.Network/*/read")

# Add permission to work with alert rules (for monitoring)
$networkMonitor.Actions.Add("Microsoft.Insights/alertRules/*")

# Add permission to read resource groups (needed to understand the environment)
$networkMonitor.Actions.Add("Microsoft.Resources/subscriptions/resourceGroups/read")

# Clear any "NotActions" (permissions specifically denied) from the template
$networkMonitor.NotActions.Clear()

# Clear the scopes where this role can be assigned
$networkMonitor.AssignableScopes.Clear()

# Add the specific resource group where this role can be assigned
# This limits the role to only be usable within this resource group
$networkMonitor.AssignableScopes.Add("/subscriptions/d4e2e78f-2a06-4c3b-88c3-0e71b39dfc10/resourceGroups/$rgName")

# Create the new role in Azure using our definition
New-AzRoleDefinition -Role $networkMonitor

# Display a message that we're creating the Storage Contributor role
Write-Host "Creating Storage Contributor role..." -ForegroundColor Cyan

# Similar to above, start with the Reader role template
$storageContributor = Get-AzRoleDefinition -Name "Reader"
$storageContributor.Id = $null
$storageContributor.Name = "Storage Contributor"
$storageContributor.Description = "Can manage storage accounts but not delete them"

# Clear existing permissions
$storageContributor.Actions.Clear()

# Add permission to do everything with storage accounts
$storageContributor.Actions.Add("Microsoft.Storage/storageAccounts/*")

# Add permission to read resource groups
$storageContributor.Actions.Add("Microsoft.Resources/subscriptions/resourceGroups/read")

# Clear any "NotActions" from the template
$storageContributor.NotActions.Clear()

# Specifically deny the permission to delete storage accounts
# This is how we allow "all storage actions except deletion"
$storageContributor.NotActions.Add("Microsoft.Storage/storageAccounts/delete")

# Clear and set where this role can be assigned (just this resource group)
$storageContributor.AssignableScopes.Clear()
$storageContributor.AssignableScopes.Add("/subscriptions/d4e2e78f-2a06-4c3b-88c3-0e71b39dfc10/resourceGroups/$rgName")

# Create the new role in Azure
New-AzRoleDefinition -Role $storageContributor

# Display a message that we're creating the DevSecOps Engineer role
Write-Host "Creating DevSecOps Engineer role..." -ForegroundColor Cyan

# Again, start with the Reader role as a template
$devSecOps = Get-AzRoleDefinition -Name "Reader"
$devSecOps.Id = $null
$devSecOps.Name = "DevSecOps Engineer"
$devSecOps.Description = "Combined permissions for development and security operations"

# Clear existing permissions
$devSecOps.Actions.Clear()

# Add read-only access to compute resources (VMs, etc.)
$devSecOps.Actions.Add("Microsoft.Compute/*/read")

# Add read-only access to network resources
$devSecOps.Actions.Add("Microsoft.Network/*/read")

# Add read-only access to storage resources
$devSecOps.Actions.Add("Microsoft.Storage/*/read")

# Add full access to security features
$devSecOps.Actions.Add("Microsoft.Security/*")

# Add full access to alerts (for monitoring)
$devSecOps.Actions.Add("Microsoft.Insights/alertRules/*")

# Add permission to read resource groups
$devSecOps.Actions.Add("Microsoft.Resources/subscriptions/resourceGroups/read")

# Clear any "NotActions" from the template
$devSecOps.NotActions.Clear()

# Clear and set where this role can be assigned (just this resource group)
$devSecOps.AssignableScopes.Clear()
$devSecOps.AssignableScopes.Add("/subscriptions/d4e2e78f-2a06-4c3b-88c3-0e71b39dfc10/resourceGroups/$rgName")

# Create the new role in Azure
New-AzRoleDefinition -Role $devSecOps

# Show a success message in green when all roles have been created
Write-Host "All custom RBAC roles created successfully!" -ForegroundColor Green