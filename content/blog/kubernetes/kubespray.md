---
title: Kubespray 시작하기
type: blog
date: 2024-12-25
tags:
  - kubernetes
  - kubespray
summary: "Kubespray를 활용하여 Kubernetes 클러스터를 구축하는 방법을 상세히 설명합니다. Vagrant와 VMware를 이용한 실습 환경 구성부터, Kubespray 설치, 클러스터 배포, 그리고 kubeconfig 설정까지의 전체 과정을 다룹니다. 특히 실제 환경과 실습 환경에서의 차이점을 비교하며, 각 단계별 구체적인 설정 방법을 제시합니다."
---

## 사내 서버 관리를 위한 [Kubespray](https://github.com/kubernetes-sigs/kubespray) 도입 배경 및 선택 이유

### 도입 배경

재직 중인 회사에서 사내 서버 관리의 필요성이 대두되었습니다. 현재는 여러 제품의 개발 배포, 실습용 가상 환경 관리, 서버 접근 관리 등을 각 직원이 개별적으로 수행하고 있어, 자원 간 충돌이나 관리 부실 등의 문제가 발생하고 있습니다. 이러한 문제를 해결하기 위해 'If Kakao 2024' 컨퍼런스에서 소개된 카카오의 사내 서버 관리 방식을 참고하였습니다. 카카오는 Kubernetes를 비롯하여 다양한 VM, Packer, Ansible을 활용한 프로비저닝으로 서버를 관리하고 있었습니다. 그러나 당사의 경우, 이러한 복잡한 관리 방식은 과도하다고 판단하여, Kubernetes를 활용한 서버 관리 방식을 도입하기로 결정하였습니다.

### Kubespray 선택 이유

Kubespray는 Ansible 기반의 자동화 도구로, 사내 환경에 Kubernetes 클러스터를 구축하고 관리하는 데 있어 다음과 같은 장점을 제공합니다:

- **관리 작업 최소화**: Ansible 플레이북을 통해 설치 및 구성을 자동화하여 수작업을 줄이고, 효율적인 관리가 가능합니다.

- **다양한 플랫폼 지원**: 베어메탈 서버부터 AWS, GCE, Azure, OpenStack 등 다양한 환경에서 Kubernetes 클러스터를 구축할 수 있어, 사내 인프라에 유연하게 적용할 수 있습니다.

- **고급 기능 제공**: 고가용성(HA) 구성, 다양한 네트워크 플러그인 지원, 클러스터 확장 및 업그레이드 등 프로덕션 환경에서 필요한 기능을 제공합니다.

- **사용자 정의 가능**: Ansible의 특성을 활용하여 클러스터 설정을 세밀하게 조정하고, 조직의 요구에 맞게 커스터마이징할 수 있습니다.

이러한 이유로, 사내 서버 관리의 효율성을 높이고 관리 작업을 최소화하기 위해 Kubespray를 선택하였습니다.

{{% details title="Kubernetes 관리 도구 비교표" closed="true" %}}

