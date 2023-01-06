export cluster="${USER}-poc"
export nodes=10
export zones="eastus2"
export ssd=2
export version="v22.2.1"
export lb=${nodes}
export app=$(($nodes - 3))

# Install Docker
echo "Installing Docker"
for i in {0..2}; do
    roachprod run ${cluster}:$(($app - $i)) -- "sudo apt-get update && sudo apt-get install ca-certificates curl gnupg lsb-release -y"
    roachprod run ${cluster}:$(($app - $i)) -- "sudo mkdir -p /etc/apt/keyrings"
    roachprod run ${cluster}:$(($app - $i)) -- "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
    roachprod run ${cluster}:$(($app - $i)) -- "echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
    roachprod run ${cluster}:$(($app - $i)) -- "sudo apt-get update && sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y"
    roachprod run ${cluster}:$(($app - $i)) -- "sudo usermod -aG docker ubuntu"
    roachprod run ${cluster}:$(($app - $i)) -- "newgrp docker"
done

echo "done"