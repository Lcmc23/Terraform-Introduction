terraform {
    required_providers {
      azurerm = {
          source = "hashicorp/azurerm"
          version = "=2.91.0"
      }
    }
}

provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-bkp"
    storage_account_name = "saterraformstatehcl"
    container_name       = "repository-terraform"
    key                  = "staging.terraform.tfstate"
  }
}

# Create Resource Group
resource "azurerm_resource_group" "default" {
  name     = "rg-terraform"
  location = var.locat
  tags = {
    "env": "staging"
    "project": "introduction_terraform"
  }
}

# Create Virtual network
resource "azurerm_virtual_network" "default" {
  name = "vnet-terraform"
  address_space = ["10.0.0.0/16"]
  location = var.locat
  resource_group_name = var.rg
  tags = {
    "env": "staging"
    "project": "introduction_terraform"
  }
}

# Create Sub-net
resource "azurerm_subnet" "internal" {
  name = "subnet-terraform-internal"
  resource_group_name = var.rg
  virtual_network_name = var.vnet
  address_prefixes = ["10.0.1.0/24"]
}

# Create Sub-net
resource "azurerm_subnet" "staging" {
  name = "subnet-terraform-staging"
  resource_group_name = var.rg
  virtual_network_name = var.vnet
  address_prefixes = ["10.0.2.0/24"]
}

# Create Virtual Machine
resource "azurerm_public_ip" "default" {
  name                = "${var.vm}-ip"
  resource_group_name = var.rg
  location            = var.locat
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "default" {
  name                = "${var.vm}-nsg"
  location            = var.locat
  resource_group_name = var.rg

  security_rule {
    name                       = "HTTP"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "default" {
  name                = "${var.vm}-nic"
  location            = var.locat
  resource_group_name = var.rg

  ip_configuration {
    name                          = "${var.vm}-ipconf"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.default.id
  }
}

resource "azurerm_network_interface_security_group_association" "default" {
  network_interface_id      = azurerm_network_interface.default.id
  network_security_group_id = azurerm_network_security_group.default.id
}

resource "azurerm_virtual_machine" "main" {
  name                  = var.vm
  location              = var.locat
  resource_group_name   = var.rg
  network_interface_ids = [azurerm_network_interface.default.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.vm}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = var.vm
    admin_username = "admvm"
    admin_password = "Test@teste132"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}

