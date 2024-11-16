---
title: self-hosted runner
type: blog
date: 2024-11-01
tags:
  - github
  - actions-runner
summary: "GitHub Actions의 self-hosted runner를 서버에 구성하는 방법을 설명합니다. 여러 개의 runner를 동일한 서버에서 운영할 때 필요한 설정 방법과 주의사항을 다룹니다. 특히 SELinux가 활성화된 환경에서의 설치 위치, 디렉토리 구성, runner 이름 설정 등 실제 구축 시 필요한 상세한 가이드를 제공합니다."
---

안녕하세요 여러분,
원하는 만큼 러너를 가질 수 있습니다. 유일한 제한은 기계 용량입니다.
확실히 실행하려면 간단한 규칙을 따라야 합니다.

1. SELinux가 활성화된 서버에서 실행하면 사용자 홈에서 작동하지 않음, /opt/github와 같은 디렉토리로 이동하십시오.
2. 모든 러너는 별도의 디렉토리에서 실행되어야 합니다.
3. 모든 러너를 하나씩 구성해야 합니다.
4. 등록 토큰은 동일할 수 있지만 실행기 이름은 GitHub 리포지토리에서 고유해야 합니다.

다음은 예제입니다 ( 토디 현재 러너 버전은 2.299.1이므로 그에 따라 교체하십시오.

## 준비

이것은 사용자가 ec2-user 인 AWS ec2 vm에서 수행되며 루트가 아닌 사용자로 러너를 실행합니다.

```shell
mkdir /opt/github/action-runner-1
mkdir /opt/github/action-runner-2

cd opt/github/action-runner-1
curl -o actions-runner-linux-x64-2.299.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.299.1/actions-runner-linux-x64-2.299.1.tar.gz
tar xzf ./actions-runner-linux-x64-2.299.1.tar.gz

# this will copy your runner source code from dir 1 to dir 2.  You must do this step before configuring your first runner.
rsync -av /opt/github/action-runner-1/ /opt/github/action-runner-2/
```

## 구성

러너 # 1의 경우

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

러너 # 2의 경우

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

짜잔, 이제 2개의 Runner가 작동합니다.

https://github.com/enterprises/{YOUR-ENTERPRISE}/settings/actions/github-hosted-runners/new
