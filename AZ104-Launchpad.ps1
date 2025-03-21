# Azure-AdminLaunchpad.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: Setup and validate Azure administration environment for AZ-104 certification preparation
# Blog: https://johnnymeintel.com

#region MODULE VERIFICATION
# Check if the Azure PowerShell module is installed
# This is critical as all Azure automation depends on this module
if (!(Get-Module -ListAvailable Az)) {  # Checks if the Azure PowerShell module is NOT installed
    Write-Host "Azure PowerShell module not found. Installing Az module..." -ForegroundColor Yellow  # Displays a yellow warning message if module isn't found
    
    # Install the module for current user only - doesn't require admin rights
    # AllowClobber allows the cmdlet to overwrite existing commands
    Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force  # Installs the Azure module without admin rights, allows overwriting, and doesn't prompt for confirmation
    
    Write-Host "Az module installed successfully!" -ForegroundColor Green  # Shows green success message after installation
} else {  # Executes if the module IS already installed
    Write-Host "Az PowerShell module is already installed." -ForegroundColor Green  # Confirms module is already installed
    
    # Optionally check for updates to ensure you have the latest version
    $currentVersion = (Get-Module -ListAvailable Az).Version | Select-Object -First 1  # Gets the version of the installed Az module
    Write-Host "Current Az module version: $currentVersion" -ForegroundColor Cyan  # Displays the version number
}
#endregion

#region AUTHENTICATION
# Enhanced authentication with support for MFA and device code scenarios
try {  # Begins error handling block to catch any issues
    Write-Host "Attempting to connect to Azure..." -ForegroundColor Cyan  # Shows message about connection attempt
    
    # First, try to get current context (in case already authenticated)
    $context = Get-AzContext  # Checks if you're already connected to Azure
    
    # If not authenticated, try interactive authentication first
    if (!$context) {  # If not already connected (no context exists)
        try {  # Nested try block for first authentication method
            # Try standard interactive authentication
            Connect-AzAccount -ErrorAction Stop  # Attempts standard login, will stop on error
            $context = Get-AzContext  # Gets the context after connection
        } catch {  # What to do if standard authentication fails
            Write-Host "Standard authentication failed. This may be due to MFA requirements." -ForegroundColor Yellow  # Shows warning about MFA
            Write-Host "Attempting to connect using device code authentication..." -ForegroundColor Cyan  # Indicates trying alternate method
            
            # Try device code authentication as fallback
            Connect-AzAccount -DeviceCode -ErrorAction Stop  # Uses device code authentication method (useful for MFA scenarios)
            $context = Get-AzContext  # Gets the context after connection
        }
    } else {  # If you're already connected
        Write-Host "Already connected to Azure with existing context." -ForegroundColor Green  # Shows you're already authenticated
    }
    
    # Validate successful connection
    if ($context) {  # If we have a valid Azure context after all the connection attempts
        Write-Host "Successfully connected to Azure!" -ForegroundColor Green  # Shows successful connection
        Write-Host "Connected to subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Green  # Shows subscription details
        Write-Host "Connected as: $($context.Account.Id)" -ForegroundColor Green  # Shows the account you're logged in as
        Write-Host "Tenant ID: $($context.Tenant.Id)" -ForegroundColor Green  # Shows the Azure tenant ID
    } else {  # If we still don't have a valid context
        throw "Failed to get Azure context after connection attempts."  # Generates an error
    }
} catch {  # Catches any errors from the entire authentication process
    Write-Error "Failed to connect to Azure: $_"  # Shows the specific error that occurred
    Write-Host "Suggestion: Try connecting manually first with 'Connect-AzAccount -DeviceCode' before running this script." -ForegroundColor Yellow  # Gives troubleshooting advice
    exit 1  # Exits the script with an error code
}
#endregion

#region DEFAULT CONFIGURATION
# Set default Azure region/location for resources
# WestUS2 is commonly used for its service availability and pricing
Write-Host "Setting default Azure region to WestUS2..." -ForegroundColor Cyan  # Shows message about setting default region
# Set the default Azure location
$PSDefaultParameterValues['New-AzResourceGroup:Location'] = 'WestUS2'  # Sets default location for new resource groups
$PSDefaultParameterValues['New-AzResource:Location'] = 'WestUS2'  # Sets default location for new resources

# List all available subscriptions for reference
Write-Host "Available subscriptions:" -ForegroundColor Cyan  # Shows header for subscription list
Get-AzSubscription | Format-Table Name, Id, TenantId, State -AutoSize  # Lists all available subscriptions in table format

