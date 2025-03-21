# AZ104-RBAC-Auditor.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: PowerShell script that inventories all role assignments across a subscription or resource group,
#          with enhanced details for custom roles and security insights.
# Blog: https://johnnymeintel.com

# Connect to Azure (comment out if already connected)
#Connect-AzAccount

# Parameters - modify as needed
param(
    [string]$SubscriptionId = "d4e2e78f-2a06-4c3b-88c3-0e71b39dfc10",
    [string]$ResourceGroupName = $null, # Set to $null to audit entire subscription
    [string]$OutputFile = "RBAC-Audit-$(Get-Date -Format 'yyyy-MM-dd').csv",
    [switch]$IncludeRoleDefinitions = $true # Include detailed role definitions for custom roles
)

# Set context to the specified subscription
try {
    $subscription = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
    Write-Host "Context set to subscription: $($subscription.Subscription.Name) ($SubscriptionId)" -ForegroundColor Green
} 
catch {
    Write-Error "Failed to set subscription context: $_"
    exit 1
}

# Get role assignments
try {
    if ($ResourceGroupName) {
        Write-Host "Auditing RBAC assignments for resource group: $ResourceGroupName" -ForegroundColor Cyan
        $roleAssignments = Get-AzRoleAssignment -ResourceGroupName $ResourceGroupName -ErrorAction Stop
    } else {
        Write-Host "Auditing RBAC assignments for the entire subscription" -ForegroundColor Cyan
        $roleAssignments = Get-AzRoleAssignment -ErrorAction Stop
    }
}
catch {
    Write-Error "Failed to retrieve role assignments: $_"
    exit 1
}

# Get all role definitions to extract custom role details
$roleDefinitions = Get-AzRoleDefinition

# Process assignments and create detailed report
$reportData = @()
$customRoleDetails = @{}

Write-Host "Processing $($roleAssignments.Count) role assignments..." -ForegroundColor Yellow
foreach ($role in $roleAssignments) {
    # Get object information with improved error handling
    $objectDetails = $null
    try {
        $objectDetails = switch ($role.ObjectType) {
            "User" { Get-AzADUser -ObjectId $role.ObjectId -ErrorAction SilentlyContinue }
            "Group" { Get-AzADGroup -ObjectId $role.ObjectId -ErrorAction SilentlyContinue }
            "ServicePrincipal" { Get-AzADServicePrincipal -ObjectId $role.ObjectId -ErrorAction SilentlyContinue }
            default { $null }
        }
    }
    catch {
        Write-Warning "Could not retrieve details for $($role.DisplayName): $_"
    }

    # Determine if this is a custom role and get additional details if it is
    $isCustomRole = $false
    $customRoleInfo = $null
    $permissions = "N/A"
    
    $roleDefinition = $roleDefinitions | Where-Object { $_.Name -eq $role.RoleDefinitionName }
    if ($roleDefinition -and $roleDefinition.IsCustom) {
        $isCustomRole = $true
        
        # Cache custom role details to avoid redundant processing
        if (-not $customRoleDetails.ContainsKey($role.RoleDefinitionName)) {
            $actions = $roleDefinition.Actions -join "; "
            $notActions = $roleDefinition.NotActions -join "; "
            $dataActions = $roleDefinition.DataActions -join "; "
            $notDataActions = $roleDefinition.NotDataActions -join "; "
            
            $customRoleDetails[$role.RoleDefinitionName] = @{
                Description = $roleDefinition.Description
                Actions = $actions
                NotActions = $notActions
                DataActions = $dataActions
                NotDataActions = $notDataActions
                AssignableScopes = $roleDefinition.AssignableScopes -join "; "
                Id = $roleDefinition.Id
            }
        }
        
        $customRoleInfo = $customRoleDetails[$role.RoleDefinitionName]
        $permissions = "Actions: $($customRoleInfo.Actions)"
    }
    
    # Determine scope type (subscription, resource group, resource)
    $scopeType = switch -Wildcard ($role.Scope) {
        "/subscriptions/*" {
            if ($role.Scope -match "/subscriptions/[^/]+$") { "Subscription" }
            elseif ($role.Scope -match "/resourceGroups/[^/]+$") { "Resource Group" }
            else { "Resource" }
        }
        default { "Unknown" }
    }
    
    # Create object for report
    $reportObject = [PSCustomObject]@{
        'PrincipalName' = $role.DisplayName
        'PrincipalType' = $role.ObjectType
        'PrincipalId' = $role.ObjectId
        'Role' = $role.RoleDefinitionName
        'RoleId' = $role.RoleDefinitionId
        'IsCustomRole' = $isCustomRole
        'Scope' = $role.Scope
        'ScopeType' = $scopeType
        'ScopeLevel' = $role.Scope.Split("/").Count  # Higher number means more specific scope
        'AssignmentId' = $role.RoleAssignmentId
        'CreatedOn' = $role.CreatedOn
        'CreatedBy' = $role.CreatedBy
        'Email' = if ($objectDetails.Mail) { $objectDetails.Mail } elseif ($objectDetails.UserPrincipalName) { $objectDetails.UserPrincipalName } else { "N/A" }
    }
    
    # Add custom role details if applicable
    if ($isCustomRole -and $IncludeRoleDefinitions) {
        $reportObject | Add-Member -NotePropertyName 'RoleDescription' -NotePropertyValue $customRoleInfo.Description
        $reportObject | Add-Member -NotePropertyName 'Actions' -NotePropertyValue $customRoleInfo.Actions
        $reportObject | Add-Member -NotePropertyName 'NotActions' -NotePropertyValue $customRoleInfo.NotActions
        $reportObject | Add-Member -NotePropertyName 'DataActions' -NotePropertyValue $customRoleInfo.DataActions
        $reportObject | Add-Member -NotePropertyName 'NotDataActions' -NotePropertyValue $customRoleInfo.NotDataActions
        $reportObject | Add-Member -NotePropertyName 'AssignableScopes' -NotePropertyValue $customRoleInfo.AssignableScopes
    }
    
    $reportData += $reportObject
}

