terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "aziz-rg" {
  name     = "aziz-resources"
  location = "West Europe"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "aziz-vn" {
  name                = "aziz-network"
  location            = azurerm_resource_group.aziz-rg.location
  resource_group_name = azurerm_resource_group.aziz-rg.name
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "aziz-subnet" {
  name                 = "aziz-subnet"
  resource_group_name  = azurerm_resource_group.aziz-rg.name
  virtual_network_name = azurerm_virtual_network.aziz-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "aziz-sg" {
  name                = "aziz-sg"
  location            = azurerm_resource_group.aziz-rg.location
  resource_group_name = azurerm_resource_group.aziz-rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "aziz-dev-rule" {
  name                        = "aziz-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.aziz-rg.name
  network_security_group_name = azurerm_network_security_group.aziz-sg.name
}

resource "azurerm_subnet_network_security_group_association" "aziz-sga" {
  subnet_id                 = azurerm_subnet.aziz-subnet.id
  network_security_group_id = azurerm_network_security_group.aziz-sg.id
}

resource "azurerm_public_ip" "aziz-ip" {
  name                = "aziz-ip"
  resource_group_name = azurerm_resource_group.aziz-rg.name
  location            = azurerm_resource_group.aziz-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}


resource "azurerm_network_interface" "aziz-nic" {
  name                = "aziz-nic"
  location            = azurerm_resource_group.aziz-rg.location
  resource_group_name = azurerm_resource_group.aziz-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.aziz-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.aziz-ip.id
  }

  tags = {
    environment = "dev"
  }
}


resource "azurerm_linux_virtual_machine" "aziz-vm" {
  name                  = "aziz-vm"
  location              = azurerm_resource_group.aziz-rg.location
  resource_group_name   = azurerm_resource_group.aziz-rg.name
  network_interface_ids = [azurerm_network_interface.aziz-nic.id]
  size                  = "Standard_B1s"
  admin_username        = "adminuser"


  custom_data = filebase64("customdata.tpl")


  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/aziz_rsa.pub")
  }

  os_disk {
    name                 = "aziz-example"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityFile = "~/.ssh/aziz_rsa"
    })
    interpreter = var.host_os == "mac" ? ["bash", "-c"] : ["Power", "-c"] 
  }

  tags = {
    environment = "dev"
  }
}

data "azurerm_public_ip" "aziz-ip-data" {
  name = azurerm_public_ip.aziz-ip.name
  resource_group_name = azurerm_resource_group.aziz-rg.name
}


output "public_ip_address" {
  value  = "${azurerm_linux_virtual_machine.aziz-vm.name} : ${data.azurerm_public_ip.aziz-ip-data.ip_address}"
}
