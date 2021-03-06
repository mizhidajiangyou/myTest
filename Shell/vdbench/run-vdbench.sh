#!/bin/bash
# 使用脚本前，请确认防火墙状态
# 该脚本用于生成单/多主机利用vdbench测试性能
# 磁盘型号
BRAND="DubheFlash"
# 脚本模式
MODE=2
# 测试类型
VD_TYPE="fc"
# 测试设备总大小（G）
V_SI=500
# 运行时间
ELAPSED=300
# 等待时间
WARMUP=30
# 暂停时间
PAUSE=30
# 打印时间
INTERVAL=1
# 总行数
ONE_RD_COUNT=`echo $ELAPSED/$INTERVAL+$WARMUP/$INTERVAL+1|bc`
# 线程
THREADS=32
# 随机比例
SEEK=(100 0)
# 块大小
BLOCK=("4K" "1M")
# 读比例
RDPCT=(0 100)
# 文件系统操作
OPERATION=(write read)
# 文件读写方式
FILEIO=(random sequential)
# 文件选择方式
FILESELECT=(sequential)
# 深度级别
FILE_DEPTH=3
# 目录个数
FILE_WIDTH=5
# 文件数目
FILE_NUM=32
# 文件大小(MB)
FILE_SIZE=10
# IP
IP_LIST=(`ip a | grep "state UP" -A 3 |awk '$2~/^[0-9]*\./ {print $2}' |awk -F "/" 'NR==1 {print $1}'`)
# 日期
FILE_DATE=`date '+%y%m%d'`
# 测试项
ALL_TEST_LIST=()
# 测试名
ALL_TEST_LIST_TITLE=()
# 本机IP
MY_IP=${IP_LIST[0]}
# 密码
MY_PASSWD=password
# 脚本地址
VD_FILE="`pwd`/$FILE_DATE/"
# VDBENCH目录
VD_HOME="/root/vdbench/"
# 报告目录
VD_OUT="$VD_FILE/vd-output/"
# 日志存放目录
VD_LOG="$VD_FILE/"
# 日志重定向文件
LOG_FILE="$VD_LOG/vd$FILE_DATE.log"
# 测试本地磁盘列表
LOCAL_DISK_LIST=()
# 测试本地文件系统列表
LOCAL_FILE_LIST=()
SSH_COMMAND=""
# 使用方法
usage(){
    echo -e "\033[1musage: vdbench.sh [ --help]
    <--brand| --mode| --type| --ip> \n
    (--Ldisk)\n
    [--size| --rdpct| --block| --fileio| --seekpct] \n
    [--runtime| --interval| --warmup | --pause] \n
    [--file| --out| --log| --date] \n
    brand     <string>            disk manufacturer;default SEAGATE
    mode      <int>               whether which run mode you test;default 2
              *   0               scan and test
              *   1               test and make report
              *   2               nohup run vdbench &
              *   3               only use your output to make picture report
              *   4               ssh no password
              *   5               use parameter \"command\" to run bash in all client
    type      <string>            whether which volume type you test;default fc
              *   fc              must install device-mapper-multipath(multipath-tools)
              *   iscsi           must install iscsi
              *   nfs             must install nfs-utils
              *   cifs            default support
              *   Ldisk           test every client local disk whitch you  appoint
              *   Lfile           test every client local file system  whitch you  appoint
    disk      <\"array\">           when the type is Ldisk must to define;no default.
    ip        <\"array\">           all ip list which you want to test;default ssh ip
    size      <int>               disk or file size;default 500
    rdpct     <\"array\">           percentage of read ;default \"0 100\"
    block     <\"array\">           test block size ;default \"4k 1M\"
    fileio    <\"array\">           test fileio ;default \"random sequential\"
    seekpct   <\"array\">           test random ratio ;default \"100 0\"
    runtime   <int>               test runtime(s) ;default 300
    interval  <int>               print interval(s) ;default 1
    warmup    <int>               hot start time(s) ;default 30
    pause     <int>               pause time(s) ;default 30
    fdepth    <int>               fsd default file depth
    fwidth    <int>               fsd default file width
    fnum      <int>               fsd default file num
    fsize     <int>               fsd default file size (MB)
    file      <\"path\">            *.vbd will put in;default pwd/date;
                                    *it is recommended to modify this option only。
    out       <\"path\">            vdbench out put will put in;default pwd/vd-output
    log       <\"path\">            run logs will put in;default same with file
    date      <date>              date for test ,like 220101;default date '+%y%m%d'
    command   <string>            the command in ssh \"ip\" bash \"command\"
    e.g.
    --mode 1 --type fc --ip \"192.168.8.81 192.168.8.82\" --file \"/root/z/aa/\"
    --size 666 --runtime 604800 --seekpct 100 --rdpct 70 --block 2M
    --mode 1 --type nfs --fdepth 3 --fdepth 5 --fnum 32 --fsize 1
    --type Ldisk --disk \"sdb sdc\"
    --command \"echo '- - -'|tee /sys/class/scsi_host/*/scan -a\"
    --command \"iscsiadm -m discovery -t st -p xx.xx.xx.xx && iscsiadm -m node --login -p xx.xx.xx.xx \"
    --command \"multipath -F && lsblk -o \"NAME,MODEL\"|grep size | grep model |awk '{print \$1}' | while read line ;do echo 1> /sys/block/\$line/device/delete;done\"
    ...\033[0m"

    exit 1

}
# 判断int类型
pdInt(){
    expr $1 + 0 &>/dev/null
    if [  $? -ne 0 ];then
        sendLog "type not int!"  3
        usage
        exit 1
    fi
    sendLog "Correct type!" 1
}
# 日志管理
sendLog(){
    case $2 in
    0)
        LEVEL="DEBUG - ";;
    1)
        LEVEL="INFO - ";;
    2)
        LEVEL="WARNING - ";;
    3)
        LEVEL="ERROR - ";;
    4)
        LEVEL="CRITICAL - ";;
    *)
        LEVEL="INFO - ";;
    esac

    printf "%-25s%s\n" "`date '+%Y-%m-%d %H:%M:%S.%3N'`"  " $LEVEL$1" >> ${LOG_FILE}
}



