# flatcar-homelab

## Prerequisites

* flatcar-install
* virt-firmware
* sg-disk
* jinja2-cli
* rook-ceph kubectl plugin

### flatcar-install
```bash
mkdir -p ~/.local/bin
# You may also add `PATH` export to your shell profile, i.e bashrc, zshrc etc.
export PATH=$PATH:$HOME/.local/bin

curl -LO https://raw.githubusercontent.com/flatcar/init/flatcar-master/bin/flatcar-install
chmod +x flatcar-install
mv flatcar-install ~/.local/bin

# install prerequisites
sudo apt install btrfs-progs gawk

# Ensure it runs
flatcar-install -hf
```

### virt-firmware

```bash
sudo pip3 install virt-firmware
```

### jinja2-cli
```bash
pip install jinja2-cli
```

### sgdisk
```bash
sudo apt install gdisk
```

### rook-ceph kubectl plugin
```bash
kubectl krew install rook-ceph
```

## Installing flatcar

1. Update Bootloader

Follow instructions as per:
https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#bootloader_update_stable

2. Install flatcar to disk

```bash
export TARGET=k2; \
export DEVICE=sda; \
sudo umount /dev/$DEVICE*; \
vlt run -c "./install.sh"; \
sudo umount /dev/$DEVICE*; \
unset TARGET; \
unset DEVICE;
```

3. Login
```bash
ssh -oUserKnownHostsFile=/dev/null \
  -oStrictHostKeyChecking=false \
  core@10.0.1.1 -i credentials/id_ed25519
```

4. Extract kubeconfig
```bash
scp -oUserKnownHostsFile=/dev/null \
  -oStrictHostKeyChecking=false \
  -i credentials/id_ed25519 \
  core@10.0.1.1:/etc/rancher/rke2/rke2.yaml credentials/rke2.yaml

sed -i 's/127[.]0[.]0[.]1/10.0.1.1/' credentials/rke2.yaml
```

5. Use kubectl

```bash
export KUBECONFIG=$PWD/credentials/rke2.yaml
kubectl get nodes
```

6. Configure kubectl to use vip
```bash
scp -oUserKnownHostsFile=/dev/null \
  -oStrictHostKeyChecking=false \
  -i credentials/id_ed25519 \
  core@10.0.1.1:/etc/rancher/rke2/rke2.yaml credentials/rke2.yaml
sed -i 's/127[.]0[.]0[.]1/10.0.2.1/' credentials/rke2.yaml
export KUBECONFIG=$PWD/credentials/rke2.yaml
kubectl get nodes
```

7. Configure Kubelogin

```bash

unset KUBECONFIG

kubectl config set-cluster k \
  --server=https://10.0.2.1:6443 \
  --embed-certs \
  --certificate-authority=<(openssl s_client -connect 10.0.2.1:6443 -showcerts </dev/null 2>/dev/null | tac | \
    sed -n '/-END CERTIFICATE-/,${p;/-BEGIN CERTIFICATE-/q}' | tac)

kubectl config set-credentials oidc \
    --exec-api-version=client.authentication.k8s.io/v1beta1 \
    --exec-command=kubectl \
    --exec-arg=oidc-login \
    --exec-arg=get-token \
    --exec-arg=--oidc-issuer-url=https://dex.homelab.evilcyborgdrone.com \
    --exec-arg=--oidc-client-id=kube-apiserver \
    --exec-arg=--oidc-extra-scope=email \
    --exec-arg=--oidc-extra-scope=profile \
    --exec-arg=--oidc-extra-scope=groups

kubectl config set-context k --cluster=k --user=oidc
kubectl config use-context k

rm -rf ~/.kube/cache/oidc-login/*

kubectl get nodes
```

8. apply K8s manifests
```bash
vlt run -c butane/manifests/apply.sh
```


## Ignition
### Generate ignition config
```bash
docker run --rm -i quay.io/coreos/butane:latest < butane/config.yml.j2 > ignition/config.json
```

## Generate kube-vip manifests
```bash

export VIP=10.0.2.1
export INTERFACE=enabcm6e4ei0
KVVERSION=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")

alias kube-vip="docker run --network host --rm ghcr.io/kube-vip/kube-vip:$KVVERSION"

kube-vip manifest daemonset \
    --interface $INTERFACE \
    --address $VIP \
    --inCluster \
    --taint \
    --controlplane \
    --arp \
    --leaderElection | tee manifests/kubevip-ds.yml

curl -L https://kube-vip.io/manifests/rbac.yaml | tee manifests/kubevip-rbac.yml
```

## Networking
* Everything     -> 10.0.0.0/20

* Infrastructure -> 10.0.0.0/24
  * Modem        -> 10.0.0.1/20
  * Office WiFi  -> 10.0.0.2/20
  # * Playroom WiFi-> 10.0.0.3/20
  * PoE Switch   -> 10.0.0.4/20

* K8s            -> 10.0.1.0/24
  * k0           -> 10.0.1.1/20
  * k1           -> 10.0.1.2/20
  * k2           -> 10.0.1.3/20

* VIPs           -> 10.0.2.0/24
  * k8s API      -> 10.0.2.1/20
  * Ingress      -> 10.0.2.2/20
  * Prom Push GW -> 10.0.2.3/20
  * ...
  * Openspeedtest-> 10.0.2.253/20
  * PiHole       -> 10.0.2.254/20

* Clients        -> 10.0.3.0/24
  * Inverter     -> 10.0.3.1/20 (cc:f9:57:c5:fd:e9)
  * valetudo     -> 10.0.3.2 (7c:49:eb:98:40:9c)





cat /sys/class/thermal/thermal_zone0/temp



dtc -@ -I dts -O dtb -o rpi-poe.dtbo rpi-poe-overlay.dts