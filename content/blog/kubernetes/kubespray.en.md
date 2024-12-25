---
title: Getting Started with Kubespray
type: blog
date: 2024-12-25
tags:
  - kubernetes
  - kubespray
summary: "This article provides a detailed explanation of how to build a Kubernetes cluster using Kubespray. It covers everything from setting up a practice environment using Vagrant and VMware to installing Kubespray, deploying clusters, and configuring kubeconfig. It also compares the differences between real environments and practice environments while providing specific configuration methods for each step."
---

## Background and Reasons for Introducing [Kubespray](https://github.com/kubernetes-sigs/kubespray) for Internal Server Management

### Introduction Background

At my current company, the need for internal server management has emerged. Currently, various product development deployments, virtual environment management for practice, and server access management are being performed individually by each employee, leading to issues such as resource conflicts and poor management. To address these issues, we referenced Kakao's internal server management approach introduced at the 'If Kakao 2024' conference. Kakao manages their servers using various tools including Kubernetes, VMs, Packer, and Ansible for provisioning. However, for our company, we determined that such a complex management approach would be excessive, and decided to adopt a server management method using Kubernetes.

### Why Kubespray

Kubespray, an Ansible-based automation tool, offers the following advantages for building and managing Kubernetes clusters in an internal environment:

- **Minimized Management Work**: Automates installation and configuration through Ansible playbooks, reducing manual work and enabling efficient management.

- **Multi-Platform Support**: Can build Kubernetes clusters across various environments from bare metal servers to AWS, GCE, Azure, OpenStack, making it flexible for internal infrastructure application.

- **Advanced Features**: Provides features necessary for production environments such as high availability (HA) configuration, support for various network plugins, and cluster expansion and upgrades.

- **Customizable**: Can fine-tune cluster settings and customize according to organizational needs using Ansible's characteristics.

For these reasons, we chose Kubespray to increase the efficiency of internal server management and minimize management tasks.

{{% details title="Kubernetes Management Tools Comparison Table" closed="true" %}}

| **Feature**             | **kubeadm**                                                              | **Kubespray**                                                                         | **kops**                                                       |
| ----------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **Management Style**    | CLI Tool                                                                 | Ansible Playbook Based                                                                | CLI Tool                                                       |
| **Environment Support** | On-premises and various cloud environments                               | Supports various platforms including AWS, GCE, Azure, OpenStack, bare metal           | Mainly supports cloud environments like AWS, GCE               |
| **Automation Level**    | Focuses on cluster initialization and node addition                      | Automates entire lifecycle management including installation, configuration, upgrades | Provides cloud-native automation features                      |
| **User Friendliness**   | Simple cluster setup with basic commands                                 | Detailed configuration possible through config files                                  | Simple installation and management via CLI                     |
| **Scalability**         | Limited user customization                                               | Various network plugins and component selection possible                              | Provides scalability through Terraform integration             |
| **Use Cases**           | Single cluster and on-premises environments                              | Various clusters and on-premises environments, suitable for Ansible-familiar users    | Easy cluster installation and management in cloud environments |
| **HA Support**          | Assumes single master node by default, requires additional config for HA | Easily configures multiple master nodes and HA setup                                  | Supports HA cluster configuration                              |
| **Config Management**   | Requires additional tools for cluster config management                  | Provides configuration management and automation through Ansible                      | Provides basic features for cluster config management          |
| **Network Plugin**      | Supports basic network plugins                                           | Choice of various network plugins including Calico, Flannel                           | Supports basic network plugins                                 |
| **Community & Support** | Active community support as official Kubernetes tool                     | Active community support as Kubernetes sub-project                                    | Supported by Kubernetes community                              |

{{% / details %}}

## Setting Up Practice Environment

Let's set up a virtual cluster environment for Kubespray practice using Vagrant and VMware. This environment will consist of one master node and two worker nodes. This post will focus on Kubespray and briefly cover Vagrant. When applying VMs in your company, please **make sure to check the relevant licenses**.

### Prerequisites

- VMware Fusion installation (for Mac OS)
- Vagrant installation
- Vagrant VMware Utility installation
- Vagrant Desktop Provider Plugin installation
- SSH key generation (`~/.ssh/id_rsa.pub`)

### Writing Vagrantfile

Let's write a Vagrantfile for the practice environment. This file has the following characteristics:

- Uses Ubuntu 24.04 LTS based VM image
- Configures 3 nodes (1 master + 2 workers)
- Allocates resources per node (2 CPU cores, 2GB memory)
- Configures two network interfaces
  - private_network for host-guest communication (192.168.56.x)
  - private_network for cluster internal communication (10.3.0.x)

{{< filetree/container >}}
{{< filetree/file name="Vagrantfile" >}}
{{< /filetree/container >}}

