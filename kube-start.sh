#!/bin/bash
PROJ_DIR="$(ls /proj/ | tail -1)"
KUBE_DIR="/proj/${PROJ_DIR}/kube-config"
KUBE_JOIN=${KUBE_DIR}/kube-join.sh
mkdir ${KUBE_DIR}
echo "#!/bin/bash" > ${KUBE_JOIN}
chmod +x ${KUBE_JOIN}
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 | tail -2 >> ${KUBE_JOIN}
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

