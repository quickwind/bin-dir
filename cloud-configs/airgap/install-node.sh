#!/bin/bash -ex
exec &>> /var/log/install.log

if blkid | grep RANCHER_STATE; then
	# don't re-format
	echo "DONE"
	exit
fi

INSTALL_DISK="/dev/vda"
if ! fdisk -l $INSTALL_DISK; then
	INSTALL_DISK="/dev/sda"
fi

(
cat << EOF
#cloud-init
rancher:
  services_include:
  password: rancher
  network:
    # http_proxy: http://10.11.11.1:3128
    # https_proxy: http://10.11.11.1:3128
    # no_proxy: localhost,127.0.0.1,10.11.11.1
    interfaces:
      # the airgapped private network
      # setting these here means they're not ready before the install - TODO: move them into vmware guestinfo
      eth0:
        addresses:
        - 10.62.88.52/24
        gateway: 10.62.88.1
    dns:
      nameservers:
      - 10.254.174.10
      - 10.104.128.235
      domain:
      - lss.emc.com
  # these are auto-set from the rancher.network. settings
  #environment:
  #  HTTP_PROXY: http://10.11.11.1:3128
  #  HTTPS_PROXY: http://10.11.11.1:3128
  #  NO_PROXY: localhost,127.0.0.1,10.11.11.1
  # repositories:
    # roast:
      # url: http://roastlink.github.io/
  # note: these are sven's home registies
  # docker:
    # registry_mirror: "https://ctdcto38.lss.emc.com"
    # insecure_registry:
    # - ctdcto38.lss.emc.com
  # system_docker:
    # registry_mirror: "https://ctdcto38.lss.emc.com"
    # insecure_registry:
    # - ctdcto38.lss.emc.com
ssh_authorized_keys:
- ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLFpfQiZsY7wd9SiLZ1/dTB/wcoDZqcvGur2CFKhAuzB2p+py4Sg9RDxNnmQ/jN61Fqg62yHZB1ffq5OBniM+6zP2O0c/BXwb1O4cZd5TOH7KxliuEUuICji1UTe8bNNyWsUR5NtMEoeFgi4TFnnQ0kD3yc7jWlLaMsconbiT5BRZDUK3db4t9QKh0f2TVpUDHMgdT03/OpZesmOBhMEhNArWAmbEjKICo8H9EzONHyDrG1AP6+KcPsUz50WVXEtqXW2ESvVXRhjZzt69+jY6l4anj/nOf3M/JMDmdyCNcrs35V/ayFki9RXnd+KpQeYrZ83PtJaz+bvNdtqW4wXX/ ucc@dfs
write_files:
- container: ntp
  path: /etc/ntp.conf
  permissions: "0644"
  owner: root
  content: |
    server nsdrm-vip.isus.emc.com prefer
    restrict default nomodify nopeer noquery limited kod
    restrict 127.0.0.1
    restrict [::1]
    restrict localhost
EOF
) > cloud-init.yml

sudo ros install -f \
	-d $INSTALL_DISK \
	--cloud-config cloud-init.yml \
	--no-reboot \
	--append "rancher.autologin=tty1"

echo "Install done"

# mount the newly installed partition, so we can customise and then save the log
sudo mount ${INSTALL_DISK}1 /mnt

echo "Rebooting"

# save the log files
mkdir -p /mnt/var/log/install/
cp -r /var/log/* /mnt/var/log/install/

# reboot --kexec is a v1.1.0 feature that will boot straight into the just created disk, without rebooting the hardware
# if you're using a pre-v1.1.0 version and have booted from cdrom/usb, you'll need to either eject the media, or have put the HD earlier in the boot order
reboot --kexec
