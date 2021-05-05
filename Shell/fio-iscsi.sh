#!/usr/bin/env bash
# 读写磁盘
filename="/dev/sdb:/dev/sdc:/dev/sdd:/dev/sde:/dev/sdf:/dev/sdg:/dev/sdh:/dev/sdi"
# 参数 落盘 使用空间100% 64个线程 运行时间1800S 任务前等待30S
fio -filename=${filename} -direct=1  -thread   -size=100%  -numjobs=64  -time_based -runtime=1800 -startdelay=30 -group_reporting  -ioengine=ioway -bs=block -rw=rwway -name=reportname >> output