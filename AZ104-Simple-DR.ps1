# AZ104-Simple-DR.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: Lightweight disaster recovery for Azure resources using PowerShell
# Blog: https://johnnymeintel.com
# These lines provide basic information about the script: its name, author, creation date, purpose, and the author's blog URL

# Connect to Azure if not already connected
if (-not (Get-AzContext)) {  # Checks if you're already connected to Azure - if not connected, this returns false
    Connect-AzAccount  # Prompts you to log in to your Azure account if you're not already connected
}

# Step 1: Prompt for Azure region
Write-Host "Available Azure Regions:" -ForegroundColor Cyan  # Displays "Available Azure Regions:" in cyan color
$locations = @("eastus", "westus", "westus2", "centralus", "southcentralus", "northeurope", "westeurope")  # Creates an array of region names
for ($i = 0; $i -lt $locations.Count; $i++) {  # Loops through each region in the array
    Write-Host "[$($i+1)] $($locations[$i])" -ForegroundColor Yellow  # Displays each region with a number in yellow
}
$locationIndex = Read-Host "Select a region (1-7) [Default is westus2]"  # Asks you to type a number and stores your response

if ([string]::IsNullOrEmpty($locationIndex) -or -not ($locationIndex -match '^\d+$') -or [int]$locationIndex -lt 1 -or [int]$locationIndex -gt 7) {  # Checks if your input is valid
    $location = "westus2"  # Sets default region if your input was invalid or empty
    Write-Host "Using default region: $location" -ForegroundColor Yellow  # Shows which region will be used
} else {  # If your input was valid
    $location = $locations[[int]$locationIndex - 1]  # Gets the selected region from the array (subtracting 1 because arrays start at 0)
    Write-Host "Selected region: $location" -ForegroundColor Green  # Shows your selected region in green
}

# Step 2: Prompt for resource group
$resourceGroups = Get-AzResourceGroup | Sort-Object -Property ResourceGroupName  # Gets all your resource groups and sorts them by name
if ($resourceGroups -and $resourceGroups.Count -gt 0) {  # If you have any existing resource groups
    Write-Host "`nAvailable Resource Groups:" -ForegroundColor Cyan  # Shows header with newline character (\n)
    for ($i = 0; $i -lt $resourceGroups.Count; $i++) {  # Loops through each resource group
        Write-Host "[$($i+1)] $($resourceGroups[$i].ResourceGroupName)" -ForegroundColor Yellow  # Shows each group with a number
    }
    Write-Host "[C] Create New Resource Group" -ForegroundColor Green  # Shows option to create a new group
    
    $rgSelection = Read-Host "Select a resource group or C to create new"  # Asks for your choice
    
    if ($rgSelection -eq "C") {  # If you chose to create a new group
        $rgName = Read-Host "Enter new Resource Group name"  # Asks for the new group name
    } else {  # If you selected an existing group
        $rgIndex = [int]$rgSelection - 1  # Converts your selection to an array index
        if ($rgIndex -ge 0 -and $rgIndex -lt $resourceGroups.Count) {  # If your selection is valid
            $rgName = $resourceGroups[$rgIndex].ResourceGroupName  # Sets the resource group name
            Write-Host "Selected Resource Group: $rgName" -ForegroundColor Green  # Shows selected group
        } else {  # If your selection was invalid
            Write-Host "Invalid selection. Please enter a new Resource Group name" -ForegroundColor Yellow  # Shows error
            $rgName = Read-Host "Enter new Resource Group name"  # Asks for a new group name
        }
    }
} else {  # If you don't have any existing resource groups
    Write-Host "No existing Resource Groups found." -ForegroundColor Yellow  # Shows message
    $rgName = Read-Host "Enter new Resource Group name"  # Asks for a new group name
}

