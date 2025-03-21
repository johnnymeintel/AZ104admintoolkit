# AZ104-Simple-DR.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: Lightweight disaster recovery for Azure resources using PowerShell
# Blog: https://johnnymeintel.com

# Connect to Azure if not already connected
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Step 1: Prompt for Azure region
Write-Host "Available Azure Regions:" -ForegroundColor Cyan
$locations = @("eastus", "westus", "westus2", "centralus", "southcentralus", "northeurope", "westeurope")
for ($i = 0; $i -lt $locations.Count; $i++) {
    Write-Host "[$($i+1)] $($locations[$i])" -ForegroundColor Yellow
}
$locationIndex = Read-Host "Select a region (1-7) [Default is westus2]"

if ([string]::IsNullOrEmpty($locationIndex) -or -not ($locationIndex -match '^\d+$') -or [int]$locationIndex -lt 1 -or [int]$locationIndex -gt 7) {
    $location = "westus2"
    Write-Host "Using default region: $location" -ForegroundColor Yellow
} else {
    $location = $locations[[int]$locationIndex - 1]
    Write-Host "Selected region: $location" -ForegroundColor Green
}

# Step 2: Prompt for resource group
$resourceGroups = Get-AzResourceGroup | Sort-Object -Property ResourceGroupName
if ($resourceGroups -and $resourceGroups.Count -gt 0) {
    Write-Host "`nAvailable Resource Groups:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $resourceGroups.Count; $i++) {
        Write-Host "[$($i+1)] $($resourceGroups[$i].ResourceGroupName)" -ForegroundColor Yellow
    }
    Write-Host "[C] Create New Resource Group" -ForegroundColor Green
    
    $rgSelection = Read-Host "Select a resource group or C to create new"
    
    if ($rgSelection -eq "C") {
        $rgName = Read-Host "Enter new Resource Group name"
    } else {
        $rgIndex = [int]$rgSelection - 1
        if ($rgIndex -ge 0 -and $rgIndex -lt $resourceGroups.Count) {
            $rgName = $resourceGroups[$rgIndex].ResourceGroupName
            Write-Host "Selected Resource Group: $rgName" -ForegroundColor Green
        } else {
            Write-Host "Invalid selection. Please enter a new Resource Group name" -ForegroundColor Yellow
            $rgName = Read-Host "Enter new Resource Group name"
        }
    }
} else {
    Write-Host "No existing Resource Groups found." -ForegroundColor Yellow
    $rgName = Read-Host "Enter new Resource Group name"
}

# Step 3: Prompt for storage account name or generate one
Write-Host "`nStorage Account name must be globally unique, 3-24 characters, and only use lowercase letters and numbers." -ForegroundColor Cyan
$storageNameInput = Read-Host "Enter Storage Account name or press Enter to generate one"
if ([string]::IsNullOrEmpty($storageNameInput)) {
    $storageAccountName = "drdemo" + (Get-Random -Maximum 999999)
    Write-Host "Generated Storage Account name: $storageAccountName" -ForegroundColor Yellow
} else {
    if ($storageNameInput -match '^[a-z0-9]{3,24}$') {
        $storageAccountName = $storageNameInput
    } else {
        Write-Host "Invalid storage account name. Using generated name instead." -ForegroundColor Yellow
        $storageAccountName = "drdemo" + (Get-Random -Maximum 999999)
        Write-Host "Generated Storage Account name: $storageAccountName" -ForegroundColor Yellow
    }
}

# Step 4: Prompt for container name
$containerNameInput = Read-Host "Enter blob container name [Default is 'backups']"
if ([string]::IsNullOrEmpty($containerNameInput)) {
    $containerName = "backups"
    Write-Host "Using default container name: $containerName" -ForegroundColor Yellow
} else {
    $containerName = $containerNameInput
}

# Step 5: Prompt for Log Analytics workspace name
$workspaceNameInput = Read-Host "Enter Log Analytics workspace name [Default is 'DR-Workspace']"
if ([string]::IsNullOrEmpty($workspaceNameInput)) {
    $logAnalyticsWorkspaceName = "DR-Workspace"
    Write-Host "Using default workspace name: $logAnalyticsWorkspaceName" -ForegroundColor Yellow
} else {
    $logAnalyticsWorkspaceName = $workspaceNameInput
}

