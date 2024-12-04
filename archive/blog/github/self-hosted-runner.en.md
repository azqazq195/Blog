---
title: self-hosted runner
type: blog
date: 2024-11-01
tags:
  - github
  - actions-runner
summary: "Learn how to set up GitHub Actions self-hosted runners on your server. This guide covers configuration methods and important considerations when running multiple runners on the same server. It provides detailed guidance on installation locations, directory structure, runner naming, and specific instructions for SELinux-enabled environments."
---

Hey there! 
You can have as many runners as you want - the only limit is your machine's capacity. 
To make sure everything runs smoothly, just follow these simple rules:

1. If you're running on a server with SELinux enabled, don't run from user's home - move to a directory like /opt/github
2. Each runner needs to run from its own directory
3. You need to configure each runner one by one
4. Registration tokens can be the same, but runner names must be unique within your GitHub repository

Here's an example (replace 2.299.1 with the current runner version as needed):

## Preparation

This is performed on an AWS EC2 VM where the user is ec2-user, running runners as a non-root user.

```shell
mkdir /opt/github/action-runner-1
mkdir /opt/github/action-runner-2

cd opt/github/action-runner-1
curl -o actions-runner-linux-x64-2.299.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.299.1/actions-runner-linux-x64-2.299.1.tar.gz
tar xzf ./actions-runner-linux-x64-2.299.1.tar.gz

# this will copy your runner source code from dir 1 to dir 2.  You must do this step before configuring your first runner.
rsync -av /opt/github/action-runner-1/ /opt/github/action-runner-2/
```

## Configuration

For runner #1:

```shell
cd opt/github/action-runner-1
./config.sh --url https://github.com/YourORG/YourRepo --token **** (Your token from github)

# You enter the group and a unique name: --> runner-1

# here we  create a startup script on an AWS ec2 machine that as the current usermame  ec2-user
sudo ./svc.sh install ec2-user

# Then you start your new service depending on what you get from previous step
sudo systemctl start actions.runner.YourOrg-OrRepo.runner-1.service

# You should see your firt runner in your github repos or Org
```

For runner #2:

```shell
cd opt/github/action-runner-2
./config.sh --url https://github.com/YourOrg/YourRepo --token **** (Your token from github)

# You enter the group and a unique name: --> runner-2

# here we  create a startup script on an AWS ec2 machine that as ec2-user
sudo ./svc.sh install ec2-user

#Then you start your new service depending on what you get from previous step
sudo systemctl start actions.runner.YourOrg-OrRepo.unner-2.service

# You should see your second runner in your github repos or Org
```

And voila! You now have 2 runners up and running.

https://github.com/enterprises/{YOUR-ENTERPRISE}/settings/actions/github-hosted-runners/new
