# AZ104-VM-RightSizing-Tool.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: A quick script to analyze and recommend right-sizing for Azure VMs based on usage metrics.
# Blog: https://johnnymeintel.com
# These lines provide basic information about the script - its name, who wrote it, when, what it does, and where to find more information

# Connect to Azure if not already connected
if (-not (Get-AzContext)) {  # Checks if you're already logged into Azure - if not connected, this returns false
    Connect-AzAccount  # Opens a prompt to log in to your Azure account
}

# Simple logging function
function Write-Log {  # Defines a custom function called Write-Log for consistent message formatting
    param (  # Defines what parameters this function accepts
        [string]$Message,  # The main message to log (required)
        [string]$Level = "INFO"  # The message importance level (optional, defaults to "INFO")
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"  # Gets current date and time in a standardized format
    $logMessage = "[$timestamp] [$Level] $Message"  # Creates formatted log message with timestamp and level
    
    # Output to console with color-coding
    switch ($Level) {  # Uses different colors based on the message level
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }  # Regular info messages in cyan
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }  # Warning messages in yellow
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }  # Error messages in red
    }
}

# Function to handle resource group selection or creation
function Get-ResourceGroup {  # Defines a function to let the user select or create an Azure resource group
    Write-Host "`n=== Resource Group Selection ===" -ForegroundColor Green  # Section header with newline
    Write-Host "1. Use an existing resource group" -ForegroundColor White  # First option
    Write-Host "2. Create a new resource group" -ForegroundColor White  # Second option
    
    $choice = Read-Host "Enter your choice (1 or 2)"  # Asks user to type 1 or 2 and stores the answer
    
    if ($choice -eq "1") {  # If user chose option 1 (use existing)
        # List existing resource groups
        Write-Log "Retrieving existing resource groups..."  # Shows progress message
        $resourceGroups = Get-AzResourceGroup | Sort-Object ResourceGroupName  # Gets all resource groups and sorts them by name
        
        if ($resourceGroups.Count -eq 0) {  # If no resource groups were found
            Write-Log "No resource groups found. You need to create one." -Level "WARNING"  # Shows warning
            return Get-ResourceGroup  # Calls this function again to prompt for creation
        }
        
        Write-Host "`nAvailable Resource Groups:" -ForegroundColor Green  # Section header with newline
        for ($i = 0; $i -lt $resourceGroups.Count; $i++) {  # Loops through each resource group
            Write-Host "$($i+1). $($resourceGroups[$i].ResourceGroupName) (Location: $($resourceGroups[$i].Location))" -ForegroundColor White  # Shows each group with number
        }
        
        $rgIndex = Read-Host "Enter the number of the resource group to use (1-$($resourceGroups.Count))"  # Asks user to select by number
        try {  # Begin error handling block
            $index = [int]$rgIndex - 1  # Converts user input to array index (subtracting 1 because arrays start at 0)
            if ($index -ge 0 -and $index -lt $resourceGroups.Count) {  # Checks if the selection is valid
                return $resourceGroups[$index].ResourceGroupName  # Returns the selected resource group name
            } else {  # If selection is out of range
                Write-Log "Invalid selection. Please try again." -Level "ERROR"  # Shows error
                return Get-ResourceGroup  # Calls function again to try again
            }
        } catch {  # What to do if an error occurs (like if user types text instead of a number)
            Write-Log "Invalid input. Please enter a number." -Level "ERROR"  # Shows error
            return Get-ResourceGroup  # Calls function again to try again
        }
    }
    elseif ($choice -eq "2") {  # If user chose option 2 (create new)
        # Create new resource group
        $rgName = Read-Host "Enter a name for the new resource group"  # Asks for new group name
        
        # Get available locations and let user choose
        $locations = Get-AzLocation | Where-Object {$_.Providers -contains "Microsoft.Compute"} | Sort-Object DisplayName  # Gets locations supporting VMs, sorted by name
        
        Write-Host "`nAvailable Locations:" -ForegroundColor Green  # Section header
        for ($i = 0; $i -lt [Math]::Min(10, $locations.Count); $i++) {  # Shows up to 10 locations
            Write-Host "$($i+1). $($locations[$i].DisplayName) ($($locations[$i].Location))" -ForegroundColor White  # Shows each location with number
        }
        
        $locationIndex = Read-Host "Enter the number of the location to use (1-10)"  # Asks user to select by number
        try {  # Begin error handling block
            $index = [int]$locationIndex - 1  # Converts user input to array index
            if ($index -ge 0 -and $index -lt 10) {  # Checks if selection is valid
                $location = $locations[$index].Location  # Gets the selected location code
                
                Write-Log "Creating resource group '$rgName' in location '$location'..."  # Shows progress
                New-AzResourceGroup -Name $rgName -Location $location | Out-Null  # Creates the resource group, suppressing output
                Write-Log "Resource group created successfully."  # Shows success message
                
                return $rgName  # Returns the new resource group name
            } else {  # If selection is out of range
                Write-Log "Invalid selection. Please try again." -Level "ERROR"  # Shows error
                return Get-ResourceGroup  # Calls function again to try again
            }
        } catch {  # What to do if an error occurs
            Write-Log "Invalid input. Please enter a number." -Level "ERROR"  # Shows error
            return Get-ResourceGroup  # Calls function again to try again
        }
    }
    else {  # If user entered something other than 1 or 2
        Write-Log "Invalid choice. Please enter 1 or 2." -Level "ERROR"  # Shows error
        return Get-ResourceGroup  # Calls function again to try again
    }
}

