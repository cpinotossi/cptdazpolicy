# Azure Policy Demo

## wsl fix
~~~bash
sudo hwclock -s
sudo ntpdate time.windows.com
~~~

## Create Blob Storage

~~~bash
prefix=cptdazpolicy
location=germanywestcentral
currentUserObjectId=$(az ad signed-in-user show --query id -o tsv)
adminPassword='demo!pass123!'
adminUsername='chpinoto'
myip=$(curl ifconfig.io)
az deployment sub create -n $prefix -l $location --template-file deploy.bicep -p myobjectid=$myobjectid myip=$myip prefix=$prefix
# Verify IP ACL
az storage account show -n $prefix -g $prefix --query networkRuleSet.ipRules

# az group delete -g $prefix -l $location
~~~

## Create Append Policy
We like to add one more IP to our storage account ip ACL.
~~~bash

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
git commit -m"init"
git push origin main
git add .gitignore

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


