# Azure Administrator Toolkit

A collection of PowerShell scripts documenting my journey from technical support to cloud engineering. These scripts are designed to help with Azure administration tasks and AZ-104 certification preparation.

Coding comments provided in part by AI (Claude 3.7 Sonnet via GitHub Copilot).

## Script Library

### Resource Management
- **[AZ104-Cleanup](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-Cleanup.ps1)**  
  Safely removes Azure resources and users from a subscription with exception handling, confirmation prompts, and detailed logging.

- **[AZ104-Resource-Checker](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-Resource-Checker.ps1)**  
  Comprehensive inventory system for Azure environments with detailed reporting of subscriptions, resource groups, and resources.

- **[AZ104-Storage-Analyzer](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-Storage-Analyzer.ps1)**  
  Evaluates storage account security by comparing baseline configurations and generating vulnerability reports.

- **[AZ104-VM-RightSizing-Tool](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-VM-RightSizing-Tool.ps1)**  
  Interactive tool for analyzing VM resource utilization and providing cost-optimized sizing recommendations.

### Security & Access Control
- **[AZ104-Custom-RBAC-Roles](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-Custom-RBAC-Roles.ps1)**  
  Creates specialized role-based access control roles with granular permission sets.
  
- **[AZ104-RBAC-Auditor](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-RBAC-Auditor.ps1)**  
  Inventories and analyzes role assignments across subscriptions for security posture assessment.
  
- **[AZ104-Remove-Custom-Roles](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-Remove-Custom-Roles.ps1)**  
  Interactive workflow for managing and safely removing custom RBAC roles.
  
- **[AZ104-NSG-Analyzer](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-NSG-Analyzer.ps1)**  
  Identifies and remediates security vulnerabilities in Network Security Groups.

### Environment Setup & Testing
- **[AZ104-Launchpad](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-Launchpad.ps1)**  
  Establishes a validated Azure administration environment for certification practice.
  
- **[AZ104-Simple-DR](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-Simple-DR.ps1)**  
  Creates a lightweight disaster recovery solution with documentation and test procedures.
  
- **[AZ104-Test-Users](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-Test-Users.ps1)**  
  Creates test users and assigns custom RBAC roles for testing scenarios.
  
- **[AZ104-Remove-Test-Users](https://github.com/johnnymeintel/AZ104admintoolkit/blob/main/scripts/AZ104-Remove-Test-Users.ps1)**  
  Cleans up test user accounts when testing is complete.

## Usage

Each script is self-contained and includes detailed comments. Most scripts include interactive prompts to guide you through the necessary parameters and actions.

## Requirements

- PowerShell 5.1 or higher
- Az PowerShell module
- Azure subscription with appropriate permissions

## Additional Resources

For more information about these scripts and my cloud journey, visit https://medium.com/@johnnymeintel
