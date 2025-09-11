# Instalar o Docker no Amazon Linux 2023 da instância EC2

```bash
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
docker version
docker run hello-world
```