# Step 3: Prompt for storage account name or generate one
Write-Host "`nStorage Account name must be globally unique, 3-24 characters, and only use lowercase letters and numbers." -ForegroundColor Cyan  # Shows naming rules
$storageNameInput = Read-Host "Enter Storage Account name or press Enter to generate one"  # Asks for a storage account name
if ([string]::IsNullOrEmpty($storageNameInput)) {  # If you didn't enter a name
    $storageAccountName = "drdemo" + (Get-Random -Maximum 999999)  # Generates a random name with prefix "drdemo"
    Write-Host "Generated Storage Account name: $storageAccountName" -ForegroundColor Yellow  # Shows the generated name
} else {  # If you entered a name
    if ($storageNameInput -match '^[a-z0-9]{3,24}$') {  # Checks if your name follows the rules
        $storageAccountName = $storageNameInput  # Uses your name
    } else {  # If your name doesn't follow the rules
        Write-Host "Invalid storage account name. Using generated name instead." -ForegroundColor Yellow  # Shows error
        $storageAccountName = "drdemo" + (Get-Random -Maximum 999999)  # Generates a random name
        Write-Host "Generated Storage Account name: $storageAccountName" -ForegroundColor Yellow  # Shows the generated name
    }
}

# Step 4: Prompt for container name
$containerNameInput = Read-Host "Enter blob container name [Default is 'backups']"  # Asks for a container name
if ([string]::IsNullOrEmpty($containerNameInput)) {  # If you didn't enter a name
    $containerName = "backups"  # Uses default name
    Write-Host "Using default container name: $containerName" -ForegroundColor Yellow  # Shows default name
} else {  # If you entered a name
    $containerName = $containerNameInput  # Uses your name
}

# Step 5: Prompt for Log Analytics workspace name
$workspaceNameInput = Read-Host "Enter Log Analytics workspace name [Default is 'DR-Workspace']"  # Asks for workspace name
if ([string]::IsNullOrEmpty($workspaceNameInput)) {  # If you didn't enter a name
    $logAnalyticsWorkspaceName = "DR-Workspace"  # Uses default name
    Write-Host "Using default workspace name: $logAnalyticsWorkspaceName" -ForegroundColor Yellow  # Shows default name
} else {  # If you entered a name
    $logAnalyticsWorkspaceName = $workspaceNameInput  # Uses your name
}

# Step 6: Create resource group if it does not exist
Write-Host "Checking resource group: $rgName..." -ForegroundColor Cyan  # Shows progress message
try {  # Begin error handling block
    $rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue  # Checks if group exists without showing errors
    if (-not $rg) {  # If group doesn't exist
        Write-Host "Creating resource group: $rgName in $location..." -ForegroundColor Yellow  # Shows progress
        New-AzResourceGroup -Name $rgName -Location $location  # Creates the resource group
        Write-Host "Resource group created successfully." -ForegroundColor Green  # Shows success message
    } else {  # If group already exists
        Write-Host "Resource group already exists." -ForegroundColor Yellow  # Shows message
    }
} catch {  # What to do if an error occurs
    Write-Host "Error creating resource group: $_" -ForegroundColor Red  # Shows error in red
    exit  # Exits the script
}

# Step 7: Create Storage Account for file backups
Write-Host "Creating storage account: $storageAccountName..." -ForegroundColor Cyan  # Shows progress
try {  # Begin error handling block
    $storageAccount = New-AzStorageAccount -ResourceGroupName $rgName `
        -Name $storageAccountName -Location $location -SkuName Standard_LRS `
        -Kind StorageV2 -AccessTier Hot -EnableHttpsTrafficOnly $true  # Creates storage account with specified settings
    Write-Host "Storage account created successfully." -ForegroundColor Green  # Shows success
} catch {  # What to do if an error occurs
    Write-Host "Error creating storage account: $_" -ForegroundColor Red  # Shows error
    exit  # Exits the script
}

# Step 8: Create blob container for backups
Write-Host "Creating blob container: $containerName..." -ForegroundColor Cyan  # Shows progress
try {  # Begin error handling block
    $ctx = $storageAccount.Context  # Gets the storage account context (connection information)
    New-AzStorageContainer -Name $containerName -Context $ctx -Permission Off  # Creates container with no public access
    Write-Host "Blob container created successfully." -ForegroundColor Green  # Shows success
} catch {  # What to do if an error occurs
    Write-Host "Error creating blob container: $_" -ForegroundColor Red  # Shows error
    exit  # Exits the script
}

