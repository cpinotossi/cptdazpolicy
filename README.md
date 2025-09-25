# Azure Policy Demo


## Protoect Azure Resource Tags via Policy

~~~powershell
$prefix="cptdazpolicy"
$location="germanywestcentral"
$currentUserObjectId=az ad signed-in-user show --query id -o tsv
$subId = (Get-Content -Raw -Path "terraform.tfvars.json" | ConvertFrom-Json).subscription_id
az account set --subscription $subId 
mkdir denytagdelete
cd denytagdelete
tf init
tf apply --auto-approve
az network vnet show -g $prefix -n $prefix --query tags
~~~

### Create policy to protect force tunneling UDR.

~~~bash
# list all custom policies under current subscription
az policy definition list --subscription $subId --query "[?policyType=='Custom'].displayName" -o table
# create new policy to protect force tunneling UDR
az policy definition create --name "DenyTagDelete" --display-name "DenyTagDelete" --description "Deny Tag Delete " --rules policy.deny.tag.delete.json --mode Indexed
# show policy
az policy definition show --name "DenyTagDelete"
~~~

~~~json
{
  "description": "Deny Tag Delete ",
  "displayName": "DenyTagDelete",
  "id": "/subscriptions/65668fbe-24d6-410e-b9b7-b9e52a499caf/providers/Microsoft.Authorization/policyDefinitions/DenyTagDelete",
  "metadata": {
    "createdBy": "c1a139f7-6a1c-4c45-ae43-33c9b758e9c3",
    "createdOn": "2025-07-02T12:56:39.0268049Z",
    "updatedBy": null,
    "updatedOn": null
  },
  "mode": "Indexed",
  "name": "DenyTagDelete",
  "parameters": null,
  "policyRule": {
    "if": {
      "allOf": [
        {
          "equals": "Microsoft.Network/virtualNetworks",
          "field": "type"
        },
        {
          "exists": "true",
          "field": "tags.Network-Type"
        }
      ]
    },
    "then": {
      "details": {
        "actionNames": [
          "delete"
        ]
      },
      "effect": "denyAction"
    }
  },
  "policyType": "Custom",
  "systemData": {
    "createdAt": "2025-07-02T12:56:38.985942+00:00",
    "createdBy": "ga1@cptdx.net",
    "createdByType": "User",
    "lastModifiedAt": "2025-07-02T12:56:38.985942+00:00",
    "lastModifiedBy": "ga1@cptdx.net",
    "lastModifiedByType": "User"
  },
  "type": "Microsoft.Authorization/policyDefinitions"
}
~~~

### Protect our tag via Azure Policy

~~~bash
# assign policy
az policy assignment create --name "DenyTagDelete" --display-name "Deny Tag Delete" --policy "DenyTagDelete" --scope "/subscriptions/$subId/resourceGroups/$prefix"
az policy assignment show --name "DenyTagDelete" --scope "/subscriptions/$subId/resourceGroups/$prefix"
~~~

### Try to delete Tag via Azure CLI

~~~bash
# delete tag via azure cli
az network vnet update -g $prefix -n $prefix --set tags.Network-Type="Hub" # Does not deny, policy seems not to apply
az network vnet update -g $prefix -n $prefix --set tags.Network-Type="Spoke"
# delete a tag from Azure VNet via Azure CLI
az network vnet update -g $prefix -n $prefix --remove tags.Network-Type
~~~

### Conclusion

Not possible to protect tag modification or deletion via Azure Policy Action DenyAction.

## How to avoid UDR deletion

We will protect "force tunneling UDR" and "Route Table" via Azure Policy.


Create Infrastructure:

~~~bash
cd denyudrdelete
prefix=cptdazpolicy
location=germanywestcentral
currentUserObjectId=$(az ad signed-in-user show --query id -o tsv)
adminPassword='demo!pass123!'
adminUsername='chpinoto'
myip=$(curl ifconfig.io)
subId=$(az account show --query id -o tsv)
az deployment sub create -n $prefix -l $location --template-file main.bicep -p subscriptionId=$subId prefix=$prefix currentUserObjectId=$currentUserObjectId
~~~

### Test force tunneling UDR:

~~~bash
# show effective routes of nic
az network nic show-effective-route-table -g $prefix -n ${prefix}1 -o table
~~~

Source    State    Address Prefix    Next Hop Type     Next Hop IP
--------  -------  ----------------  ----------------  -------------
Default   Active   10.0.0.0/16       VnetLocal
Default   Active   10.1.0.0/16       VNetPeering
Default   Invalid  0.0.0.0/0         Internet
User      Active   0.0.0.0/0         VirtualAppliance  10.1.0.4


~~~bash
# show all routes
az network route-table route list -g $prefix --route-table-name $prefix -o table
~~~

AddressPrefix    HasBgpOverride    Name            NextHopIpAddress    NextHopType       ProvisioningState    ResourceGroup
---------------  ----------------  --------------  ------------------  ----------------  -------------------  ---------------
0.0.0.0/0        False             forceTunneling  10.1.0.4            VirtualAppliance  Succeeded            cptdazpolicy


