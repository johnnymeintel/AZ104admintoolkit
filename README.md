# Azure Administrator Toolkit

Scripts and resources documenting my journey from technical support to cloud engineering.


# AZ104-Cleanup

This PowerShell script automatically removes Azure resources and users from a subscription while allowing for exceptions to be preserved. It includes safety confirmations, detailed logging, and verification of cleanup results.


# AZ104-Custom-RBAC-Roles

This PowerShell script creates three custom RBAC (Role-Based Access Control) roles in Azure: Network Monitor, Storage Contributor, and DevSecOps Engineer, each with specific permissions tailored to different operational needs. The script establishes these roles within a specific resource group, ensuring granular access control by defining precise action permissions and limitations for each role.


# AZ104-Launchpad.ps1

This PowerShell script establishes and validates an Azure administration environment specifically designed for AZ-104 certification preparation. The script follows a methodical approach by verifying required modules, handling authentication with MFA support, creating a dedicated resource group with appropriate tagging, and providing comprehensive output of the configured environment—all while incorporating Azure administration best practices.


# AZ104-NSG-Analyzer

Establishes and analyzes Azure Network Security Groups (NSGs) to identify and remediate potential security vulnerabilities. The comprehensive script follows a structured approach by first defining analysis and remediation functions, then creating network resources with initial security rules, performing security analysis to identify risks, applying best practice security configurations, and finally generating detailed comparison reports with actionable recommendations for further security enhancements.


# AZ104-RBAC-Auditor

Comprehensive RBAC (Role-Based Access Control) auditing solution for Azure environments. The script systematically inventories and analyzes all role assignments across an Azure subscription or resource group, providing detailed insights into the security posture.


# AZ104-Remove-Custom-Roles

Provides an interactive workflow for managing custom Azure roles by first displaying all existing custom roles and then guiding administrators through a deletion process with appropriate confirmation safeguards. The script includes comprehensive error handling and continuously updates the roles list after deletions, ensuring administrators always work with current information throughout the session.


# AZ104-Remove-Test-Users

Simple script to remove the test users.


# AZ104-Resource-Checker

Inventory system for Azure environments with enhanced formatting and detailed output capabilities. The script methodically catalogs all subscriptions, resource groups, resources, Azure AD users, and role assignments, producing both color-coded console output and a plain text report file with timestamps for documentation purposes.


# AZ104-Simple-DR

Creates a lightweight disaster recovery solution for Azure by establishing storage resources, generating a sample configuration file, backing it up to blob storage, and creating recovery documentation and procedures. It guides users through an interactive setup process with sensible defaults, produces recovery scripts and runbooks, and offers an optional test of the recovery process.


# AZ104-Storage-Analyzer

Creates two Azure storage accounts with different security configurations and evaluates them using a custom security assessment function. The script establishes a baseline for comparison by creating one minimally secured storage account and one with enhanced security features, then generates a detailed security report that identifies specific vulnerabilities and calculates a security score for each account.


# AZ104-Test-Users

Simple script to create test users and asign the custom RBAC roles used in AZ104-Custom-RBAC-Roles


# AZ104-VM-RightSizing-Tool

Interactive tool for analyzing Azure virtual machines and providing right-sizing recommendations based on resource utilization metrics. The script guides users through selecting or creating Azure resources, collects simulated performance metrics, analyzes VM usage patterns, and delivers actionable recommendations with cost impact assessments and implementation guidance.
