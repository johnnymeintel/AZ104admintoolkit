# Get all custom Azure roles
$CustomRoles = Get-AzRoleDefinition | Where-Object {$_.IsCustom}

if ($CustomRoles.Count -eq 0) {
    Write-Host "No custom Azure roles found."
    return
}

Write-Host "Current Custom Azure Roles:"

# Display the roles with Name and ID
$CustomRoles | Format-Table Name, Id

# Prompt the user for deletion
$DeleteConfirmation = Read-Host "Do you want to delete any of these custom roles? (y/n)"

if ($DeleteConfirmation -eq "y") {
    do {
        $RoleNameToDelete = Read-Host "Enter the Name of the role to delete (or type 'exit' to stop):"

        if ($RoleNameToDelete -eq "exit") {
            break
        }

        $RoleToDelete = $CustomRoles | Where-Object {$_.Name -eq $RoleNameToDelete}

        if ($RoleToDelete) {
            $ConfirmDelete = Read-Host "Are you sure you want to delete '$($RoleToDelete.Name)'? (y/n)"

            if ($ConfirmDelete -eq "y") {
                try {
                    Remove-AzRoleDefinition -Name $RoleToDelete.Name -Force
                    Write-Host "Role '$($RoleToDelete.Name)' deleted successfully."
                    #Update the custom roles array after deletion.
                    $CustomRoles = Get-AzRoleDefinition | Where-Object {$_.IsCustom}
                }
                catch {
                    Write-Error "Failed to delete role '$($RoleToDelete.Name)': $($_.Exception.Message)"
                }
            } else {
                Write-Host "Deletion cancelled."
            }
        } else {
            Write-Warning "Role '$RoleNameToDelete' not found."
        }
    } while ($true) # Continue until user types 'exit'
} else {
    Write-Host "No roles deleted."
}