# Export to CSV
$reportData | Export-Csv -Path $OutputFile -NoTypeInformation
Write-Host "Audit complete. Report saved to: $OutputFile" -ForegroundColor Green

# Generate summary statistics
$totalAssignments = $reportData.Count
$customRoleCount = ($reportData | Where-Object { $_.IsCustomRole -eq $true }).Count
$builtInRoleCount = $totalAssignments - $customRoleCount

# Principal type distribution
$principalTypeDistribution = $reportData | Group-Object -Property PrincipalType | 
                              Select-Object Name, Count | 
                              Sort-Object -Property Count -Descending

# Scope type distribution
$scopeTypeDistribution = $reportData | Group-Object -Property ScopeType |
                         Select-Object Name, Count |
                         Sort-Object -Property Count -Descending

# Display summary statistics with formatting
Write-Host ""
Write-Host "Summary Statistics:" -ForegroundColor Cyan
Write-Host "-------------------"
Write-Host "Total Role Assignments: $($totalAssignments)"
Write-Host "Custom Role Assignments: $($customRoleCount)"
Write-Host "Built-in Role Assignments: $($builtInRoleCount)"

Write-Host ""
Write-Host "Principal Type Distribution:" -ForegroundColor Cyan
Write-Host "--------------------------"
foreach ($type in $principalTypeDistribution) {
    Write-Host "$($type.Name): $($type.Count) assignment(s)"
}

Write-Host ""
Write-Host "Scope Type Distribution:" -ForegroundColor Cyan
Write-Host "----------------------"
foreach ($scope in $scopeTypeDistribution) {
    Write-Host "$($scope.Name): $($scope.Count) assignment(s)"
}

Write-Host ""
Write-Host "Role Distribution:" -ForegroundColor Cyan
Write-Host "----------------"
$roleDistribution = $reportData | Group-Object -Property Role | Select-Object Name, Count | Sort-Object -Property Count -Descending
foreach ($role in $roleDistribution) {
    $isCustomIndicator = if (($reportData | Where-Object { $_.Role -eq $role.Name })[0].IsCustomRole) { " (Custom)" } else { "" }
    Write-Host "$($role.Name)$($isCustomIndicator): $($role.Count) assignment(s)"
}

