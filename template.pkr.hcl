packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
    azure = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "node-nginx-app-v1-{{timestamp}}"
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

source "azure-arm" "ubuntu" {
  client_id       = "${var.azure_client_id}"
  client_secret   = "${var.azure_client_secret}"
  subscription_id = "${var.azure_subscription_id}"
  tenant_id       = "${var.azure_tenant_id}"
  
  managed_image_name                = "node-nginx-app-v1-{{timestamp}}"
  managed_image_resource_group_name = "tu-grupo-de-recursos"
  
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts"
  
  location = "East US"
  vm_size  = "Standard_B1s"
}

build {
  sources = [
    "source.amazon-ebs.ubuntu",
    "source.azure-arm.ubuntu"
  ]

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
      # 1. Esperar a que el sistema esté listo
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Esperando a cloud-init...'; sleep 2; done",
      
      # 2. Actualizar repositorios
      "sudo apt-get update -y",
      "sudo apt-get install -y nginx curl",
      
      # 3. Instalación moderna de Node.js (v20 LTS)
      "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -",
      "sudo apt-get install -y nodejs",
      
      # 4. Instalación de PM2
      "sudo npm install -g pm2",
      
      # 5. Configuración de Nginx
      "sudo mv /tmp/nginx.conf /etc/nginx/sites-available/default",
      "sudo systemctl restart nginx",
      
      # 6. Configuración de la App
      "sudo mkdir -p /var/www/html",
      "sudo mv /tmp/hello.js /var/www/html/hello.js",
      "sudo chown -R ubuntu:ubuntu /var/www/html",
      
      # 7. Gestión de procesos con PM2
      "pm2 start /var/www/html/hello.js --name hello",
      "pm2 save",
      "sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu"
    ]
  }
}
