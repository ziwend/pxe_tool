# 特性说明

一：一次编译到处使用

这里选择dnsmasq 实现DHCP server 和TFTP server，选择nginx 作为HTTP server，尝试以源码编译的方式部署DHCP server、TFTP server 和HTTP server。编译好的软件都在一个固定的目录中（/pxe_tool），后面使用时只需要拷贝到任意一台作为pxe网络部署OS的Server即可。

二：提前适配相关OS，零成本复制

目前该工具已适配CentOS7/CentOS8/Ubuntu等系统，并进行了验证，可以拿来即用,后续可自行适配其他OS。

三：方便定制

安装OS后往往还需要安装一些基础软件，执行一些配置脚本，这些都可以通过该工具中的init.sh编写脚本自动实现。

# Quick Start
```
cd /
git clone https://github.com/ziwend/pxe_tool
chmod +x /pxe_tool/sbin/*

#检查并修改dnsmasq.conf, grub.cfg, user-data, ks.cfg等配置文件

#启动
cd pxe_tool
./sbin/dnsmasq -C conf/dnsmasq.conf
./sbin/nginx
```

详细的使用说明见[下面](https://github.com/ziwend/pxe_tool/blob/master/readme.md#pxe%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E)

# 背景说明

PXE（Pre-boot Execution Environment/预启动执行环境）的实现依赖于网卡，只有支持 PXE Client 的网卡才能实现网络自动安装。这种网卡实现 DHCP Client和 TFTP Client，在 BIOS 的引导下通过 DHCP 协议自动分配 IP 地址，通过 TFTP获取最小内核，然后在最小内核环境下通过 HTTP 协议或 NFS 协议获取 OS安装版本，之后最小内核引导进行OS 的安装。

在通过网络批量安装OS的场景中，一般会选择一台服务器作为PXE server并安装部署DHCP server、 TFTP server和HTTP server软件。在以项目为维度的批量部署交付任务中，每次都要安装部署多个软件并进行各种复杂的配置才能配置一台PXE server，这样的操作费时费力，并且不能在下一个项目中复用。

这里选择dnsmasq实现DHCP server和TFTP server，选择nginx作为HTTP server，尝试以源码编译的方式安装DHCP server、 TFTP server和HTTP server，实现一次编译到处使用的目的。编译好的软件都在一个固定的目录中（/pxe\_tool），后面使用时只需要拷贝到任意一台作为PXE server的服务器即可，甚至可以直接使用便携式笔记本电脑上的虚拟机（网络选择桥接模式）作为PXE server，最大限度地减少了PXE server部署的工作量，方便快捷地完成批量部署OS的任务。

# pxe工具的制作过程说明
## 编译安装Nginx
```
# 下载nginx源码包，可以去官网查看最新版本包：http://nginx.org/download/
sudo wget http://nginx.org/download/nginx-1.23.3.tar.gz
# 下载依赖包 #https://sourceforge.net/projects/pcre/files/pcre/
sudo wget https://nchc.dl.sourceforge.net/project/pcre/pcre/8.45/pcre-8.45.tar.gz

# 解压nginx源码包
sudo tar -zxvf nginx-1.23.3.tar.gz
# 解压依赖包
sudo tar -zxvf pcre-8.45.tar.gz
# 删除压缩包
sudo rm *.tar.gz

# pcre不用安装，直接安装nginx
cd nginx-1.23.3/
sudo ./configure --prefix=/pxe_tool/ --with-pcre=/pxe_tool/pcre-8.45 --without-http_gzip_module --with-debug
# 编译
sudo make
# 运行安装
sudo make install
# 清除编译产生的文件
sudo make clean
```

## 编译安装Dnsmasq

```
#源码安装dnsmasq，从官网下载安装包#https://thekelleys.org.uk/dnsmasq/
sudo wget https://thekelleys.org.uk/dnsmasq/dnsmasq-2.89.tar.gz
#解压安装
sudo tar -zxvf dnsmasq-2.89.tar.gz
cd dnsmasq-2.89/
#修改编译保存位置
sed -i 's#PREFIX        = /usr/local#PREFIX        = /pxe_tool#g' Makefile
# 运行安装
sudo make install
```

## 启动并调试

首先要关闭防火墙（Centos可能还要关闭selinux）
```
#Master user 和worker user不一致会出现403报错，做如下调整
sed -i 's/#user  nobody;/user  root;/g' /pxe_tool/conf/nginx.conf	
# 启动Nginx
sudo ./sbin/nginx
# 验证
sudo lsof -i :80	
# 查看帮助
sudo ./sbin/nginx -h
# 停止Nginx
sudo ./sbin/nginx -s stop
# 重启nginx
sudo ./sbin/nginx -s reload

=============================================	
#生成dnsmasq配置文件
sudo mv /etc/dnsmasq.conf /pxe_tool/conf
cat > /pxe_tool/conf/dnsmasq.conf << 'EOF'
interface=eth1,lo
bind-interfaces
dhcp-range=eth1,192.168.0.50,192.168.0.250
# legacy bios
# dhcp-boot=pxelinux.0 
dhcp-match=set:efi-x86_64,option:client-arch,7
# secureboot
#dhcp-boot=tag:efi-x86_64,grub/bootx64.efi
# non-secureboot
dhcp-boot=tag:efi-x86_64,grub/grubx64.efi
enable-tftp
tftp-root=/pxe_tool/ftpd
log-facility=/pxe_tool/logs/dnsmasq.log
EOF

# 启动dnsmasq：
sudo ./sbin/dnsmasq -C dnsmasq.conf

验证：netstat -tunlp|grep 53
sudo lsof -i :53
关闭：sudo killall -KILL dnsmasq 或 pkill -9 dnsmasq


调试：
sudo tail -f /pxe_tool/dnsmasq.log
sudo tail -f /pxe_tool/logs/access.log
sudo tail -f /pxe_tool/logs/error.log
```

## 补充其他文件，最终的PXE tool的目录结构如下

```
/pxe_tool
├── client_body_temp
├── conf
│   ├── dnsmasq_centos.conf
│   ├── dnsmasq.conf
│   ├── dnsmasq_debian.conf
│   ├── dnsmasq_ubuntu.conf
│   └── nginx.conf
├── fastcgi_temp
├── ftpd
│   ├── EFI
│   │   └── centos
│   │       ├── 7
│   │       │   ├── initrd.img
│   │       │   └── vmlinuz
│   │       ├── 8
│   │       │   ├── initrd.img
│   │       │   └── vmlinuz
│   │       ├── grub.cfg
│   │       ├── grubx64.efi
│   │       └── x86_64-efi
│   │           └── linuxefi.mod
│   ├── grub
│       ├── grub.cfg
│       ├── grubx64.efi
│       ├── ubuntu-22.04
│       │   ├── initrd
│       │   └── vmlinuz
│       ├── ubuntu-22.04
│       │   ├── initrd
│       │   └── vmlinuz
│       └── ubuntu-23.04
│           ├── initrd
│           └── vmlinuz
├── html
│   ├── centos7
│   ├── centos8
│   ├── id_rsa.pub
│   └── ubuntu
│       ├── init.sh
│       ├── meta-data
│       ├── ubuntu-23.04-live-server-amd64.iso
│       ├── user-data
│       └── vendor-data
├── logs
│   ├── access.log
│   ├── dnsmasq.log
│   ├── error.log
│   └── nginx.pid
├── proxy_temp
├── sbin
│   ├── dnsmasq
│   └── nginx
├── scgi_temp
├── share
│   └── man
│       └── man8
│           └── dnsmasq.8
├── starter.sh
├── test.cfg
└── uwsgi_temp
```

# pxe工具使用说明

本工具的实现是在[本文](https://blog.csdn.net/u010438035/article/details/128396790)的验证基础上实现的

已编译好的工具可直接clone至任意一台作为PXE Server的服务器（ubuntu，centos等linux系统）根目录，微调即可使用。

```
git clone https://github.com/ziwend/pxe_tool
```

## 准备工作
1. 关闭防火墙（Centos可能还要关闭selinux），熟悉防火墙配置的放开对应端口（如53,69，80，等）也可以。
```
#关闭ubuntu的防火墙
ufw status
ufw disable
``` 
2. 配置免密登录，已配置的可忽略，也可跳过这一步
```
#在/root 下创建目录.ssh（如果已经存在.ssh 目录，需要先删除.ssh 目录rm -rf /.ssh），并将生成/root/.ssh/id_rsa和/root/.ssh/id_rsa.pub

ssh-keygen -t rsa -P ''
cp /root/.ssh/id_rsa.pub /pxe_tool/html/
```
## 分系统说明
=================ubuntu===================

参考：https://ubuntu.com/server/docs/install/netboot-amd64

```
#检查user-data是否符合目标配置，否则，需手动修改user-data内容
cat /pxe_tool/html/ubuntu/user-data

#由于initrd,vmlinuz文件较大，并没有上传github，需要自行复制到对应目录，以23.04为例
mount -t iso9660 -o loop,ro ubuntu-23.04-live-server-amd64.iso /mnt
cp /mnt/casper/{initrd,vmlinuz} /pxe_tool/ftpd/ubuntu-23.04
#同样iso文件也要自行从官方渠道下载并放置到对应目录，比如23.04
/pxe_tool/html/ubuntu2304/ubuntu-23.04-live-server-amd64.iso

#暂时未找到方法更改这两个文件{grubx64.efi grub.cfg}的位置，所以根据要安装的系统是22.04还是20.04 把grubx64.efi文件移动到tftp根目录，把grub.cfg移动到tftp的grub目录
#grubx64.efi文件可能不区分是20或22，grub.cfg可以同时添加20和22，安装的时候选择，或提前设置默认值

# 以下以22.04为例
#检查grub配置，主要需要修改ip地址或iso包文件名等
cat  /pxe_tool/ftpd/grub/grub.cfg

#比如替换ip
ifconfig | grep 'inet '| cut -f 2 |cut -d " " -f 10
SERVER_IP=192.168.1.2
sed -i "s#192.168.0.49#$SERVER_IP#g" ftpd/grub/grub.cfg

#直接复制(已验证grubx64.efi 20.04和22.04都可用)
cp ftpd/ubuntu-22.04/grubx64.efi ftpd/  #(non-secureboot时不用复制)
chmod +r ftpd/ubuntu-22.04/*

#dnsmasq.conf修改（修改boot路径，ip range，interface等）
#查看dnsmasq配置,根据实际情况更改
grep -Ev "^$|#" dnsmasq.conf

#特殊情况：网络中已经有其他DHCP服务器了，并且我不希望我的DHCP干扰网络中其他的正常ip分配。所以希望pxe的DHCP服务器只对某个固定的MAC地址分配ip，比如配置如下ip
dhcp-range=192.168.0.2,static
dhcp-host=00:15:5d:a9:8b:03,192.168.0.2

chmod +x /pxe_tool/sbin/*


#根据具体服务器配置需要修改dnsmasq_ubuntu.conf文件中的interface=eth1,lo
ip a
sed -i 's/interface=eth1/interface=ens29f0/g' conf/dnsmasq_ubuntu.conf

#启动
./sbin/dnsmasq -C conf/dnsmasq_ubuntu.conf
./sbin/nginx

#这个是初始化脚本，不需要开机做一些设置的可忽略
cat > /pxe_tool/html/ubuntu/init.sh  << 'EOF'
#!/bin/bash
# add log
cat << "EOF" >> /etc/profile
#set user history
USER=`whoami`
USER_IP=`who -u am i 2>/dev/null| awk '{print $NF}'|sed -e 's/[()]//g'`
if [ "$USER_IP" = "" ]; then
    USER_IP=`hostname`
fi
if [ ! -d /var/log/history/${LOGNAME} ]; then
    sudo mkdir -p /var/log/history/${LOGNAME}
    sudo chown -R ${LOGNAME}:${LOGNAME} /var/log/history/${LOGNAME}
    sudo chmod 300 /var/log/history/${LOGNAME}
fi
export HISTORY_FILE="/var/log/history/${LOGNAME}/bash_history"
export PROMPT_COMMAND='{ msg=$(history 1 | { read x y; echo $y; });echo $(date +"%Y-%m-%d %H:%M:%S") [$USER@$LOGNAME@$USER_IP `pwd` ]" $msg" >> $HISTORY_FILE; }'
EOF

# 调试：
sudo tail -f /pxe_tool/logs/dnsmasq.log

sudo tail -f /pxe_tool/logs/access.log
sudo tail -f /pxe_tool/logs/error.log
sudo tail -f /var/log/messages(centos)

# 停止
sudo ./sbin/nginx -s stop
sudo killall -KILL dnsmasq
```
=============================Debian===========================

参考：https://wiki.debian.org/PXEBootInstall

<https://www.debian.org/releases/stable/example-preseed.txt>

```
wget https://deb.debian.org/debian/dists/bullseye/main/installer-amd64/current/images/netboot/netboot.tar.gz
tar -zxvf netboot.tar.gz -C /pxe_tool/ftpd/
cd /pxe_tool/ftpd
ln -s debian-installer/amd64/grubx64.efi .
#ln -s debian-installer/amd64/grub . 该步骤可以不做

mv /pxe_tool/ftpd/debian-installer/amd64/grub/grub.cfg /pxe_tool/ftpd/debian-installer/amd64/grub/grub.cfg.bak
vi /pxe_tool/ftpd/debian-installer/amd64/grub/grub.cfg
set timeout=10
menuentry 'Install' {
set background_color=black
linux    /debian-installer/amd64/linux vga=788 auto=true priority=critical debian-installer/allow_unauthenticated=true  interface=auto netcfg/dhcp_timeout=60 netcfg/choose_interface=auto url=http://192.168.0.49/debian/preseed.cfg --- quiet
initrd   /debian-installer/amd64/initrd.gz
}

mkdir /pxe_tool/html/debian


mount -t iso9660 -o loop,ro debian-11.6.0-amd64-DVD-1.iso /mnt
cp -r /mnt/* /pxe_tool/html/debian/
umount /mnt

# 根据实际情况编辑preseed.cfg文件
vi /pxe_tool/html/debian/preseed.cfg


#启动
./sbin/dnsmasq -C conf/dnsmasq_debian.conf
./sbin/nginx
```
=============================CentOS8===========================

参考：<https://docs.centos.org/en-US/8-docs/advanced-install/assembly_preparing-for-a-network-install/>

```
systemctl status firewalld
systemctl stop firewalld
systemctl disable firewalld

mkdir /pxe_tool/html/centos8
上传CentOS-8.5.2111-x86_64-dvd1.iso到目录/pxe_tool/html/centos8
mount -t iso9660 -o loop,ro CentOS-8.5.2111-x86_64-dvd1.iso /mnt
cp -r /mnt/. /pxe_tool/html/centos8
umount /mnt

cat /root/anaconda-ks.cfg >/pxe_tool/html/centos8/ks.cfg
注意点1：network  --bootproto=dhcp --device=eth0 --onboot=yes --ipv6=auto --activate这里的device需要根据实际情况更改

#这个包是centos7的
rpm2cpio grub2-efi-x64-modules-2.02-0.86.el7.centos.noarch.rpm | cpio -dimv
mkdir -p  /pxe_tool/ftpd/EFI/centos/x86_64-efi/
cp ./usr/lib/grub/x86_64-efi/linuxefi.mod  /pxe_tool/ftpd/EFI/centos/x86_64-efi/

rpm2cpio grub2-efi-x64-2.02-90.el8.x86_64.rpm | cpio -dimv
mkdir -p /pxe_tool/ftpd/EFI/centos/
cp boot/efi/EFI/centos/grubx64.efi /pxe_tool/ftpd/EFI/centos/

cat > /pxe_tool/ftpd/EFI/centos/grub.cfg << EOF
set default="1"
set timeout=10
menuentry 'CentOS 7' {
  linuxefi EFI/centos/7/vmlinuz ip=dhcp inst.repo=http://192.168.0.49/centos7/ inst.ks=http://192.168.0.49/centos7/ks.cfg
  initrdefi EFI/centos/7/initrd.img
}

menuentry 'CentOS 8' {
  linuxefi EFI/centos/8/vmlinuz ip=dhcp inst.ks=http://192.168.0.49/centos8/ks.cfg inst.stage2=http://192.168.0.49/centos8/ 
  initrdefi EFI/centos/8/initrd.img
}
EOF
mkdir -p /pxe_tool/ftpd/EFI/centos/8
cp /pxe_tool/html/centos8/images/pxeboot/{vmlinuz,initrd.img} /pxe_tool/ftpd/EFI/centos/8/
chmod +r /pxe_tool/ftpd/EFI/centos/*
chmod +x /pxe_tool/sbin/*

#根据服务器配置需要修改dnsmasq_centos.conf文件中的interface=eth1,lo

ip a
sed -i 's/interface=eth1/interface=ens29f0/g' conf/dnsmasq_centos.conf
# 启动服务
./sbin/dnsmasq -C conf/dnsmasq_centos.conf
./sbin/nginx
```
=============================CentOS7===========================

参考：<https://docs.centos.org/en-US/centos/install-guide/pxe-server/#sect-network-boot-setup-uefi>

```
systemctl status firewalld
systemctl stop firewalld
systemctl disable firewalld

setenforce 0; sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config
cat /etc/selinux/config


mkdir /pxe_tool/html/centos7
上传CentOS-7.9.2009-x86_64-DVD.iso文件至/pxe_tool/html/centos7
mkdir /media/CentOS
mount -t iso9660 -o loop,ro CentOS-7.9.2009-x86_64-DVD.iso /media/CentOS/
cp -r /media/CentOS/. /pxe_tool/html/centos7
#umount /media/CentOS

cat /root/anaconda-ks.cfg >/pxe_tool/html/centos7/ks.cfg
vi /pxe_tool/html/centos7/ks.cfg
# Use network installation
url --url="http://192.168.0.49/centos7"

#决定是否在系统第一次引导时启动"设置代理".如果启用,firstboot软件包必须被安装.如果不指定,这个选项是缺省为禁用的
firstboot --disable

#指定时区
timezone Asia/Shanghai --isUtc

#删除系统分区,防止系统盘之前装过系统，初始化标签
clearpart --all --initlabel

reboot

%packages
%end

cat > /pxe_tool/ftpd/EFI/centos/grub.cfg << EOF
set default="0"
set timeout=10
menuentry 'CentOS 7' {
  linuxefi EFI/centos/7/vmlinuz ip=dhcp inst.repo=http://192.168.0.49/centos7/ inst.ks=http://192.168.0.49/centos7/ks.cfg
  initrdefi EFI/centos/7/initrd.img
}

menuentry 'CentOS 8' {
  linuxefi EFI/centos/8/vmlinuz ip=dhcp inst.ks=http://192.168.0.49/centos8/ks.cfg inst.stage2=http://192.168.0.49/centos8/ 
  initrdefi EFI/centos/8/initrd.img
}
EOF

mkdir -p /pxe_tool/ftpd/EFI/centos/7
# vmlinuz,initrd.img 这两个文件centos7和8不一样
cp /pxe_tool/html/centos7/images/pxeboot/{vmlinuz,initrd.img} /pxe_tool/ftpd/EFI/centos/7
chmod +r /pxe_tool/ftpd/EFI/centos/*

#chmod +x sbin/dnsmasq
#chmod +x sbin/nginx
chmod +x sbin/*

ip a
sed -i 's/interface=eth1/interface=ens29f0/g' conf/dnsmasq_centos.conf

# 启动
./sbin/dnsmasq -C conf/dnsmasq_centos.conf
lsof -i :53
# 启动Nginx
./sbin/nginx
lsof -i :80
···
