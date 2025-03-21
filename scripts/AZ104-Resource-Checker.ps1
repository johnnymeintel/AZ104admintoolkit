# AZ104-Resource-Checker.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: A quick script to list all Azure subscriptions, resource groups, and users with enhanced formatting
# Blog: https://johnnymeintel.com

# Connect to Azure if not already connected
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Create a timestamp for the output file
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = "Azure-Inventory-$timestamp.txt"

# Output separator function with enhanced formatting (no background)
function Write-Separator {
    param (
        [string]$Title
    )
    
    $separator = "=" * 80
    Write-Host "`n$separator" -ForegroundColor Cyan
    Write-Host " $Title " -ForegroundColor Cyan
    Write-Host "$separator" -ForegroundColor Cyan
    
    # Also write to file without color codes
    $output = "`n$separator`n $Title `n$separator"
    Add-Content -Path $outputFile -Value $output
}

# Start logging
"Azure Inventory Report - $(Get-Date)" | Out-File -FilePath $outputFile
Write-Host "Azure Inventory Report - $(Get-Date)" -ForegroundColor Green

# Get and display all subscriptions
Write-Separator "AZURE SUBSCRIPTIONS"
$subscriptions = Get-AzSubscription

foreach ($sub in $subscriptions) {
    Write-Host "Subscription: " -ForegroundColor White -NoNewline
    Write-Host "$($sub.Name)" -ForegroundColor Green
    Write-Host "ID: " -ForegroundColor White -NoNewline
    Write-Host "$($sub.Id)" -ForegroundColor Yellow
    Write-Host "Tenant: " -ForegroundColor White -NoNewline
    Write-Host "$($sub.TenantId)" -ForegroundColor Yellow
    Write-Host ""
    
    # Save to file without color codes
    $output = "Subscription: $($sub.Name)`nID: $($sub.Id)`nTenant: $($sub.TenantId)`n"
    Add-Content -Path $outputFile -Value $output
}

# Get resource groups for each subscription
Write-Separator "RESOURCE GROUPS BY SUBSCRIPTION"

foreach ($sub in $subscriptions) {
    # Set the current subscription context
    Set-AzContext -Subscription $sub.Id | Out-Null
    
    Write-Host "`nSubscription: " -ForegroundColor White -NoNewline
    Write-Host "$($sub.Name)" -ForegroundColor Green
    
    $output = "`nSubscription: $($sub.Name)"
    Add-Content -Path $outputFile -Value $output
    
    # Get all resource groups in the current subscription
    $resourceGroups = Get-AzResourceGroup
    
    if ($resourceGroups.Count -eq 0) {
        Write-Host "  No resource groups found" -ForegroundColor Yellow
        Add-Content -Path $outputFile -Value "  No resource groups found"
    }
    else {
        foreach ($rg in $resourceGroups) {
            $resourceCount = (Get-AzResource -ResourceGroupName $rg.ResourceGroupName).Count
            Write-Host "  • " -ForegroundColor Cyan -NoNewline
            Write-Host "$($rg.ResourceGroupName)" -ForegroundColor White -NoNewline
            Write-Host " - Location: " -ForegroundColor Gray -NoNewline
            Write-Host "$($rg.Location)" -ForegroundColor White -NoNewline
            Write-Host " - Resources: " -ForegroundColor Gray -NoNewline
            Write-Host "$resourceCount" -ForegroundColor Yellow
            
            $output = "  • $($rg.ResourceGroupName) - Location: $($rg.Location) - Resources: $resourceCount"
            Add-Content -Path $outputFile -Value $output
        }
    }
}

# Code to add to your script after the resource groups section
# This will list all resources in each resource group with enhanced formatting

Write-Separator "DETAILED RESOURCE INVENTORY"

