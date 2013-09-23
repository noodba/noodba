noodba：一个即时的oracle诊断工具
======


<h2>1 安装：</h2>
<pre>
下载后直接使用；
要求oracle用户下配置ORACLE_HOME等环境变量，里面会调用sqlplus。
perl版本一般用系统默认自带的就可以了。
oracle版本在10.2.0.5和11.2.0.3上测试过（应该10.2.0.1上都可以）。
操作系统只在rhel 5测试过。
</pre>

<h2>2 可通过如下方式获取使用帮助：</h2>
<pre>
[oracle@testdb ~]$ perl noodba.pl -h

==========================================================================================
Info  :
        Created By noodba (www.noodba.com) .
   References: orzdba.pl (zhuxu@taobao.com) ; fc.pl by wwwf
Usage :
Command line options :

   -h,--help           Print Help Info. 
   -i,--interval       Time(second) Interval(default 2).  
   -n,--net            Net  Info(default eth0).
   
   +++++++++++++++++++++++++ The list 7 options should  select one. ++++++++++++++++++++++
   --sysstat           OS system info.
   --orastat           Oracle load info.
   --topevent          Oracle top events.
   --active            Oracle active session.
   --lockobj           Oracle locked object.
   --blocking          Oracle blocking info.
   --ratio             Oracle Instance Efficiency Ratios.
  
Sample :
   shell> perl noodba.pl --topevent -i 1
==========================================================================================
</pre>

<h2>3  目前一共有7个方面的功能：</h2>
<pre>
OS系统、oracle load info、 Instance Efficiency Ratios、top events、blocking tree
，lock objects，active session等

以下是运行样例：

[oracle@testdb ~]$ perl noodba.pl --orastat -i 1   
      Time       Load    Logicr    Phyr     Phyw   BlkCg  Logcum Logcur   CPU    Redo    Execs  HParse  Parse  Comit   Rollbk   UsCall
09-23 13:12:10  12.2  3.7e+05     1348       34      265     1     0       5s     35k    9388      0     39      28       0     24045
09-23 13:12:12  12.2  2.8e+05      727       23       94     1     0       5s     37k   10402      0     20      16       0     25258
09-23 13:12:13  12.4  2.6e+05      889       26      661     1     0       5s     84k   11103      0     21      23       0     28266
09-23 13:12:14  12.4    2e+05      966        2      563     1     0       5s    103k   10180      0     21      25       2     25540
09-23 13:12:15  12.4  5.1e+05      701       33      177     1     0       5s     25k   11517      0     34      13       0     27562


[oracle@testdb ~]$ perl noodba.pl --ratio --i 1
      Time       Load   BufHit%  Softps%   Memsort%  Parseexe%  Pcputotal% Pcpuelapsd%   
09-23 13:14:33   9.8     99.92    100.00    100.00     99.72     94.96     70.58
09-23 13:14:34   9.8     99.90    100.00    100.00     99.90     96.33     84.00
09-23 13:14:35   9.8     99.83    100.00    100.00     99.83     95.44     86.20
09-23 13:14:36   9.8     99.74    100.00    100.00     99.81     94.25     83.33
09-23 13:14:37   9.8     99.82    100.00    100.00     99.89     94.85     92.85


[oracle@testdb ~]$ perl noodba.pl --blocking

USERNAME             MACHINE                        SID SERIAL#     WTS STATUS     MODULE                         TIME
-------------------- ------------------------- -------- ------- ------- ---------- ------------------------------ ---------------
TSUSER               xxxxxxxxxxxxxxxxx                9   38763       0 ACTIVE     JDBC Thin Client               09-23 13:30:07
+++TSUSER            xxxxxxxxxxxxxxxxx              655   27095       0 ACTIVE     JDBC Thin Client               09-23 13:30:07
+++TSUSER            xxxxxxxxxxxxxxxxx             1011   14447       0 ACTIVE     JDBC Thin Client               09-23 13:30:07
+++TSUSER            xxxxxxxxxxxxxxxxx             1523   11657       0 ACTIVE     JDBC Thin Client               09-23 13:30:07
+++TSUSER            xxxxxxxxxxxxxxxxx             2909    2333       0 ACTIVE     JDBC Thin Client               09-23 13:30:07
TSUSER               xxxxxxxxxxxxxxxxx             1530   63207       1 INACTIVE   JDBC Thin Client               09-23 13:30:07

