﻿<#
.Synopsis 
    This PowerShell script deploys the ProfileM Microservice
.Description 
    This PowerShell script deploys the ProfileM Microservice
    You must provide the connection strings from your DocumentDb and Redis Cache instances for this script to function
.Notes 
    File Name  : Deploy-ProfileM.ps1
    Author     : Bob Familiar
    Requires   : PowerShell V4 or above, PowerShell / ISE Elevated

    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help .\Deploy-ProfileM.ps1 [Null], [-Full], [-Detailed], [-Examples]

.Link   
    https://microservices.codeplex.com/

.Parameter Repo
    Example:  c:\users\bob\source\repos\looksfamiliar
.Parameter Subscription
    Example:  MySubscription
.Parameter AzureLocation
    Example:  East US
.Parameter Prefix
    Example:  looksfamiliar
.Parameter Suffix
    Example:  test
.Inputs
    The [Repo] parameter is the path to the Git Repo
    The [Subscription] parameter is the name of the client Azure subscription.
    The [AzureLocation] parameter is the name of the Azure Region/Location to host the Virtual Machines for this subscription.
    The [Prefix] parameter is the common prefix that will be used to name resources
    The [Suffix] parameter is one of 'dev', 'test' or 'prod'
.Outputs
    Console
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The path to the Git Repo.")]
    [string]$Repo,
    [Parameter(Mandatory=$True, Position=1, HelpMessage="The name of the Azure Subscription.")]
    [string]$Subscription,
    [Parameter(Mandatory=$True, Position=2, HelpMessage="The name of the Azure Region/Location: East US, Central US, West US.")]
    [string]$AzureLocation,
    [Parameter(Mandatory=$True, Position=3, HelpMessage="A unique user tag assigned for purposes of the lab")]
    [string]$UserTag,
    [switch]$DeployData
)

#######################################################################################
# V A R I A B L E S
#######################################################################################

$includePath = $Repo + "\HandsOnLabs\Automation\Include-ConnectionStrings.ps1"
."$includePath"

# name for resource group
$HOL_RG = "HOL_RG_" + $UserTag

$ProfileM_SP = $UserTag + "ProfileM_SP" + $UserTag

$ProfileM_DB = "ProfileM"

$ProfilePublicAPI = $UserTag + "ProfilePublicAPI" + $UserTag
$ProfileAdminAPI = $UserTag + "ProfileAdminAPI" + $UserTag

#######################################################################################
# F U N C T I O N S
#######################################################################################

Function Select-Subscription()
{
    Param([String] $Subscription)

    Try
    {
        Select-AzureSubscription -SubscriptionName $Subscription -ErrorAction Stop

        # List Subscription details if successfully connected.
        Get-AzureSubscription -Current -ErrorAction Stop

        Write-Verbose -Message "Currently selected Azure subscription is: $Subscription."
    }
    Catch
    {
        Write-Verbose -Message $Error[0].Exception.Message
        Write-Verbose -Message "Exiting due to exception: Subscription Not Selected."
    }
}

##########################################################################################
# M A I N
##########################################################################################

$Error.Clear()

# Mark the start time.
$StartTime = Get-Date

# Select Subscription
Select-Subscription $Subscription 

# Load DocumetnDb with User Profile data
if ($DeployData)
{
    $connStr = $docdbconnstr + "Database=" + $ProfileM_DB
    $command = $Repo + "\Automation\Common\Load-DocDb.ps1"
    &$command -Repo $Repo -Subscription $Subscription -DocDbConnStr $connStr -CollectionName ProfileCollection
}

# Package APIs
.\Package-ProfileM.ps1 $Repo

# Deploy the APIs and update their app settings for documentdb and redis
$command = $Repo + "\Automation\Common\Publish-WebSite.ps1"
&$command -Repo $Repo -ResourceGroupName $HOL_RG -DeploymentName ProfileAdminAPI  -Location $AzureLocation -SiteName $ProfileAdminAPI  -ServicePlan $ProfileM_SP -DocDbURI $docdburi -DocDbKEY $docdbkey -RedisURI $redisuri 
&$command -Repo $Repo -ResourceGroupName $HOL_RG -DeploymentName ProfilePublicAPI -Location $AzureLocation -SiteName $ProfilePublicAPI -ServicePlan $ProfileM_SP -DocDbURI $docdburi -DocDbKEY $docdbkey -RedisURI $redisuri 

# Mark the finish time.
$FinishTime = Get-Date

# Console output
$TotalTime = ($FinishTime - $StartTime).TotalSeconds
Write-Verbose -Message "Elapse Time (Seconds): $TotalTime"