{{% details title="Vagrantfile" closed="true" %}}

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  BOX_IMAGE = "gutehall/ubuntu24-04"

  # VM Configuration
  NODES = [
    { :hostname => "master", :ip => "192.168.56.10", :ip_internal => "10.3.0.1", :memory => 2048, :cpus => 2 },
    { :hostname => "worker1", :ip => "192.168.56.11", :ip_internal => "10.3.0.2", :memory => 2048, :cpus => 2 },
    { :hostname => "worker2", :ip => "192.168.56.12", :ip_internal => "10.3.0.3", :memory => 2048, :cpus => 2 }
  ]

  # Configure each node
  NODES.each do |node|
    config.vm.define node[:hostname] do |nodeconfig|
      nodeconfig.vm.box = BOX_IMAGE
      nodeconfig.vm.hostname = node[:hostname]

      # VMware Fusion provider settings
      nodeconfig.vm.provider "vmware_desktop" do |v|
        v.memory = node[:memory]
        v.cpus = node[:cpus]
        v.gui = false
      end

      # Prevent SSH key copying
      nodeconfig.ssh.insert_key = false

      # Network settings
      nodeconfig.vm.network "private_network", ip: node[:ip]
      nodeconfig.vm.network "private_network", ip: node[:ip_internal]

      # SSH key settings
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

### Setting Up VM Environment

Set up the VM environment using the commands below. Initial execution may take time due to VM image download.

```shell
vagrant up
```

Check the status of each node using the `vagrant status` command.

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

### Other Vagrant Commands

```shell
# Start VM
vagrant up

# Stop VM
vagrant halt

# Re-run provisioning (when settings change while VM is running)
vagrant provision

# Reset and restart VM
vagrant destroy -f
vagrant up
```

We have now configured the VMs for building a Kubernetes cluster using Kubespray. Let's look at how to configure Kubespray.

## Getting Started with Kubespray

Now let's build a Kubernetes cluster using Kubespray in our Vagrant-configured environment. We'll follow the [Kubespray Official Guide](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/getting_started/getting-started.md).

### Clone Kubespray Repository

First, clone the Kubespray repository to your local environment.

```shell
git clone https://github.com/kubernetes-sigs/kubespray.git
```

{{< filetree/container >}}
{{< filetree/folder name="kubespray">}}
{{< /filetree/folder >}}
{{< filetree/file name="Vagrantfile" >}}
{{< /filetree/container >}}

### Inventory Configuration

Since Kubespray is based on Ansible, we need an inventory file for cluster configuration. Start by copying the sample inventory:

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

#### Examining the Inventory File

The `inventory/mycluster/inventory.ini` file defines the roles and configurations of nodes that make up the cluster. Let's look at the main components of the basic sample file:

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
  - Defines nodes where Kubernetes control plane will run
  - Also called master nodes, running API server, controller manager, and scheduler
  - Can specify multiple nodes for high availability (HA)
- `[etcd:children]`
  - Specifies nodes that make up the etcd cluster
  - Uses children directive to set all kube_control_plane group nodes as etcd members
  - This is called "stacked topology" where etcd runs on control plane nodes
- `[kube_node]`
  - Defines worker nodes where actual workloads will run
  - These are the nodes where application pods are scheduled and run

#### Configuring Inventory File

Let's write the inventory file according to our Vagrant environment. Our environment consists of one master node and two worker nodes, with the following roles:

- master (node1): Control plane
- worker1 (node2): Worker node + etcd
- worker2 (node3): Worker node + etcd

Write the `inventory/mycluster/inventory.ini` file as follows:

```ini
# Define basic node information
node1 ansible_user=vagrant ansible_host=192.168.56.10 ip=10.3.0.1
node2 ansible_user=vagrant ansible_host=192.168.56.11 ip=10.3.0.2
node3 ansible_user=vagrant ansible_host=192.168.56.12 ip=10.3.0.3

# Specify control plane node
[kube_control_plane]
node1

# Configure etcd cluster
[etcd]
node1
node2
node3

# Specify worker nodes
[kube_node]
node2
node3
```

Basic Node Information