~~~bash
# get firewall public ip
az network public-ip show -g $prefix -n ${prefix}fw -o tsv --query ipAddress # 4.184.94.213
# send curl request via serial console of vm via azure cli
az vm run-command invoke -g $prefix -n ${prefix}1 --command-id RunShellScript --scripts 'curl https://ifconfig.io' 
~~~

Our curl request has been send via the firewall public ip 4.184.94.213
~~~json
{
  "value": [
    {
      "code": "ProvisioningState/succeeded",
      "displayStatus": "Provisioning succeeded",
      "level": "Info",
      "message": "Enable succeeded: \n[stdout]\n4.184.94.213\n\n[stderr]\n  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current\n                                 Dload  Upload   Total   Spent    Left  Speed\n\r  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0\r100    13  100    13    0     0     31      0 --:--:-- --:--:-- --:--:--    31\n",
      "time": null
    }
  ]
}
~~~

### Create policy to protect force tunneling UDR.

~~~bash
# list all custom policies under current subscription
az policy definition list --subscription $subId --query "[?policyType=='Custom'].displayName" -o table
# create new policy to protect force tunneling UDR
az policy definition create --name "DenyUDRDelete" --display-name "DenyUDRDelete" --description "Deny UDR Delete " --rules policy.deny.udr.delete.json --mode All
# show policy
az policy definition show --name "DenyUDRDelete" | sed 's|/subscriptions/.*/providers||g'
~~~

~~~json
{
  "description": "Deny UDR Delete ",
  "displayName": "DenyUDRDelete",
  "id": "/Microsoft.Authorization/policyDefinitions/DenyUDRDelete",
  "metadata": {
    "createdBy": "842e630f-0d53-45be-a9d8-abc4bf36076c",
    "createdOn": "2023-12-20T09:35:25.1693585Z",
    "updatedBy": null,
    "updatedOn": null
  },
  "mode": "Indexed",
  "name": "DenyUDRDelete",
  "parameters": null,
  "policyRule": {
    "if": {
      "allOf": [
        {
          "equals": "Microsoft.Network/routeTables/routes",
          "field": "type"
        },
        {
          "anyOf": [
            {
              "not": {
                "field": "Microsoft.Network/routeTables/routes[*].addressPrefix",
                "notEquals": "0.0.0.0/0"
              }
            },
            {
              "equals": "0.0.0.0/0",
              "field": "Microsoft.Network/routeTables/routes/addressPrefix"
            }
          ]
        }
      ]
    },
    "then": {
      "details": {
        "actionNames": [
          "delete"
        ]
      },
      "effect": "denyAction"
    }
  },
  "policyType": "Custom",
  "systemData": {
    "createdAt": "2023-12-20T09:35:25.138715+00:00",
    "createdBy": "ga@myedge.org",
    "createdByType": "User",
    "lastModifiedAt": "2023-12-20T09:35:25.138715+00:00",
    "lastModifiedBy": "ga@myedge.org",
    "lastModifiedByType": "User"
  },
  "type": "Microsoft.Authorization/policyDefinitions"
}
~~~

### Protect our force tunnel UDR via Azure Policy

~~~bash
# assign policy
az policy assignment create --name "DenyUDRDelete" --display-name "Deny UDR Delete" --policy "DenyUDRDelete" --scope "/subscriptions/$subId/resourceGroups/$prefix"
# I can see the assignment via the portal but not via azure cli
az policy assignment list --scope "/subscriptions/$subId" # not working
az policy assignment show --name "DenyUDRDelete" --scope "/subscriptions/$subId" # not working
az policy assignment list -o table # not working
az policy assignment list --query "[?name=='DenyUDRDelete']" -o table # not working
~~~

### Try to delete UDR via Azure CLI

~~~bash
# delete route rule via azure cli
az network route-table route delete -g $prefix --route-table-name $prefix -n forceTunneling # Result (RequestDisallowedByPolicy) Deletion of resource 'forceTunneling' was disallowed by policy. Policy identifiers: '[{"policyAssignment":{"name":"Deny UDR Delete","id":"
az network route-table route list -g $prefix --route-table-name $prefix -o table # force tunneling route is still there
~~~

### Protect our Route Table via Azure Policy

~~~bash
# create new policy to protect force tunneling UDR
az policy definition create --name "DenyRTDelete" --display-name "DenyRTDelete" --description "Deny Route Table Delete " --rules policy.deny.rt.delete.json --mode All
# list all custom policies under current subscription
az policy definition list --subscription $subId --query "[?policyType=='Custom'].displayName" -o table
# assign policy
az policy assignment create --name "DenyRTDelete" --display-name "Deny RT Delete" --policy "DenyRTDelete" --scope "/subscriptions/$subId/resourceGroups/$prefix"
~~~

### Try to delete Route Table via Azure CLI

~~~bash
az network route-table delete -g $prefix -n $prefix # Result: (RequestDisallowedByPolicy) Deletion of resource 'cptdazpolicy' was disallowed by policy. Policy identifiers: '[{"policyAssignment":{"name":"Deny RT Delete"
~~~

### Cleanup (WORK IN PROGRESS)

