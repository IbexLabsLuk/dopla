# DoPla - DevOps Platform
DoPla is an app-infrastructure platform offering Kubernetes, DevOps workflows and orchestration of a virtual datacenter providing Kubernetes clusters, Docker hosts, fileservers, monitoring and other useful things.

![alt text](https://github.com/ninuxch/dopla/raw/master/docs/dopla-architecture.png "DoPla Architecture explained.")

- *Fast and effective:* Deploy your stack within less than an hour.
- *Stable infrastructure:* On Ubuntu LTS, Docker, Kubernetes technology.
- *Easy deployment and orchestration:* Kubernetes is deployed and orchestrated through rancher.
- *Scalable and Mobile:* Bare metal, AWS, GKE, and more are supported.
- *Distributed:* The internal tinc VPN creates a service network that enables you to spread your "Virtual Datacenter" amongst many providers.
- *Monitoring and alerting:* Prometheus, Grafana preconfigured. Slack and E-Mail Notifiers for alerting.
- *Traffic management:* HTTPS-Endpoint with letsencrypt, Reverse Web Proxy, Loadbalancer, Kibana Web Stats.
- *CI / CD Workflows:* Private registries and a Concourse Server for Continuous integration are available.
- *Authentication, Autorisation:* LDAP-Directory, with web based admin frontend.

## Install
### Prerequisites
You don't need much to start with DoPla:

- Knowledge about Ansible
- A basic idea about Kubernetes
- A few Ubuntu 18.04 boxes for Nodes and Controller.

### Copy the default configs
Copy the generic configs for your specific setup:
```bash
$ cp ansible/inventory/group_vars/example.yml ansible/inventory/group_vars/all.yml
$ cp ansible/inventory/example.ini ansible/inventory/hosts.ini
```

### Configure your cluster
Edit the example.ini to assign hosts to your cluster:

```ini
[dopla-base]
# Installs and configures tinc, dns, dopla and does all the updates. 
# In the example playbook hosts in this group are also assigned to the dopla-docker role, installing docker.
host1.fqdn.name ansible_connection=ssh dopla_ip=192.168.254.1 ajgarlag_tinc_node_name=vpn0 dopla_host=controller01
host2.fqdn.name ansible_connection=ssh dopla_ip=192.168.254.2 ajgarlag_tinc_node_name=vpn1 dopla_host=prod01
host3.fqdn.name ansible_connection=ssh dopla_ip=192.168.254.3 ajgarlag_tinc_node_name=vpn2 dopla_host=test01

[dopla-rke]
# Creates the volume path for k8s local path volumes
host2.fqdn.name ansible_connection=ssh
host3.fqdn.name ansible_connection=ssh

[dopla-controller]
# The controller gets deployed on this host.
host1.fqdn.name ansible_connection=ssh dopla_ip=192.168.254.1 dopla_host=controller01

[vpn]

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

Edit the example.yml to configure your cluster:
```yaml
# Those are the most basic variables for dopla roles.
# For more specific configuration (e.g. Custom tinc subnet) see:
# - roles/dopla-base/defaults/main.yml
# - roles/dopla-controller/defaults/main.yml
# - roles/dopla-docker/defaults/main.yml
# - roles/dopla-rke/defaults/main.yml

# Domain for dopla
dopla_domain: example.com
# Dopla admin mail
dopla_admin_mail: admin@example.com

# Controller hostname (default: Controller)
dopla_host_controller: controller
# Controller IP (default: 192.168.254.1/24)
dopla_int_ip_controller: 192.168.254.1
# Logs (Kibana) IP (default: 192.168.254.1/24, as controller)
dopla_host_logging: logs
dopla_int_ip_logging: 192.168.254.1
# Internal logging hostname
dopla_host_ldap: ldap
dopla_int_ip_ldap: 192.168.254.1

# Tinc network name (default: dopla)
dopla_tinc_network: dopla

dopla_registries:
  - #registry_url: "https://index.docker.io/v1/"
    username: "dockeruser"
    password: "dockerpass"
    email: "admin@example.com"
    #reauthorize: false
    #config_path: "$HOME/.docker/config.json"
    #state: "present"

# LDAP
# LDAP Organization
dopla_ldap_org: "Example LLC"
# LDAP Admin Password
dopla_ldap_admin_pass: "pass123"
# LDAP Config Password
dopla_ldap_config_pass: "pass123"

# DNS
# Default DNS admin user
dopla_dns_admin_user: "admin"
# Default DNS admin user password:
dopla_dns_admin_pass: "pass123"
# Default upstream dns
dopla_dns_upstream:
  - 8.8.8.8
  - 8.8.4.4
```
### Determine whether volumes are managed by DoPla
DoPla can manage LVM volumes for /var/lib/docker and the kubernetes local volume path:
```yaml
# Dopla docker volume name
dopla_docker_vol_name: k8spv
# Dopla docker volume size
dopla_docker_vol_size: 50G
# Dopla k8s volumes volume name
dopla_k8s_vol_name: k8spv
# Dopla k8s volumes volume size
dopla_k8s_vol_size: 50G
# Dopla host volume group
dopla_host_vg: system
# Use dopla to manage the volumes - SET TO FALSE FOR HOSTS THAT HAVE NO VOLUMES MANAGED BY DOPLA
dopla_manage_vols: true
# Dopla default fs for docker and k8s volumes
dopla_host_fstype: ext4
```
### Install DoPla on the target hosts
Run the playbook on your platform hosts:
```bash
$ ansible-playbook playbook.yml -u sudouser -i ./inventory/hosts.ini
```
After the installation the following DoPla components are available:

- Service network based on tinc vpn
- Rancher controller, available on all interfaces.
- LDAP directory available in the service network.
- ELK instance available in the service network.
- HTTP at port 9999 on controller to provide k8s xamples and templates 

To finish the setup you have to continue with the Rancher and Kubernetes configuration.

### Rancher and Kubernetes configuration
After the ansible installation, the controller is available at https://controller.domain.tld. SSL is configured automatically using letsencrypt. You have to set a password and the default domain first. Configure by hand:

- Add your first cluster. If you use a single node, remember to ceck all options (etcd, worker, pane...).
- Enable catalogs: In Global -> Tools -> Catalogs enable the "Library" and "Helm-Stable" catalogs.
- Install letsencrypt support. In the apps category install cert-manager

Your Rancher instance is now ready, the next step is to initialize the cluster.

### Cluster initialization
- Change to your cluster dashboard and start kubectl from the browser
- Execute the init script to install SSL Cluster issuers, local storage and the persistent volumes:
````bash
_> kubectl apply -f http://controller.example.com:9999/dopla-init.yaml
````
After the execution of dopla-init.yaml provides:

- CertificateIssuers to issue TLS / SSL-Certs using letsencrypt.
- The configured persistent volumes
- A special storage class for pvc provisioning of hostpath volumes.

### Cluster Monitoring / Logging
To get logging, alerting and Grafana dashboards everything in the Rancher tools menu of your cluster needs configuration:

- Enable Monitoring: In Monitoring enable monitoring, persistent volumes for Grafana and Prometheus are not needed.
- Log to elastic: In Logging choose Elastic and log to http://logging.dopla-domain.tld:9200 (defaults to Controller IP, 192.168.254.1)
- Notifier: A Slack, E-Mail or other notifier is needed for alerting.
- Configure alerts: In Alerting edit the alert groups and add the notifier (at the bottom of the page.)

Be aware that elastic needs a lot of iOPS and should only be enabled on adequate hosts.

## DoPla Specific operation procedures
### Web interfaces / Port

| Type | URL | Name | Comment |
| ---- | --- | --- | --- |
| Public / Web | https://controller.example.com | Rancher Controller | The main interface for Rancher Administration |
| Public / Web | https://controller.example.com | Grafana Dashboards | Grafana dashboards are accessible through Rancher. |
| Private / Web | http://logging.example.com:5601 | Kibana for Logs | No special authentication needed, accessible from web interface. |
| Private / API | http://logging.example.com:9200 | Elastic for Logs | RW access from the service network. |
| Private / Web | http://ldap.example.com:8181 | PHP LDAP Admin | Frontend for internal LDAP directory. |
| Private / Protocol | LDAP IP, TCP 389 | LDAP | LDAP directory access, PW-Protected from service network |
| Private / Web | http://controller.example.com:8053 | DNS Admin | Admin interface for internal DNS config |
| Private / Protocol | Controller IP, UDP 53 | DNS | Split Horizon DNS for service network. |

The easiest way to access internal web interfaces is SSH port forwarding:
````bash
$> ssh -L localhost:8181:192.168.254.1:8181 user@controller.example.com
````

### Issue SSL certs
After the init clusters can auto-generate and issue SSL certificates. The ACME procedure is automatically executed on ingress rules with the following annotations:
````yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    certmanager.k8s.io/cluster-issuer: letsencrypt-issuer
    kubernetes.io/tls-acme: "true"
...
spec:
  tls:
  - hosts:
    - demolicious.{{dopla_domain}}
    secretName: demolicious-crt
````
Alternatively you can also trigger the cert issuance by hand applying a YAML as found in examples/letsencrypt-certificate.yaml. More information is available in the cert-manager documentation.

### Demolicious: An easy start into Kubernetes and Rancher
DoPla provides a meaningless sample application called demolicious. It serves a nginx default page with a letsencrypt certificate on demolicious.{{dopla_domain}}

So if you're new to K8s or need a sample to figure how DoPla works:

````bash
$> kubectl -f apply http://controller.example.com:9999/demolicious.yaml
````

### A few words about storage in Kubernetes
The Kubernetes storage concepts are a bit off when you have storage experience. A few words are needed.

#### PV and PVC
A PV is a physical volume which was created manually by an admin. A PV can be claimed, bound and will then be released and therefore used but not deleted. A used PV will list as "Released" and cannot be bound again. PVs have a certain amount of storage fixely assigned.

A PVC is a persistant volume claim. Persistant Volume in the PVC context means "a volume that lives as long as the volume claim / deployment lives". A PVC can claim a PV but also a dynamically created volume.

#### The role of the storage class
Since PVs have fixed sizes there could be a lot of memory waste and conflicts. Imagine a workload needs 1GB at least but only 25GB PV are available. 24 GB go to waste. Now imagine a workload actually needs 25GB but your other workload took the last PV serving enough storage. That cannot end well.

Storage classes solve this issue by dynamically creating a Persistent Volume in the PVC sense and delete it again as soon as the claim gets deleted.

When rolling out dopla-init.yaml dopla-dynamic, which is based on the idea of rancher-local-path is rolled out. It's a storage class for Node Path Kubernetes bindings. That saves you the headache of manually creating folders for Node Path PVs.

#### How to keep a PV for a specific app
To keep a volume for a specific app can be useful and is simple: A volume stays bound as long as the claim exists. If you delete the workload, you can use the same depolyment to create a new workload and bind it to the storage claim.

If you deleted the volume claim you can preserve the PV by deleting the now released volume declaration but not the folders. Then create the PV and the volume claim again.

### Using LDAP
DoPla pre-installs an LDAP-Server with phpldapadmin. The server is preconfigured with your domain and admin password:
```yaml
# dopla_domain is also your default domain for ldap.
dopla_domain: example.com

# LDAP
# LDAP Organization
dopla_ldap_org: "example.com private site"
# LDAP Admin Password
dopla_ldap_admin_pass: "changeme1"
# LDAP Config Password
dopla_ldap_config_pass: "changeme2"

```

To maintain the LDAP ldap forward the port 8181 from the controller machine to your localhost:
````bash
$> ssh -L localhost:8181:192.168.254.1:8181 user@controller.example.com
````
You can now reach phpldapadmin at http://localhost:8181

Configure applications to use the LDAP directory by connecting to the controller over the internal tinc network where LDAP is exposed.

## Known Issues
- Only local storage is supported out of the box.
- It should be possible to roll out logging on a seperate host because ELK eats RAM. If you want logging at the moment, ensure your controller node has AT LEAST 24 GB of RAM.
- Local Storage volumes are the same for every node in every cluster.
- A lot of the recipes could be better, e.g. read host names from roles instead of hardwiring the dopla-base group name
- Split horizon DNS can interfere with internal K8s DNS and search domains. If necessary deactivate search domain and configure the DNS servers in /etc/systemd/systemd-resolved.conf.