foreach ($sub in $subscriptions) {
    # Set the current subscription context
    Set-AzContext -Subscription $sub.Id | Out-Null
    
    Write-Host "`nSubscription: " -ForegroundColor White -NoNewline
    Write-Host "$($sub.Name)" -ForegroundColor Green
    
    $output = "`nSubscription: $($sub.Name)"
    Add-Content -Path $outputFile -Value $output
    
    # Get all resource groups in the current subscription
    $resourceGroups = Get-AzResourceGroup
    
    if ($resourceGroups.Count -eq 0) {
        Write-Host "  No resource groups found in this subscription" -ForegroundColor Yellow
        Add-Content -Path $outputFile -Value "  No resource groups found in this subscription"
    }
    else {
        foreach ($rg in $resourceGroups) {
            Write-Host "`n  Resource Group: " -ForegroundColor Cyan -NoNewline
            Write-Host "$($rg.ResourceGroupName)" -ForegroundColor Green -NoNewline
            Write-Host " (Location: $($rg.Location))" -ForegroundColor Cyan
            
            $output = "`n  Resource Group: $($rg.ResourceGroupName) (Location: $($rg.Location))"
            Add-Content -Path $outputFile -Value $output
            
            # Get all resources in this resource group
            $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName
            
            if ($resources.Count -eq 0) {
                Write-Host "    No resources found in this resource group" -ForegroundColor Yellow
                Add-Content -Path $outputFile -Value "    No resources found in this resource group"
            }
            else {
                # Group resources by type for better organization
                $resourcesByType = $resources | Group-Object -Property ResourceType
                
                foreach ($resourceType in $resourcesByType) {
                    Write-Host "    Resource Type: " -ForegroundColor Yellow -NoNewline
                    Write-Host "$($resourceType.Name)" -ForegroundColor White -NoNewline
                    Write-Host " ($($resourceType.Count) resources)" -ForegroundColor Yellow
                    
                    $output = "    Resource Type: $($resourceType.Name) ($($resourceType.Count) resources)"
                    Add-Content -Path $outputFile -Value $output
                    
                    foreach ($resource in $resourceType.Group) {
                        # Get the SKU/size info if available
                        $skuInfo = ""
                        try {
                            if ($resource.ResourceType -eq "Microsoft.Compute/virtualMachines") {
                                $vm = Get-AzVM -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
                                $skuInfo = " (Size: $($vm.HardwareProfile.VmSize))"
                            }
                            elseif ($resource.ResourceType -eq "Microsoft.Storage/storageAccounts") {
                                $storage = Get-AzStorageAccount -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
                                $skuInfo = " (SKU: $($storage.Sku.Name), Kind: $($storage.Kind))"
                            }
                        }
                        catch {
                            # Silently continue if we can't get additional details
                        }
                        
                        # Get the creation time if available
                        $creationTime = ""
                        if ($resource.CreationTime) {
                            $creationTime = " [Created: $($resource.CreationTime.ToString('yyyy-MM-dd'))]"
                        }
                        
                        Write-Host "      • " -ForegroundColor Cyan -NoNewline
                        Write-Host "$($resource.Name)" -ForegroundColor White -NoNewline
                        if ($skuInfo) { 
                            Write-Host "$skuInfo" -ForegroundColor Gray -NoNewline 
                        }
                        if ($creationTime) { 
                            Write-Host "$creationTime" -ForegroundColor Gray 
                        } else {
                            Write-Host ""
                        }
                        
                        Write-Host "        ID: " -ForegroundColor DarkGray -NoNewline
                        Write-Host "$($resource.ResourceId)" -ForegroundColor DarkGray
                        
                        $output = "      • $($resource.Name)$skuInfo$creationTime`n        ID: $($resource.ResourceId)"
                        
                        # Add tags if they exist
                        if ($resource.Tags -and $resource.Tags.Count -gt 0) {
                            Write-Host "        Tags: " -ForegroundColor DarkGray -NoNewline
                            $tagOutput = ""
                            foreach ($tag in $resource.Tags.GetEnumerator()) {
                                Write-Host "$($tag.Key)=" -ForegroundColor DarkGray -NoNewline
                                Write-Host "$($tag.Value)" -ForegroundColor DarkCyan -NoNewline
                                Write-Host "; " -ForegroundColor DarkGray -NoNewline
                                $tagOutput += "$($tag.Key)=$($tag.Value); "
                            }
                            Write-Host ""
                            $output += "`n        Tags: $tagOutput"
                        }
                        
                        Add-Content -Path $outputFile -Value $output
                    }
                }
            }
        }
    }
}