# Step 9: Create Log Analytics workspace for monitoring
Write-Host "Creating Log Analytics workspace: $logAnalyticsWorkspaceName..." -ForegroundColor Cyan  # Shows progress
try {  # Begin error handling block
    New-AzOperationalInsightsWorkspace -ResourceGroupName $rgName `
        -Name $logAnalyticsWorkspaceName -Location $location -Sku "PerGB2018"  # Creates workspace with pay-per-GB pricing
    Write-Host "Log Analytics workspace created successfully." -ForegroundColor Green  # Shows success
} catch {  # What to do if an error occurs
    Write-Host "Error creating Log Analytics workspace: $_" -ForegroundColor Red  # Shows error
    # Continue even if this fails - not critical
}

# Step 10: Prompt for a sample file to backup
$sampleFileNameInput = Read-Host "Enter a name for the sample configuration file [Default is 'critical-config.json']"  # Asks for filename
if ([string]::IsNullOrEmpty($sampleFileNameInput)) {  # If you didn't enter a name
    $sampleFileName = "critical-config.json"  # Uses default name
    Write-Host "Using default file name: $sampleFileName" -ForegroundColor Yellow  # Shows default name
} else {  # If you entered a name
    $sampleFileName = $sampleFileNameInput  # Uses your name
    # Add .json extension if not provided
    if (-not $sampleFileName.EndsWith('.json')) {  # If filename doesn't end with .json
        $sampleFileName = "$sampleFileName.json"  # Adds .json extension
    }
}

$sampleFileContent = @"
{
    "environment": "production",
    "lastUpdated": "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")",
    "configuration": {
        "databaseConnection": "Server=db.example.com;Database=prod;",
        "apiEndpoints": [
            "https://api1.example.com",
            "https://api2.example.com"
        ],
        "features": {
            "darkMode": true,
            "betaFeatures": false
        }
    }
}
"@  # Creates a multi-line string with sample JSON content including the current date/time
$sampleFileContent | Out-File -FilePath $sampleFileName  # Saves the content to a file
Write-Host "Created sample configuration file: $sampleFileName" -ForegroundColor Green  # Shows success

# Step 11: Upload sample file to Azure Storage (simulate backup)
Write-Host "Uploading file to Azure Storage..." -ForegroundColor Cyan  # Shows progress
try {  # Begin error handling block
    Set-AzStorageBlobContent -File $sampleFileName -Container $containerName `
        -Blob $sampleFileName -Context $ctx -Force  # Uploads file to blob storage, overwriting if it exists
    Write-Host "File uploaded successfully." -ForegroundColor Green  # Shows success
} catch {  # What to do if an error occurs
    Write-Host "Error uploading file: $_" -ForegroundColor Red  # Shows error
    exit  # Exits the script
}

# Step 12: Create a simple recovery script for the backed-up file
$recoveryScriptNameInput = Read-Host "Enter a name for the recovery script [Default is 'Recover-Configuration.ps1']"  # Asks for script name
if ([string]::IsNullOrEmpty($recoveryScriptNameInput)) {  # If you didn't enter a name
    $recoveryScriptName = "Recover-Configuration.ps1"  # Uses default name
    Write-Host "Using default script name: $recoveryScriptName" -ForegroundColor Yellow  # Shows default name
} else {  # If you entered a name
    $recoveryScriptName = $recoveryScriptNameInput  # Uses your name
    # Add .ps1 extension if not provided
    if (-not $recoveryScriptName.EndsWith('.ps1')) {  # If filename doesn't end with .ps1
        $recoveryScriptName = "$recoveryScriptName.ps1"  # Adds .ps1 extension
    }
}

$recoveryScriptContent = @"
# Recovery script for Azure resources
# Usage: .\Recover-Configuration.ps1 [FileName]

