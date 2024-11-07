packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.3"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "is_arm64" {
  type    = bool
  default = false
}

variable "distrib" {
  type    = string
  default = "noble"
}

data "amazon-ami" "arm" {
  filters = {
    virtualization-type = "hvm"
    name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"
    root-device-type    = "ebs"
  }
  owners      = ["099720109477"]
  most_recent = true
}

data "amazon-ami" "amd" {
  filters = {
    virtualization-type = "hvm"
    name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    root-device-type    = "ebs"
  }
  owners      = ["099720109477"]
  most_recent = true
}

source "amazon-ebs" "ubuntu" {
  ami_name        = "custom-ubuntu-ami-{{timestamp}}"
  skip_create_ami = true
  instance_type   = var.is_arm64 ? "m7g.large" : "m5.large"
  region          = "eu-west-3"
  source_ami      = var.is_arm64 ? data.amazon-ami.arm.id : data.amazon-ami.amd.id
  ssh_username    = "ubuntu"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 40
    volume_type           = "gp3"
    delete_on_termination = true
  }
}

build {
  name = "custom-ubuntu-iso"
  sources = [
    "source.amazon-ebs.ubuntu",
  ]

  provisioner "file" {
    source      = "customize_squashfs.sh"
    destination = "/tmp/customize_squashfs.sh"
  }

  provisioner "file" {
    source      = "customize_grub.sh"
    destination = "/tmp/customize_grub.sh"
  }

  provisioner "file" {
    source      = "autoinstall.yaml"
    destination = "/tmp/autoinstall.yaml"
  }

  provisioner "file" {
    source      = "create_efi_partition_${var.is_arm64 ? "arm64" : "amd64"}.sh"
    destination = "/tmp/create_efi_partition.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -yq --no-install-recommends genisoimage syslinux-common isolinux xorriso mtools",
    ]
  }

  provisioner "shell" {
    env = {
      "DISTRIB" = var.distrib
      "ARCH"    = var.is_arm64 ? "arm64" : "amd64"
    }
    scripts = [
      "build_custom_iso.sh"
    ]
  }

  provisioner "shell" {
    inline = concat([
      "sudo chmod a+r /tmp/custom-ubuntu.iso",
    ])
  }

  provisioner "file" {
    direction   = "download"
    sources     = ["/tmp/custom-ubuntu.iso"]
    destination = "custom-ubuntu-${var.is_arm64 ? "arm64" : "amd64"}-{{timestamp}}.iso"
  }
}