| **특징**              | **kubeadm**                                                                | **Kubespray**                                                             | **kops**                                         |
| --------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------ |
| **관리 방식**         | CLI 도구                                                                   | Ansible 플레이북 기반                                                     | CLI 도구                                         |
| **지원 환경**         | 온프레미스 및 다양한 클라우드 환경                                         | AWS, GCE, Azure, OpenStack, 베어메탈 등 다양한 플랫폼 지원                | 주로 AWS 및 GCE와 같은 클라우드 환경 지원        |
| **자동화 수준**       | 클러스터 초기화 및 노드 추가에 중점                                        | 클러스터 설치, 구성, 업그레이드 등 전체 라이프사이클 관리 자동화          | 클라우드 네이티브 자동화 기능 제공               |
| **사용자 편의성**     | 간단한 명령어로 클러스터 설정 가능                                         | 설정 파일을 통한 세밀한 구성 가능                                         | CLI 명령어를 통한 간단한 설치 및 관리            |
| **확장성**            | 제한된 사용자 정의 가능                                                    | 다양한 네트워크 플러그인 및 구성 요소 선택 가능                           | Terraform과의 통합을 통한 확장성 제공            |
| **사용 사례**         | 단일 클러스터 및 온프레미스 환경                                           | 다양한 클러스터 및 온프레미스 환경, 특히 Ansible에 익숙한 사용자에게 적합 | 클라우드 환경에서의 간편한 클러스터 설치 및 관리 |
| **고가용성 지원**     | 기본적으로 단일 마스터 노드를 가정하며, 고가용성을 위해 추가적인 구성 필요 | 다중 마스터 노드를 지원하며, 고가용성 구성을 쉽게 설정 가능               | 고가용성 클러스터 구성을 지원                    |
| **구성 관리**         | 클러스터 구성 관리를 위한 추가 도구 필요                                   | Ansible을 통한 구성 관리 및 자동화 기능 제공                              | 클러스터 구성 관리를 위한 기본 기능 제공         |
| **네트워크 플러그인** | 기본 네트워크 플러그인 지원                                                | Calico, Flannel 등 다양한 네트워크 플러그인 선택 가능                     | 기본 네트워크 플러그인 지원                      |
| **커뮤니티 및 지원**  | Kubernetes 공식 도구로서 활발한 커뮤니티 지원                              | Kubernetes의 서브 프로젝트로서 활발한 커뮤니티 지원                       | Kubernetes 커뮤니티에서 지원                     |

{{% / details %}}

## 실습 환경 구성

Kubespray 실습을 위해 Vagrant와 VMware를 활용하여 가상의 클러스터 환경을 구성해보겠습니다. 이 환경은 1개의 마스터 노드와 2개의 워커 노드로 구성됩니다. 이번 포스팅은 Kubespray 위주로 Vagrant에 대해서는 간단하게 넘어가겠습니다. 사내에서 VM으로 적용하는 경우 사용하시는 **관련 라이선스를 꼭 확인해 주세요.**

### 사전 준비

- VMware Fusion 설치 (Mac OS 기준)
- Vagrant 설치
- Vagrant VMware Utility 설치
- Vagrant Desktop Provider Plugin 설치
- SSH 키 생성 (`~/.ssh/id_rsa.pub`)

### Vagrantfile 작성

실습 환경을 위한 Vagrantfile을 작성합니다. 이 파일은 다음과 같은 특징을 가집니다:

- Ubuntu 24.04 LTS 기반의 VM 이미지 사용
- 3개의 노드 구성 (1 마스터 + 2 워커)
- 노드별 리소스 할당 (CPU 2코어, 메모리 2GB)
- 두 개의 네트워크 인터페이스 구성
  - 호스트-게스트 통신용 private_network (192.168.56.x)
  - 클러스터 내부 통신용 private_network (10.3.0.x)

{{< filetree/container >}}
{{< filetree/file name="Vagrantfile" >}}
{{< /filetree/container >}}