# Update existing summary section by adding resource counts
$totalResources = 0
foreach ($sub in $subscriptions) {
    Set-AzContext -Subscription $sub.Id | Out-Null
    $totalResources += (Get-AzResource).Count
}

# Add this to your existing SUMMARY section
Write-Host "`nTotal Resources: " -ForegroundColor White -NoNewline
Write-Host "$totalResources" -ForegroundColor Yellow
$output = "`nTotal Resources: $totalResources"
Add-Content -Path $outputFile -Value $output

# Get and display all Azure AD users
Write-Separator "AZURE AD USERS"

try {
    Write-Host "Retrieving Azure AD users..." -ForegroundColor Cyan
    $allUsers = Get-AzADUser -First 500 # Limiting to 500 users for performance
    
    if ($allUsers.Count -eq 0) {
        Write-Host "No Azure AD users found" -ForegroundColor Yellow
        Add-Content -Path $outputFile -Value "No Azure AD users found"
    }
    else {
        Write-Host "Total Azure AD Users: " -ForegroundColor White -NoNewline
        Write-Host "$($allUsers.Count)" -ForegroundColor Yellow
        
        $output = "Total Azure AD Users: $($allUsers.Count)"
        Add-Content -Path $outputFile -Value $output
        
        # Display recently created users (last 30 days)
        $recentUsers = $allUsers | Where-Object { 
            $_.CreatedDateTime -and 
            [DateTime]$_.CreatedDateTime -gt (Get-Date).AddDays(-30) 
        } | Sort-Object CreatedDateTime -Descending
        
        if ($recentUsers.Count -gt 0) {
            Write-Host "`n--- Recently Created Users (Last 30 Days) ---" -ForegroundColor Yellow
            $output = "`n--- Recently Created Users (Last 30 Days) ---"
            Add-Content -Path $outputFile -Value $output
            
            foreach ($user in $recentUsers) {
                $createDate = if ($user.CreatedDateTime) { 
                    [DateTime]$user.CreatedDateTime 
                } else { 
                    "Unknown" 
                }
                
                Write-Host "  • " -ForegroundColor Cyan -NoNewline
                Write-Host "$($user.DisplayName)" -ForegroundColor White -NoNewline
                Write-Host " ($($user.UserPrincipalName))" -ForegroundColor Gray
                Write-Host "    Created: " -ForegroundColor DarkGray -NoNewline
                Write-Host "$createDate" -ForegroundColor Gray
                Write-Host "    Object ID: " -ForegroundColor DarkGray -NoNewline
                Write-Host "$($user.Id)" -ForegroundColor Gray
                Write-Host "    Account Type: " -ForegroundColor DarkGray -NoNewline
                Write-Host "$(if ($user.UserType) { $user.UserType } else { "Unknown" })" -ForegroundColor Gray
                Write-Host ""
                
                $output = "  • $($user.DisplayName) ($($user.UserPrincipalName))"
                $output += "`n    Created: $createDate"
                $output += "`n    Object ID: $($user.Id)"
                $output += "`n    Account Type: $(if ($user.UserType) { $user.UserType } else { "Unknown" })"
                
                Add-Content -Path $outputFile -Value $output
                Add-Content -Path $outputFile -Value ""
            }
        }
        
        # Group users by domain
        Write-Host "`n--- Users by Domain ---" -ForegroundColor Yellow
        $output = "`n--- Users by Domain ---"
        Add-Content -Path $outputFile -Value $output
        
        $domains = $allUsers | 
            Where-Object { $_.UserPrincipalName -match "@" } |
            Group-Object { ($_.UserPrincipalName -split "@")[1] } |
            Sort-Object Count -Descending
        
        foreach ($domain in $domains) {
            Write-Host "  • " -ForegroundColor Cyan -NoNewline
            Write-Host "$($domain.Name): " -ForegroundColor White -NoNewline
            Write-Host "$($domain.Count) users" -ForegroundColor Yellow
            
            $output = "  • $($domain.Name): $($domain.Count) users"
            Add-Content -Path $outputFile -Value $output
        }
        
        # Check for guest users
        $guestUsers = $allUsers | Where-Object { $_.UserType -eq "Guest" }
        if ($guestUsers.Count -gt 0) {
            Write-Host "`n--- Guest Users ($($guestUsers.Count) total) ---" -ForegroundColor Yellow
            $output = "`n--- Guest Users ($($guestUsers.Count) total) ---"
            Add-Content -Path $outputFile -Value $output
            
            foreach ($guest in $guestUsers | Sort-Object DisplayName) {
                Write-Host "  • " -ForegroundColor Cyan -NoNewline
                Write-Host "$($guest.DisplayName)" -ForegroundColor White -NoNewline
                Write-Host " ($($guest.UserPrincipalName))" -ForegroundColor Gray
                
                $output = "  • $($guest.DisplayName) ($($guest.UserPrincipalName))"
                Add-Content -Path $outputFile -Value $output
            }
        }
        
        # List custom display name patterns (potential test users)
        $testPatterns = @("test", "demo", "monitor", "contributor", "devsecops")
        $potentialTestUsers = $allUsers | Where-Object { 
            $user = $_
            $matchFound = $false
            foreach ($pattern in $testPatterns) {
                if ($user.DisplayName -like "*$pattern*" -or $user.UserPrincipalName -like "*$pattern*") {
                    $matchFound = $true
                    break
                }
            }
            $matchFound
        }
        
        if ($potentialTestUsers.Count -gt 0) {
            Write-Host "`n--- Potential Test Users ($($potentialTestUsers.Count) total) ---" -ForegroundColor Yellow
            $output = "`n--- Potential Test Users ($($potentialTestUsers.Count) total) ---"
            Add-Content -Path $outputFile -Value $output
            
            foreach ($testUser in $potentialTestUsers | Sort-Object DisplayName) {
                Write-Host "  • " -ForegroundColor Cyan -NoNewline
                Write-Host "$($testUser.DisplayName)" -ForegroundColor White -NoNewline
                Write-Host " ($($testUser.UserPrincipalName))" -ForegroundColor Gray
                
                $output = "  • $($testUser.DisplayName) ($($testUser.UserPrincipalName))"
                Add-Content -Path $outputFile -Value $output
            }
        }
    }
}
catch {
    Write-Host "Error retrieving Azure AD users: $_" -ForegroundColor Red
    $output = "Error retrieving Azure AD users: $_"
    Add-Content -Path $outputFile -Value $output
}