# Function to handle VM selection or creation
function Get-VirtualMachine {  # Defines a function to let user select or create a VM
    param (  # Defines what parameters this function accepts
        [string]$ResourceGroupName  # The resource group where the VM is/will be
    )
    
    Write-Host "`n=== Virtual Machine Selection ===" -ForegroundColor Green  # Section header
    Write-Host "1. Use an existing VM in the resource group" -ForegroundColor White  # First option
    Write-Host "2. Create a new test VM" -ForegroundColor White  # Second option
    
    $choice = Read-Host "Enter your choice (1 or 2)"  # Asks user to type 1 or 2
    
    if ($choice -eq "1") {  # If user chose option 1 (use existing)
        # List existing VMs in the resource group
        Write-Log "Retrieving VMs in resource group '$ResourceGroupName'..."  # Shows progress
        $vms = Get-AzVM -ResourceGroupName $ResourceGroupName | Sort-Object Name  # Gets all VMs in the group, sorted by name
        
        if ($vms.Count -eq 0) {  # If no VMs were found
            Write-Log "No VMs found in this resource group. You need to create one." -Level "WARNING"  # Shows warning
            return Get-VirtualMachine -ResourceGroupName $ResourceGroupName  # Calls function again to try again
        }
        
        Write-Host "`nAvailable Virtual Machines:" -ForegroundColor Green  # Section header
        for ($i = 0; $i -lt $vms.Count; $i++) {  # Loops through each VM
            Write-Host "$($i+1). $($vms[$i].Name) (Size: $($vms[$i].HardwareProfile.VmSize))" -ForegroundColor White  # Shows each VM with number and size
        }
        
        $vmIndex = Read-Host "Enter the number of the VM to analyze (1-$($vms.Count))"  # Asks user to select by number
        try {  # Begin error handling block
            $index = [int]$vmIndex - 1  # Converts user input to array index
            if ($index -ge 0 -and $index -lt $vms.Count) {  # Checks if selection is valid
                return $vms[$index].Name  # Returns the selected VM name
            } else {  # If selection is out of range
                Write-Log "Invalid selection. Please try again." -Level "ERROR"  # Shows error
                return Get-VirtualMachine -ResourceGroupName $ResourceGroupName  # Calls function again to try again
            }
        } catch {  # What to do if an error occurs
            Write-Log "Invalid input. Please enter a number." -Level "ERROR"  # Shows error
            return Get-VirtualMachine -ResourceGroupName $ResourceGroupName  # Calls function again to try again
        }
    }
    elseif ($choice -eq "2") {  # If user chose option 2 (create new)
        # Create new VM with a name that meets Windows VM naming requirements (15 chars max)
        $vmName = "TestVM-" + (Get-Date -Format "MMddHHmm")  # Creates name with "TestVM-" prefix and date/time
        
        # Ensure the name is not longer than 15 characters
        if ($vmName.Length -gt 15) {  # If name would be too long
            $vmName = "VM-" + (Get-Date -Format "MMddHHmm")  # Uses shorter prefix "VM-" instead
        }
        
        Write-Log "Creating a new test VM: $vmName"  # Shows progress
        
        # VM size selection
        $vmSizes = @(  # Creates an array of VM size options
            "Standard_B1s",  # Budget VM with 1 CPU, 1GB RAM
            "Standard_B2s",  # Budget VM with 2 CPUs, 4GB RAM
            "Standard_DS1_v2",  # General purpose VM with 1 CPU, 3.5GB RAM
            "Standard_DS2_v2"  # General purpose VM with 2 CPUs, 7GB RAM
        )
        
        Write-Host "`nAvailable VM Sizes:" -ForegroundColor Green  # Section header
        for ($i = 0; $i -lt $vmSizes.Count; $i++) {  # Loops through each size option
            Write-Host "$($i+1). $($vmSizes[$i])" -ForegroundColor White  # Shows each size with number
        }
        
        $sizeIndex = Read-Host "Enter the number of the VM size to use (1-$($vmSizes.Count))"  # Asks user to select by number
        try {  # Begin error handling block
            $index = [int]$sizeIndex - 1  # Converts user input to array index
            if ($index -ge 0 -and $index -lt $vmSizes.Count) {  # Checks if selection is valid
                $vmSize = $vmSizes[$index]  # Gets the selected VM size
                
                # Set admin credentials
                $adminUsername = "azureadmin"  # Sets VM admin username
                $adminPassword = ConvertTo-SecureString "P@ssw0rd1234!" -AsPlainText -Force  # Sets VM admin password (securely)
                $credential = New-Object System.Management.Automation.PSCredential($adminUsername, $adminPassword)  # Creates credential object
                
                # Create VM
                Write-Log "Deploying VM. This may take a few minutes..."  # Shows progress
                
                try {  # Begin nested error handling block
                    New-AzVM -ResourceGroupName $ResourceGroupName `
                           -Name $vmName `
                           -Location (Get-AzResourceGroup -Name $ResourceGroupName).Location `
                           -Size $vmSize `
                           -Credential $credential `
                           -OpenPorts 3389 | Out-Null  # Creates VM with RDP port open, suppressing output
                           
                    Write-Log "VM deployed successfully."  # Shows success message
                    
                    # Add tags
                    try {  # Begin tag-specific error handling
                        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName  # Gets the VM object
                        
                        # Create new tags dictionary in the correct format
                        $tags = New-Object 'System.Collections.Generic.Dictionary[string,string]'  # Creates empty tags dictionary
                        $tags.Add("Purpose", "RightSizingAnalysis")  # Adds first tag
                        $tags.Add("Environment", "Test")  # Adds second tag
                        $tags.Add("CreatedBy", "RightSizingTool")  # Adds third tag
                        
                        # Set the tags on the VM object
                        $vm.Tags = $tags  # Assigns tags to VM
                        
                        # Update the VM
                        Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vm | Out-Null  # Applies changes to VM
                        Write-Log "Tags added to VM successfully." -Level "SUCCESS"  # Shows success message
                    }
                    catch {  # What to do if adding tags fails
                        Write-Log "Warning: Could not add tags to VM: $_" -Level "WARNING"  # Shows warning with error details
                        # Continue even if tags failed
                    }
                    
                    return $vmName  # Returns the new VM name
                }
                catch {  # What to do if VM creation fails
                    Write-Log "Error creating VM: $_" -Level "ERROR"  # Shows error with details
                    Write-Log "Please try again or select an existing VM." -Level "WARNING"  # Shows suggestion
                    return Get-VirtualMachine -ResourceGroupName $ResourceGroupName  # Calls function again to try again
                }
            } else {  # If size selection is out of range
                Write-Log "Invalid selection. Please try again." -Level "ERROR"  # Shows error
                return Get-VirtualMachine -ResourceGroupName $ResourceGroupName  # Calls function again to try again
            }
        } catch {  # What to do if an error occurs
            Write-Log "Invalid input. Please enter a number." -Level "ERROR"  # Shows error
            return Get-VirtualMachine -ResourceGroupName $ResourceGroupName  # Calls function again to try again
        }
    }
    else {  # If user entered something other than 1 or 2
        Write-Log "Invalid choice. Please enter 1 or 2." -Level "ERROR"  # Shows error
        return Get-VirtualMachine -ResourceGroupName $ResourceGroupName  # Calls function again to try again
    }
}

# Function to analyze VM usage and recommend appropriate sizing
function Get-VMRightSizingRecommendation {  # Defines a function to analyze VM and make recommendations
    param (  # Defines what parameters this function requires
        [Parameter(Mandatory=$true)]  # Makes this parameter required
        [string]$ResourceGroupName,  # The resource group containing the VM
        
        [Parameter(Mandatory=$true)]  # Makes this parameter required
        [string]$VMName  # The name of the VM to analyze
    )
    
    Write-Log "Analyzing VM: $VMName in resource group: $ResourceGroupName"  # Shows progress
    
    # Get VM details
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName  # Gets VM object
    if (-not $vm) {  # If VM wasn't found
        Write-Log "VM not found: $VMName" -Level "ERROR"  # Shows error
        return $null  # Returns nothing (null)
    }
    
    # Get current VM size
    $currentSize = $vm.HardwareProfile.VmSize  # Gets the current VM size
    Write-Log "Current VM size: $currentSize"  # Shows current size
    
    # For demonstration purposes, we'll simulate metric collection
    # In a real scenario, you would use Azure Monitor metrics
    Write-Log "Collecting performance metrics (simulated for demonstration)"  # Explains this is simulated data
    
    $cpuUtilization = Get-Random -Minimum 5 -Maximum 40  # Generates random number between 5-40 for CPU usage
    $memoryUtilization = Get-Random -Minimum 10 -Maximum 60  # Generates random number between 10-60 for memory usage
    $diskIOPS = Get-Random -Minimum 100 -Maximum 500  # Generates random number between 100-500 for disk operations
    
    Write-Log "CPU Utilization: $cpuUtilization%"  # Shows simulated CPU usage
    Write-Log "Memory Utilization: $memoryUtilization%"  # Shows simulated memory usage
    Write-Log "Disk IOPS: $diskIOPS"  # Shows simulated disk operations
    
    # Define VM size options (simplified for demonstration)
    $vmSizeTiers = @(  # Creates an array of hashtables with VM size details
        @{Name="Standard_B1s"; CPUCores=1; MemoryGB=1; Cost=1},  # Smallest/cheapest option
        @{Name="Standard_B2s"; CPUCores=2; MemoryGB=4; Cost=2},  # Next size up
        @{Name="Standard_DS1_v2"; CPUCores=1; MemoryGB=3.5; Cost=3},  # Different series, more RAM
        @{Name="Standard_DS2_v2"; CPUCores=2; MemoryGB=7; Cost=4},  # Mid-range option
        @{Name="Standard_DS3_v2"; CPUCores=4; MemoryGB=14; Cost=5},  # Large option
        @{Name="Standard_DS4_v2"; CPUCores=8; MemoryGB=28; Cost=6}  # Largest/most expensive option
    )
    
    # Find current size in our tier list
    $currentSizeIndex = 0  # Default to first size
    for ($i = 0; $i -lt $vmSizeTiers.Count; $i++) {  # Loops through each size
        if ($vmSizeTiers[$i].Name -eq $currentSize) {  # If this is the current size
            $currentSizeIndex = $i  # Remember the index
            break  # Exit the loop
        }
    }
    
    # Determine recommended size based on utilization
    $recommendedSizeIndex = $currentSizeIndex  # Start with current size
    $recommendation = "current size is appropriate"  # Default recommendation text
    
    if ($cpuUtilization -lt 20 -and $memoryUtilization -lt 30) {  # If usage is low
        # Underutilized - recommend downsizing if possible
        if ($currentSizeIndex -gt 0) {  # If not already at smallest size
            $recommendedSizeIndex = $currentSizeIndex - 1  # Recommend one size smaller
            $recommendation = "downsizing (resource underutilization)"  # Update recommendation text
        }
    }
    elseif ($cpuUtilization -gt 80 -or $memoryUtilization -gt 80) {  # If usage is high
        # Overutilized - recommend upsizing
        if ($currentSizeIndex -lt ($vmSizeTiers.Count - 1)) {  # If not already at largest size
            $recommendedSizeIndex = $currentSizeIndex + 1  # Recommend one size larger
            $recommendation = "upsizing (resource constraints)"  # Update recommendation text
        }
    }
    
    $recommendedSize = $vmSizeTiers[$recommendedSizeIndex].Name  # Get the name of recommended size
    
    # Calculate estimated monthly cost difference (simplified)
    $currentCost = $vmSizeTiers[$currentSizeIndex].Cost * 730  # 730 hours in a month
    $recommendedCost = $vmSizeTiers[$recommendedSizeIndex].Cost * 730  # Calculate recommended monthly cost
    $costDifference = $recommendedCost - $currentCost  # Calculate difference
    $costChangePercent = [math]::Round((($recommendedCost - $currentCost) / $currentCost) * 100, 1)  # Calculate percentage change
    
    # Format cost strings
    $costImpact = if ($costDifference -eq 0) {  # If no cost change
        "No change"  # No impact
    }
    elseif ($costDifference -gt 0) {  # If cost increases
        "Increase of approximately $costChangePercent%"  # Show percent increase
    }
    else {  # If cost decreases
        "Decrease of approximately $($costChangePercent * -1)%"  # Show percent decrease (as positive number)
    }
    
    # Create result object
    $result = [PSCustomObject]@{  # Creates a custom object with all analysis results
        VMName = $VMName  # VM name
        ResourceGroup = $ResourceGroupName  # Resource group
        CurrentSize = $currentSize  # Current size
        RecommendedSize = $recommendedSize  # Recommended size
        Recommendation = $recommendation  # Recommendation text
        CPUUtilization = "$cpuUtilization%"  # CPU usage
        MemoryUtilization = "$memoryUtilization%"  # Memory usage
        CostImpact = $costImpact  # Cost impact
        CurrentSpecs = "$($vmSizeTiers[$currentSizeIndex].CPUCores) vCPUs, $($vmSizeTiers[$currentSizeIndex].MemoryGB) GB RAM"  # Current specifications
        RecommendedSpecs = "$($vmSizeTiers[$recommendedSizeIndex].CPUCores) vCPUs, $($vmSizeTiers[$recommendedSizeIndex].MemoryGB) GB RAM"  # Recommended specifications
        AnalysisDate = Get-Date -Format "yyyy-MM-dd HH:mm"  # Analysis timestamp
    }
    
    return $result  # Return the analysis results
}

# Main execution flow
Write-Log "VM Right-Sizing Analysis Tool - Enhanced Version"  # Shows script title
Write-Log "================================================"  # Shows separator line

# Get resource group (create new or use existing)
$resourceGroup = Get-ResourceGroup  # Calls function to get resource group name

# Get VM (create new or use existing)
$vmName = Get-VirtualMachine -ResourceGroupName $resourceGroup  # Calls function to get VM name

# Wait a moment if VM was just created
if ($vmName -like "TestVM-*") {  # If this looks like a newly created test VM
    Write-Log "Waiting for VM initialization..."  # Shows waiting message
    Start-Sleep -Seconds 20  # Pauses script for 20 seconds to let VM initialize
}

# Run analysis
$analysis = Get-VMRightSizingRecommendation -ResourceGroupName $resourceGroup -VMName $vmName  # Calls function to analyze VM

if ($analysis) {  # If analysis was successful (not null)
    # Display results
    Write-Host "`n==== Right-Sizing Analysis Results ====" -ForegroundColor Green  # Shows section header
    $analysis | Format-List  # Shows all analysis properties in list format
    
    # Export results to CSV
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"  # Creates timestamp for filename
    $csvPath = "VM-Sizing-$($vmName)-$timestamp.csv"  # Creates unique CSV filename
    $analysis | Export-Csv -Path $csvPath -NoTypeInformation  # Exports results to CSV file
    Write-Log "Analysis results exported to: $csvPath"  # Shows export location
    
    # Provide guidance on how to resize
    Write-Host "`n==== How to Implement This Recommendation ====" -ForegroundColor Green  # Shows section header
    if ($analysis.CurrentSize -ne $analysis.RecommendedSize) {  # If a change is recommended
        Write-Host "To resize the VM, use the following PowerShell commands:" -ForegroundColor Yellow  # Shows instruction
        Write-Host "# Step 1: Stop the VM (required for resizing)" -ForegroundColor White  # Shows step 1
        Write-Host "Stop-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Force" -ForegroundColor White  # Shows command for step 1
        Write-Host "`n# Step 2: Update the VM size" -ForegroundColor White  # Shows step 2
        Write-Host "`$vm = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName" -ForegroundColor White  # Shows command 1 for step 2
        Write-Host "`$vm.HardwareProfile.VmSize = '$($analysis.RecommendedSize)'" -ForegroundColor White  # Shows command 2 for step 2
        Write-Host "Update-AzVM -ResourceGroupName $resourceGroup -VM `$vm" -ForegroundColor White  # Shows command 3 for step 2
        Write-Host "`n# Step 3: Restart the VM" -ForegroundColor White  # Shows step 3
        Write-Host "Start-AzVM -ResourceGroupName $resourceGroup -Name $vmName" -ForegroundColor White  # Shows command for step 3
        Write-Host "`nNote: Resizing requires VM restart and may cause downtime." -ForegroundColor Yellow  # Shows important warning
    } else {  # If no change is recommended
        Write-Host "The current VM size is optimal. No action needed." -ForegroundColor Green  # Shows "no change needed" message
    }
    
    # Ask if user wants to cleanup
    if ($vmName -like "TestVM-*") {  # If this is a test VM
        Write-Host "`n==== Resource Cleanup ====" -ForegroundColor Green  # Shows section header
        $cleanup = Read-Host "Would you like to delete the test VM to avoid ongoing charges? (y/n)"  # Asks about cleanup
        
        if ($cleanup -eq "y" -or $cleanup -eq "Y") {  # If user answered yes
            Write-Log "Cleaning up test VM..."  # Shows progress
            Remove-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Force  # Deletes the VM
            Write-Log "VM deleted successfully."  # Shows success message
        }
    }
}

Write-Log "Analysis complete. Thank you for using the VM Right-Sizing Tool."  # Shows completion message