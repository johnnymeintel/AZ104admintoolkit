# AZ104-Resource-Checker.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: A quick script to list all Azure subscriptions, resource groups, and users with enhanced formatting
# Blog: https://johnnymeintel.com
# These lines are comments that describe the script's name, author, creation date, purpose, and the author's blog

# Connect to Azure if not already connected
if (-not (Get-AzContext)) {  # Checks if you're already connected to Azure - if not connected, this returns false
    Connect-AzAccount  # Runs the command to connect to Azure with your credentials
}

# Create a timestamp for the output file
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"  # Creates a timestamp in format YYYYMMDD-HHMMSS (e.g., 20250315-142530)
$outputFile = "Azure-Inventory-$timestamp.txt"  # Creates a filename with the timestamp to store results

# Output separator function with enhanced formatting (no background)
function Write-Separator {  # Defines a reusable function called Write-Separator
    param (  # Specifies what parameters this function accepts
        [string]$Title  # A string parameter called $Title that will appear in the separator
    )
    
    $separator = "=" * 80  # Creates a string of 80 equals signs for visual separation
    Write-Host "`n$separator" -ForegroundColor Cyan  # Prints a newline and the separator in cyan color
    Write-Host " $Title " -ForegroundColor Cyan  # Prints the title in cyan color
    Write-Host "$separator" -ForegroundColor Cyan  # Prints another separator line in cyan
    
    # Also write to file without color codes
    $output = "`n$separator`n $Title `n$separator"  # Creates the same separator text for the file
    Add-Content -Path $outputFile -Value $output  # Adds this text to the output file
}

# Start logging
"Azure Inventory Report - $(Get-Date)" | Out-File -FilePath $outputFile  # Creates the output file with a header
Write-Host "Azure Inventory Report - $(Get-Date)" -ForegroundColor Green  # Displays the report header in green

# Get and display all subscriptions
Write-Separator "AZURE SUBSCRIPTIONS"  # Calls our separator function to create a section header
$subscriptions = Get-AzSubscription  # Gets a list of all Azure subscriptions you have access to

foreach ($sub in $subscriptions) {  # Loops through each subscription
    Write-Host "Subscription: " -ForegroundColor White -NoNewline  # Prints label without adding a newline
    Write-Host "$($sub.Name)" -ForegroundColor Green  # Prints subscription name in green
    Write-Host "ID: " -ForegroundColor White -NoNewline  # Prints label without a newline
    Write-Host "$($sub.Id)" -ForegroundColor Yellow  # Prints subscription ID in yellow
    Write-Host "Tenant: " -ForegroundColor White -NoNewline  # Prints label without a newline
    Write-Host "$($sub.TenantId)" -ForegroundColor Yellow  # Prints tenant ID in yellow
    Write-Host ""  # Prints an empty line for spacing
    
    # Save to file without color codes
    $output = "Subscription: $($sub.Name)`nID: $($sub.Id)`nTenant: $($sub.TenantId)`n"  # Formats subscription info
    Add-Content -Path $outputFile -Value $output  # Adds this text to the output file
}

# Get resource groups for each subscription
Write-Separator "RESOURCE GROUPS BY SUBSCRIPTION"  # Prints a section header

foreach ($sub in $subscriptions) {  # Loops through each subscription again
    # Set the current subscription context
    Set-AzContext -Subscription $sub.Id | Out-Null  # Changes to this subscription, suppressing output with Out-Null
    
    Write-Host "`nSubscription: " -ForegroundColor White -NoNewline  # Prints label with a leading newline
    Write-Host "$($sub.Name)" -ForegroundColor Green  # Prints subscription name in green
    
    $output = "`nSubscription: $($sub.Name)"  # Formats subscription name for the file
    Add-Content -Path $outputFile -Value $output  # Adds to the output file
    
    # Get all resource groups in the current subscription
    $resourceGroups = Get-AzResourceGroup  # Gets all resource groups in this subscription
    
    if ($resourceGroups.Count -eq 0) {  # If no resource groups were found
        Write-Host "  No resource groups found" -ForegroundColor Yellow  # Prints message in yellow
        Add-Content -Path $outputFile -Value "  No resource groups found"  # Adds to output file
    }
    else {  # If resource groups were found
        foreach ($rg in $resourceGroups) {  # Loops through each resource group
            $resourceCount = (Get-AzResource -ResourceGroupName $rg.ResourceGroupName).Count  # Counts resources in this group
            Write-Host "  • " -ForegroundColor Cyan -NoNewline  # Prints a bullet point in cyan
            Write-Host "$($rg.ResourceGroupName)" -ForegroundColor White -NoNewline  # Prints resource group name in white
            Write-Host " - Location: " -ForegroundColor Gray -NoNewline  # Prints label in gray
            Write-Host "$($rg.Location)" -ForegroundColor White -NoNewline  # Prints location in white
            Write-Host " - Resources: " -ForegroundColor Gray -NoNewline  # Prints label in gray
            Write-Host "$resourceCount" -ForegroundColor Yellow  # Prints resource count in yellow
            
            $output = "  • $($rg.ResourceGroupName) - Location: $($rg.Location) - Resources: $resourceCount"  # Formats for file
            Add-Content -Path $outputFile -Value $output  # Adds to output file
        }
    }
}