{{% details title="Vagrantfile" closed="true" %}}

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  BOX_IMAGE = "gutehall/ubuntu24-04"

  # VM 구성
  NODES = [
    { :hostname => "master", :ip => "192.168.56.10", :ip_internal => "10.3.0.1", :memory => 2048, :cpus => 2 },
    { :hostname => "worker1", :ip => "192.168.56.11", :ip_internal => "10.3.0.2", :memory => 2048, :cpus => 2 },
    { :hostname => "worker2", :ip => "192.168.56.12", :ip_internal => "10.3.0.3", :memory => 2048, :cpus => 2 }
  ]

  # 각 노드 설정
  NODES.each do |node|
    config.vm.define node[:hostname] do |nodeconfig|
      nodeconfig.vm.box = BOX_IMAGE
      nodeconfig.vm.hostname = node[:hostname]

      # VMware Fusion provider 설정
      nodeconfig.vm.provider "vmware_desktop" do |v|
        v.memory = node[:memory]
        v.cpus = node[:cpus]
        v.gui = false
      end

      # SSH 키 복사 방지
      nodeconfig.ssh.insert_key = false

      # 네트워크 설정
      nodeconfig.vm.network "private_network", ip: node[:ip]
      nodeconfig.vm.network "private_network", ip: node[:ip_internal]

      # SSH 키 설정
      nodeconfig.vm.provision "shell" do |s|
        ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip
        s.args = [ssh_pub_key]
        s.inline = <<-SHELL
          mkdir -p /root/.ssh
          echo $1 >> /root/.ssh/authorized_keys
          mkdir -p /home/vagrant/.ssh
          echo $1 >> /home/vagrant/.ssh/authorized_keys
          chown -R vagrant:vagrant /home/vagrant/.ssh
        SHELL
      end

    end
  end
end
```

{{% / details %}}

### VM 환경 구성하기

아래 명령어를 통해 VM 환경을 구성합니다. 최초 실행 시 VM 이미지 다운로드로 인해 시간이 소요될 수 있습니다.

```shell
vagrant up
```

`vagrant status` 명령어를 통해 각 노드의 실행 상태를 확인합니다.

```shell
> vagrant status
Current machine states:

master                    running (vmware_desktop)
worker1                   running (vmware_desktop)
worker2                   running (vmware_desktop)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
```

### 기타 Vagrant 명령어

```shell
# VM 실행
vagrant up

# VM 중단
vagrant halt

# 프로비저닝 재실행 (VM 실행 중에 설정 변경 시)
vagrant provision

# VM 초기화 후 재시작
vagrant destroy -f
vagrant up
```

Kubespray를 통한 Kubernetes 클러스터 구축을 위한 VM을 구성하였습니다. 이제 Kubespray를 구성하는 방법을 살펴보겠습니다.

## Kubespray 시작하기

이제 Vagrant로 구성한 환경에 Kubespray를 사용하여 Kubernetes 클러스터를 구축해보겠습니다. 여기서는 [Kubespray 공식 가이드](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/getting_started/getting-started.md)를 기반으로 진행합니다.

### Kubespray 저장소 clone

먼저 Kubespray 저장소를 로컬 환경에 클론합니다.

```shell
git clone https://github.com/kubernetes-sigs/kubespray.git
```

{{< filetree/container >}}
{{< filetree/folder name="kubespray">}}
{{< /filetree/folder >}}
{{< filetree/file name="Vagrantfile" >}}
{{< /filetree/container >}}

### Inventory 구성

Kubespray는 Ansible을 기반으로 하므로, 클러스터 구성을 위한 인벤토리 파일이 필요합니다. 샘플 인벤토리를 복사하여 시작합니다:

```shell
cd kubespray
cp -r ./inventory/sample ./inventory/mycluster
```

{{< filetree/container >}}
{{< filetree/folder name="kubespray">}}
{{< filetree/folder name="inventory">}}
{{< filetree/folder name="sample">}}
{{< /filetree/folder >}}
{{< filetree/folder name="mycluster">}}
{{< /filetree/folder >}}
{{< /filetree/folder >}}
{{< /filetree/folder >}}
{{< filetree/file name="Vagrantfile" >}}
{{< /filetree/container >}}

#### Inventory 파일 살펴보기

`inventory/mycluster/inventory.ini` 파일은 클러스터를 구성하는 노드들의 역할과 설정을 정의합니다. 기본 샘플 파일의 주요 구성 요소를 살펴보겠습니다:

```ini
# This inventory describe a HA typology with stacked etcd (== same nodes as control plane)
# and 3 worker nodes
# See https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html
# for tips on building your # inventory

