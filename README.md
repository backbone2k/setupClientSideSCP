# setupClientSideSCP
Script to create necessary registry values for ClientSideSCP hybrid join

The script setupClientSideSCP.ps1 prepares a client for clientSideSCP configuration by getting data from Azure AD or by parameter and configures the local registry

# examples
## example 1
PS > SetupClientSideSCP.ps1

The above example will start an automate discovery of your tenant id and name and create the apropriate registry key and 
values

## example 2
PS > SetupClientSideSCP.ps1 -tenantName contoso.com -tenantId 2dcc96e-488e-4587-9e64-554c6a5e3d34

This call will start a manual creation of the registry key and values. No Azure AD module and connection is required.

## example 3
PS > SetupClientSideSCP.ps1 -RemoveRegistryKey

This example will wipe the any previous registry key. 
