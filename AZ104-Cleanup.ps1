# AZ104-Cleanup.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: Safely removes Azure resources and users from a subscription with exception handling, confirmation prompts, and detailed logging.
# Resume: https://johnnymeintel.com

# Check if already connected to Azure, if not, prompt for login
if (-not (Get-AzContext)) {
    # The Connect-AzAccount cmdlet opens a login prompt for Azure
    Connect-AzAccount
}

# Create a timestamp in format like "20250315-123045" for unique log filenames
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
# Define the log file name using the timestamp to make it unique
$logFile = "Azure-Cleanup-Log-$timestamp.txt"

# Define a function to handle logging with different severity levels
function Write-Log {
    # Define the parameters this function accepts
    param (
        # The message to log
        [string]$Message,
        # The level/severity of the message, defaulting to "INFO"
        [string]$Level = "INFO"
    )
    
    # Get current time for the log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Format the log message with timestamp and level
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Use different colors in console based on the message level
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }      # Blue for general information
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }  # Yellow for warnings
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }       # Red for errors
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }   # Green for successful operations
    }
    
    # Save the message to the log file
    Add-Content -Path $logFile -Value $logMessage
}

# Log the script starting
Write-Log "Azure Environment Cleanup Script - Starting" -Level "INFO"
# Add a warning about the script's destructive nature
Write-Log "CAUTION: This script will delete resources. Actions will be logged to: $logFile" -Level "WARNING"

# Get information about the current Azure connection
$currentContext = Get-AzContext
# Store the current user's ID to avoid deleting it later
$currentUser = $currentContext.Account.Id
# Store the current subscription name for logging
$currentSubscriptionName = $currentContext.Subscription.Name

# Log the current user and subscription that will be preserved
Write-Log "Current user ($currentUser) and subscription ($currentSubscriptionName) will be preserved" -Level "INFO"

# Add blank line for readability
Write-Host "`n" -NoNewline
# Display a warning banner about destructive operations
Write-Host "===== CAUTION: DESTRUCTIVE OPERATION =====" -ForegroundColor Red
Write-Host "This script will DELETE resources from your Azure environment!" -ForegroundColor Red
Write-Host "The following will be removed:" -ForegroundColor Red
Write-Host " - All Resource Groups (except those you specify to preserve)" -ForegroundColor Red
Write-Host " - All Users (except the current user: $currentUser)" -ForegroundColor Red
Write-Host "`nThis operation cannot be undone!" -ForegroundColor Red
Write-Host "=====================================" -ForegroundColor Red
# Add another blank line
Write-Host "`n" -NoNewline

# Ask for explicit confirmation before proceeding
$confirmation = Read-Host "Type 'YES' to confirm you want to proceed"
# Exit the script if the user doesn't type YES exactly
if ($confirmation -ne "YES") {
    Write-Log "Operation canceled by user" -Level "WARNING"
    exit
}

# Ask if the user wants to preserve any resource groups
Write-Host "`nWould you like to preserve any specific resource groups? (y/n)" -ForegroundColor Yellow
# Get the user's response (y/n)
$preserveRGs = Read-Host
# Create an empty array to hold preserved resource group names
$rgToPreserve = @()

# If user answered yes, collect resource group names to preserve
if ($preserveRGs -eq "y") {
    Write-Host "Enter the names of resource groups to preserve, one per line." -ForegroundColor Yellow
    Write-Host "Press Enter on an empty line when done." -ForegroundColor Yellow
    
    # Loop until the user enters an empty line
    while ($true) {
        # Get the resource group name from user input
        $rgName = Read-Host
        # Check if user pressed Enter without typing anything
        if ([string]::IsNullOrWhiteSpace($rgName)) {
            # Exit the loop if the line is empty
            break
        }
        # Add the resource group name to the preservation list
        $rgToPreserve += $rgName
        # Log which resource group will be preserved
        Write-Log "Resource Group to preserve: $rgName" -Level "INFO"
    }
}

# Section 1: Delete Resource Groups
Write-Log "Beginning Resource Group cleanup..." -Level "INFO"
# Get all resource groups in the subscription
$allResourceGroups = Get-AzResourceGroup

# Filter the list to exclude resource groups that should be preserved
$resourceGroupsToDelete = $allResourceGroups | Where-Object { $rgToPreserve -notcontains $_.ResourceGroupName }

# Log how many resource groups will be deleted
Write-Log "Found $($resourceGroupsToDelete.Count) resource group(s) to remove" -Level "INFO"

# Process each resource group to delete
foreach ($rg in $resourceGroupsToDelete) {
    # Log which resource group is being removed
    Write-Log "Removing Resource Group: $($rg.ResourceGroupName)" -Level "INFO"
    
    # Try to remove the resource group, with error handling
    try {
        # -Force removes without confirmation, -AsJob runs in background
        Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force -AsJob | Out-Null
        # Log that the deletion job was started
        Write-Log "Resource Group deletion initiated: $($rg.ResourceGroupName)" -Level "INFO"
    }
    catch {
        # Log any errors that occur
        Write-Log "Error removing Resource Group $($rg.ResourceGroupName): $_" -Level "ERROR"
    }
}

# Set the maximum number of concurrent jobs to avoid overloading Azure
$maxConcurrentJobs = 5
# Wait if there are too many running jobs
while ((Get-Job -State Running).Count -ge $maxConcurrentJobs) {
    # Pause for 2 seconds before checking again
    Start-Sleep -Seconds 2
}

# Log that all deletion jobs have been submitted
Write-Log "All Resource Group deletion jobs submitted. Waiting for completion..." -Level "INFO"