# Configure 'ip' variable to bind kubernetes services on a different ip than the default iface
# We should set etcd_member_name for etcd cluster. The node that are not etcd members do not need to set the value,
# or can set the empty string value.
[kube_control_plane]
# node1 ansible_host=95.54.0.12  # ip=10.3.0.1 etcd_member_name=etcd1
# node2 ansible_host=95.54.0.13  # ip=10.3.0.2 etcd_member_name=etcd2
# node3 ansible_host=95.54.0.14  # ip=10.3.0.3 etcd_member_name=etcd3

[etcd:children]
kube_control_plane

[kube_node]
# node4 ansible_host=95.54.0.15  # ip=10.3.0.4
# node5 ansible_host=95.54.0.16  # ip=10.3.0.5
# node6 ansible_host=95.54.0.17  # ip=10.3.0.6
```

- `[kube_control_plane]`
  - Kubernetes 컨트롤 플레인이 실행될 노드들을 정의합니다
  - 마스터 노드라고도 불리며, API 서버, 컨트롤러 매니저, 스케줄러가 실행됩니다
  - 고가용성(HA) 구성을 위해 여러 노드를 지정할 수 있습니다
- `[etcd:children]`
  - etcd 클러스터를 구성하는 노드들을 지정합니다
  - children 지시자를 사용하여 kube_control_plane 그룹의 모든 노드를 etcd 멤버로 설정
  - 이를 "stacked topology"라고 하며, 컨트롤 플레인 노드에서 etcd도 함께 실행되는 구성입니다
- `[kube_node]`
  - 실제 워크로드가 실행될 워커 노드들을 정의합니다
  - 애플리케이션 파드들이 스케줄링되어 실행되는 노드들입니다

#### Inventory 파일 구성

앞서 Vagrant로 구성한 환경에 맞춰 inventory 파일을 작성해보겠습니다. 우리 환경은 1개의 마스터 노드와 2개의 워커 노드로 구성되어 있으며, 각각 다음과 같은 역할을 부여할 것입니다:

- master (node1): 컨트롤 플레인
- worker1 (node2): 워커 노드 + etcd
- worker2 (node3): 워커 노드 + etcd

`inventory/mycluster/inventory.ini` 파일을 다음과 같이 작성합니다:

```ini
# 노드 기본 정보 정의
node1 ansible_user=vagrant ansible_host=192.168.56.10 ip=10.3.0.1
node2 ansible_user=vagrant ansible_host=192.168.56.11 ip=10.3.0.2
node3 ansible_user=vagrant ansible_host=192.168.56.12 ip=10.3.0.3

# 컨트롤 플레인 노드 지정
[kube_control_plane]
node1

# etcd 클러스터 구성
[etcd]
node1
node2
node3