# Code to add to your script after the resource groups section
# This will list all resources in each resource group with enhanced formatting

Write-Separator "DETAILED RESOURCE INVENTORY"  # Prints a section header

foreach ($sub in $subscriptions) {  # Loops through each subscription again
    # Set the current subscription context
    Set-AzContext -Subscription $sub.Id | Out-Null  # Changes to this subscription, suppressing output
    
    Write-Host "`nSubscription: " -ForegroundColor White -NoNewline  # Prints label with newline
    Write-Host "$($sub.Name)" -ForegroundColor Green  # Prints subscription name in green
    
    $output = "`nSubscription: $($sub.Name)"  # Formats for file
    Add-Content -Path $outputFile -Value $output  # Adds to output file
    
    # Get all resource groups in the current subscription
    $resourceGroups = Get-AzResourceGroup  # Gets all resource groups in this subscription
    
    if ($resourceGroups.Count -eq 0) {  # If no resource groups were found
        Write-Host "  No resource groups found in this subscription" -ForegroundColor Yellow  # Prints message in yellow
        Add-Content -Path $outputFile -Value "  No resource groups found in this subscription"  # Adds to file
    }
    else {  # If resource groups were found
        foreach ($rg in $resourceGroups) {  # Loops through each resource group
            Write-Host "`n  Resource Group: " -ForegroundColor Cyan -NoNewline  # Prints label with newline
            Write-Host "$($rg.ResourceGroupName)" -ForegroundColor Green -NoNewline  # Prints group name in green
            Write-Host " (Location: $($rg.Location))" -ForegroundColor Cyan  # Prints location in cyan
            
            $output = "`n  Resource Group: $($rg.ResourceGroupName) (Location: $($rg.Location))"  # Formats for file
            Add-Content -Path $outputFile -Value $output  # Adds to output file
            
            # Get all resources in this resource group
            $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName  # Gets all resources in this group
            
            if ($resources.Count -eq 0) {  # If no resources were found
                Write-Host "    No resources found in this resource group" -ForegroundColor Yellow  # Prints message
                Add-Content -Path $outputFile -Value "    No resources found in this resource group"  # Adds to file
            }
            else {  # If resources were found
                # Group resources by type for better organization
                $resourcesByType = $resources | Group-Object -Property ResourceType  # Groups resources by their type
                
                foreach ($resourceType in $resourcesByType) {  # Loops through each resource type
                    Write-Host "    Resource Type: " -ForegroundColor Yellow -NoNewline  # Prints label
                    Write-Host "$($resourceType.Name)" -ForegroundColor White -NoNewline  # Prints resource type name
                    Write-Host " ($($resourceType.Count) resources)" -ForegroundColor Yellow  # Prints count in yellow
                    
                    $output = "    Resource Type: $($resourceType.Name) ($($resourceType.Count) resources)"  # Formats for file
                    Add-Content -Path $outputFile -Value $output  # Adds to output file
                    
                    foreach ($resource in $resourceType.Group) {  # Loops through each resource of this type
                        # Get the SKU/size info if available
                        $skuInfo = ""  # Initializes variable for SKU info
                        try {  # Starts error handling block
                            if ($resource.ResourceType -eq "Microsoft.Compute/virtualMachines") {  # If it's a VM
                                $vm = Get-AzVM -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name  # Gets VM details
                                $skuInfo = " (Size: $($vm.HardwareProfile.VmSize))"  # Gets VM size
                            }
                            elseif ($resource.ResourceType -eq "Microsoft.Storage/storageAccounts") {  # If it's storage
                                $storage = Get-AzStorageAccount -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name  # Gets storage details
                                $skuInfo = " (SKU: $($storage.Sku.Name), Kind: $($storage.Kind))"  # Gets storage SKU and kind
                            }
                        }
                        catch {  # What to do if an error occurs
                            # Silently continue if we can't get additional details
                        }
                        
                        # Get the creation time if available
                        $creationTime = ""  # Initializes variable for creation time
                        if ($resource.CreationTime) {  # If creation time is available
                            $creationTime = " [Created: $($resource.CreationTime.ToString('yyyy-MM-dd'))]"  # Formats creation date
                        }
                        
                        Write-Host "      • " -ForegroundColor Cyan -NoNewline  # Prints bullet in cyan
                        Write-Host "$($resource.Name)" -ForegroundColor White -NoNewline  # Prints resource name
                        if ($skuInfo) {  # If SKU info is available
                            Write-Host "$skuInfo" -ForegroundColor Gray -NoNewline  # Prints SKU info in gray
                        }
                        if ($creationTime) {  # If creation time is available
                            Write-Host "$creationTime" -ForegroundColor Gray  # Prints creation time in gray with newline
                        } else {
                            Write-Host ""  # Prints just a newline if no creation time
                        }
                        
                        Write-Host "        ID: " -ForegroundColor DarkGray -NoNewline  # Prints label in dark gray
                        Write-Host "$($resource.ResourceId)" -ForegroundColor DarkGray  # Prints resource ID in dark gray
                        
                        $output = "      • $($resource.Name)$skuInfo$creationTime`n        ID: $($resource.ResourceId)"  # Formats for file
                        
                        # Add tags if they exist
                        if ($resource.Tags -and $resource.Tags.Count -gt 0) {  # If resource has tags
                            Write-Host "        Tags: " -ForegroundColor DarkGray -NoNewline  # Prints label
                            $tagOutput = ""  # Initializes variable for tag output
                            foreach ($tag in $resource.Tags.GetEnumerator()) {  # Loops through each tag
                                Write-Host "$($tag.Key)=" -ForegroundColor DarkGray -NoNewline  # Prints tag key
                                Write-Host "$($tag.Value)" -ForegroundColor DarkCyan -NoNewline  # Prints tag value
                                Write-Host "; " -ForegroundColor DarkGray -NoNewline  # Prints separator
                                $tagOutput += "$($tag.Key)=$($tag.Value); "  # Adds to tag output string
                            }
                            Write-Host ""  # Prints newline after all tags
                            $output += "`n        Tags: $tagOutput"  # Adds tags to file output
                        }
                        
                        Add-Content -Path $outputFile -Value $output  # Adds to output file
                    }
                }
            }
        }
    }
}

