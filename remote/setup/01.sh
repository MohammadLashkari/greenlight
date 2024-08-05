#!/bin/bash
set -eu

# set the timezone for the server.
TIMEZONE=Asia/Tehran
# set the name of the new user to create
USERNAME=greenlight
# prompt to enter a password for the postgresql greenlight user
read -p "Enter password for greenlight DB user: " DB_PASSWORD
# force all output to be presented in en_US for the duration of this script
export LC_ALL=en_US.UTF-8

# enable the "universe" repository
add-apt-repository --yes universe

# update all software packages
apt update

# set the system timezone and install all locales
timedatectl set-timezone ${TIMEZONE}
apt --yes install locales-all

# add the new user and give them sudo privileges
useradd --create-home --shell "/bin/bash" --groups sudo "${USERNAME}"

# force a password to be set for the new user the first time they log in
passwd --delete "${USERNAME}"
chage --lastday 0 "${USERNAME}"

# copy ssh keys from the root user to the new user
rsync --archive --chown=${USERNAME}:${USERNAME} /root/.ssh /home/${USERNAME}

# configure the firwall to allow ssh, http and https traffics
ufw allow 22
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# install fail2ban
apt --yes install fail2ban

# install the migrate cli tool
curl -L https://github.com/golang-migrate/migrate/releases/download/v4.17.1/migrate.linux-amd64.tar.gz | tar xv
mv migrate.linux-amd64 /usr/local/bin/migrate

# install postgresql
apt --yes install postgresql

# set up the greenlight DB and create a user account with the password entered earlier
sudo -i -u postgres psql -c "CREATE DATABASE greenlight"
sudo -i -u postgres psql -d greenlight -c "CREATE EXTENSION IF NOT EXISTS citext"
sudo -i -u postgres psql -d greenlight -c "CREATE ROLE greenlight WITH LOGIN PASSWORD '${DB_PASSWORD}'"

# add a DSN for connecting to the greenlight database to the system-wide environment
echo "GREENLIGHT_DB_DSN='postgres://greenlight:${DB_PASSWORD}@localhost/greenlight'" >> /etc/environment

# install caddy (https://caddyserver.com/docs/install#debian-ubuntu-raspbian)
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt --yes install caddy

# upgrade all packages. Using the --force-confnew flag means that configuration
# files will be replaced if newer ones are available
apt --yes -o Dpkg::Options::="--force-confnew" upgrade

echo "Script complete! Rebooting..."
reboot