# 워커 노드 지정
[kube_node]
node2
node3
```

노드 기본 정보

- ansible_user: Ansible이 SSH 접속 시 사용할 사용자 계정 (Vagrant VM의 기본 사용자)
- ansible_host: 노드의 외부 접속 IP (Vagrant의 첫 번째 private_network)
- ip: 쿠버네티스 내부 통신용 IP (Vagrant의 두 번째 private_network)

etcd 구성

- 고가용성과 데이터 안정성을 위해 3개의 노드로 구성
- etcd는 분산 합의(consensus) 알고리즘을 사용하므로, 공식 문서에서 권장하는 대로 홀수 개의 노드로 구성

더 복잡한 구성이 필요한 경우 (예: Bastion 호스트 사용, 추가 네트워크 설정, 노드 레이블링 등) [인벤토리 가이드](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/ansible/inventory.md)를 참조해 주세요.

### Kubespray 설치 및 배포

이제 준비된 환경에 Kubernetes 클러스터를 배포해보겠습니다. Kubespray는 Python과 Ansible을 기반으로 동작하므로, 먼저 필요한 의존성을 설치합니다.

#### Python 가상환경 설정

의존성 충돌을 방지하고 클린한 환경을 위해 Python 가상환경을 사용합니다.

```shell
# kubespray 디렉토리에서
python3 -m venv venv
source venv/bin/activate
pip install -U -r requirements.txt
```

{{< callout type="warning" >}}
[Kubespray 공식 문서](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/ansible/ansible.md#installing-ansible)에서는 Python 3.10-3.12를 지원한다고 명시되어 있지만, Python 3.13.1에서도 정상 동작이 확인되었습니다.
{{< /callout >}}

설치가 완료되면 `ansible --version` 커맨드로 Ansible 버전을 확인합니다.

```shell
> ansible --version
ansible [core 2.16.14]
  config file = /Users/seongha.moon/Documents/blog-code-example/kubernetes/kubespray/ansible.cfg
  configured module search path = ['/Users/seongha.moon/Documents/blog-code-example/kubernetes/kubespray/library']
  ansible python module location = /Users/seongha.moon/Documents/blog-code-example/kubernetes/kubespray/venv/lib/python3.13/site-packages/ansible
  ansible collection location = /Users/seongha.moon/.ansible/collections:/usr/share/ansible/collections
  executable location = /Users/seongha.moon/Documents/blog-code-example/kubernetes/kubespray/venv/bin/ansible
  python version = 3.13.1 (main, Dec  3 2024, 17:59:52) [Clang 16.0.0 (clang-1600.0.26.4)] (/Users/seongha.moon/Documents/blog-code-example/kubernetes/kubespray/venv/bin/python3.13)
  jinja version = 3.1.5
  libyaml = True
```

#### 호스트 접근 확인

클러스터 구성 전에 모든 노드에 대한 SSH 접근이 정상적으로 이루어지는지 확인합니다.

```shell
ansible all -i inventory/mycluster/inventory.ini -m ping --private-key=~/.ssh/<your-private-key>
```

ansible 옵션 설명:

- `-i`: 인벤토리 파일 경로 지정
- `-b`: become (sudo 권한 사용)
- `-v`: verbose 모드 (상세 로그 출력)
- `--private-key`: SSH 접속에 사용할 개인키 지정, Vagrant에서 VM 설정하면서 사용한 개인키 경로 입니다.

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/kubernetes/kubespray/ansible-ping.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>Ansible hosts ping 확인</figcaption>
</figure>

#### Kubernetes 클러스터 배포

ping까지 이상없이 확인이 완료되었다면 마지막으로 Kubernetes 클러스터를 배포합니다.

```shell
# kubespray dir
ansible-playbook -i inventory/mycluster/inventory.ini cluster.yml -b -v --private-key=~/.ssh/<your-private-key>
```

Macbook M3 Pro 칩 기준으로 배포과정은 약 20분 정도 소요 되었습니다.

```shell
PLAY RECAP *************************************************************************************************************************
node1                      : ok=660  changed=141  unreachable=0    failed=0    skipped=1071 rescued=0    ignored=6
node2                      : ok=520  changed=111  unreachable=0    failed=0    skipped=695  rescued=0    ignored=2
node3                      : ok=520  changed=111  unreachable=0    failed=0    skipped=693  rescued=0    ignored=2