# If custom roles exist, provide detailed analysis
if ($customRoleCount -gt 0 -and $IncludeRoleDefinitions) {
    Write-Host ""
    Write-Host "Custom Role Analysis:" -ForegroundColor Cyan
    Write-Host "--------------------"
    
    $customRoles = $reportData | Where-Object { $_.IsCustomRole -eq $true } | Select-Object Role -Unique
    
    foreach ($customRole in $customRoles) {
        $roleName = $customRole.Role
        $roleDetails = $customRoleDetails[$roleName]
        
        Write-Host "Role: $($roleName)" -ForegroundColor Yellow
        Write-Host "  Description: $($roleDetails.Description)"
        Write-Host "  ID: $($roleDetails.Id)"
        Write-Host "  Assignment count: $(($reportData | Where-Object { $_.Role -eq $roleName }).Count)"
        Write-Host "  Assignable scopes: $($roleDetails.AssignableScopes)"
        
        # Display permissions in a readable format
        Write-Host "  Actions:"
        foreach ($action in $roleDetails.Actions.Split(';')) {
            if ($action.Trim()) {
                Write-Host "    - $($action.Trim())"
            }
        }
        
        if ($roleDetails.NotActions) {
            Write-Host "  NotActions:"
            foreach ($notAction in $roleDetails.NotActions.Split(';')) {
                if ($notAction.Trim()) {
                    Write-Host "    - $($notAction.Trim())"
                }
            }
        }
        
        if ($roleDetails.DataActions) {
            Write-Host "  DataActions:"
            foreach ($dataAction in $roleDetails.DataActions.Split(';')) {
                if ($dataAction.Trim()) {
                    Write-Host "    - $($dataAction.Trim())"
                }
            }
        }
        
        if ($roleDetails.NotDataActions) {
            Write-Host "  NotDataActions:"
            foreach ($notDataAction in $roleDetails.NotDataActions.Split(';')) {
                if ($notDataAction.Trim()) {
                    Write-Host "    - $($notDataAction.Trim())"
                }
            }
        }
        
        Write-Host ""
    }
    
    # Export custom role definitions to a separate file for reference
    $customRoleFile = "CustomRoles-$(Get-Date -Format 'yyyy-MM-dd').json"
    $customRoleDefinitions = $roleDefinitions | Where-Object { $_.IsCustom }
    $customRoleDefinitions | ConvertTo-Json -Depth 5 | Out-File -FilePath $customRoleFile
    Write-Host "Custom role definitions exported to: $customRoleFile" -ForegroundColor Green
}

# Security insights section
Write-Host ""
Write-Host "Security Insights:" -ForegroundColor Cyan
Write-Host "-----------------"

# Check for highly privileged roles
$highPrivilegeRoles = @('Owner', 'Contributor', 'User Access Administrator')
$highPrivAssignments = $reportData | Where-Object { $highPrivilegeRoles -contains $_.Role }

if ($highPrivAssignments) {
    Write-Host "High Privilege Role Assignments: $($highPrivAssignments.Count)" -ForegroundColor Yellow
    
    foreach ($roleType in $highPrivilegeRoles) {
        $count = ($highPrivAssignments | Where-Object { $_.Role -eq $roleType }).Count
        if ($count -gt 0) {
            Write-Host "  $($roleType): $($count) assignment(s)"
        }
    }
    
    # List service principals with high privileges as a potential security concern
    $spWithHighPrivilege = $highPrivAssignments | Where-Object { $_.PrincipalType -eq 'ServicePrincipal' }
    if ($spWithHighPrivilege) {
        Write-Host "  Service Principals with high privileges: $($spWithHighPrivilege.Count)" -ForegroundColor Yellow
        foreach ($sp in $spWithHighPrivilege) {
            Write-Host "    - $($sp.PrincipalName) ($($sp.Role))"
        }
    }
}

# Check for direct resource assignments vs. group-based assignments
$directUserAssignments = ($reportData | Where-Object { $_.PrincipalType -eq 'User' }).Count
$groupAssignments = ($reportData | Where-Object { $_.PrincipalType -eq 'Group' }).Count

Write-Host "Direct user assignments: $($directUserAssignments)"
Write-Host "Group-based assignments: $($groupAssignments)"

if ($directUserAssignments -gt $groupAssignments) {
    Write-Host "Consider using more group-based assignments for better management" -ForegroundColor Yellow
}

# Check for inactive assignments (over 90 days old)
$cutoffDate = (Get-Date).AddDays(-90)
$oldAssignments = $reportData | Where-Object { $_.CreatedOn -and [DateTime]$_.CreatedOn -lt $cutoffDate }

if ($oldAssignments) {
    Write-Host "Potentially stale assignments (over 90 days old): $($oldAssignments.Count)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Audit completed successfully!" -ForegroundColor Green