# Get user role assignments
Write-Separator "USER ROLE ASSIGNMENTS"

try {
    Write-Host "Retrieving role assignments..." -ForegroundColor Cyan
    
    # Get all role assignments
    $roleAssignments = Get-AzRoleAssignment | Where-Object { $_.ObjectType -eq "User" }
    
    if ($roleAssignments.Count -eq 0) {
        Write-Host "No user role assignments found" -ForegroundColor Yellow
        $output = "No user role assignments found"
        Add-Content -Path $outputFile -Value $output
    }
    else {
        Write-Host "Total User Role Assignments: " -ForegroundColor White -NoNewline
        Write-Host "$($roleAssignments.Count)" -ForegroundColor Yellow
        
        $output = "Total User Role Assignments: $($roleAssignments.Count)"
        Add-Content -Path $outputFile -Value $output
        
        # Group by role definition
        $roleGroups = $roleAssignments | Group-Object RoleDefinitionName | Sort-Object Count -Descending
        
        Write-Host "`n--- Role Assignments by Role ---" -ForegroundColor Yellow
        $output = "`n--- Role Assignments by Role ---"
        Add-Content -Path $outputFile -Value $output
        
        foreach ($role in $roleGroups) {
            Write-Host "  • " -ForegroundColor Cyan -NoNewline
            Write-Host "$($role.Name): " -ForegroundColor White -NoNewline
            Write-Host "$($role.Count) assignments" -ForegroundColor Yellow
            
            $output = "  • $($role.Name): $($role.Count) assignments"
            Add-Content -Path $outputFile -Value $output
        }
        
        # List all custom assignments (non-built-in roles)
        $customAssignments = $roleAssignments | Where-Object { 
            $_.RoleDefinitionName -notin @("Owner", "Contributor", "Reader", "User Access Administrator") 
        }
        
        if ($customAssignments.Count -gt 0) {
            Write-Host "`n--- Custom Role Assignments ---" -ForegroundColor Yellow
            $output = "`n--- Custom Role Assignments ---"
            Add-Content -Path $outputFile -Value $output
            
            foreach ($assignment in $customAssignments) {
                if ($assignment.SignInName) {
                    $userInfo = $assignment.SignInName
                } else {
                    $user = $allUsers | Where-Object { $_.Id -eq $assignment.ObjectId } | Select-Object -First 1
                    $userInfo = if ($user) { "$($user.DisplayName) ($($user.UserPrincipalName))" } else { $assignment.ObjectId }
                }
                
                Write-Host "  • " -ForegroundColor Cyan -NoNewline
                Write-Host "$userInfo" -ForegroundColor White
                Write-Host "    Role: " -ForegroundColor DarkGray -NoNewline
                Write-Host "$($assignment.RoleDefinitionName)" -ForegroundColor Yellow
                Write-Host "    Scope: " -ForegroundColor DarkGray -NoNewline
                Write-Host "$($assignment.Scope)" -ForegroundColor Gray
                Write-Host ""
                
                $output = "  • $userInfo"
                $output += "`n    Role: $($assignment.RoleDefinitionName)"
                $output += "`n    Scope: $($assignment.Scope)"
                
                Add-Content -Path $outputFile -Value $output
                Add-Content -Path $outputFile -Value ""
            }
        }
    }
}
catch {
    Write-Host "Error retrieving role assignments: $_" -ForegroundColor Red
    $output = "Error retrieving role assignments: $_"
    Add-Content -Path $outputFile -Value $output
}