~~~bash
az policy definition delete --name "Deny UDR Delete" --verbose
~~~

## Misc

### Azure CLI

Find all ip configurations of our subnet
~~~bash
# get subnet ipconfigurations
az rest --method get --uri https://management.azure.com/subscriptions/$subId/resourceGroups/$prefix/providers/Microsoft.Network/virtualNetworks/$prefix/subnets/$prefix?api-version=2021-02-01 | sed 's|/subscriptions/.*/providers||g'
~~~

~~~json
{
  "etag": "W/\"4b29ebdb-d37d-4560-8fa9-33c83cc17ef3\"",
  "id": "/Microsoft.Network/virtualNetworks/cptdazpolicy/subnets/cptdazpolicy",
  "name": "cptdazpolicy",
  "properties": {
    "addressPrefix": "10.0.0.0/24",
    "delegations": [],
    "ipConfigurations": [
      {
        "id": "/Microsoft.Network/networkInterfaces/CPTDAZPOLICY/ipConfigurations/CPTDAZPOLICY"
      }
    ],
    "privateEndpointNetworkPolicies": "Disabled",
    "privateLinkServiceNetworkPolicies": "Enabled",
    "provisioningState": "Succeeded",
    "routeTable": {
      "id": "/Microsoft.Network/routeTables/cptdazpolicy"
    }
  },
  "type": "Microsoft.Network/virtualNetworks/subnets"
}
~~~

~~~json
{
  "etag": "W/\"e965fda5-34ba-460c-8d70-77e140ddff5c\"",
  "id": "/Microsoft.Network/networkInterfaces/cptdazpolicy/ipConfigurations/cptdazpolicy",
  "name": "cptdazpolicy",
  "properties": {
    "primary": true,
    "privateIPAddress": "10.0.0.4",
    "privateIPAddressVersion": "IPv4",
    "privateIPAllocationMethod": "Static",
    "provisioningState": "Succeeded",
    "subnet": {
      "id": "/Microsoft.Network/virtualNetworks/cptdazpolicy/subnets/cptdazpolicy"
    }
  },
  "type": "Microsoft.Network/networkInterfaces/ipConfigurations"
}
~~~



## Misc

### Build Azure infra

~~~bash
sudo hwclock -s
sudo ntpdate time.windows.com
prefix=cptdazasa
location=westeurope
myip=$(curl ifconfig.io) # Just in case we like to whitelist our own ip.
myobjectid=$(az ad user list --query '[?displayName==`ga`].id' -o tsv) 
plan=standard
relativePath=complete/target/demo-0.0.1-SNAPSHOT.jar
az deployment sub create -n $prefix -l $location --template-file infra/main.bicep -p environmentName=$prefix principalId=$myobjectid location=$location plan=$plan relativePath=$relativePath

az deployment sub create --name spring-apps --location westeurope --template-file infra/azuredeploy.json 
~~~

### Deploy the app to Azure Spring Apps

~~~bash
cd complete
./mvnw com.microsoft.azure:azure-spring-apps-maven-plugin:1.18.0:config
# Configurations are saved to: /mnt/c/Users/chpinoto/workspace/cptdazasa/complete/pom.xml
./mvnw com.microsoft.azure:azure-spring-apps-maven-plugin:1.18.0:deploy
curl -v https://asa-n7om2xjayn2ls-demo.azuremicroservices.io
curl -v https://asa-n7om2xjayn2ls-demo.azuremicroservices.io/hello?name=batman
~~~


### github
~~~ bash
# Create a repo at github
gh repo create cptdazpolicy --private
git init
git remote add origin https://github.com/cpinotossi/cptdazpolicy.git
git remote -v # list remotes
git status
git add .
git commit -m"protect dns via policy"
git push origin main
git add .gitignore
gh api repos/{owner}/{repo} --jq '.private'


# Add Azure DevOps as remote
git remote rename origin mslearning
git remote remove mslearning
git push --set-upstream origin master #set default remote
git remote -v
# Add github as remote
git remote add github https://github.com/cpinotossi/cptdazpipline.git
git remote -v
git push github && git push azuredevops #push to both in one line 
git push github main
# git push -u origin --all
# git remote add origin https://github.com/cpinotossi/$prefix.git

git remote -h
git config --global credential.helper 'cache --timeout=36000'
git push origin main
git rm README.md # unstage
git config advice.addIgnoredFile false
git pull origin main
git merge 
origin main
git config pull.rebase false

git log --oneline --decorate // List commits
git tag -a v1 e1284bf //tag my last commit
git push origin master


git tag //list local repo tags
git ls-remote --tags origin //list remote repo tags
git fetch --all --tags // get all remote tags into my local repo

git log --pretty=oneline //list commits


git checkout v1
git switch - //switch back to current version
co //Push all my local tags
git push origin <tagname> //Push a specific tag
git commit -m"not transient"
git tag v1
git push origin v1
git tag -l
git fetch --tags
git clone -b <git-tagname> <repository-url> 

## git branch
gh issue list
git branch --list
git branch iss1 # create branch for issue#1
git checkout iss1 # switch to branch iss1

## git commit
git log # list commits
~~~


