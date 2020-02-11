#!/bin/bash

LOG="/local/kube_start.log"
PROJ_DIR="$(ls /proj/ | tail -1)"
KUBE_DIR="/proj/${PROJ_DIR}/kube-config/$1"
KUBE_JOIN=/local/kube_join.sh
PROJ_DIR="$(ls /proj/ | tail -1)"

#sudo rm -f ${KUBE_JOIN}
echo "executing kube-start at $(date)" > ${LOG}

log() {
    echo "$1" >> ${LOG}
}

# generate keys to get token via SCP
/usr/bin/geni-get key > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 644 ~/.ssh/authorized_keys

log "Created ssh key"


curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository    "deb [arch=amd64] https://download.docker.com/linux/ubuntu 
   $(lsb_release -cs) 
   stable"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y docker-ce kubelet kubeadm kubectl
sudo apt-mark hold docker-ce kubelet kubeadm kubectl

sudo swapoff -a


HOSTNAME="$(hostname)"
#echo ${HOSTNAME}

if [[ ${HOSTNAME} =~ "kubernetes00" ]]; then
    log "I am the master"
    mkdir -p ${KUBE_DIR}
    log "Made proj directory"

    export KUBECONFIG=/local/kubeconfig
    log "Exported KUBECONFIG"
    JOIN_STRING="$(sudo kubeadm init --pod-network-cidr=10.244.0.0/16 | tail -2)"
    log "Finished kubeadm init"
    sudo cp -i /etc/kubernetes/admin.conf /local/kubeconfig
    sudo chmod 777 /local/kubeconfig
    #sudo chown $(id -u):$(id -g) /local/kubeconfig
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
    log "applied flannel"

    LOCAL_KUBE_JOIN="/local/.tmp.kube_join.sh"
    echo "#!/bin/bash" > ${LOCAL_KUBE_JOIN}
    echo "${JOIN_STRING}" >> ${LOCAL_KUBE_JOIN}
    sudo chmod 777 ${LOCAL_KUBE_JOIN}
    sudo mv ${LOCAL_KUBE_JOIN} ${KUBE_JOIN}
    #sudo echo ${JOIN_STRING} >> ${KUBE_JOIN}
    echo "export KUBECONFIG=/local/kubeconfig" | sudo tee -a /etc/environment
    log "Created kube join file"
else
    log "I am a worker"
    MASTER_HOST="kubernetes00.$(hostname | cut -d. -f2-)"
    ssh-keyscan -H ${MASTER_HOST} >> ~/.ssh/known_hosts
    while true
    do
        if scp $MASTER_HOST:${KUBE_JOIN} ${KUBE_JOIN} &> /dev/null
        then
            break
        fi
        log "Waiting for the kubernetes token..."
        sleep 5
    done
    #until [ -f ${KUBE_JOIN} ]
    #do
    #echo "Waiting for join command" >> ${LOG}
    #    sleep 5
    #done
    log "Joining"
    sudo ${KUBE_JOIN}
    log "Joined"
fi
