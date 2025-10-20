# kube-vip

https://kube-vip.io/docs/installation/daemonset/#generating-a-manifest

```bash
source ../../../../env/k0.env

export INTERFACE=eth0
KVVERSION=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")

alias kube-vip="docker run --network host --rm ghcr.io/kube-vip/kube-vip:$KVVERSION"

kube-vip manifest daemonset \
    --interface $INTERFACE \
    --address $KUBE_VIP_ADDRESS \
    --inCluster \
    --taint \
    --controlplane \
    --services \
    --arp \
    --leaderElection > ../kube-vip.yml

```