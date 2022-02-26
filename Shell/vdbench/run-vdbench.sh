#!/bin/bash

# 判断参数
if [ z$* != z ]
then
    if [ $# -eq 4 ]
    then
        printf "%s\n" "all good!"
    fi
else
    printf "%s\n%s\n\t%s\n\t%s\n\t%s\n\t%s\n" "usage:" "mode(1/2/3)" "title" "type" "size"
    exit 0
fi
# 卷大小
V_SI="${4}G"
# 路径配置
FILE_DATE=`date '+%y%m%d'`
mkdir -p /var/log/z
LOG_FILE="/var/log/z/z.log.${FILE_DATE}"
orPath="`pwd`"
# IP配置
IP_LIST=("10.0.24.96" "10.0.24.97" "10.0.24.98" "10.0.24.99")
clientName=()
# 测试磁盘列表
diskList=()
# 测试文件系统列表
fileList=()

# 环境配置
envInpect(){
# doker配置

# 将vdbench放置root目录
if [ /root/vdbench -d ]
then
    echo "vdbench is in /root" >> ${LOG_FILE}
else
    echo "cp vdbench" >> ${LOG_FILE}
    cp -r ../Tools/vdbench /root
fi
}
# 根据IP生成客户端名称C-xx
makeClient(){
for ((i=0;i<${#IP_LIST[*]};i++))
do
    clientName[$i]="C-`echo ${IP_LIST[$i]} |cut -d '.' -f4`"
done
}
# 判断IP是否可用
checkIP(){
 a=1
 while [ $a -eq 1 ];do
    line=`ping -c 1 -W 1 -s 1 $1 | grep "100% packet loss" | wc -l`
    if [ $line -eq 0 ];then
        echo "ping $1 ok" >> ${LOG_FILE}
        a=0
        return 0
    else
        echo "$1 not ok try again after 3s!" >> ${LOG_FILE}
    fi
        sleep 3
 done
}
# 重启
reStart(){
    ssh $1 << ZTX
    chronyc -a makestep
    sleep 1
    reboot
ZTX
}
# 配置hostname
setHostName(){
    expect << ZTX
    set timeout 3
    spawn ssh root@$1
    expect {
        "*yes/no" { send "yes\r" }
        "*password:" { send "password\r" }
    }
    exit 0
ZTX
}
# 配置IP

# host.vdb
setHost(){
printf "%s\n" "hd=default,user=root,vdbench=/root/vdbench,shell=ssh,jvms=${#IP_LIST[*]}" > /root/vdbench/host.vdb
for ((i=0;i<${#IP_LIST[*]};i++))
do
    printf "%s\n" "hd=${clientName[$i]},system=${IP_LIST[$i]}" >> /root/vdbench/host.vdb
done
}

# run.vdb
setRun(){
# 获取盘符
case ${1:0:1} in

m)
    printf "%s\n" "include=host.vdb" > /root/vdbench/run.vdb
    diskList=(`multipath -ll |grep -B2 $V_SI|grep DubheFlash|awk '{print $1}'`)
    diskNum=0

    for i in ${diskList[*]};do echo "sd=sd$diskNum,hd=${clientName[0]},lun=/dev/mapper/$i,openflags=o_direct" >> /root/vdbench/run.vdb ;let diskNum++;done
    ;;
*)
    echo "error! no matching!"
    ;;
esac
# 生成测试项
printf "%s\n" "wd=wd1,sd=sd*,xfersize=512,rdpct=100,seekpct=0
wd=wd2,sd=sd*,xfersize=512,rdpct=0,seekpct=0
wd=wd3,sd=sd*,xfersize=512,rdpct=100,seekpct=100
wd=wd4,sd=sd*,xfersize=512,rdpct=0,seekpct=100
wd=wd5,sd=sd*,xfersize=1M,rdpct=100,seekpct=0
wd=wd6,sd=sd*,xfersize=1M,rdpct=0,seekpct=0
wd=wd7,sd=sd*,xfersize=1M,rdpct=100,seekpct=100
wd=wd8,sd=sd*,xfersize=1M,rdpct=0,seekpct=100
rd=rd1,wd=wd1,warmup=30,iorate=max,elapsed=300,interval=10,threads=32
rd=rd2,wd=wd2,warmup=30,iorate=max,elapsed=300,interval=10,threads=32
rd=rd3,wd=wd3,warmup=30,iorate=max,elapsed=300,interval=10,threads=32
rd=rd4,wd=wd4,warmup=30,iorate=max,elapsed=300,interval=10,threads=32
rd=rd5,wd=wd5,warmup=30,iorate=max,elapsed=300,interval=10,threads=32
rd=rd6,wd=wd6,warmup=30,iorate=max,elapsed=300,interval=10,threads=32
rd=rd7,wd=wd7,warmup=30,iorate=max,elapsed=300,interval=10,threads=32
rd=rd8,wd=wd8,warmup=30,iorate=max,elapsed=300,interval=10,threads=32
" >> /root/vdbench/run.vdb

}



envInpect
makeClient
setHost
setRun $3

# 执行vdbench脚本
/root/vdbench/vdbench -f run.vdb -o $2
# 生成报告

