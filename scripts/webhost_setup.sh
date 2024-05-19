#!/bin/bash
set -euo pipefail

#
# Variables
#

# Name of the user to create and grant sudo privileges
username=webhost

# Whether to copy over the root user's `authorized_keys` file to the new sudo
# user.
copy_authorized_keys_from_root=true

#
# Logic
#

# Add sudo user and grant privileges
id -u "${username}" &>/dev/null || useradd --create-home --shell "/bin/bash" --groups sudo "${username}"

# Check whether the root account has a real password set
encrypted_root_pw="$(grep root /etc/shadow | cut --delimiter=: --fields=2)"

if [ "${encrypted_root_pw}" != "*" ]; then
    # Transfer auto-generated root password to user if present
    # and lock the root account to password-based access
    echo "${username}:${encrypted_root_pw}" | chpasswd --encrypted
    passwd --lock root
else
    # Delete invalid password for user if using keys so that a new password
    # can be set without providing a previous value
    passwd --delete "${username}"
fi

# Expire the sudo user's password immediately to force a change
chage --lastday 0 "${username}"

# Create SSH directory for sudo user
home_directory="$(eval echo ~${username})"
mkdir --parents "${home_directory}/.ssh"

# Copy `authorized_keys` file from root if requested
if [ "${copy_authorized_keys_from_root}" = true ]; then
    cp /root/.ssh/authorized_keys "${home_directory}/.ssh"
fi

# Adjust SSH configuration ownership and permissions
chmod 0700 "${home_directory}/.ssh"
chmod 0600 "${home_directory}/.ssh/authorized_keys"
chown --recursive "${username}":"${username}" "${home_directory}/.ssh"

# Disable root SSH login with password
sed --in-place 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
systemctl restart ssh.service

# Add exception for SSH and enable UFW firewall
ufw allow OpenSSH
ufw --force enable