# Update existing summary section by adding resource counts
$totalResources = 0  # Initializes counter for total resources
foreach ($sub in $subscriptions) {  # Loops through each subscription
    Set-AzContext -Subscription $sub.Id | Out-Null  # Changes to this subscription
    $totalResources += (Get-AzResource).Count  # Adds resource count to total
}

# Add this to your existing SUMMARY section
Write-Host "`nTotal Resources: " -ForegroundColor White -NoNewline  # Prints label with newline
Write-Host "$totalResources" -ForegroundColor Yellow  # Prints total resources in yellow
$output = "`nTotal Resources: $totalResources"  # Formats for file
Add-Content -Path $outputFile -Value $output  # Adds to output file

# Get and display all Azure AD users
Write-Separator "AZURE AD USERS"  # Prints a section header

try {  # Starts error handling block
    Write-Host "Retrieving Azure AD users..." -ForegroundColor Cyan  # Prints status message
    $allUsers = Get-AzADUser -First 500 # Limiting to 500 users for performance  # Gets up to 500 Azure AD users
    
    if ($allUsers.Count -eq 0) {  # If no users were found
        Write-Host "No Azure AD users found" -ForegroundColor Yellow  # Prints message
        Add-Content -Path $outputFile -Value "No Azure AD users found"  # Adds to file
    }
    else {  # If users were found
        Write-Host "Total Azure AD Users: " -ForegroundColor White -NoNewline  # Prints label
        Write-Host "$($allUsers.Count)" -ForegroundColor Yellow  # Prints user count in yellow
        
        $output = "Total Azure AD Users: $($allUsers.Count)"  # Formats for file
        Add-Content -Path $outputFile -Value $output  # Adds to output file
        
        # Display recently created users (last 30 days)
        $recentUsers = $allUsers | Where-Object {  # Filters users
            $_.CreatedDateTime -and  # Must have a creation date
            [DateTime]$_.CreatedDateTime -gt (Get-Date).AddDays(-30)  # Created in last 30 days
        } | Sort-Object CreatedDateTime -Descending  # Sorts newest first
        
        if ($recentUsers.Count -gt 0) {  # If recent users were found
            Write-Host "`n--- Recently Created Users (Last 30 Days) ---" -ForegroundColor Yellow  # Prints header
            $output = "`n--- Recently Created Users (Last 30 Days) ---"  # Formats for file
            Add-Content -Path $outputFile -Value $output  # Adds to output file
            
            foreach ($user in $recentUsers) {  # Loops through each recent user
                $createDate = if ($user.CreatedDateTime) {  # If creation date exists
                    [DateTime]$user.CreatedDateTime  # Converts to datetime
                } else {  
                    "Unknown"  # Uses "Unknown" if no date
                }
                
                Write-Host "  • " -ForegroundColor Cyan -NoNewline  # Prints bullet in cyan
                Write-Host "$($user.DisplayName)" -ForegroundColor White -NoNewline  # Prints user name
                Write-Host " ($($user.UserPrincipalName))" -ForegroundColor Gray  # Prints email/UPN
                Write-Host "    Created: " -ForegroundColor DarkGray -NoNewline  # Prints label
                Write-Host "$createDate" -ForegroundColor Gray  # Prints creation date
                Write-Host "    Object ID: " -ForegroundColor DarkGray -NoNewline  # Prints label
                Write-Host "$($user.Id)" -ForegroundColor Gray  # Prints object ID
                Write-Host "    Account Type: " -ForegroundColor DarkGray -NoNewline  # Prints label
                Write-Host "$(if ($user.UserType) { $user.UserType } else { "Unknown" })" -ForegroundColor Gray  # Prints account type
                Write-Host ""  # Prints blank line for spacing
                
                $output = "  • $($user.DisplayName) ($($user.UserPrincipalName))"  # Formats user info for file
                $output += "`n    Created: $createDate"  # Adds creation date
                $output += "`n    Object ID: $($user.Id)"  # Adds object ID
                $output += "`n    Account Type: $(if ($user.UserType) { $user.UserType } else { "Unknown" })"  # Adds account type
                
                Add-Content -Path $outputFile -Value $output  # Adds to output file
                Add-Content -Path $outputFile -Value ""  # Adds blank line for spacing
            }
        }
        
        # Group users by domain
        Write-Host "`n--- Users by Domain ---" -ForegroundColor Yellow  # Prints header with newline
        $output = "`n--- Users by Domain ---"  # Formats for file
        Add-Content -Path $outputFile -Value $output  # Adds to output file
        
        $domains = $allUsers |  # Starts processing all users
            Where-Object { $_.UserPrincipalName -match "@" } |  # Filters for valid email format
            Group-Object { ($_.UserPrincipalName -split "@")[1] } |  # Groups by domain (part after @)
            Sort-Object Count -Descending  # Sorts by count, highest first
        
        foreach ($domain in $domains) {  # Loops through each domain
            Write-Host "  • " -ForegroundColor Cyan -NoNewline  # Prints bullet
            Write-Host "$($domain.Name): " -ForegroundColor White -NoNewline  # Prints domain name
            Write-Host "$($domain.Count) users" -ForegroundColor Yellow  # Prints user count
            
            $output = "  • $($domain.Name): $($domain.Count) users"  # Formats for file
            Add-Content -Path $outputFile -Value $output  # Adds to output file
        }
        
        # Check for guest users
        $guestUsers = $allUsers | Where-Object { $_.UserType -eq "Guest" }  # Filters for guest users
        if ($guestUsers.Count -gt 0) {  # If guest users were found
            Write-Host "`n--- Guest Users ($($guestUsers.Count) total) ---" -ForegroundColor Yellow  # Prints header
            $output = "`n--- Guest Users ($($guestUsers.Count) total) ---"  # Formats for file
            Add-Content -Path $outputFile -Value $output  # Adds to output file
            
            foreach ($guest in $guestUsers | Sort-Object DisplayName) {  # Loops through guests, sorted by name
                Write-Host "  • " -ForegroundColor Cyan -NoNewline  # Prints bullet
                Write-Host "$($guest.DisplayName)" -ForegroundColor White -NoNewline  # Prints guest name
                Write-Host " ($($guest.UserPrincipalName))" -ForegroundColor Gray  # Prints email/UPN
                
                $output = "  • $($guest.DisplayName) ($($guest.UserPrincipalName))"  # Formats for file
                Add-Content -Path $outputFile -Value $output  # Adds to output file
            }
        }
        
        # List custom display name patterns (potential test users)
        $testPatterns = @("test", "demo", "monitor", "contributor", "devsecops")  # Array of patterns to check
        $potentialTestUsers = $allUsers | Where-Object {  # Filters users
            $user = $_  # Stores current user in variable
            $matchFound = $false  # Initializes match flag as false
            foreach ($pattern in $testPatterns) {  # Loops through each pattern
                if ($user.DisplayName -like "*$pattern*" -or $user.UserPrincipalName -like "*$pattern*") {  # Checks name and email
                    $matchFound = $true  # Sets match flag to true
                    break  # Exits pattern loop since we found a match
                }
            }
            $matchFound  # Returns true/false to Where-Object filter
        }
        
        if ($potentialTestUsers.Count -gt 0) {  # If potential test users were found
            Write-Host "`n--- Potential Test Users ($($potentialTestUsers.Count) total) ---" -ForegroundColor Yellow  # Prints header
            $output = "`n--- Potential Test Users ($($potentialTestUsers.Count) total) ---"  # Formats for file
            Add-Content -Path $outputFile -Value $output  # Adds to output file
            
            foreach ($testUser in $potentialTestUsers | Sort-Object DisplayName) {  # Loops through test users, sorted by name
                Write-Host "  • " -ForegroundColor Cyan -NoNewline  # Prints bullet
                Write-Host "$($testUser.DisplayName)" -ForegroundColor White -NoNewline  # Prints user name
                Write-Host " ($($testUser.UserPrincipalName))" -ForegroundColor Gray  # Prints email/UPN
                
                $output = "  • $($testUser.DisplayName) ($($testUser.UserPrincipalName))"  # Formats for file
                Add-Content -Path $outputFile -Value $output  # Adds to output file
            }
        }
    }
}
catch {  # What to do if an error occurs
    Write-Host "Error retrieving Azure AD users: $_" -ForegroundColor Red  # Prints error in red
    $output = "Error retrieving Azure AD users: $_"  # Formats error for file
    Add-Content -Path $outputFile -Value $output  # Adds to output file
}