# Step 6: Create resource group if it does not exist
Write-Host "Checking resource group: $rgName..." -ForegroundColor Cyan
try {
    $rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Host "Creating resource group: $rgName in $location..." -ForegroundColor Yellow
        New-AzResourceGroup -Name $rgName -Location $location
        Write-Host "Resource group created successfully." -ForegroundColor Green
    } else {
        Write-Host "Resource group already exists." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error creating resource group: $_" -ForegroundColor Red
    exit
}

# Step 7: Create Storage Account for file backups
Write-Host "Creating storage account: $storageAccountName..." -ForegroundColor Cyan
try {
    $storageAccount = New-AzStorageAccount -ResourceGroupName $rgName `
        -Name $storageAccountName -Location $location -SkuName Standard_LRS `
        -Kind StorageV2 -AccessTier Hot -EnableHttpsTrafficOnly $true
    Write-Host "Storage account created successfully." -ForegroundColor Green
} catch {
    Write-Host "Error creating storage account: $_" -ForegroundColor Red
    exit
}

# Step 8: Create blob container for backups
Write-Host "Creating blob container: $containerName..." -ForegroundColor Cyan
try {
    $ctx = $storageAccount.Context
    New-AzStorageContainer -Name $containerName -Context $ctx -Permission Off
    Write-Host "Blob container created successfully." -ForegroundColor Green
} catch {
    Write-Host "Error creating blob container: $_" -ForegroundColor Red
    exit
}

# Step 9: Create Log Analytics workspace for monitoring
Write-Host "Creating Log Analytics workspace: $logAnalyticsWorkspaceName..." -ForegroundColor Cyan
try {
    New-AzOperationalInsightsWorkspace -ResourceGroupName $rgName `
        -Name $logAnalyticsWorkspaceName -Location $location -Sku "PerGB2018"
    Write-Host "Log Analytics workspace created successfully." -ForegroundColor Green
} catch {
    Write-Host "Error creating Log Analytics workspace: $_" -ForegroundColor Red
    # Continue even if this fails - not critical
}

# Step 10: Prompt for a sample file to backup
$sampleFileNameInput = Read-Host "Enter a name for the sample configuration file [Default is 'critical-config.json']"
if ([string]::IsNullOrEmpty($sampleFileNameInput)) {
    $sampleFileName = "critical-config.json"
    Write-Host "Using default file name: $sampleFileName" -ForegroundColor Yellow
} else {
    $sampleFileName = $sampleFileNameInput
    # Add .json extension if not provided
    if (-not $sampleFileName.EndsWith('.json')) {
        $sampleFileName = "$sampleFileName.json"
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
"@
$sampleFileContent | Out-File -FilePath $sampleFileName
Write-Host "Created sample configuration file: $sampleFileName" -ForegroundColor Green

# Step 11: Upload sample file to Azure Storage (simulate backup)
Write-Host "Uploading file to Azure Storage..." -ForegroundColor Cyan
try {
    Set-AzStorageBlobContent -File $sampleFileName -Container $containerName `
        -Blob $sampleFileName -Context $ctx -Force
    Write-Host "File uploaded successfully." -ForegroundColor Green
} catch {
    Write-Host "Error uploading file: $_" -ForegroundColor Red
    exit
}

