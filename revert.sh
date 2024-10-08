sudo rm -rf awx_files
minikube stop
minikube delete
sudo rm /usr/local/bin/minikube
sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras -y
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo groupdel docker
sudo apt autoremove -y