# Display summary
$totalSubs = $subscriptions.Count
$totalRGs = (Get-AzResourceGroup).Count
$totalUsers = if ($allUsers) { $allUsers.Count } else { "Unknown" }
$totalRoleAssignments = if ($roleAssignments) { $roleAssignments.Count } else { "Unknown" }

Write-Separator "SUMMARY"

Write-Host "Total Subscriptions: " -ForegroundColor White -NoNewline
Write-Host "$totalSubs" -ForegroundColor Yellow
Write-Host "Total Resource Groups: " -ForegroundColor White -NoNewline
Write-Host "$totalRGs" -ForegroundColor Yellow
Write-Host "Total Azure AD Users: " -ForegroundColor White -NoNewline
Write-Host "$totalUsers" -ForegroundColor Yellow
Write-Host "Total User Role Assignments: " -ForegroundColor White -NoNewline
Write-Host "$totalRoleAssignments" -ForegroundColor Yellow

$output = "Total Subscriptions: $totalSubs"
$output += "`nTotal Resource Groups: $totalRGs"
$output += "`nTotal Azure AD Users: $totalUsers"
$output += "`nTotal User Role Assignments: $totalRoleAssignments"
Add-Content -Path $outputFile -Value $output

Write-Host "`nInventory saved to file: " -ForegroundColor Green -NoNewline
Write-Host "$outputFile" -ForegroundColor Cyan