param (
    [Parameter(Mandatory=`$false)]
    [string]`$FileName = "$sampleFileName"
)

# Connect to Azure if not already connected
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Configuration variables
`$resourceGroupName = "$rgName"
`$storageAccountName = "$storageAccountName"
`$containerName = "$containerName"

# Get storage account context
`$storageAccount = Get-AzStorageAccount -ResourceGroupName `$resourceGroupName -Name `$storageAccountName
`$ctx = `$storageAccount.Context

# Download the backup file
Write-Host "Recovering `$FileName from Azure Storage..." -ForegroundColor Cyan
try {
    Get-AzStorageBlobContent -Container `$containerName -Blob `$FileName -Destination "./recovered-`$FileName" -Context `$ctx -Force
    Write-Host "File recovered successfully to: ./recovered-`$FileName" -ForegroundColor Green
    
    # Display file content
    Get-Content -Path "./recovered-`$FileName" | Write-Host
} catch {
    Write-Host "Error recovering file: `$_" -ForegroundColor Red
    exit
}

Write-Host "`nRecovery completed successfully!" -ForegroundColor Green
"@  # Creates a multi-line string with PowerShell script content to recover files
$recoveryScriptContent | Out-File -FilePath $recoveryScriptName  # Saves the script to a file
Write-Host "Created recovery script: $recoveryScriptName" -ForegroundColor Green  # Shows success

# Step 13: Set up a basic monitoring note (simplified for compatibility)
Write-Host "Setting up basic monitoring documentation..." -ForegroundColor Cyan  # Shows progress

# Prompt for email address for notifications (for documentation purposes)
$emailAddress = Read-Host "Enter email address for alert notifications [Default is admin@example.com]"  # Asks for email
if ([string]::IsNullOrEmpty($emailAddress)) {  # If you didn't enter an email
    $emailAddress = "admin@example.com"  # Uses default email
    Write-Host "Using default email: $emailAddress" -ForegroundColor Yellow  # Shows default email
}

# Create monitoring documentation instead of actual setup
$monitoringDocPath = "MonitoringSetup.md"  # Sets documentation filename
$monitoringDoc = @"
# Azure Monitoring Setup Instructions

## Overview
This document describes how to set up monitoring alerts for your disaster recovery solution.

## Email Notifications
Configure alert notifications to be sent to: $emailAddress

## Alert Setup Steps
1. In the Azure Portal, navigate to your storage account ($storageAccountName)
2. Select "Alerts" from the left menu
3. Click "Create alert rule"
4. Configure the condition for monitoring availability
5. Set up an action group for email notifications
6. Name and create the alert rule

## Monitoring Dashboard
Create a monitoring dashboard to track:
- Storage account availability
- Successful backup operations
- File recovery tests

## Testing Alerts
Periodically verify alert functionality by:
1. Temporarily changing access policies
2. Confirming alert notifications are received
3. Restoring original access settings

"@  # Creates a multi-line string with markdown documentation
$monitoringDoc | Out-File -FilePath $monitoringDocPath  # Saves the documentation to a file
Write-Host "Created monitoring setup documentation: $monitoringDocPath" -ForegroundColor Green  # Shows success
Write-Host "Note: Azure PowerShell modules for creating actual alerts may vary by version." -ForegroundColor Yellow  # Shows warning

# Step 14: Create a disaster recovery runbook document
# Prompt for runbook filename
$runbookNameInput = Read-Host "Enter a name for the DR runbook [Default is 'DR-Runbook.md']"  # Asks for runbook name
if ([string]::IsNullOrEmpty($runbookNameInput)) {  # If you didn't enter a name
    $runbookName = "DR-Runbook.md"  # Uses default name
    Write-Host "Using default runbook name: $runbookName" -ForegroundColor Yellow  # Shows default name
} else {  # If you entered a name
    $runbookName = $runbookNameInput  # Uses your name
    # Add .md extension if not provided
    if (-not $runbookName.EndsWith('.md')) {  # If filename doesn't end with .md
        $runbookName = "$runbookName.md"  # Adds .md extension
    }
}

$runbookContent = @"
# Disaster Recovery Runbook

## Resource Information
- Resource Group: $rgName
- Storage Account: $storageAccountName
- Backup Container: $containerName
- Region: $location

## Backed Up Resources
- Configuration files in blob storage

## Recovery Procedure
1. Run the recovery script: .\$recoveryScriptName
2. Verify the recovered file contents
3. Apply the configuration to the target system

## Testing Procedure
1. Run the recovery script with the desired file parameter
2. Verify the file is recovered correctly
3. Document test results and any issues encountered

## Contact Information
- Primary: [Your Name], [Your Contact Information]
- Secondary: [Backup Contact], [Their Contact Information]

## Last Updated
$(Get-Date -Format "yyyy-MM-dd")
"@  # Creates a multi-line string with markdown runbook content including current date
$runbookContent | Out-File -FilePath $runbookName  # Saves the runbook to a file
Write-Host "Created disaster recovery runbook: $runbookName" -ForegroundColor Green  # Shows success

# Step 15: Ask if user wants to simulate a disaster recovery test
$runTest = Read-Host "Would you like to simulate a disaster recovery test? (Y/N) [Default is Y]"  # Asks if you want to test
if ([string]::IsNullOrEmpty($runTest) -or $runTest.ToUpper() -eq "Y") {  # If you didn't answer or answered Y
    Write-Host "`nSimulating disaster recovery test..." -ForegroundColor Cyan  # Shows progress
    Write-Host "1. Simulating deletion of local file..." -ForegroundColor Yellow  # Shows step 1
    Remove-Item -Path $sampleFileName -Force  # Deletes the local file
    Write-Host "2. Executing recovery procedure..." -ForegroundColor Yellow  # Shows step 2
    . .\$recoveryScriptName  # Runs the recovery script (dot-sourcing it)
    Write-Host "Disaster recovery test completed." -ForegroundColor Green  # Shows completion
} else {  # If you answered N or something else
    Write-Host "Skipping disaster recovery test." -ForegroundColor Yellow  # Shows skip message
}

# Step 16: Summary and cleanup instructions
Write-Host "`n=== Disaster Recovery Solution Summary ===" -ForegroundColor Green  # Shows summary header
Write-Host "Resource Group: $rgName" -ForegroundColor Yellow  # Shows resource group
Write-Host "Storage Account: $storageAccountName" -ForegroundColor Yellow  # Shows storage account
Write-Host "Backup Container: $containerName" -ForegroundColor Yellow  # Shows container
Write-Host "Sample File Backed Up: $sampleFileName" -ForegroundColor Yellow  # Shows backed up file
Write-Host "Recovery Script: $recoveryScriptName" -ForegroundColor Yellow  # Shows recovery script
Write-Host "DR Runbook: $runbookName" -ForegroundColor Yellow  # Shows runbook name
Write-Host "`nFor your AZ-104 exam preparation, focus on these key concepts:" -ForegroundColor Cyan  # Shows exam tips
Write-Host "1. Storage redundancy options (LRS, ZRS, GRS, etc.)" -ForegroundColor Cyan  # Shows tip 1
Write-Host "2. Azure Backup vs. manual backup strategies" -ForegroundColor Cyan  # Shows tip 2
Write-Host "3. Recovery options and procedures" -ForegroundColor Cyan  # Shows tip 3
Write-Host "4. Monitoring and alerting for Azure resources" -ForegroundColor Cyan  # Shows tip 4
Write-Host "`nTo clean up resources when done:" -ForegroundColor Red  # Shows cleanup instructions
Write-Host "Remove-AzResourceGroup -Name $rgName -Force" -ForegroundColor Red  # Shows cleanup command

# Ask if user wants to clean up resources now
$cleanup = Read-Host "Would you like to clean up the created resources now? (Y/N) [Default is N]"  # Asks about cleanup
if (-not [string]::IsNullOrEmpty($cleanup) -and $cleanup.ToUpper() -eq "Y") {  # If you answered Y
    Write-Host "Cleaning up resource group $rgName..." -ForegroundColor Yellow  # Shows cleanup progress
    Remove-AzResourceGroup -Name $rgName -Force  # Deletes the resource group and all its resources
    Write-Host "Resources cleaned up successfully." -ForegroundColor Green  # Shows success
} else {  # If you didn't answer Y
    Write-Host "Resources were not cleaned up. Remember to remove them when no longer needed." -ForegroundColor Yellow  # Shows reminder
}