# Get user role assignments
Write-Separator "USER ROLE ASSIGNMENTS"  # Prints a section header

try {  # Starts error handling block
    Write-Host "Retrieving role assignments..." -ForegroundColor Cyan  # Prints status
    
    # Get all role assignments
    $roleAssignments = Get-AzRoleAssignment | Where-Object { $_.ObjectType -eq "User" }  # Gets all user role assignments
    
    if ($roleAssignments.Count -eq 0) {  # If no assignments were found
        Write-Host "No user role assignments found" -ForegroundColor Yellow  # Prints message
        $output = "No user role assignments found"  # Formats for file
        Add-Content -Path $outputFile -Value $output  # Adds to output file
    }
    else {  # If assignments were found
        Write-Host "Total User Role Assignments: " -ForegroundColor White -NoNewline  # Prints label
        Write-Host "$($roleAssignments.Count)" -ForegroundColor Yellow  # Prints count in yellow
        
        $output = "Total User Role Assignments: $($roleAssignments.Count)"  # Formats for file
        Add-Content -Path $outputFile -Value $output  # Adds to output file
        
        # Group by role definition
        $roleGroups = $roleAssignments | Group-Object RoleDefinitionName | Sort-Object Count -Descending  # Groups by role name
        
        Write-Host "`n--- Role Assignments by Role ---" -ForegroundColor Yellow  # Prints header
        $output = "`n--- Role Assignments by Role ---"  # Formats for file
        Add-Content -Path $outputFile -Value $output  # Adds to output file
        
        foreach ($role in $roleGroups) {  # Loops through each role
            Write-Host "  • " -ForegroundColor Cyan -NoNewline  # Prints bullet
            Write-Host "$($role.Name): " -ForegroundColor White -NoNewline  # Prints role name
            Write-Host "$($role.Count) assignments" -ForegroundColor Yellow  # Prints assignment count
            
            $output = "  • $($role.Name): $($role.Count) assignments"  # Formats for file
            Add-Content -Path $outputFile -Value $output  # Adds to output file
        }
        
        # List all custom assignments (non-built-in roles)
        $customAssignments = $roleAssignments | Where-Object {  # Filters assignments
            $_.RoleDefinitionName -notin @("Owner", "Contributor", "Reader", "User Access Administrator")  # Excludes built-in roles
        }
        
        if ($customAssignments.Count -gt 0) {  # If custom assignments were found
            Write-Host "`n--- Custom Role Assignments ---" -ForegroundColor Yellow  # Prints header
            $output = "`n--- Custom Role Assignments ---"  # Formats for file
            Add-Content -Path $outputFile -Value $output  # Adds to output file
            
            foreach ($assignment in $customAssignments) {  # Loops through each custom assignment
                if ($assignment.SignInName) {  # If sign-in name is available
                    $userInfo = $assignment.SignInName  # Uses sign-in name
                } else {  # Otherwise
                    $user = $allUsers | Where-Object { $_.Id -eq $assignment.ObjectId } | Select-Object -First 1  # Looks up user by ID
                    $userInfo = if ($user) { "$($user.DisplayName) ($($user.UserPrincipalName))" } else { $assignment.ObjectId }  # Uses display name or ID
                }
                
                Write-Host "  • " -ForegroundColor Cyan -NoNewline  # Prints bullet
                Write-Host "$userInfo" -ForegroundColor White  # Prints user info
                Write-Host "    Role: " -ForegroundColor DarkGray -NoNewline  # Prints label
                Write-Host "$($assignment.RoleDefinitionName)" -ForegroundColor Yellow  # Prints role name
                Write-Host "    Scope: " -ForegroundColor DarkGray -NoNewline  # Prints label
                Write-Host "$($assignment.Scope)" -ForegroundColor Gray  # Prints scope
                Write-Host ""  # Prints blank line
                
                $output = "  • $userInfo"  # Formats user info for file
                $output += "`n    Role: $($assignment.RoleDefinitionName)"  # Adds role
                $output += "`n    Scope: $($assignment.Scope)"  # Adds scope
                
                Add-Content -Path $outputFile -Value $output  # Adds to output file
                Add-Content -Path $outputFile -Value ""  # Adds blank line
            }
        }
    }
}
catch {  # What to do if an error occurs
    Write-Host "Error retrieving role assignments: $_" -ForegroundColor Red  # Prints error in red
    $output = "Error retrieving role assignments: $_"  # Formats error for file
    Add-Content -Path $outputFile -Value $output  # Adds to output file
}