- ansible_user: User account for Ansible SSH connection (default Vagrant VM user)
- ansible_host: External access IP for the node (Vagrant's first private_network)
- ip: Internal communication IP for Kubernetes (Vagrant's second private_network)

etcd Configuration

- Configured with 3 nodes for high availability and data stability
- etcd uses a distributed consensus algorithm, so configured with an odd number of nodes as recommended in official documentation

For more complex configurations (e.g., using Bastion hosts, additional network settings, node labeling), please refer to the [inventory guide](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/ansible/inventory.md).

### Installing and Deploying Kubespray

Now let's deploy the Kubernetes cluster in our prepared environment. Since Kubespray is based on Python and Ansible, we'll first install the necessary dependencies.

#### Python Virtual Environment Setup

Use a Python virtual environment to prevent dependency conflicts and maintain a clean environment.

```shell
# In kubespray directory
python3 -m venv venv
source venv/bin/activate
pip install -U -r requirements.txt
```

{{< callout type="warning" >}}
While the [Kubespray official documentation](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/ansible/ansible.md#installing-ansible) states support for Python 3.10-3.12, normal operation has been confirmed with Python 3.13.1.
{{< /callout >}}

After installation, check the Ansible version with the `ansible --version` command.

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

#### Verify Host Access

Before cluster configuration, verify that SSH access to all nodes is working properly.

```shell
ansible all -i inventory/mycluster/inventory.ini -m ping --private-key=~/.ssh/<your-private-key>
```

Ansible options explanation:

- `-i`: Specify inventory file path
- `-b`: Use become (sudo privileges)
- `-v`: Verbose mode (detailed log output)
- `--private-key`: Specify private key for SSH connection, this is the private key path used when setting up VMs with Vagrant

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/kubernetes/kubespray/ansible-ping.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>Verify Ansible hosts ping</figcaption>
</figure>

#### Deploy Kubernetes Cluster

If the ping check is successful, proceed with deploying the Kubernetes cluster.

```shell
# kubespray dir
ansible-playbook -i inventory/mycluster/inventory.ini cluster.yml -b -v --private-key=~/.ssh/<your-private-key>
```

On a Macbook M3 Pro chip, the deployment process took about 20 minutes.

```shell
PLAY RECAP *************************************************************************************************************************
node1                      : ok=660  changed=141  unreachable=0    failed=0    skipped=1071 rescued=0    ignored=6
node2                      : ok=520  changed=111  unreachable=0    failed=0    skipped=695  rescued=0    ignored=2
node3                      : ok=520  changed=111  unreachable=0    failed=0    skipped=693  rescued=0    ignored=2

Wednesday 25 December 2024  17:48:50 +0900 (0:00:00.080)       0:21:11.858 ***************
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

### Kubernetes Cluster Access Configuration

Although we've completed the cluster configuration with Kubespray, additional setup is needed to access the cluster using kubectl commands. Kubernetes requires authentication information for cluster access, which is stored in the kubeconfig file. The kubeconfig file contains cluster connection information including:

- Cluster API server address
- Certificate information
- Context settings
- User authentication information

By default, this information is stored in the `/etc/kubernetes/admin.conf` file on the master node. Let's bring this file to the host that will access Kubernetes. Related information can be found in [setting-up-your-first-cluster](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/getting_started/setting-up-your-first-cluster.md#access-the-kubernetes-cluster).

#### Copy kubeconfig File to Local Host

First, modify permissions to copy the file.

{{< tabs items="Real Environment,Practice Environment" >}}

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

Now copy the kubeconfig file to the local host.

{{< callout type="warning" >}}
When operating multiple Kubernetes clusters, it's better to manage kubeconfig files separately for each cluster rather than copying to `~/.kube/config` to avoid confusion. You can use the KUBECONFIG environment variable or specify a particular configuration file using the --kubeconfig flag when executing kubectl commands. This method is explained in [setting-up-your-first-cluster](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/getting_started/setting-up-your-first-cluster.md#access-the-kubernetes-cluster).
{{< /callout >}}

{{< tabs items="Real Environment,Practice Environment" >}}

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

#### Configure kubeconfig Master Host

Specify the Kubernetes master node's host (IP) in the kubeconfig file copied to local.
Please check the appropriate tab as settings differ between real bare metal (or cloud) environments and Vagrant practice environments.

{{< tabs items="Real Environment,Practice Environment" >}}

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

The two IPs set in Vagrant are as follows:

- eth0: Auto-assigned (NAT) -> 192.168.63.148 (may vary by practice environment)
- eth1: 192.168.56.10 (Host Only)
- eth2: 10.3.0.1 (Host Only)

From Kubernetes' perspective:

- eth0: 192.168.63.148 (public IP assigned by NAT)
- eth1: 192.168.56.10 (IP for SSH management)
- eth2: 10.3.0.1 (Pod Network IP)

As a result, the Kubernetes API server is configured based on the NAT IP (eth0 = 192.168.63.148). Therefore, you must access server: https://192.168.63.148:6443 for the TLS certificate to match. Accessing via 192.168.56.10 will result in a certificate mismatch error.

Check your public IP with the command below and write it:

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
    server: https://192.168.63.148:6443 # <-- here, your master node public ip
```

{{< /tab >}}
{{< /tab >}}

#### Verify Kubernetes Configuration

After completing the kubeconfig setup, verify the Kubernetes components from your local host.

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

You can check the status of the three nodes we configured.
This concludes Getting Started with Kubespray, and in the next post, we'll deploy Github Actions Runner for CI/CD use in our company.
