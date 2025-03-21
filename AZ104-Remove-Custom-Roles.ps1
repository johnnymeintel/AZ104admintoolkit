# Get all custom Azure roles
$CustomRoles = Get-AzRoleDefinition | Where-Object {$_.IsCustom}
# This line gets all role definitions in Azure and filters to keep only the custom ones (not built-in roles)

if ($CustomRoles.Count -eq 0) {
    # This checks if there are no custom roles found by counting the items in the $CustomRoles variable
    Write-Host "No custom Azure roles found."
    # This displays a message if no custom roles exist
    return
    # This exits the script early if there are no custom roles to work with
}

Write-Host "Current Custom Azure Roles:"
# This displays a heading for the list of custom roles

# Display the roles with Name and ID
$CustomRoles | Format-Table Name, Id
# This shows a nicely formatted table with just the Name and Id columns of each custom role

# Prompt the user for deletion
$DeleteConfirmation = Read-Host "Do you want to delete any of these custom roles? (y/n)"
# This asks the user if they want to delete roles and stores their answer (y or n) in the $DeleteConfirmation variable

if ($DeleteConfirmation -eq "y") {
    # This checks if the user typed "y" to confirm they want to delete roles
    do {
        # This starts a loop that will keep running until explicitly broken
        $RoleNameToDelete = Read-Host "Enter the Name of the role to delete (or type 'exit' to stop):"
        # This asks the user to type the name of a role they want to delete

        if ($RoleNameToDelete -eq "exit") {
            # This checks if the user typed "exit" to stop deleting roles
            break
            # This exits the loop if the user wants to stop
        }

        $RoleToDelete = $CustomRoles | Where-Object {$_.Name -eq $RoleNameToDelete}
        # This finds the role object that matches the name the user entered

        if ($RoleToDelete) {
            # This checks if a matching role was found
            $ConfirmDelete = Read-Host "Are you sure you want to delete '$($RoleToDelete.Name)'? (y/n)"
            # This asks the user to confirm deletion of the specific role

            if ($ConfirmDelete -eq "y") {
                # This checks if the user confirmed with "y"
                try {
                    # This starts an error-handling block to catch any problems
                    Remove-AzRoleDefinition -Name $RoleToDelete.Name -Force
                    # This actually deletes the role from Azure (the -Force parameter skips additional confirmation)
                    Write-Host "Role '$($RoleToDelete.Name)' deleted successfully."
                    # This shows a success message
                    #Update the custom roles array after deletion.
                    $CustomRoles = Get-AzRoleDefinition | Where-Object {$_.IsCustom}
                    # This refreshes the list of custom roles after deletion
                }
                catch {
                    # This handles any errors that occur during deletion
                    Write-Error "Failed to delete role '$($RoleToDelete.Name)': $($_.Exception.Message)"
                    # This shows an error message with details about what went wrong
                }
            } else {
                # This runs if the user didn't confirm with "y"
                Write-Host "Deletion cancelled."
                # This shows that the deletion was cancelled
            }
        } else {
            # This runs if no role with the entered name was found
            Write-Warning "Role '$RoleNameToDelete' not found."
            # This shows a warning that the role name wasn't found
        }
    } while ($true) # Continue until user types 'exit'
    # This makes the loop continue indefinitely until the user types "exit"
} else {
    # This runs if the user initially answered "n" (or anything other than "y")
    Write-Host "No roles deleted."
    # This shows that no roles were deleted
}