# Optional: Set a specific subscription if you have multiple
# Uncomment the following lines to use a specific subscription by name or ID
# $targetSubscription = "Your-Subscription-Name-or-ID"  # Define the subscription to use
# Select-AzSubscription -Subscription $targetSubscription  # Switch to that subscription
#endregion

#region RESOURCE GROUP CREATION
# Create a dedicated resource group for AZ-104 practice
# Using a consistent naming convention is an important best practice
# Isolating practice resources makes cleanup easier and prevents accidental deletion
try {  # Error handling for resource group creation
    $rgName = "AZ104-Practice-RG"  # Sets the resource group name
    $location = "WestUS2"  # Sets the location for the resource group
    
    # Check if the resource group already exists
    $existingRg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue  # Checks if the group exists without throwing an error
    
    if ($existingRg) {  # If the resource group already exists
        Write-Host "Resource group '$rgName' already exists." -ForegroundColor Yellow  # Shows warning that it exists
    } else {  # If the resource group doesn't exist
        Write-Host "Creating resource group '$rgName' in location '$location'..." -ForegroundColor Cyan  # Shows creating message
        New-AzResourceGroup -Name $rgName -Location $location -ErrorAction Stop  # Creates the resource group
        Write-Host "Resource group created successfully!" -ForegroundColor Green  # Shows success message
    }
} catch {  # Catches any errors in resource group creation
    Write-Error "Failed to create resource group: $_"  # Shows specific error message
}
#endregion

#region TAGGING STRATEGY
# Create a basic tagging structure for resources
# Tags are crucial for organization, cost management, and governance
$tags = @{  # Creates a hashtable (dictionary) of tags
    "Environment" = "Development"  # Indicates this is for development, not production
    "Project" = "AZ104-Certification"  # Purpose of these resources
    "Owner" = "Johnny Meintel"  # Who owns these resources
    "Department" = "IT"  # Department responsible
    "CostCenter" = "Personal"  # For billing/cost tracking
    "CreatedBy" = "AdminLaunchpadScript"  # How it was created
    "CreatedDate" = (Get-Date -Format "yyyy-MM-dd")  # When it was created (current date)
}

# Apply tags to the resource group
# Tags can be inherited by resources within the group but best practice is to set explicitly
try {  # Error handling for applying tags
    Write-Host "Applying tags to resource group '$rgName'..." -ForegroundColor Cyan  # Shows tagging message
    Set-AzResourceGroup -Name $rgName -Tag $tags -ErrorAction Stop  # Applies the tags to the resource group
    Write-Host "Tags applied successfully!" -ForegroundColor Green  # Shows success message
} catch {  # Catches any errors in tagging
    Write-Error "Failed to apply tags: $_"  # Shows specific error message
}
#endregion

#region VALIDATION AND OUTPUT
# Output environment details for verification
# This provides a summary of the configured environment
Write-Host "`n====== Azure Environment Setup Summary ======" -ForegroundColor Cyan  # Creates a header for the summary (with newline)
Write-Host "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"  # Shows subscription details
Write-Host "Tenant ID: $($context.Tenant.Id)"  # Shows tenant ID
Write-Host "User: $($context.Account.Id)"  # Shows user account
Write-Host "Default Location: $location"  # Shows default region
Write-Host "Practice Resource Group: $rgName"  # Shows resource group name

# List the tags that were applied
Write-Host "`nApplied Tags:" -ForegroundColor Cyan  # Shows header for tags (with newline)
$tags.GetEnumerator() | Format-Table Name, Value -AutoSize  # Lists all tags in table format

# Optional: Validate resource group creation by retrieving properties
$rgDetails = Get-AzResourceGroup -Name $rgName  # Gets the resource group details
Write-Host "`nResource Group Properties:" -ForegroundColor Cyan  # Shows header for properties (with newline)
$rgDetails | Format-List ResourceGroupName, Location, ProvisioningState, Tags  # Lists details in list format

Write-Host "`n====== Environment Setup Complete ======" -ForegroundColor Green  # Shows completion header (with newline)
Write-Host "Your Azure administrator environment is ready for AZ-104 practice!"  # Success message
Write-Host "Next steps: Deploy resources within your practice resource group."  # Guidance on what to do next
#endregion

#region CLEANUP INSTRUCTIONS
<#
# CLEANUP INSTRUCTIONS (DO NOT RUN AUTOMATICALLY)
# To clean up resources when you're finished, run:
# Remove-AzResourceGroup -Name "AZ104-Practice-RG" -Force
#>
#endregion