수요일 25 12월 2024  17:48:50 +0900 (0:00:00.080)       0:21:11.858 ***************
===============================================================================
kubernetes/preinstall : Ensure kubelet expected parameters are set --------------------------------------------------------- 91.00s
kubernetes/preinstall : Create kubernetes directories ---------------------------------------------------------------------- 60.67s
Gather necessary facts (hardware) ------------------------------------------------------------------------------------------ 30.73s
kubernetes/preinstall : Write Kubespray DNS settings to systemd-resolved --------------------------------------------------- 30.46s
Gather necessary facts (network) ------------------------------------------------------------------------------------------- 30.43s
kubernetes/preinstall : Remove swapfile from /etc/fstab -------------------------------------------------------------------- 30.42s
kubernetes/preinstall : Create cni directories ----------------------------------------------------------------------------- 30.36s
kubernetes/preinstall : Create other directories of root owner ------------------------------------------------------------- 30.35s
Gather minimal facts ------------------------------------------------------------------------------------------------------- 30.34s
kubernetes/preinstall : Clean previously used sysctl file locations -------------------------------------------------------- 30.33s
kubernetes/preinstall : Update package management cache (APT) -------------------------------------------------------------- 27.38s
bootstrap-os : Assign inventory name to unconfigured hostnames (non-CoreOS, non-Flatcar, Suse and ClearLinux, non-Fedora) -- 25.67s
kubernetes/preinstall : Install packages requirements ---------------------------------------------------------------------- 21.61s
kubernetes/kubeadm : Join to cluster if needed ----------------------------------------------------------------------------- 20.92s
kubernetes/preinstall : Mask swap.target (persist swapoff) ----------------------------------------------------------------- 15.51s
adduser : User | Create User ----------------------------------------------------------------------------------------------- 15.32s
kubernetes/preinstall : Disable fapolicyd service -------------------------------------------------------------------------- 15.25s
kubernetes/preinstall : Check if /etc/fstab exists ------------------------------------------------------------------------- 15.25s
kubernetes/preinstall : Disable swap --------------------------------------------------------------------------------------- 15.25s
bootstrap-os : Ensure bash_completion.d folder exists ---------------------------------------------------------------------- 15.24s
ansible-playbook -i inventory/mycluster/inventory.ini cluster.yml -b -v   113.51s user 69.05s system 14% cpu 21:12.74 total
```

### Kubernetes 클러스터 접근 설정

Kubespray로 클러스터 구성을 완료했지만, kubectl 명령어로 클러스터에 접근하기 위해서는 추가 설정이 필요합니다. Kubernetes는 보안을 위해 클러스터 접근 시 인증 정보가 필요하며, 이 정보는 kubeconfig 파일에 저장됩니다. kubeconfig 파일은 Kubernetes 클러스터 연결 정보를 담고 있는 설정 파일로, 다음과 같은 정보들이 포함되어 있습니다.

- 클러스터 API 서버 주소
- 인증서 정보
- 컨텍스트 설정
- 사용자 인증 정보

기본적으로 마스터 노드의 `/etc/kubernetes/admin.conf` 파일에 이 정보가 저장되어 있습니다. 해당 파일을 Kubernetes에 접근할 호스트로 가져오겠습니다. 관련 정보는 [setting-up-your-first-cluster](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/getting_started/setting-up-your-first-cluster.md#access-the-kubernetes-cluster)에서 확인할 수 있습니다.

#### kubeconfig 파일 로컬 호스트로 복사하기

먼저 파일을 복사해오기 위해 권한을 수정합니다.

{{< tabs items="실제 환경,실습 환경" >}}

{{< tab >}}

```shell
ssh <username>@<master-node-ip>
USERNAME=$(whoami)
sudo chown -R $USERNAME:$USERNAME /etc/kubernetes/admin.conf
exit
```

{{< /tab >}}
{{< tab >}}

```shell
ssh vagrant@192.168.56.10
sudo chown -R vagrant:vagrant /etc/kubernetes/admin.conf
exit
```

{{< /tab >}}

{{< /tabs >}}

이제 로컬 호스트에서 kubeconfig 파일을 복사합니다.

{{< callout type="warning" >}}
여러 개의 Kubernetes 클러스터를 운영하는 경우, `~/.kube/config` 에 복사하지 않고 각 클러스터의 kubeconfig 파일을 별도로 관리하여 혼동을 피하는 것이 좋습니다. 이를 위해 KUBECONFIG 환경 변수를 활용하거나, kubectl 명령어 실행 시 --kubeconfig 플래그를 사용하여 특정 설정 파일을 지정할 수 있습니다. 해당 방법은 [setting-up-your-first-cluster](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/getting_started/setting-up-your-first-cluster.md#access-the-kubernetes-cluster)에 설명되어 있습니다.
{{< /callout >}}

{{< tabs items="실제 환경,실습 환경" >}}

{{< tab >}}

```shell
mkdir ~/.kube
scp <username>@<master-node-ip>:/etc/kubernetes/admin.conf ~/.kube/config
chmod 600 ~/.kube/config
```

{{< /tab >}}
{{< tab >}}

```shell
mkdir ~/.kube
scp vagrant@192.168.56.10:/etc/kubernetes/admin.conf ~/.kube/config
chmod 600 ~/.kube/config
```

{{< /tab >}}

{{< /tabs >}}

#### kubeconfig master host 설정하기

로컬에 복사해 온 kubeconfig 파일에서 쿠버네티스 마스터 노드의 호스트(IP) 를 지정해 줍니다.
실제 베어메탈(또는 클라우드) 환경과 Vagrant 실습 환경에서 설정이 다르므로 해당되는 탭을 확인해 주세요.

{{< tabs items="실제 환경,실습 환경" >}}

{{< tab >}}

```shell
vi ~/.kube/config

apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ~
    server: https://<master-node-ip>:6443 # <-- here
```

{{< /tab >}}
{{< tab >}}

Vagrant 에서 설정한 두 아이피는 아래와 같습니다.

- eht0: 자동 할당 (NAT) -> 192.168.63.148 (실습 환경마다 다를 수 있음)
- eth1: 192.168.56.10 (Host Only)
- eth2: 10.3.0.1 (Host Only)

Kubenetes 관점에서 보자면

- eht0: 192.168.63.148 (NAT 으로 부여된 public ip)
- eth1: 192.168.56.10 (ssh 관리용 IP)
- eth2: 10.3.0.1 (Pod Network IP)

결과적으로 쿠버네티스 API 서버는 NAT IP(eth0 = 192.168.63.148) 기준으로 설정되어 있습니다. 따라서 server: https://192.168.63.148:6443 로 접근해야 TLS 인증서가 일치합니다. 192.168.56.10으로 접근하면 인증서 불일치 오류가 발생합니다.

아래 명령어로 public ip를 확인하여 작성해 주세요.

```shell
ssh vagrant@192.168.56.10
ip addr show
```

```shell
> vagrant@node1:~$ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:ea:a2:b3 brd ff:ff:ff:ff:ff:ff
    altname enp2s0
    altname ens160
    inet 192.168.63.148/24 metric 100 brd 192.168.63.255 scope global dynamic eth0
       valid_lft 1100sec preferred_lft 1100sec
    inet6 fe80::20c:29ff:feea:a2b3/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:ea:a2:bd brd ff:ff:ff:ff:ff:ff
    altname enp18s0
    altname ens224
    inet 192.168.56.10/24 brd 192.168.56.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:feea:a2bd/64 scope link
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:ea:a2:c7 brd ff:ff:ff:ff:ff:ff
    altname enp26s0
    altname ens256
    inet 10.3.0.1/24 brd 10.3.0.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:feea:a2c7/64 scope link
       valid_lft forever preferred_lft forever
```

```shell
vi ~/.kube/config

apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ~
    server: https://192.168.63.148:6443 # <-- here, 자신의 master node public ip
```

{{< /tab >}}
{{< /tab >}}

#### Kubernetes 구성 확인

kubeconfig 설정까지 마무리 하였다면 로컬 호스트에서 kubernetes 구성요소를 확인해 봅니다.

```shell
kubectl get nodes
```

```shell
> kubectl get nodes
NAME    STATUS   ROLES           AGE    VERSION
node1   Ready    control-plane   165m   v1.31.3
node2   Ready    <none>          164m   v1.31.3
node3   Ready    <none>          164m   v1.31.3
```

설정한 세개의 node의 상태를 확인할 수 있습니다.
여기까지 Kubesrpay 시작하기를 마치며, 다음 포스팅은 사내에서 사용할 CI / CD 를 위한 Github Actions Runner를 배포해 보겠습니다.
