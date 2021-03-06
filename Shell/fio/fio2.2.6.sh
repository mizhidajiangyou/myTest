#!/usr/bin/env bash
# 必要参数设置
# 设置报告路径op
# 获取当日时间
# day=`date +%y%m%d`
day=`cat ../TestData/day.date | sed -n "1,1p"`
# 报告目录
output="../Report/DiskPerformance/Outputs/"
# python文件准备
cp ../Performance/bar.py ../Shell
cp ../Performance/IOLine.py ../Shell
cp bar.py bar.py-bak
cp IOLine.py IOLine.py-bak
# 生成文件夹
mkdir -p ${output}${day}
# 数据存放位置
path=${output}${day}"/"
# 带时间的报告文件设置date如下
# date=`date +%y%m%d`.txt
# 不带时间的报告文件设置date如下
date="test.txt"
# 测试项目
block=(4k 1M 128k)
ioway=(libaio sync)
rwway=(randwrite randread write read)
orgin=" -ioengine=ioway -bs=block -rw=rwway -name=reportname"
#生成后的测试项目
mode=()
rpname=()
#文件存放目录
fileList=()
pngList=()
# iostat行数统计
iostatNum=`iostat |wc -l`
# 计数
statCount=180
# 筛选行数=Iostat行数*计数
ioCount=`echo ${statCount}*${iostatNum}|bc`