# Step 12: Create a simple recovery script for the backed-up file
$recoveryScriptNameInput = Read-Host "Enter a name for the recovery script [Default is 'Recover-Configuration.ps1']"
if ([string]::IsNullOrEmpty($recoveryScriptNameInput)) {
    $recoveryScriptName = "Recover-Configuration.ps1"
    Write-Host "Using default script name: $recoveryScriptName" -ForegroundColor Yellow
} else {
    $recoveryScriptName = $recoveryScriptNameInput
    # Add .ps1 extension if not provided
    if (-not $recoveryScriptName.EndsWith('.ps1')) {
        $recoveryScriptName = "$recoveryScriptName.ps1"
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
"@
$recoveryScriptContent | Out-File -FilePath $recoveryScriptName
Write-Host "Created recovery script: $recoveryScriptName" -ForegroundColor Green

# Step 13: Set up a basic monitoring note (simplified for compatibility)
Write-Host "Setting up basic monitoring documentation..." -ForegroundColor Cyan

# Prompt for email address for notifications (for documentation purposes)
$emailAddress = Read-Host "Enter email address for alert notifications [Default is admin@example.com]"
if ([string]::IsNullOrEmpty($emailAddress)) {
    $emailAddress = "admin@example.com"
    Write-Host "Using default email: $emailAddress" -ForegroundColor Yellow
}

# Create monitoring documentation instead of actual setup
$monitoringDocPath = "MonitoringSetup.md"
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

"@

$monitoringDoc | Out-File -FilePath $monitoringDocPath
Write-Host "Created monitoring setup documentation: $monitoringDocPath" -ForegroundColor Green
Write-Host "Note: Azure PowerShell modules for creating actual alerts may vary by version." -ForegroundColor Yellow

# Step 14: Create a disaster recovery runbook document
# Prompt for runbook filename
$runbookNameInput = Read-Host "Enter a name for the DR runbook [Default is 'DR-Runbook.md']"
if ([string]::IsNullOrEmpty($runbookNameInput)) {
    $runbookName = "DR-Runbook.md"
    Write-Host "Using default runbook name: $runbookName" -ForegroundColor Yellow
} else {
    $runbookName = $runbookNameInput
    # Add .md extension if not provided
    if (-not $runbookName.EndsWith('.md')) {
        $runbookName = "$runbookName.md"
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
"@
$runbookContent | Out-File -FilePath $runbookName
Write-Host "Created disaster recovery runbook: $runbookName" -ForegroundColor Green

# Step 15: Ask if user wants to simulate a disaster recovery test
$runTest = Read-Host "Would you like to simulate a disaster recovery test? (Y/N) [Default is Y]"
if ([string]::IsNullOrEmpty($runTest) -or $runTest.ToUpper() -eq "Y") {
    Write-Host "`nSimulating disaster recovery test..." -ForegroundColor Cyan
    Write-Host "1. Simulating deletion of local file..." -ForegroundColor Yellow
    Remove-Item -Path $sampleFileName -Force
    Write-Host "2. Executing recovery procedure..." -ForegroundColor Yellow
    . .\$recoveryScriptName
    Write-Host "Disaster recovery test completed." -ForegroundColor Green
} else {
    Write-Host "Skipping disaster recovery test." -ForegroundColor Yellow
}

# Step 16: Summary and cleanup instructions
Write-Host "`n=== Disaster Recovery Solution Summary ===" -ForegroundColor Green
Write-Host "Resource Group: $rgName" -ForegroundColor Yellow
Write-Host "Storage Account: $storageAccountName" -ForegroundColor Yellow
Write-Host "Backup Container: $containerName" -ForegroundColor Yellow
Write-Host "Sample File Backed Up: $sampleFileName" -ForegroundColor Yellow
Write-Host "Recovery Script: $recoveryScriptName" -ForegroundColor Yellow
Write-Host "DR Runbook: $runbookName" -ForegroundColor Yellow
Write-Host "`nFor your AZ-104 exam preparation, focus on these key concepts:" -ForegroundColor Cyan
Write-Host "1. Storage redundancy options (LRS, ZRS, GRS, etc.)" -ForegroundColor Cyan
Write-Host "2. Azure Backup vs. manual backup strategies" -ForegroundColor Cyan
Write-Host "3. Recovery options and procedures" -ForegroundColor Cyan
Write-Host "4. Monitoring and alerting for Azure resources" -ForegroundColor Cyan
Write-Host "`nTo clean up resources when done:" -ForegroundColor Red
Write-Host "Remove-AzResourceGroup -Name $rgName -Force" -ForegroundColor Red

# Ask if user wants to clean up resources now
$cleanup = Read-Host "Would you like to clean up the created resources now? (Y/N) [Default is N]"
if (-not [string]::IsNullOrEmpty($cleanup) -and $cleanup.ToUpper() -eq "Y") {
    Write-Host "Cleaning up resource group $rgName..." -ForegroundColor Yellow
    Remove-AzResourceGroup -Name $rgName -Force
    Write-Host "Resources cleaned up successfully." -ForegroundColor Green
} else {
    Write-Host "Resources were not cleaned up. Remember to remove them when no longer needed." -ForegroundColor Yellow
}