# 判断IP是否可用
pingIP(){
    a=1
    while [ $a -eq 1 ];do
    line=`ping -c 1 -W 1 -s 1 $1 | grep "100% packet loss" | wc -l`
        if [ $line -eq 0 ];then
            sendLog "ping $1 ok" 1
            a=0
            return 0
        else
            sendLog "$1 not ok try again after 3s!" 3
        fi
            sleep 3
    done
}

checkIP(){
    for i in ${IP_LIST[*]}
    do
        pingIP $i
    done
    if [ `ip a | grep $MY_IP |wc -l` -eq 1 ];then
        sendLog "MY_IP is $MY_IP" 1
    else
        sendLog "$MY_IP not ok !" 3
        tail ${LOG_FILE} -n 5
        exit 1
    fi
}


# 根据IP生成客户端名称C-xx
makeClient(){
    for ((i=0;i<${#IP_LIST[*]};i++))
    do
        clientName[$i]="C-`echo ${IP_LIST[$i]} |cut -d '.' -f4`"
        echo $i
    done
}
makeHosts(){
    printf  "%s\n%s\n"  "127.0.0.1    localhost localhost.localdomain " "::1    localhost localhost.localdomain" >  /etc/hosts

    for ((i=0;i<${#IP_LIST[*]};i++))
    do
        hostInfo="${IP_LIST[$i]}    ${clientName[$i]}"
        echo "$hostInfo" >> /etc/hosts
    done
}
# 免密
getPub(){

    expect -c "
        set timeout 3;
        spawn ssh root@$1
        expect {
            \"yes/no\" {send \"yes\r\"; exp_continue;}
            \"password:\" {send \"$MY_PASSWD\r\";}
        }
        expect \"#\"
        send \"yes | ssh-keygen -t rsa -b 2048 -P '' -f /root/.ssh/id_rsa\r\"
        expect \"#\"
        send \"scp /root/.ssh/id_rsa.pub ${MY_IP}:/root/pb-$1\r\"
        expect {
            \"yes/no\" {send \"yes\r\"; exp_continue;}
            \"password:\" {send \"$MY_PASSWD\r\";}
        }
        expect \"#\"
        send \"exit\r\"
        expect eof"

    cat /root/pb-$1 >> /root/.ssh/authorized_keys


}
sendPub(){
    expect -c "
        set timeout 3;
        spawn scp /root/.ssh/authorized_keys root@$1:/root/.ssh
        expect {
            \"yes/no\" {send \"yes\r\"; exp_continue;}
            \"password:\" {send \"$MY_PASSWD\r\";}
        }
        expect eof"
}
run-no(){
    yes | ssh-keygen -t rsa -b 2048 -P "" -f /root/.ssh/id_rsa
    # 完成免密
    for i in ${IP_LIST[*]}
    do
       getPub ${i}
    done
    # echo `cat /root/.ssh/id_rsa.pub` >> /root/.ssh/authorized_keys
    for i in ${IP_LIST[*]}
    do
       sendPub ${i}
    done
    # 修改know_host文件
    for ((i=0;i<${#IP_LIST[*]};i++))
    do
       echo `sed "s/${IP_LIST[$i]}/${clientName[$i]}/g" /root/.ssh/known_hosts |grep ${clientName[$i]}` >> /root/.ssh/known_hosts

    done
    # 修改hosts
    for i in ${IP_LIST[*]}
    do
       scp /etc/hosts root@${i}:/etc
       scp /root/.ssh/known_hosts root@${i}:/root/.ssh/
    done

}
runBash(){

    for i in ${IP_LIST[*]}
    do
       ssh ${i} "$SSH_COMMAND"
    done

}


ip_main(){
    checkIP
    makeClient
    makeHosts
    run-no
}



# 检查变量正确性
checkVal(){


    # 检测日志存放目录
    if [ -d $VD_LOG ]
    then
        sendLog "log file in $VD_LOG" 1
    else
        mkdir -p $VD_LOG
        sendLog "mkdir log FILE" 2
    fi


    # PYTHON环境检查
    if [ ! -n $ZHOME  ]
    then
        sendLog "path not ready!" 3
        sendLog "know path zhome is : $ZHOME" 3
        tail ${LOG_FILE} -n 5
        exit 1
    fi

    # 检测脚本存放目录
    if [ -d $VD_FILE ]
    then
        sendLog "*vdb will in $VD_FILE" 1
    else
        mkdir -p $VD_FILE
        sendLog "mkdir file" 1
    fi

    # 检测vdbench目录
    if [ -d $VD_HOME ]
    then
        sendLog "vdbench is in $VD_HOME" 1
    else
        sendLog "no vdbench！" 3
        tail ${LOG_FILE} -n 5
        exit 1
    fi
    # 参数正确性
    ## type类型
    if [ $VD_TYPE == "fc" -o $VD_TYPE == "iscsi" -o $VD_TYPE == "nfs" -o $VD_TYPE == "cifs" -o $VD_TYPE == "Ldisk" -o $VD_TYPE == "Lfile" ];then
        sendLog "know run type : $VD_TYPE" 1
    else
        sendLog "type : $VD_TYPE error! no match" 3
        usage
    fi

    ## 判断参数类型
    sendLog "check ELAPSED" 1
    pdInt $ELAPSED
    sendLog "check FILE_DEPTH" 1
    pdInt $FILE_DEPTH
    sendLog "check FILE_NUM" 1
    pdInt $FILE_NUM
    sendLog "check FILE_SIZE" 1
    pdInt $FILE_SIZE
    sendLog "check FILE_WIDTH" 1
    pdInt $FILE_WIDTH
    sendLog "check INTERVAL" 1
    pdInt $INTERVAL
    sendLog "check WARMUP" 1
    pdInt $WARMUP
    sendLog "check PAUSE" 1
    pdInt $PAUSE

    # 生成文件总大小
    FILE_ALL_SIZE=$[$FILE_DEPTH**$FILE_WIDTH*$FILE_NUM*$FILE_SIZE*1024*${#IP_LIST[*]}]
    # 简单判断大小
    if [ $VD_TYPE == "nfs" ] || [ $VD_TYPE == "cifs" ];then
        sendLog "check size" 1
        pdInt `df |awk '$1~/[0-9]./{print $4;exit}'`
        if [ $FILE_ALL_SIZE -ge `df |awk '$1~/[0-9]./{print $4;exit}'` ];then
            sendLog "set size $FILE_ALL_SIZE ,bigger than nfs avail" 3
            usage
        fi
    fi



    # 检测java

    if [  `ls /bin | grep -w java |wc -l` -eq 0 ]
    then
        sendLog "no java！" 3
        tail ${LOG_FILE} -n 5
        exit 1
    else
        #echo "`ls /bin | grep -w java`" >> ${LOG_FILE}
        sendLog "java is good" 1

    fi

    # 检测IP是否可用
    checkIP

    #
}

# 获取命令
getCommand(){
    case $VD_TYPE in
    fc)
        COMMAND="multipath -ll |grep -B2 $V_SI|grep ${BRAND}|awk '{printf \"/dev/mapper/%s\n\",\$1}'";;

    iscsi)
        COMMAND="lsblk -o NAME,SIZE,VENDOR,MODEL,TRAN|grep iscsi |grep -B2 $V_SI|grep ${BRAND}|awk '{printf \"/dev/%s\n\",\$1}'";;
    Ldisk)
        COMMAND="echo ${LOCAL_DISK_LIST[*]}|tr \" \" \"\n\"|sed \"s/s/\/dev\/s/g\"";;
    nfs)
        COMMAND="df | awk '\$1~/^[0-9]./{print \$6}'"
        ;;
    cifs)
        COMMAND="df | awk '\$1~/^\/\/[0-9]./{print \$6}'"
        ;;

    *)
        exit 0;;
    esac
}


# 块设备
getTestListB(){
    for i in ${BLOCK[*]}
    do
        for j in ${SEEK[*]}
        do
            for k in ${RDPCT[*]}
            do
                #设定参数
                wd="xfersize=${i},rdpct=${k},seekpct=${j}"
                ms="${i}-${k}%read-${j}seek"
                ALL_TEST_LIST[${#ALL_TEST_LIST[*]}]=${wd}
                ALL_TEST_LIST_TITLE[${#ALL_TEST_LIST_TITLE[*]}]=${ms}

            done
        done
    done
    sendLog "testBlist:${ALL_TEST_LIST[*]}" 0
    # printf "%s\n" "testBlist:${ALL_TEST_LIST[*]}" >> ${LOG_FILE}
}
# 文件系统
getTestListF(){
    for i in ${FILESELECT[*]}
    do
        for j in ${BLOCK[*]}
        do
            for k in ${OPERATION[*]}
            do
                for f in ${FILEIO[*]}
                do
                    #设定参数
                    fwd="operation=$k,xfersize=$j,fileio=$f,fileselect=$i"
                    ms="${j}-${f}-$k-$i.s"
                    ALL_TEST_LIST[${#ALL_TEST_LIST[*]}]=${fwd}
                    ALL_TEST_LIST_TITLE[${#ALL_TEST_LIST_TITLE[*]}]=${ms}
                done
            done
        done
    done
    sendLog "testFlist:${ALL_TEST_LIST[*]}" 0
    #printf "%s\n" "testFlist:${ALL_TEST_LIST[*]}" >> ${LOG_FILE}
}
# 块设备wd设置
getwd(){
    WD_LIST=()
    FWDL=()
    for ((i=0;i<${#ALL_TEST_LIST[*]};i++))
    do
        if [ $VD_TYPE == "nfs" ] || [ $VD_TYPE == "cifs" ];then
            for ((j=0;j<${#IP_LIST[*]};j++))
            do
                FWDN="${i}t${j}h"
                FWDL[$i]="${FWDL[$i]}${FWDN},"
                FSDLN="(${FSDL[$j]})"
                count=$[$i*${#IP_LIST[*]}+$j]
                WD_LIST[$count]="fwd=$FWDN,fsd=$FSDLN,${ALL_TEST_LIST[$i]},host=hd$j"
            done
        # printf "%s\n" "FWDL:${FWDL[*]}" >> ${LOG_FILE}
        else
            WD_LIST[$i]="wd=wd$i,sd=sd*,${ALL_TEST_LIST[$i]}"
        fi

    done
    sendLog "wdlist:${WD_LIST[*]}" 0
    #printf "%s\n" "wdlist:${WD_LIST[*]}" >> ${LOG_FILE}
}

# 获取设备列表
getsd(){
    # sd类型直接使用数组存放脚本信息，fsd需额外处理
    SD_LIST=()
    # 存放所有数据以便后续调用
    FSD_LIST=()
    #存放同一hd的fsd
    FSDL=()
    for ((i=0;i<${#IP_LIST[*]};i++))
    do
        # 获取盘符
        DN=(`ssh ${IP_LIST[$i]} "$COMMAND"`)
        # 判断是否为空
        if [ ${#DN[*]} -lt 1 ]
        then
            printf "\033[32mcan't get list\033[0m for command:%s\n" "$COMMAND" >> ${LOG_FILE}
            tail ${LOG_FILE} -n 5
            exit 1
        fi
        if [ $VD_TYPE == "nfs" ] || [ $VD_TYPE == "cifs" ];then

            FSD_LIST[${#FSD_LIST[*]}]="${DN[*]}"
            printf "%s\n" "fsdlist:${FSD_LIST[*]}" >> ${LOG_FILE}

            FSD=(${DN[*]})
            for ((j=0;j<${#FSD[*]};j++))
            do
                FSDN="${i}hd${j}"
                FSDL[$i]="${FSDL[$i]}${FSDN},"
                SD_LIST[${#SD_LIST[*]}]="fsd=$FSDN,anchor=${FSD[$j]}/$FSDN"
            done
            # printf "%s\n" "FSDL:${FSDL[*]}" >> ${LOG_FILE}

        else
            for ((j=0;j<${#DN[*]};j++))
            do
                count=$[$i*${#DN[*]}+$j]
                SD_LIST[${#SD_LIST[*]}]="sd=sd$count,hd=hd$i,lun=${DN[$j]}"
            done
        fi
    done
    sendLog "sdlist:${SD_LIST[*]}" 0
    #printf "%s\n" "sdlist:${SD_LIST[*]}" >> ${LOG_FILE}
}


# run设置
getrd(){
    RD_LIST=()

    for ((i=0;i<${#ALL_TEST_LIST[*]};i++))
    do

        if [ $VD_TYPE == "nfs" ] || [ $VD_TYPE == "cifs" ];then

            FWDLN="(${FWDL[$i]})"
            RD_LIST[$i]="rd=rd$i,fwd=$FWDLN,fwdrate=max,format=restart,elapsed=$ELAPSED,interval=$INTERVAL,warmup=$WARMUP,pause=$PAUSE,threads=$THREADS"


        else
            RD_LIST[$i]="rd=rd$i,wd=wd$i,threads=$THREADS,iorate=max,elapsed=$ELAPSED,interval=$INTERVAL,warmup=$WARMUP,pause=$PAUSE"
        fi

    done
    sendLog "rdlist:${RD_LIST[*]}" 0
    #printf "%s\n" "rdlist:${RD_LIST[*]}" >> ${LOG_FILE}
}


# host.vdb
setHost(){
    printf "%s\n" "hd=default,user=root,vdbench=$VD_HOME,shell=ssh,jvms=${#IP_LIST[*]}" > ${VD_FILE}/host.vdb
    for ((i=0;i<${#IP_LIST[*]};i++))
    do
        printf "%s\n" "hd=hd${i},system=${IP_LIST[$i]}" >> ${VD_FILE}/host.vdb
    done
}


# volume.vdb
setVol(){

    if [ $VD_TYPE == "nfs" ] || [ $VD_TYPE == "cifs" ];then
        printf "%s\n" "fsd=default,depth=${FILE_DEPTH},width=${FILE_WIDTH},files=${FILE_NUM},size=${FILE_SIZE}M,shared=yes,openflags=directio" > ${VD_FILE}/volume.vdb
    else
        printf "%s\n" "sd=default,openflags=o_direct" > ${VD_FILE}/volume.vdb
    fi
    for ((i=0;i<${#SD_LIST[*]};i++))
    do
        printf "%s\n" "${SD_LIST[$i]}" >> ${VD_FILE}/volume.vdb
    done
}



# run.vdb
setTerm(){
    printf "%s\n%s\n%s\n" "messagescan=no" "include=$VD_FILE/host.vdb" "include=$VD_FILE/volume.vdb" > ${VD_FILE}/run.vdb

    for ((i=0;i<${#WD_LIST[*]};i++))
    do
        #printf "%s\n%s\n" ${WD_LIST[$i]} ${RD_LIST[$i]} >> ${VD_FILE}/run.vdb
        printf "%s\n" ${WD_LIST[$i]}  >> ${VD_FILE}/run.vdb
    done
    for ((i=0;i<${#ALL_TEST_LIST[*]};i++))
    do
        printf "%s\n"  ${RD_LIST[$i]} >> ${VD_FILE}/run.vdb
    done
}

runVdb-nohup(){
    nohup $VD_HOME/vdbench -f ${VD_FILE}/run.vdb -o $VD_OUT >> $VD_LOG/run.vdb.$FILE_DATE 2>&1 &
    if [ $? -eq 0 ];then
        printf "\033[32m%s\033[0m\n%s\n" "successful run vdb" "PID:$!" >> ${LOG_FILE}
    else
        printf "\033[31m%s\033[0m\n%s\n" "error!" "PID:$!" >> ${LOG_FILE}
    fi
}

runVdb(){
    $VD_HOME/vdbench -f ${VD_FILE}/run.vdb -o $VD_OUT
}
# 绘制实时IO图，并生成total.sin来简化total内容
getDataMakePic(){
    # 生成最简报告
    awk '$3~/^[0-9]*\./{printf "%s\n","block:"$5"--iops:"$3"--bs:"$4"--resp:"$7}' $VD_OUT/totals.html  > $VD_OUT/total.sin

    # 判断python文件是否存在
    if [ -f $ZHOME/Performance/IOLine.py ]
    then
        sendLog "python file is ok" 1
    else
        sendLog "no python file!" 3
        sendLog "run --mode 3 --out `pwd`/ --type $VD_TYPE;to only make pic again." 0
        return 1
    fi
    # 绘图
    sendLog "run make pic" 1
    for ((i=0;i<${#ALL_TEST_LIST_TITLE[*]};i++))
    do

        data_name="$VD_OUT/${ALL_TEST_LIST_TITLE[$i]}"
        # f_n=`echo $ONE_RD_COUNT*$i+1|bc`
        # l_n=`echo $ONE_RD_COUNT*$i+$ONE_RD_COUNT|bc`
        #awk '$3~/^[0-9]*\./{print $3}' $VD_OUT/summary.html | awk "NR>=$f_n && NR<=$l_n" > $data_name.iops
        #awk '$3~/^[0-9]*\./{print $4}' $VD_OUT/summary.html | awk "NR>=$f_n && NR<=$l_n" > $data_name.bs
        awk "/RD=rd$i/,/avg/{print}" $VD_OUT/summary.html |awk '$1~/^[0-9]/{print $3}' > $data_name.iops

        if [ $VD_TYPE == "nfs" ] || [ $VD_TYPE == "cifs" ];then
            awk "/RD=rd$i/,/avg/{print}" $VD_OUT/summary.html |awk '$1~/^[0-9]/{print $14}' > $data_name.bs
        else
            awk "/RD=rd$i/,/avg/{print}" $VD_OUT/summary.html |awk '$1~/^[0-9]/{print $4}' > $data_name.bs
        fi
        cp $ZHOME/Performance/IOLine.py IOLine.py
        sed -i "s!LINE_TITLE!${ALL_TEST_LIST_TITLE[$i]}!g" IOLine.py
        sed -i "s!SAVE_PATH!$VD_OUT!g" IOLine.py
        python3  IOLine.py
    done


}
# 生成TotalReport.z来获取易读的total信息
makeTotalReport(){
    if [ $VD_TYPE == "nfs" ] || [ $VD_TYPE == "cifs" ];then
        if [ `cat ${VD_OUT}"totals.html" | grep avg|awk '!(NR%2)' | wc -l` -ne ${#ALL_TEST_LIST_TITLE[*]} ] ; then
            sendLog "output data error!" 3
            tail ${LOG_FILE} -n 5
            exit 1
        fi
        echo "**********Report***********" >> ${VD_OUT}/TotalReport.z
        for((i=0;i<${#ALL_TEST_LIST_TITLE[*]};i++))
        do
            cat ${VD_OUT}"totals.html" | grep avg|awk '!(NR%2)' |awk -v ti=${ALL_TEST_LIST_TITLE[$i]} -v num=$i 'NR==num+1 {printf "Title:\033[36m%s\033[0m, iops:\033[32m%s\033[0m, bs:\033[35m%s\033[0m\n",ti,$3,$14}' >> ${VD_OUT}/TotalReport.z
        done
        if [ $BLOCK[0] == "4K" ];then
            echo "************md************" >> ${VD_OUT}/TotalReport.z
            printf -- "|   4k随机写   |   4k随机读   |   4k顺序写   |   4k顺序读   |   1M随机写   |   1M随机读   |   1M顺序写   |   1M顺序读   |\n" >> ${VD_OUT}/TotalReport.z
            cat ${VD_OUT}/totals.html|grep avg|awk '!(NR%2)' | awk '{printf "%-15s","|"$3"/"$4}' >> ${VD_OUT}/TotalReport.z
            printf -- "|\n" >> ${VD_OUT}/TotalReport.z
        fi
        echo "**************************" >> ${VD_OUT}/TotalReport.z
    else
        if [ `cat ${VD_OUT}"totals.html" | grep avg|wc -l` -ne ${#ALL_TEST_LIST_TITLE[*]} ] ; then
            sendLog "output data error!" 3
            tail ${LOG_FILE} -n 5
            exit 1
        fi
        echo "**********Report***********" >> ${VD_OUT}/TotalReport.z
        for((i=0;i<${#ALL_TEST_LIST_TITLE[*]};i++))
        do
            cat ${VD_OUT}"totals.html" | grep avg |awk -v ti=${ALL_TEST_LIST_TITLE[$i]} -v num=$i 'NR==num+1 {printf "Title:\033[36m%-20s\033[0miops:\033[32m%-10s\033[0mbs:\033[35m%-10s\033[0m\n",ti,$3,$4}' >> ${VD_OUT}/TotalReport.z
        done
        if [ ${BLOCK[0]} == "4K" ];then
            echo "************md************" >> ${VD_OUT}/TotalReport.z
            printf -- "|   4k随机写   |   4k随机读   |   4k顺序写   |   4k顺序读   |   1M随机写   |   1M随机读   |   1M顺序写   |   1M顺序读   |\n" >> ${VD_OUT}/TotalReport.z
            awk '$3~/^[0-9]*\./{printf "%-15s","|"$3"/"$7}' ${VD_OUT}/totals.html >> ${VD_OUT}/TotalReport.z
            printf -- "|\n" >> ${VD_OUT}/TotalReport.z
        fi
        echo "**************************" >> ${VD_OUT}/TotalReport.z
    fi


}

# 生成图表依赖数据文件
makeMaxReport(){
    continue
}
# 根据type生成vdbench可执行的脚本
choiceList(){
    #
    if [ $VD_TYPE == "nfs" ] || [ $VD_TYPE == "cifs" ]
    then
        getTestListF
        sendLog "getTestListF ok" 0
    else
        getTestListB
        sendLog "getTestListB ok" 0
    fi
}


vd-createFile(){
    checkVal
    sendLog "checkval ok" 0
    getCommand
    sendLog "getCommand ok" 0
    choiceList
    sendLog "choiceList ok" 0
    getsd
    sendLog "getsd ok" 0
    getwd
    sendLog "getwd ok" 0
    getrd
    sendLog "getrd ok" 0
    setHost
    sendLog "setHost ok" 0
    setVol
    sendLog "setVol ok" 0
    setTerm
    sendLog "setTerm ok" 0


}

vd-normal(){
    vd-createFile
    sendLog "vd-createFile ok" 0
    runVdb
    sendLog "runVdb ok" 0
    getDataMakePic
    sendLog "getDataMakePic ok" 0
    makeTotalReport
    sendLog "makeTotalReport ok" 0
}



## main ##
# 检测参数正确性
    if [ x$1 == x ];then
        read -p "you wile use default mode! enter yes to continue or no see usage! " USE_DEFAULT
        if [ $USE_DEFAULT == "yes" -o $USE_DEFAULT == "y" ]
        then
            echo "run in default"
        else
            usage
            echo "don't run!"
            exit 0
        fi
    else
        echo "continue"
    fi




LINE=`getopt -o a --long help,brand:,mode:,type:,disk:,ip:,size:,rdpct:,block:,fileio:,seekpct:,runtime:,interval:,warmup:,pause:,file:,out:,log:,date:,command:,fdepth:,fwidth:,fnum:,fsize: -n 'Invalid parameter' -- "$@"`

if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$LINE"

while true;do
    case "$1" in
    --h)
    usage; shift 2;;
    --help)
    usage; shift 2;;
    --brand)
    BRAND=$2; shift 2;;
    --mode)
    MODE=$2; shift 2;;
    --type)
    VD_TYPE=$2; shift 2;;
    --disk)
    LOCAL_DISK_LIST=($2); shift 2;;
    --ip)
    IP_LIST=($2); shift 2;;
    --size)
    V_SI=$2; shift 2;;
    --rdpct)
    RDPCT=($2); shift 2;;
    --block)
    BLOCK=($2); shift 2;;
    --fileio)
    FILEIO=($2); shift 2;;
    --seekpct)
    SEEK=($2); shift 2;;
    --runtime)
    ELAPSED=$2;ONE_RD_COUNT=`echo $ELAPSED/$INTERVAL+$WARMUP/$INTERVAL+1|bc`; shift 2;;
    --interval)
    INTERVAL=$2;ONE_RD_COUNT=`echo $ELAPSED/$INTERVAL+$WARMUP/$INTERVAL+1|bc`; shift 2;;
    --warmup)
    WARMUP=$2;ONE_RD_COUNT=`echo $ELAPSED/$INTERVAL+$WARMUP/$INTERVAL+1|bc`; shift 2;;
    --pause)
    PAUSE=$2; shift 2;;
    --file)
    VD_FILE=$2; VD_OUT="$VD_FILE/vd-output/";VD_LOG="$VD_FILE/";LOG_FILE="$VD_LOG/vd$FILE_DATE.log";shift 2;;
    --out)
    VD_OUT=$2; shift 2;;
    --log)
    VD_LOG=$2; LOG_FILE="$VD_LOG/vd$FILE_DATE.log"; shift 2;;
    --date)
    FILE_DATE=$2; shift 2;;
    --command)
    SSH_COMMAND=$2; shift 2;;
    --fdepth)
    FILE_DEPTH=$2; shift 2;;
    --fwidth)
    FILE_WIDTH=$2; shift 2;;
    --fnum)
    FILE_NUM=$2; shift 2;;
    --fsize)
    FILE_SIZE=$2; shift 2;;
    --)
    shift;break;;
    *)
    break;;
    esac
done



case $MODE in
0)
    vd-normal
    sendLog "vd-normal fi" 1
    ;;
1)
    vd-normal
    sendLog "vd-normal fi" 1
    ;;

2)
    vd-createFile
    sendLog "create vdfile fi" 1
    runVdb-nohup
    sendLog "nohup run fi" 1
    ;;
3)
    choiceList
    getDataMakePic
    sendLog "makePic fi" 1
    ;;
4)
    checkVal
    sendLog "checkval fi" 1
    ip_main
    sendLog "no passwd fi" 1
    ;;
5)
    runBash
    sendLog "run ssh ok!" 1
    ;;

*)
    echo "no this mode!" ;exit 127;;
esac


tail $LOG_FILE -n 20