#生成测试项
getTestList(){
for i in ${ioway[*]}
do
    for j in ${block[*]}
    do
        for k in ${rwway[*]}
        do
            #设定参数
            ys=" -ioengine=${i} -bs=${j} -rw=${k}"
            #fio参数组合mode
            mode[${#mode[*]}]=${ys}
            #定义报告名称
            n="${i}-${j}-${k}"
            rpname[${#rpname[*]}]=${n}
        done
    done
done
#echo ${mode[*]}
#echo ${rpname[*]}
}
# 生成报告
createFile(){
# 创建报告文件
for ((i=0;i<=${#ioway[*]}-1;i++))
do
    #设定文件名
    fn=${path}${op}-${ioway[i]}-${date}
    #设定PNG文件名
    #png=${path}${op}-${ioway[i]}-${date}.png
    #生成报告存放数组
    fileList[${#fileList[*]}]=${fn}
    #生成图片存放数组
    #pngList[${#pngList[*]}]=${png}
done

for ((i=0;i<${#fileList[*]};i++))
do
    echo "create ${fileList[${i}]}"
    sleep 1
    touch ${fileList[${i}]}
done

}
# 测试fio
fioTest(){
count=${#block[*]}*${#rwway[*]}
ioPath=${path}"iostat"
iostat -t 10 &>>${ioPath}&
for ((i=0;i<=${#fileList[*]}-1;i++))
do
    # 修改报告路径
    #echo ${fileList[${i}]}
    sed -i "s!output!${fileList[${i}]}!g" ${runio}
    for ((j=0;j<=${count}-1;j++))
    do
        changeFile="${mode[${j}+${i}*${count}]} -name=${rpname[${j}+${i}*${count}]}"
        echo ${rpname[${j}+${i}*${count}]} >> ${ioPath}
        echo "now is ${changeFile}"
        sed -i "s/${orgin}/${changeFile}/g" ${runio}
        #cat ${runio}
        ./${runio}
        echo "=============fi===========" >> ${ioPath}
        # 还原fio文件
        sed -i "s/${changeFile}/${orgin}/g" ${runio}
        #cat ${runio}

    done
    # 复原报告路径
    sed -i "s!${fileList[${i}]}!output!g" ${runio}
done
# 终止iostat
ps -aux | grep iostat | sed -n "1,1p" | awk '{print $2}' |xargs kill -9
}
# 汇总报告输出
allReportCreate(){
    for ((i=0;i<${#fileList[*]};i++))
    do
        echo "======================================================${ioway[${i}]}======================================================" >> ${path}${op}-all-${date}
        cat ${fileList[${i}]} |grep -B 1 "BW=" >> ${path}${op}-all-${date}
    done
}
#替换（传参有误，待优化）
th(){
    for ((i=0;i<${#ioway[*]};i++))
    do
        echo ${rpname[*]}
        # 定义数据来源文件
        rp=${fileList[${i}]}
        echo "from:"${rp}"building png"
        for ((j=0;j<${#block[*]};j++))
        do
            # 替换标题
            barTitle=${ioway[${i}]}-${block[${j}]}-$1
            echo ${barTitle}
            sed -i "s/test-title/${barTitle}/" bar.py
            #替换具体参数

            for ((k=0;k<${#rwway[*]};k++))
            do
                rname=${rpname[(${i}*${#block[*]}+${j})*${#rwway[*]}+${k}]}
                #echo $2
                #echo ${rname}

                num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $4}' | cut -d "=" -f2 | cut -d "," -f1`
                echo ${num:0-4}
                echo "==============="${num:0:0-4}
                #if ${num:0-4} -eq "KB/s";then
                    #num=${num:0:0-4}/1024
                #fi

                # 替换x轴标注
                sed -i "s!mmm${k}!${num:0:0-4}!g" bar.py
                # 替换数值
                sed -i "s!label${k}!${rname}!g" bar.py
            done
            # 定义PNG
            sed -i "s!barpng!${path}${op}-${barTitle}.png!g" bar.py
            # 执行py文件
            python3 bar.py
            # 复原
            for ((k=0;k<${#rwway[*]};k++))
            do
                rname=${rpname[(${i}*${#block[*]}+${j})*${#rwway[*]}+${k}]}
                num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $4}' | cut -d "=" -f2 | cut -d "," -f1`
                echo ${num:0-4}
                echo "==============="num=${num:0:0-4}
                #if ${num:0-4} -eq "KB/s";then
                    #num=${num:0:0-4}/1024
                #fi
                # 替换x轴标注
                sed -i "s!${num:0:0-4}!mmm${k}!g" bar.py
                # 替换数值
                sed -i "s!${rname}!label${k}!g" bar.py
            done
            sed -i "s/${barTitle}/test-title/" bar.py
            echo "${path}${op}-${barTitle}.png"
            sed -i "s!${path}${op}-${barTitle}.png!barpng!g" bar.py
        done

    done

}
# 使用python生成bar图
barBuild(){
    #预置参数预防获取不到值的情况
    num=-1
    # 判断生成类型
    case $1 in

    bw)
        echo "create bwPNG"
        # 修改y轴
        # sed -i "s!miaoshu!MB/s!g" bar.py
        # 替换
        for ((i=0;i<${#ioway[*]};i++))
        do
        # echo ${rpname[*]}
        # 定义数据来源文件
        rp=${fileList[${i}]}
        echo "from:"${rp}"building png"
        for ((j=0;j<${#block[*]};j++))
        do
            # 修改y轴
            sed -i "s!miaoshu!MB/s!g" bar.py
            # 替换标题
            barTitle=${ioway[${i}]}-${block[${j}]}-$1
            echo "now is ${barTitle}"
            sed -i "s/test-title/${barTitle}/" bar.py
            #替换具体参数

            for ((k=0;k<${#rwway[*]};k++))
            do
                rname=${rpname[(${i}*${#block[*]}+${j})*${#rwway[*]}+${k}]}
                num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $4}'`
                if [ ${num:0:4} == "iops" ]; then
                    num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $3}'`
                fi
                num=`echo ${num}  | cut -d "=" -f2 | cut -d "," -f1`

                # 单位
                #echo ${num:0-4}
                # 数值
                 if [ ${num:0-4} == "KB/s" ]; then
                    num=`echo "scale=1; ${num:0:0-4}/1024" | bc`
                    num=${num}"MB/s"
                 fi


                # 替换x轴标注
                sed -i "s!mmm${k}!${num:0:0-4}!g" bar.py
                # 替换数值
                sed -i "s!label${k}!${rname}!g" bar.py
            done
            # 定义PNG
            sed -i "s!barpng!${path}${op}-${ioway[${i}]}--${block[${j}]}--$1.png!g" bar.py
            # 执行py文件
            python3 bar.py
            # 复原
            # for ((k=0;k<${#rwway[*]};k++))
            # do
                # rname=${rpname[(${i}*${#block[*]}+${j})*${#rwway[*]}+${k}]}
                # num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $4}' | cut -d "=" -f2 | cut -d "," -f1`
                # echo ${num:0-4}
                # echo "==============="num=${num:0:0-4}
                # #if ${num:0-4} -eq "KB/s";then
                    # #num=${num:0:0-4}/1024
                # #fi
                # # 替换x轴标注
                # sed -i "s!${num:0:0-4}!mmm${k}!g" bar.py
                # # 替换数值
                # sed -i "s!${rname}!label${k}!g" bar.py
            # done
            # sed -i "s/${barTitle}/test-title/" bar.py
            # echo "${path}${op}-${ioway[${i}]}--${block[${j}]}--$1.png"
            # sed -i "s!${path}${op}-${ioway[${i}]}--${block[${j}]}--$1.png!barpng!g" bar.py
            sleep 1
            rm bar.py
            cp bar.py-bak bar.py
            done

        done

        # 复原
        #sed -i "s!MB/s!miaoshu!g" bar.py
        ;;
    iops)
        echo "create iopsPNG"
        # 替换
        for ((i=0;i<${#ioway[*]};i++))
        do
        # 修改y轴
        sed -i "s!miaoshu!IOPS!g" bar.py
        #echo ${rpname[*]}
        # 定义数据来源文件
        rp=${fileList[${i}]}
        echo "from:"${rp}"building png"
        for ((j=0;j<${#block[*]};j++))
        do
            # 替换标题
            barTitle=${ioway[${i}]}-${block[${j}]}-$1
            echo ${barTitle}
            sed -i "s/test-title/${barTitle}/" bar.py
            #替换具体参数

            for ((k=0;k<${#rwway[*]};k++))
            do
                rname=${rpname[(${i}*${#block[*]}+${j})*${#rwway[*]}+${k}]}
                #echo $2
                #echo ${rname}

                num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $5}'`
                if [ ${num:0:4} == "runt" ]; then
                    num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $4}'`
                fi
                num=`echo ${num}  | cut -d "=" -f2 | cut -d "," -f1`
                # 替换x轴标注
                sed -i "s!mmm${k}!${num}!g" bar.py
                # 替换数值
                sed -i "s!label${k}!${rname}!g" bar.py
            done
            # 定义PNG
            sed -i "s!barpng!${path}${op}-${ioway[${i}]}--${block[${j}]}--$1.png!g" bar.py
            # 执行py文件
            python3 bar.py

            # 复原
            # for ((k=0;k<${#rwway[*]};k++))
            # do
                # rname=${rpname[(${i}*${#block[*]}+${j})*${#rwway[*]}+${k}]}
                # num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $2}' | cut -d "=" -f2 | cut -d "," -f1`
                # # 替换x轴标注
                # sed -i "s!${num}!mmm${k}!g" bar.py
                # # 替换数值
                # sed -i "s!${rname}!label${k}!g" bar.py
            # done
            # sed -i "s/${barTitle}/test-title/" bar.py
            # echo "${path}${op}-${ioway[${i}]}--${block[${j}]}--$1.png"
            # sed -i "s!${path}${op}-${ioway[${i}]}--${block[${j}]}--$1.png!barpng!g" bar.py

            sleep 1
            rm bar.py
            cp bar.py-bak bar.py
            done

        done

        #sed -i "s!IOPS!miaoshu!g" bar.py
        ;;
    *)
        echo "error! no this type"
        exit 0
        ;;
    esac

}
# 生成表格
tableCreate(){
    # randwrite randread write read
    tableFile="${path}${op}-all-${date}.table"
    for ((i=0;i<${#ioway[*]};i++))
    do
        # 定义数据来源文件
        rp=${fileList[${i}]}
        echo "from:"${rp}" building table"
        echo "=================================================${ioway[${i}]}=================================================" >> ${tableFile}


        # 定义输出文件
        for ((j=0;j<${#block[*]};j++))
        do
            echo "************************************${block[${j}]}************************************" >> ${tableFile}
            echo "
---------------------------------------------------------------------------------------------
|                    |    block随机写      |    block随机读    |    block顺序写    |    block顺序读    |
---------------------------------------------------------------------------------------------
|  吞吐(MB/S)        |    m0bw     |    m1bw     |     m2bw     |     m3bw    |
---------------------------------------------------------------------------------------------
|  IOPS              |       m0iops       |       m1iops      |       m2iops       |      m3iops      |
---------------------------------------------------------------------------------------------
|  slat (usec)       |     m0slat     |    m1slat    |    m2slat    |    m3slat    |
---------------------------------------------------------------------------------------------
|  clat (usec)       |    m0clat    |    m1clat    |    m2clat    |    m3clat    |

----------------------------------------------------------------------------------------------" >>  ${tableFile}
            sed -i "s!block!${block[${j}]}!g" ${tableFile}

            for ((k=0;k<${#rwway[*]};k++))
            do
                rname=${rpname[(${i}*${#block[*]}+${j})*${#rwway[*]}+${k}]}
                #echo $2
                #echo ${rname}

                bw=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $4}'`
                if [ ${bw:0:4} == "iops" ]; then
                    bw=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $3}'`
                fi
                bw=`echo ${bw}  | cut -d "=" -f2 | cut -d "," -f1`

                iops=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $5}'`
                if [ ${iops:0:4} == "runt" ]; then
                    iops=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $4}'`
                fi
                iops=`echo ${iops}  | cut -d "=" -f2 | cut -d "," -f1`

                slat=`cat ${rp} |grep -C 2 "bw=" | grep -A 3 ${rname} | sed -n "3,1p" | awk '{print $5}' | cut -d "=" -f2 | cut -d "," -f1`
                clat=`cat ${rp} |grep -C 2 "bw=" | grep -A 3 ${rname} | sed -n "4,1p" | awk '{print $5}' | cut -d "=" -f2 | cut -d "," -f1`
                sed -i "s!m${k}bw!${bw}!g" ${tableFile}
                sed -i "s!m${k}iops!${iops}!g" ${tableFile}
                sed -i "s!m${k}slat!${slat}!g" ${tableFile}
                sed -i "s!m${k}clat!${clat}!g" ${tableFile}

            done

        done



    done
}
# 最大值生成
getMax(){
#预置参数预防获取不到值的情况
    max=(0 0 0 0 0 0 0 0)
    # 判断生成类型
    case $1 in

    bw)
        echo "create bwMAX"

        for ((i=0;i<${#ioway[*]};i++))
        do
        # echo ${rpname[*]}
        # 定义数据来源文件
        rp=${fileList[${i}]}
            for ((j=0;j<${#block[*]};j++))
            do
                for ((k=0;k<${#rwway[*]};k++))
                do
                    # 测试项
                    rname=${rpname[(${i}*${#block[*]}+${j})*${#rwway[*]}+${k}]}
                    num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $4}' | cut -d "=" -f2 | cut -d "," -f1`
                    num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $4}'`
                    if [ ${num:0:4} == "iops" ]; then
                        num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $3}'`
                    fi
                    num=`echo ${num}  | cut -d "=" -f2 | cut -d "," -f1`
                    # 单位
                    # echo ${num:0-4}
                    # 数值
                    # echo ${num:0:0-4}
                    # if [ $(echo "max[${k}] < ${num:0:0-4}"|bc) = 1 ]
                    if [ ${num:0-4} == "KB/s" ] ; then
                        num=`echo "scale=1; ${num:0:0-4}/1024" | bc`
                        num=${num}"MB/s"
                    fi


                    # 格式化num
                    num=`awk -v x=1 -v y="${num:0:0-4}" 'BEGIN{printf "%d",x*y}'`
                    if [ ${num} -gt ${max[${k}]} ]
                    then
                        # echo "============"${max[${k}]}
                        max[${k}]=${num}
                        # l=$((${k}+${#rwway[*]}))
                        # echo ${l}
                        max[$((${k}+${#rwway[*]}))]=${rname}
                        # echo "-------------"${max[*]}
                    fi
                done
            done
        done
        # 定义max文件
        maxBwFile=${path}${op}-max-${date}
        # echo ${maxBwFile}
        # echo ${max[*]}
        echo "=========================================MaxBW=========================================" >> ${maxBwFile}
        echo ${max[*]} >> ${maxBwFile}

        ;;
    iops)
        echo "create iopsMAX"
        for ((i=0;i<${#ioway[*]};i++))
        do
        # echo ${rpname[*]}
        # 定义数据来源文件
        rp=${fileList[${i}]}
            for ((j=0;j<${#block[*]};j++))
            do
                for ((k=0;k<${#rwway[*]};k++))
                do
                    # 测试项
                    rname=${rpname[(${i}*${#block[*]}+${j})*${#rwway[*]}+${k}]}
                    num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $5}'`
                    if [ ${num:0:4} == "runt" ]; then
                        num=`cat ${rp} |grep -B 1 "bw=" | grep -A 1 ${rname} | sed -n "2,1p" | awk '{print $4}'`
                    fi
                    num=`echo ${num}  | cut -d "=" -f2 | cut -d "," -f1`
                    # 数值
                    # echo ${num}
                    # echo ${num:0-1}
                    # 如果最后一位为k则*1000
                    if [ "${num:0-1}" == "k" ];then
                    num=`awk -v x=1000 -v y="${num:0:0-1}" 'BEGIN{printf "%d",x*y}'`
                    # echo ${num}
                    fi
                    if [ ${num} -gt ${max[${k}]} ]
                    then
                        # echo "============"${max[${k}]}
                        max[${k}]=${num}
                        # l=$((${k}+${#rwway[*]}))
                        # echo ${l}
                        max[$((${k}+${#rwway[*]}))]=${rname}
                        # echo "-------------"${max[*]}
                    fi
                done
            done
        done
        # 定义max文件
        maxBwFile=${path}${op}-max-${date}
        echo "=========================================MaxIOPS=========================================" >> ${maxBwFile}
        echo ${max[*]} >> ${maxBwFile}
        ;;
    *)
        echo "error! no this type"
        exit 0
        ;;
    esac
}
# 实时IO图生成
iostatReport(){
    ioPath=${path}"iostat"
    count=${#block[*]}*${#rwway[*]}
    case $1 in
    fc)
        deviceList=(dm-0 dm-1 dm-2 dm-3 dm-4 dm-5 dm-6 dm-7)
        ;;
    iscsi)
        deviceList=(`lsblk --scsi | grep iscsi | awk '{print $1}' | tr '\n' ':' | sed "s/:/ /g"`)
        ;;
    disk)
        if [ x$2 != x ]
        then
            echo "auto chose volume/entire/ondisk!"
            case ${2:0:1} in
            v)
                poolname=`zpool list | sed -n "2,1p" | awk '{print $1}'`
                cd /dev/zvol/${poolname}
                deviceList=(`ls -al | grep zd | awk '{print $11}' | cut -d "/" -f3 | tr '\n' ':' | sed "s/:/ /g"`)
                cd -
                ;;
            e)
                cd ../Config/
                deviceList=(`cat performance.py | grep entireDisk | cut -d "\"" -f2 | tr " " ":" | sed "s/:/ /g"`)
                cd -
                ;;
            m)
                deviceList=$2
                ;;
            n)
                deviceList=$2
                ;;
            s)
                deviceList=$2
                ;;
            *)
                echo "error type! in make IOreport"
                ;;
            esac
         else
            echo "error no type! in make IOreport"
         fi
        ;;
    *)
        echo "error no match! in make IOreport"
        exit 0
        ;;
    esac
    for ((i=0;i<${#fileList[*]};i++))
    do
        for ((j=0;j<${count};j++))
        do
            for ((num=1;num<=${statCount};num++))
            do
                readSum=0
                writeSum=0
                echo "start sum ${rpname[${j}+${i}*${count}]}"
                for ((k=0;k<${#deviceList[*]};k++))
                do
                    # 初始化
                    readIO=0
                    writeIO=0
                    # 获取每一行的数据
                    readIO=`cat ${ioPath} | grep -A ${ioCount} ${rpname[${j}+${i}*${count}]} | grep ${deviceList[$k]} | sed -n "${num},1p"| awk '{print $2}'`
                    writeIO=`cat ${ioPath} | grep -A ${ioCount} ${rpname[${j}+${i}*${count}]} | grep ${deviceList[$k]} | sed -n "${num},1p"| awk '{print $3}'`
                    # echo "readIO=========="${readIO}
                    # echo "writeIO========"${writeIO}
                    # 求和
                    readSum=`echo ${readSum}+${readIO}|bc`
                    writeSum=`echo ${writeSum}+${writeIO}|bc`
                    echo "readSum=$readSum"
                    echo "writeSum=$writeSum"
                done
                # echo "==============fin============readSum=$readSum"
                # echo "==============fin============writeSum=$writeSum"
                # 生成读数据文件
                echo  $readSum >> ${path}${rpname[${j}+${i}*${count}]}.iostat.read
                # 从kb/s换算为mb/s
                readSum1=`echo "scale=1; ${readSum}/1024" | bc`
                echo "read sum chage=="${readSum1}"MB/S"
                echo ${readSum1} >> ${path}${rpname[${j}+${i}*${count}]}.iostat.read.mb
                # 计算IOPS（4k）
                readSum2=`echo "scale=1; ${readSum}/4" | bc`
                echo "read sum chage=="${readSum2}"IOPS"
                echo ${readSum2} >> ${path}${rpname[${j}+${i}*${count}]}.iostat.read.iops

                 # 生成写数据文件
                echo  $writeSum >> ${path}${rpname[${j}+${i}*${count}]}.iostat.write
                # 从kb/s换算为mb/s
                writeSum1=`echo "scale=1; ${writeSum}/1024" | bc`
                echo "write sum chage=="${writeSum1}"MB/S"
                echo ${writeSum1} >> ${path}${rpname[${j}+${i}*${count}]}.iostat.write.mb
                # 计算IOPS（4k）
                writeSum2=`echo "scale=1; ${writeSum}/4" | bc`
                echo "write sum chage=="${writeSum2}"IOPS"
                echo ${writeSum2} >> ${path}${rpname[${j}+${i}*${count}]}.iostat.write.iops
            done
            cp IOLine.py-bak IOLine.py
            sed -i "s/LINE_TITLE/${path}${rpname[${j}+${i}*${count}]}.iostat.read/g" IOLine.py
            sed -i "s!SAVE_PATH!${path}!g" IOLine.py
            python3 IOLine.py
            cp IOLine.py-bak IOLine.py
            sed -i "s/LINE_TITLE/${path}${rpname[${j}+${i}*${count}]}.iostat.write/g" IOLine.py
            sed -i "s!SAVE_PATH!${path}!g" IOLine.py
            python3 IOLine.pypython3 IOLine.py
        done
    done

}
# 获取硬件信息
getTestInfo(){
infoFile="${path}${op}-Info-${date}.table"
echo "****************************************get memory info****************************************"  >> ${infoFile}
echo "################FREE -H################" >> ${infoFile}
free -h >> ${infoFile}
echo "################DMIDECODE################" >> ${infoFile}
dmidecode -t memory | grep Size >> ${infoFile}
echo "****************************************get cpu info****************************************" >> ${infoFile}
echo "################LSCPU################" >> ${infoFile}
lscpu >> ${infoFile}
echo "################PROC/CPUINFO################" >> ${infoFile}
cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c >> ${infoFile}
echo "****************************************get pci info****************************************" >> ${infoFile}
echo "################QLogic################" >> ${infoFile}
lspci | grep QLogic >> ${infoFile}
echo "################LSI################" >> ${infoFile}
lspci |  grep LSI >> ${infoFile}
echo "################Ethernet################" >> ${infoFile}
lspci |  grep Ethernet >> ${infoFile}
echo "****************************************get FC info****************************************" >> ${infoFile}
echo "################WWPN################" >> ${infoFile}
cat /sys/class/fc_host/*/port_name >> ${infoFile}
echo "################STATE################" >> ${infoFile}
cat /sys/class/fc_host/*/port_state >> ${infoFile}
echo "################SYMBOLIC################" >> ${infoFile}
cat /sys/class/fc_host/*/symbolic_name >> ${infoFile}
case $1 in
disk)
    echo "****************************************get disk info****************************************" >> ${infoFile}
    case ${2:0:1} in
    e)
       cd ../Performance/
       deviceList=(`cat urlConfig.py |grep entireDisk | cut -d "\"" -f2 |te " " ":" | sed "s/:/ /g"`)
       cd -
       ;;
    s)
       deviceList=$2
       ;;
    n)
       deviceList=$2
       ;;
    *)
       deviceList=(dump)
       ;;
    esac
    ;;
*)
    echo "dump get disk info!" >> ${infoFile}
    ;;
esac

for ((i=0;i<${#deviceList[*]};i++))
do
    if [ "$deviceList[0]" == "dump" ];then
        echo "dump get disk info!" >> ${infoFile}
    else
        echo "################$deviceList[${i}]################" >> ${infoFile}
        smartctl -a /dev/${deviceList[${i}]} >> ${infoFile}
    fi
done


}

#参数1位类型
case $1 in
fc)
    echo "fio will run fio-fc.sh"
    runio="fio-fc.sh"
    # 生成文件夹
    mkdir -p ${output}${day}/"fc"
    # 重新定义数据存放位置
    path=${output}${day}"/fc/"
    ;;
iscsi)
    echo "fio will run fio-iscsi.sh"
    runio="fio-iscsi.sh"
    # 生成文件夹
    mkdir -p ${output}${day}/"iscsi"
    # 重新定义数据存放位置
    path=${output}${day}"/iscsi/"
    ;;
nfs)
    echo "fio will run fio-nfs.sh"
    runio="fio-nfs.sh"
    # 生成文件夹
    mkdir -p ${output}${day}/"nfs"
    # 重新定义数据存放位置
    path=${output}${day}"/nfs/"
    ;;
disk)
    echo "fio will run fio-disk.sh"
    # 判断参数4（磁盘名称）是否存在
    if [ x$4 != x ]
    then
        runio="fio-disk.sh"
        sed -i "s!d=\"testDisk\"!d=$4!g" ${runio}
        # 生成文件夹
        mkdir -p ${output}${day}/$4
        # 重新定义数据存放位置
        path=${output}${day}"/"$4"/"
    else
        echo "error! please enter disk name in \$4 !"
        exit 0
    fi
    ;;
*)
    echo "error! please enter volume-type!(fc/iscsi/nfs)"
    exit 0
    ;;
esac
#参数2为名称
if [ x$2 != x ]
then
    #设置文件存放位置
    op=$2
    echo "file in ${op}"
else
    echo "error! please enter filename!"
    exit 0
fi
#参数3设定执行方式


case $3 in
1)
    echo "**all test**"
    getTestList
    createFile
    fioTest
    allReportCreate
    tableCreate
    getMax bw
    getMax iops
    iostatReport $1 $4
    barBuild bw
    barBuild iops
    getTestInfo $1 $4
    ;;
2)
    echo "**only Bar**"
    getTestList
    createFile
    barBuild bw
    barBuild iops
    ;;
3)
    echo "**only Max**"
    getTestList
    createFile
    getMax bw
    getMax iops
    ;;
4)
    echo "**only Fio**"
    getTestList
    createFile
    fioTest
    ;;
5)
    echo "**only Table**"
    getTestList
    createFile
    tableCreate
    ;;
6)
    echo "**only All**"
    getTestList
    createFile
    allReportCreate
    ;;
7)
    echo "**only iostatReport**"
    getTestList
    createFile
    iostatReport $1 $4
    ;;
8)
    echo "**only getdiskInfo**"
    getTestList
    createFile
    getTestInfo $1 $4
    ;;
*)
    echo "error!no this type!"
    echo "enter: 1--**all test** 2--**only Bar** 3--**only Max** 4--**only Fio** 5--**only Table** 6--**only All** 7--**only iostatReport** 8--**only diskInfo**"
    exit 0
    ;;
esac


cp fio-disk.sh.bak fio-disk.sh

echo "successful"