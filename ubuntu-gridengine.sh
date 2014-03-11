# Ubuntu 12.04 LTS on Amazon AWS

# HPC MASTER
# ==========

# Ubuntu
# ------

# set up hostname & hosts
sudo sh -c 'echo "`curl -s http://169.254.169.254/latest/meta-data/local-ipv4` hpc-master hpc-share" >> /etc/hosts'
sudo sh -c 'echo "hpc-master" > /etc/hostname'
sudo hostname hpc-master
bash

# install packages
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get autoremove -y
sudo apt-get install debconf-utils -y # for apt-get unattended installations
sudo apt-get install htop unzip -y # add other useful packages for administration here

# disable ipv6
echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p # applies sysctl.conf changes
sudo sed -i "s/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/" /etc/ssh/sshd_config
sudo service ssh restart

sudo reboot

# Grid
# ----

# unattended gridengine install
# postfix is a dependency which we disable
echo "postfix postfix/main_mailer_type        select  No configuration" | sudo debconf-set-selections
echo "gridengine-master       shared/gridenginemaster string  hpc-master" | sudo debconf-set-selections
echo "gridengine-master       shared/gridenginecell   string  default" | sudo debconf-set-selections
echo "gridengine-master       shared/gridengineconfig boolean false" | sudo debconf-set-selections
echo "gridengine-common       shared/gridenginemaster string  hpc-master" | sudo debconf-set-selections
echo "gridengine-common       shared/gridenginecell   string  default" | sudo debconf-set-selections
echo "gridengine-common       shared/gridengineconfig boolean false" | sudo debconf-set-selections
echo "gridengine-client       shared/gridenginemaster string  hpc-master" | sudo debconf-set-selections
echo "gridengine-client       shared/gridenginecell   string  default" | sudo debconf-set-selections
echo "gridengine-client       shared/gridengineconfig boolean false" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get install gridengine-common gridengine-client gridengine-master -y
sudo -u sgeadmin /usr/share/gridengine/scripts/init_cluster /var/lib/gridengine default /var/spool/gridengine/spooldb sgeadmin
sudo service gridengine-master restart
sudo service postfix stop
sudo update-rc.d postfix disable

# Grid configuration
# ------------------

# add the user ubuntu to the manager list (root, sgeadmin are already there)
sudo qconf -am ubuntu
# add the hpc-master to the submit host list (will be to do qsub)
sudo qconf -as hpc-master

# create a host list
echo -e "group_name @allhosts\nhostlist NONE" > ./grid
sudo qconf -Ahgrp ./grid
rm ./grid

# create a queue
# note: qname, hostlist, load_thresholds
cat > ./grid <<EOL
qname                 my.q
hostlist              @allhosts
seq_no                0
load_thresholds       NONE
suspend_thresholds    NONE
nsuspend              1
suspend_interval      00:00:01
priority              0
min_cpu_interval      00:00:01
processors            UNDEFINED
qtype                 BATCH INTERACTIVE
ckpt_list             NONE
pe_list               make
rerun                 FALSE
slots                 2
tmpdir                /tmp
shell                 /bin/csh
prolog                NONE
epilog                NONE
shell_start_mode      posix_compliant
starter_method        NONE
suspend_method        NONE
resume_method         NONE
terminate_method      NONE
notify                00:00:01
owner_list            NONE
user_lists            NONE
xuser_lists           NONE
subordinate_list      NONE
complex_values        NONE
projects              NONE
xprojects             NONE
calendar              NONE
initial_state         default
s_rt                  INFINITY
h_rt                  INFINITY
s_cpu                 INFINITY
h_cpu                 INFINITY
s_fsize               INFINITY
h_fsize               INFINITY
s_data                INFINITY
h_data                INFINITY
s_stack               INFINITY
h_stack               INFINITY
s_core                INFINITY
h_core                INFINITY
s_rss                 INFINITY
h_rss                 INFINITY
s_vmem                INFINITY
h_vmem                INFINITY
EOL
sudo qconf -Aq ./grid
rm ./grid

