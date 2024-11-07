#!/bin/bash

set -ex

apt-get update
apt-get upgrade -y
apt-get install -yq --no-install-recommends \
    openssh-server \
    ripgrep \
    ubuntu-desktop \
    vim

# Customize MOTD
cat <<EOF >/etc/update-motd.d/10-custom
#!/bin/sh
echo "Welcome to the Custom Ubuntu Desktop 24.04 LTS"
EOF

# Create Ansible user
useradd -m -s /bin/bash ansible

# Import Ansible SSH Public Key
mkdir -p /home/ansible/.ssh
echo "ssh-ed25519 <REDACTED> github-ansible" >>/home/ansible/.ssh/authorized_keys

# Purge apt cache
apt-get clean
rm -rf /var/lib/apt/lists/*

exit