[oracle@testdb ~]$ perl noodba.pl --lockobj

TIME                 SID  SERIAL# ORACLE_USERNAME      OS_USER_NAME         OBJECT_NAME                    LOCKED_MODE
--------------- -------- -------- -------------------- -------------------- ------------------------------ -----------
09-23 13:10:08      1035    38601 TSUSER               testus               aaaaaaaaaaaaaaaaaaaaaaaa                 3
09-23 13:10:08      1035    38601 TSUSER               testus               BBBBBBBBBBBB                             3
09-23 13:10:08      1035    38601 TSUSER               testus               CCCCCCCCCCCCC                            3
09-23 13:10:08      1035    38601 TSUSER               testus               DDDDDDDDDDDDD                            3
09-23 13:10:08      1035    38601 TSUSER               testus               EEEEEEEEEEEEEEEEEEEEEEE                  3

[oracle@testdb ~]$ perl noodba.pl --sysstat -n eth2
      Time       Load   us%   sy%   id%   wa%   Nsend   Nrecv  
09-23 13:09:34  11.8     0     0     0     0   62319k  24962k 
09-23 13:09:36  11.8    29     4    53    13   69253k  27519k 
09-23 13:09:38  12.0    24     3    61    11   63557k  25789k 
09-23 13:09:40  12.0    24     3    59    14   59824k  24150k 
09-23 13:09:42  12.0    22     4    64    11   59051k  23778k 

[oracle@testdb ~]$ perl noodba.pl --active

SSID              USERNAME   MACHINE                                  EVENT                             WTS SQL_ID          ST    LCT
----------------- ---------- ---------------------------------------- ------------------------------ ------ --------------- -- ------
1155,43833        TSUSER     JDBC Thin Client@zzzzzzzzzzzz            SQL*Net message to client           0 4f0t0ngr1fb0m   A       0
530,64801         TSUSER     JDBC Thin Client@zzzzzzzzzzzz            SQL*Net message to client           0 cy5umdk1h2s8q   A       0
901,58003         TSUSER     JDBC Thin Client@zzzzzzzzzzzzsssss       SQL*Net message to client           0 2pw3knwpg4rc8   A       0
1652,23347        TSUSER     JDBC Thin Client@zzzzzzzzzzzz            SQL*Net message to client           0 b9x80sbcwyczx   A       0
910,3137          TSUSER     JDBC Thin Client@zzzzzzzzzzzz            db file sequential read             0 av7kfcmcxc1fk   A       0
777,53695         TSUSER     JDBC Thin Client@zzzzzzzzzzzzsssss       db file sequential read             0 8kcm7vd2nuwu3   A       0


[oracle@testdb ~]$ perl noodba.pl --topevent
      Time                    Event                  Waits        WaitTime(ms)    AvgWait(ms)    WaitClass 
09-23 13:11:06         db file sequential read         549          1330            2              User I/O  
09-23 13:11:06    control file sequential read           3            50           17            System I/O  
09-23 13:11:06           db file parallel read           4            50           13              User I/O  
09-23 13:11:06       SQL*Net message to client       36656            30            0               Network  
09-23 13:11:06         log file parallel write          41            10            0            System I/O  

      Time                    Event                  Waits        WaitTime(ms)    AvgWait(ms)    WaitClass 
09-23 13:11:08         db file sequential read        1563          7140            5              User I/O  
09-23 13:11:08                   log file sync          37           880           24                Commit  
09-23 13:11:08         log file parallel write          36           570           16            System I/O  
09-23 13:11:08          db file scattered read        1857           550            0              User I/O  
09-23 13:11:08           db file parallel read           1           130          130              User I/O  

</pre>
