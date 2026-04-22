terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.7"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# mage
resource "libvirt_volume" "ubuntu" {
  name = "ubuntu-22.04-base.qcow2"
  pool = "default"
  target = {
    format = { type = "qcow2" }
  }
  create = {
    content = {
      url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    }
  }
}

# VM disk
resource "libvirt_volume" "vm_disk" {
  name     = "vm-system-disk.qcow2"
  pool     = "default"
  capacity = 10737418240 
  target   = { format = { type = "qcow2" } }
  backing_store = {
    path   = libvirt_volume.ubuntu.path
    format = { type = "qcow2" }
  }
}

# Cloud-Init
resource "libvirt_cloudinit_disk" "commoninit" {
  name = "commoninit.iso"

  user_data = <<-EOF
#cloud-config
users:
  - name: toros
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - "${var.ssh_public_key}"

chpasswd:
  list: |
    toros:1vlad1t2
  expire: false

ssh_pwauth: true

packages:
  - openssh-server

runcmd:
  - [ sed, -i, 's/PasswordAuthentication no/PasswordAuthentication yes/g', /etc/ssh/sshd_config ]
  - [ systemctl, restart, ssh ]
EOF

  meta_data = <<-EOF
instance-id: vm-001
local-hostname: vm
EOF
}

resource "libvirt_volume" "commoninit_volume" {
  name   = "commoninit-vol.iso"
  pool   = "default"
  create = {
    content = {
      url = libvirt_cloudinit_disk.commoninit.path
    }
  }
}

resource "libvirt_domain" "app_server" {
  name        = "vm"
  memory      = 2048
  memory_unit = "MiB"
  vcpu        = 2
  type        = "kvm"
  running     = true

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.vm_disk.pool
            volume = libvirt_volume.vm_disk.name
          }
        }
        driver = { type = "qcow2" }
        target = { dev = "vda", bus = "virtio" }
      },
      {
        device = "cdrom" 
        source = {
          volume = {
            pool   = libvirt_volume.commoninit_volume.pool
            volume = libvirt_volume.commoninit_volume.name
          }
        }
        target = { dev = "sda", bus = "sata" }
      }
    ]

    interfaces = [
      {
        source = {
          network = { network = "default" }
        }
        model = { type = "virtio" }
        wait_for_ip = {
          timeout = 300
          source  = "lease"
        }
      }
    ]

    consoles = [
      {
        type = "pty"
        target = { type = "serial", port = "0" }
      }
    ]
  }
}

data "libvirt_domain_interface_addresses" "app_server_ip" {
  domain = libvirt_domain.app_server.name
  source = "lease"
}

output "vm_ip" {
  value = data.libvirt_domain_interface_addresses.app_server_ip.interfaces[0].addrs[0].addr 
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for the user toros"
}