# Wait for all background jobs to complete
Get-Job | Wait-Job | Out-Null
# Clean up completed jobs
Get-Job | Remove-Job -Force

# Log completion of resource group cleanup
Write-Log "Resource Group cleanup completed" -Level "SUCCESS"

# Section 2: Delete Azure AD Users
Write-Log "Beginning Azure AD user cleanup..." -Level "INFO"

# Use error handling for the user cleanup section
try {
    # Get all users (limiting to 1000 for performance)
    $allUsers = Get-AzADUser -First 1000
    
    # Extract the email from the current user ID for comparison
    $currentUserEmail = ""
    # Use regex to find an email pattern in the current user ID
    if ($currentUser -match "([^@]+@[^@]+\.[^@]+)") {
        # Store the matched email address
        $currentUserEmail = $matches[1]
    }
    
    # Log the identified email
    Write-Log "Current user email identified as: $currentUserEmail" -Level "INFO"
    
    # Filter users to determine which ones should be deleted
    $usersToDelete = $allUsers | Where-Object { 
        # Skip if it's exactly the current user
        if ($_.UserPrincipalName -eq $currentUser) {
            return $false
        }
        
        # Skip if it's an external representation of the current user (contains the email with _)
        if ($currentUserEmail -and 
            ($_.UserPrincipalName -like "*$($currentUserEmail.Replace('@', '_'))*" -or
             $_.UserPrincipalName -like "*$currentUserEmail*")) {
            return $false 
        }
        
        # Skip admin accounts for safety
        if ($_.UserPrincipalName -like "*admin*") {
            return $false
        }
        
        # Skip if explicitly preserving guest accounts
        if ($_.UserType -eq "Guest" -and $preserveGuests) {
            return $false
        }
        
        # For all other users, include them in deletion list
        return $true
    }
    
    # Log how many users will be deleted
    Write-Log "Found $($usersToDelete.Count) user(s) to remove" -Level "INFO"
    
    # If there are users to delete, ask for confirmation
    if ($usersToDelete.Count -gt 0) {
        # Show a list of users that will be deleted
        Write-Host "`nThe following users will be deleted:" -ForegroundColor Yellow
        
        # Number each user in the list
        $i = 1
        foreach ($user in $usersToDelete) {
            # Display user name and ID
            Write-Host "$i. $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor White
            # Increment the counter
            $i++
        }
        
        # Ask for confirmation to delete these users
        Write-Host "`nWould you like to proceed with deleting these users? (y/n)" -ForegroundColor Yellow
        $confirmUsers = Read-Host
        
        # If confirmed, proceed with deletion
        if ($confirmUsers -eq "y") {
            # Process each user
            foreach ($user in $usersToDelete) {
                try {
                    # Log which user is being removed
                    Write-Log "Removing user: $($user.DisplayName) ($($user.UserPrincipalName))" -Level "INFO"
                    
                    # First remove role assignments to avoid orphaned permissions
                    try {
                        # Get all role assignments for this user
                        $userRoleAssignments = Get-AzRoleAssignment -ObjectId $user.Id
                        
                        # Remove each role assignment
                        foreach ($assignment in $userRoleAssignments) {
                            Remove-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $assignment.RoleDefinitionName -Scope $assignment.Scope
                            # Log the removed role
                            Write-Log "  Removed role assignment: $($assignment.RoleDefinitionName) on $($assignment.Scope)" -Level "INFO"
                        }
                    }
                    catch {
                        # Log any errors with role removal
                        Write-Log "  Error removing role assignments: $_" -Level "WARNING"
                    }
                    
                    # After roles are removed, delete the user
                    Remove-AzADUser -ObjectId $user.Id
                    # Log successful user removal
                    Write-Log "  User removed successfully" -Level "SUCCESS"
                }
                catch {
                    # Log any errors with user removal
                    Write-Log "  Error removing user: $_" -Level "ERROR"
                }
            }
        }
        else {
            # Log if user cleanup was skipped
            Write-Log "User cleanup skipped by user choice" -Level "WARNING"
        }
    }
    else {
        # Log if no users were found to delete
        Write-Log "No users found to delete" -Level "INFO"
    }
}
catch {
    # Log any errors in the overall user cleanup process
    Write-Log "Error during user cleanup: $_" -Level "ERROR"
}

# Section 3: Verify the results of the cleanup
Write-Log "Verifying cleanup results..." -Level "INFO"

# Check which resource groups remain
$remainingRGs = Get-AzResourceGroup
# Log the count of remaining resource groups
Write-Log "Remaining Resource Groups: $($remainingRGs.Count)" -Level "INFO"
# List each remaining resource group
foreach ($rg in $remainingRGs) {
    Write-Log "  • $($rg.ResourceGroupName)" -Level "INFO"
}

# Check which users remain
try {
    # Get remaining users (limit to 100 for performance)
    $remainingUsers = Get-AzADUser -First 100
    # Log the count of remaining users
    Write-Log "Remaining Users: $($remainingUsers.Count)" -Level "INFO"
    # List each remaining user
    foreach ($user in $remainingUsers) {
        Write-Log "  • $($user.DisplayName) ($($user.UserPrincipalName))" -Level "INFO"
    }
}
catch {
    # Log any errors checking remaining users
    Write-Log "Error checking remaining users: $_" -Level "ERROR"
}

# Log successful completion of the entire script
Write-Log "Azure Environment Cleanup completed" -Level "SUCCESS"
# Show where the log file is saved
Write-Host "`nCleanup log saved to: $logFile" -ForegroundColor Green