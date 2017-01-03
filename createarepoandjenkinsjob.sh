#!/bin/bash

# This script creates a new repo on github.dowjones.net, then does a berks cookbook, pushes to it the remote repo from the current directory and creates a jenkins job with the same name.
# This script gets a username from .gitconfig.  If it indicates that your default username is an empty string, you can set it with
# git config --add github.user YOUR_GIT_USERNAME

# Gather constant vars
CURRENTDIR=$PWD
GITHUB_CREDS=~/.ssh/github.curl
GITORG=DevOps-Cookbooks
JENKINS_CONFIG=config.xml
JENKINS_URL=http://djdo-jenkins01.dowjones.net:8080
REPO_TEMPLATE=git@github.dowjones.net:DevOps-Cookbooks/cookbook-template.git

# Get user input for git repo
echo "Enter the name for new github repo"
read REPONAME
echo "Enter description for your new repo, on one line, then <return>"
read DESCRIPTION

# Get user input for Jenkins job
echo "Enter the tenant name djin or djcs"
read TENANT
echo "Enter comma-separated list of email addresses for job notifications"
read EMAIL

echo "Will create a new repo named $REPONAME"
echo "on github.dowjones.net with this description:"
echo $DESCRIPTION
echo "Type 'y' to proceed, any other character to cancel."
read OK
if [ "$OK" != "y" ]; then
  echo "User cancelled"
  exit
fi

# Clone template cookbook
TEMP_PATH=$(mktemp -d /tmp/cb.XXXXXXXXXX)
cd ${TEMP_PATH}
git clone ${REPO_TEMPLATE} ${REPONAME}
cd $REPONAME
(cat <<EOF_GENERATE_METADATARB
name             '${REPONAME}'
maintainer       'YOUR_NAME'
maintainer_email '${EMAIL}'
license          'All rights reserved'
description      'Installs/Configures ${REPONAME}'
long_description 'Installs/Configures ${REPONAME}'
version          '0.1.0'
EOF_GENERATE_METADATARB
) &> metadata.rb
git add .
git commit -m "Created ${REPONAME} from template"

# Curl some json to the github API
# This creates a repo under a specific github org
curl -K ${GITHUB_CREDS} https://github.dowjones.net/api/v3/orgs/$GITORG/repos -d "{\"name\": \"$REPONAME\", \"description\": \"${DESCRIPTION}\", \"has_issues\": true, \"has_downloads\": true, \"has_wiki\": false}"

# Add remote to organizational unit repo
sleep 3
git remote add ${REPONAME} https://github.dowjones.net/$GITORG/$REPONAME.git
git push ${REPONAME} master

cd $CURRENTDIR

# Create Jenkins Job
sed -e 's/cookbook-test/'${REPONAME}'/g' -e 's/djin/'${TENANT}'/g' -e 's/EMAIL/'${EMAIL}'/g' -i.bak ${JENKINS_CONFIG}
curl -K ${GITHUB_CREDS} -X POST -H "Content-Type:application/xml" -d @${JENKINS_CONFIG} "${JENKINS_URL}/createItem?name=$REPONAME"

# Cleanup
git checkout ${JENKINS_CONFIG}
rm ${JENKINS_CONFIG}.bak
rm -rf $TEMP_PATH