# change scheduler config
# note: schedule_interval
cat > ./grid <<EOL
algorithm                         default
schedule_interval                 0:0:1
maxujobs                          0
queue_sort_method                 load
job_load_adjustments              np_load_avg=0.50
load_adjustment_decay_time        0:7:30
load_formula                      np_load_avg
schedd_job_info                   true
flush_submit_sec                  0
flush_finish_sec                  0
params                            none
reprioritize_interval             0:0:0
halftime                          168
usage_weight_list                 cpu=1.000000,mem=0.000000,io=0.000000
compensation_factor               5.000000
weight_user                       0.250000
weight_project                    0.250000
weight_department                 0.250000
weight_job                        0.250000
weight_tickets_functional         0
weight_tickets_share              0
share_override_tickets            TRUE
share_functional_shares           TRUE
max_functional_jobs_to_schedule   200
report_pjob_tickets               TRUE
max_pending_tasks_per_job         50
halflife_decay_list               none
policy_hierarchy                  OFS
weight_ticket                     0.500000
weight_waiting_time               0.278000
weight_deadline                   3600000.000000
weight_urgency                    0.500000
weight_priority                   0.000000
max_reservation                   0
default_duration                  INFINITY
EOL
sudo qconf -Msconf ./grid
rm ./grid

# hpc-share
# ---------

sudo mkdir -p /mnt/hpc-share
sudo mkfs.ext4 /dev/xvdf
sudo echo "/dev/xvdf       /mnt/hpc-share  ext4    defaults        0       2" | sudo tee -a /etc/fstab
sudo mount -a

sudo mkdir -p /opt
sudo ln -s /mnt/hpc-share /opt/share

# NFS
# ---

sudo apt-get install nfs-kernel-server -y

echo "/opt/share    *(rw,insecure,no_subtree_check,no_root_squash,async)" | sudo tee -a /etc/exports

# disable ipv6
sudo sed -i 's/^udp6/#udp6/' /etc/netconfig
sudo sed -i 's/^tcp6/#tcp6/' /etc/netconfig

sudo service nfs-kernel-server restart
sudo service portmap restart

# HPC WORKER
# ==========

# Ubuntu
# ------

# set up hosts
IP="1.2.3.4" # hpc master & share private ip
echo "$IP hpc-master hpc-share" | sudo tee -a /etc/hosts

# install packages
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get autoremove -y
sudo apt-get install debconf-utils -y # for apt-get unattended installations
sudo apt-get install htop unzip -y # add other useful packages for administration here

# disable ipv6
echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p # applies sysctl.conf changes
sudo sed -i "s/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/" /etc/ssh/sshd_config
sudo service ssh restart

sudo reboot

# Grid
# ----

echo "postfix postfix/main_mailer_type        select  No configuration" | sudo debconf-set-selections
echo "gridengine-common       shared/gridenginemaster string  hpc-master" | sudo debconf-set-selections
echo "gridengine-common       shared/gridenginecell   string  default" | sudo debconf-set-selections
echo "gridengine-common       shared/gridengineconfig boolean false" | sudo debconf-set-selections
echo "gridengine-client       shared/gridenginemaster string  hpc-master" | sudo debconf-set-selections
echo "gridengine-client       shared/gridenginecell   string  default" | sudo debconf-set-selections
echo "gridengine-client       shared/gridengineconfig boolean false" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get install gridengine-client gridengine-exec -y
sudo service postfix stop
sudo update-rc.d postfix disable

# if it doesn't work:
#echo hpc-master | sudo tee /var/lib/gridengine/default/common/act_qmaster

# NFS
# ---

sudo apt-get install portmap nfs-common -y
sudo sed -i 's/^udp6/#udp6/' /etc/netconfig
sudo sed -i 's/^tcp6/#tcp6/' /etc/netconfig
sudo service portmap restart

echo "hpc-share:/opt/share  /opt/share     nfs     defaults    0       0" | sudo tee -a /etc/fstab
sudo mkdir -p /opt/share
sudo mount -a
