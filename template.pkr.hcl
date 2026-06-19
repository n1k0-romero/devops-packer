packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "node-nginx-app-v1"
  instance_type = "t3.micro"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"]
    most_recent = true
  }
  ssh_username = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.ubuntu"]

  # 1. Copiar archivos necesarios al servidor
  provisioner "file" {
    source      = "./hello.js"
    destination = "/tmp/hello.js"
  }

  provisioner "file" {
    source      = "./nginx.conf"
    destination = "/tmp/nginx.conf"
  }

  # 2. Aprovisionamiento automatizado
  provisioner "shell" {
    inline = [
      "echo 'Esperando a que apt termine de inicializar...'",
      "sleep 10",
      "sudo apt-get update",
      "sudo apt-get install -y nginx nodejs npm",
      
      # Instalación de PM2
      "sudo npm install -g pm2",
      
      # Configuración de Nginx
      "sudo mv /tmp/nginx.conf /etc/nginx/sites-available/default",
      "sudo systemctl restart nginx",
      
      # Configuración de la App
      "sudo mkdir -p /var/www/html",
      "sudo mv /tmp/hello.js /var/www/html/hello.js",
      "sudo chown -R ubuntu:ubuntu /var/www/html",
      
      # Gestión de procesos con PM2
      "pm2 start /var/www/html/hello.js --name hello",
      "pm2 save",
      
      # Automatización del inicio del sistema (Startup)
      "sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu"
    ]
  }
}