# Display summary
$totalSubs = $subscriptions.Count  # Counts subscriptions
$totalRGs = (Get-AzResourceGroup).Count  # Counts resource groups
$totalUsers = if ($allUsers) { $allUsers.Count } else { "Unknown" }  # Counts users if available
$totalRoleAssignments = if ($roleAssignments) { $roleAssignments.Count } else { "Unknown" }  # Counts assignments if available

Write-Separator "SUMMARY"  # Prints a section header

Write-Host "Total Subscriptions: " -ForegroundColor White -NoNewline  # Prints label
Write-Host "$totalSubs" -ForegroundColor Yellow  # Prints subscription count
Write-Host "Total Resource Groups: " -ForegroundColor White -NoNewline  # Prints label
Write-Host "$totalRGs" -ForegroundColor Yellow  # Prints resource group count
Write-Host "Total Azure AD Users: " -ForegroundColor White -NoNewline  # Prints label
Write-Host "$totalUsers" -ForegroundColor Yellow  # Prints user count
Write-Host "Total User Role Assignments: " -ForegroundColor White -NoNewline  # Prints label
Write-Host "$totalRoleAssignments" -ForegroundColor Yellow  # Prints assignment count

$output = "Total Subscriptions: $totalSubs"  # Formats summary for file
$output += "`nTotal Resource Groups: $totalRGs"  # Adds resource group count
$output += "`nTotal Azure AD Users: $totalUsers"  # Adds user count
$output += "`nTotal User Role Assignments: $totalRoleAssignments"  # Adds assignment count
Add-Content -Path $outputFile -Value $output  # Adds to output file

Write-Host "`nInventory saved to file: " -ForegroundColor Green -NoNewline  # Prints final message
Write-Host "$outputFile" -ForegroundColor Cyan  # Prints filename in cyan