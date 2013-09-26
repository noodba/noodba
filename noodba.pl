#!/usr/bin/perl
use strict;
use Getopt::Long;   
use POSIX qw(strftime);    
Getopt::Long::Configure qw(no_ignore_case);    #


select (STDOUT); $| = 1;
select (STDERR); $| = 1;

my %opt;
my $interval = 2;
my @sys_load;

# Variables For :
#-----> Get SysInfo (from /proc/stat): CPU
my @sys_cpu1 = (0) x 8;
my @sys_cpu2;
my $total_1 = 0;
my $total_2;

my $cpu_not_first = 0;

my $user_diff;
my $system_diff;
my $idle_diff;
my $iowait_diff;

my $user_diff_1;
my $system_diff_1;
my $idle_diff_1;
my $iowait_diff_1;
my $HZ = 100;
#<----- Get SysInfo (from /proc/stat): CPU

#-----> Get SysInfo (from /proc/net/dev): NET
my %net1 = (
	"recv" => 0,
	"send" => 0
);
my $net_not_first = 0;
my %net2;
my $diff_recv;
my $diff_send;
my $net="eth0";
#<----- Get SysInfo (from /proc/net/dev): NET


my %sysstat2 ;
my %sysstat1 ;
my %sysevent2 ;
my %sysevent1 ;
my %sysevent_diff;
my @sysevent_keys;

my $print_not_first = 0;

my $sysstat  = 0;  
my $orastat =0;
my $topevent = 0;  
my $active= 0;   
my $lockobj = 0;   
my $blocking  = 0;   
my $ratio=0;
my $pgcount=0;   
my $snap_time ;

my $sysstat_header="      Time       Load   us%   sy%   id%   wa%   Nsend   Nrecv  \n";
my $orastat_header="      Time       Load    Logicr    Phyr     Phyw   BlkCg  Logcum Logcur   CPU    Redo    Execs  HParse  Parse  Comit   Rollbk   UsCall\n";
my $ratio_header=  "      Time       Load   BufHit%  Softps%   Memsort%  Parseexe%  Pcputotal% Pcpuelapsd%   \n";
my $sysevent_header="      Time                    Event                  Waits        WaitTime(ms)    AvgWait(ms)    WaitClass \n";

&noodba_main();

# ----------------------------------------------------------------------------------------
#  Func : main
# ----------------------------------------------------------------------------------------
sub noodba_main{	
	
	&get_options();
	
	while(1) {

		if($sysstat){			
			&print_sysstat();
		}elsif($orastat==1){
			&print_orastat();
		}elsif($ratio){	
			&print_ratiostat();
		}elsif($lockobj){
			&get_lockobj();
			exit;
		}elsif($blocking){
			&get_blocking();
			exit;
		}elsif($topevent){
			&print_topevent();
		}elsif($active){
			&get_activesession();
			exit;																
		}else{
			exit;
		}		

	    $pgcount += 1;
	    sleep($interval);
	}	
}


# ----------------------------------------------------------------------------------------
#  Func : print Instance Efficiency Ratios info
# ----------------------------------------------------------------------------------------
sub print_ratiostat {
	
    if ( $pgcount%20 == 0 ) {  
       print $ratio_header;         
     } 		 	
	%sysstat1=%sysstat2;
 		 	
	&get_sysstat();
	&get_loadinfo();
		
	$snap_time = strftime "%m-%d %H:%M:%S", localtime;
	if($print_not_first){
		my($buffer_cache_hits,$soft_parse,$in_memory_sort,$parse_exec,$parse_cpu_total,$parse_time_elapse);
		
		if (($sysstat2{"session logical reads"}-$sysstat1{"session logical reads"}) >0) {
			$buffer_cache_hits=int((1-(( $sysstat2{"physical reads"}- $sysstat1{"physical reads"}-$sysstat2{"physical reads direct"}+$sysstat1{"physical reads direct"}-$sysstat2{"physical reads direct (lob)"}+$sysstat1{"physical reads direct (lob)"})  /($sysstat2{"session logical reads"}-$sysstat1{"session logical reads"}))) *10000)/100;
		}else{
			$buffer_cache_hits = 0;
		}
		
		if (($sysstat2{"parse count (total)"}-$sysstat1{"parse count (total)"}) >0) {
			$soft_parse=int((1-(( $sysstat2{"parse count (hard)"}- $sysstat1{"parse count (hard)"})  /($sysstat2{"parse count (total)"}-$sysstat1{"parse count (total)"}))) *10000)/100;
		}else{
			$soft_parse = 0;
		}

		if ((($sysstat2{"sorts (memory)"}+$sysstat2{"sorts (disk)"})-($sysstat1{"sorts (memory)"}+$sysstat1{"sorts (disk)"})) >0) {
			$in_memory_sort=int(  (($sysstat2{"sorts (memory)"}-$sysstat1{"sorts (memory)"})/($sysstat2{"sorts (memory)"}+$sysstat2{"sorts (disk)"}-$sysstat1{"sorts (memory)"}-$sysstat1{"sorts (disk)"}) ) *10000)/100;	
		}else{
			$in_memory_sort = 0;
		}

		if (($sysstat2{"execute count"}-$sysstat1{"execute count"}) >0) {
			$parse_exec=int((1-(( $sysstat2{"parse count (total)"}- $sysstat1{"parse count (total)"})  /($sysstat2{"execute count"}-$sysstat1{"execute count"}))) *10000)/100;
		}else{
			$parse_exec = 0;
		}
		
		if(($sysstat2{"CPU used by this session"}-$sysstat1{"CPU used by this session"}) >0) {
			$parse_cpu_total=int((1-(( $sysstat2{"parse time cpu"}- $sysstat1{"parse time cpu"})  /($sysstat2{"CPU used by this session"}-$sysstat1{"CPU used by this session"}))) *10000)/100;
		}else{
			$parse_cpu_total = 0;
		}

		if (($sysstat2{"parse time elapsed"}-$sysstat1{"parse time elapsed"}) >0) {
			$parse_time_elapse=int(((( $sysstat2{"parse time cpu"}- $sysstat1{"parse time cpu"})  /($sysstat2{"parse time elapsed"}-$sysstat1{"parse time elapsed"}))) *10000)/100;
		}else{
			$parse_time_elapse = 0;
		}

	    printf "%s %5.1f %9.2f %9.2f %9.2f %9.2f %9.2f %9.2f\n",
	    $snap_time,$sys_load[0], $buffer_cache_hits,$soft_parse,$in_memory_sort,$parse_exec,$parse_cpu_total,$parse_time_elapse;	     
	}
     $print_not_first=1;

}

# ----------------------------------------------------------------------------------------
#  Func : print sysstat info
# ----------------------------------------------------------------------------------------
sub print_sysstat {
	
    if ( $pgcount%20 == 0 ) {  
       print $sysstat_header;         
     }	
 		 	
	&get_loadinfo();
	&get_cpuinfo();
	&get_netinfo();
		
	$snap_time = strftime "%m-%d %H:%M:%S", localtime;
	if($print_not_first){	
	    printf "%s %5.1f %5d %5d %5d %5d  %7s %7s \n",
	    $snap_time,$sys_load[0], $user_diff_1,$system_diff_1,$idle_diff_1,$iowait_diff_1,
	    int($diff_send/1024 + 0.5)."k",int($diff_recv/1024 + 0.5)."k";
	     
	}
     $print_not_first=1;

}

# ----------------------------------------------------------------------------------------
#  Func : print sysstat info
# ----------------------------------------------------------------------------------------
sub print_orastat {
	
    if ( $pgcount%20 == 0 ) {  
       print $orastat_header;         
     }	
	%sysstat1=%sysstat2;
 		 	
	&get_sysstat();
	&get_loadinfo();
		
	$snap_time = strftime "%m-%d %H:%M:%S", localtime;

	if($print_not_first){	
	    printf "%s %5.1f %8.2g %8d %8d %8d %5d %5d  %7s %7s %7d %6d %6d  %6d  %6d  %8d\n",
	    $snap_time,$sys_load[0], 
	     ($sysstat2{"session logical reads"}-$sysstat1{"session logical reads"}),
	     ($sysstat2{"physical reads"}-$sysstat1{"physical reads"}),
	     ($sysstat2{"physical writes"}-$sysstat1{"physical writes"}),
	     ($sysstat2{"db block changes"}-$sysstat1{"db block changes"}),
	     $sysstat2{"logons cumulative"}-$sysstat1{"logons cumulative"},
	     $sysstat2{"logons current"}-$sysstat1{"logons current"},
	     int(($sysstat2{"CPU used by this session"}-$sysstat1{"CPU used by this session"})/100 + 0.5) . "s",
	     int(($sysstat2{"redo size"}-$sysstat1{"redo size"})/1024 + 0.5). "k",
	     $sysstat2{"execute count"}-$sysstat1{"execute count"},
	     $sysstat2{"parse count (hard)"}-$sysstat1{"parse count (hard)"},
	     $sysstat2{"parse count (total)"}-$sysstat1{"parse count (total)"},
	     $sysstat2{"user commits"}-$sysstat1{"user commits"},
	     $sysstat2{"user rollbacks"}-$sysstat1{"user rollbacks"},
	     $sysstat2{"user calls"}-$sysstat1{"user calls"};
	}
     $print_not_first=1;
}


# ----------------------------------------------------------------------------------------
#  Func : print system_event info
# ----------------------------------------------------------------------------------------
sub print_topevent {
my ($total_waits1 , $time_waited1  , $wait_class1 );
my ($total_waits2 , $time_waited2  , $wait_class2 );
my $topnum=0;
my $waits_diff=0;
my $avgwait_time=0;

	%sysevent1=%sysevent2; 		 	
	&get_systemevent();
		
	$snap_time = strftime "%m-%d %H:%M:%S", localtime;
	if($print_not_first){	
		@sysevent_keys = keys %sysevent2;

	 	foreach (@sysevent_keys) {
			($total_waits2 ,$time_waited2,$wait_class2) = split(/;/,$sysevent2{"$_"});
			($total_waits1 ,$time_waited1,$wait_class1) = split(/;/,$sysevent1{"$_"});
			$sysevent_diff{"$_"}=$time_waited2-$time_waited1;
	 	}
		print $sysevent_header; 
		foreach my $key (sort  { $sysevent_diff{$b} <=> $sysevent_diff{$a} } keys %sysevent_diff){  
			($total_waits2 ,$time_waited2,$wait_class2) = split(/;/,$sysevent2{"$key"});
			($total_waits1 ,$time_waited1,$wait_class1) = split(/;/,$sysevent1{"$key"});		     

            $waits_diff=$total_waits2-$total_waits1;
            if($waits_diff>0){
            	$avgwait_time=int($sysevent_diff{$key}*10/$waits_diff+0.5);
            }else{
            	$avgwait_time="";
            }
             
		    printf "%s  %30s  %10d  %12d %12s  %20s  \n",
		    $snap_time,$key, $waits_diff,$sysevent_diff{$key}*10, $avgwait_time,$wait_class2;
		    
		     $topnum++;
		     last if $topnum>=5;
		 }
		 print "\n"	 	
		
	}
     $print_not_first=1;
}

# ----------------------------------------------------------------------------------------
# Func :  print usage
# ----------------------------------------------------------------------------------------
sub print_usage {

	#print BLUE(),BOLD(),<<EOF,RESET();
	print <<EOF;

==========================================================================================
Info  :
        Created By noodba (www.noodba.com) .
   References: orzdba.pl (zhuxu\@taobao.com) ; f.pl by wwwf
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
EOF
	exit;
}

# ----------------------------------------------------------------------------------------
# Func : get options and set option flag
# ----------------------------------------------------------------------------------------
sub get_options {

	# Get options info
	GetOptions(
		\%opt,
		'h|help',          # OUT : print help info
		'i|interval=i',    # IN  : time(second) interval
		'n|net=s',          # IN  : print info
		'sysstat',          # IN  : print info
		'orastat',          # IN  : print info
		'topevent',          # IN  : print info
		'active',          # IN  : print info
		'lockobj',          # IN  : print info
		'blocking',          # IN  : print info								
		'ratio'        # IN  : print info							
	) or print_usage();

	if ( !scalar(%opt) ) {
		&print_usage();
	}

	# Handle for options
	$opt{'h'}  and print_usage();
	$opt{'n'}  and $net = $opt{'n'};
	$opt{'i'}  and $interval = $opt{'i'};
	$opt{'sysstat'}   and $sysstat = 1;
	$opt{'orastat'}   and $orastat = 1; 
	$opt{'topevent'}   and $topevent = 1; 
	$opt{'active'}   and $active = 1; 
	$opt{'lockobj'}   and $lockobj = 1; 
	$opt{'blocking'}   and $blocking = 1; 
	$opt{'ratio'}   and $ratio = 1; 
	if (
		!(
			$sysstat == 1
			or $orastat == 1  
			or $topevent == 1
			or $active == 1
			or $lockobj == 1
			or $blocking == 1
			or $ratio == 1
		)
	  )
	{
		&print_usage();
	}					 

}

# ----------------------------------------------------------------------------------------
#  Func : get Load info
# ----------------------------------------------------------------------------------------
sub get_loadinfo {
	open PROC_LOAD, "</proc/loadavg" or die "Can't open file(/proc/loadavg)!";
	if ( defined( my $line = <PROC_LOAD> ) ) {
		chomp($line);
		@sys_load = split( /\s+/, $line );
	}
	close PROC_LOAD or die "Can't close file(/proc/loadavg)!";
}

# ----------------------------------------------------------------------------------------
#  Func : get CPU info
# ----------------------------------------------------------------------------------------
sub get_cpuinfo {
	open PROC_CPU, "</proc/stat" or die "Can't open file(/proc/stat)!";
	if ( defined( my $line = <PROC_CPU> ) )	{
		chomp($line);
		my @sys_cpu2 = split( /\s+/, $line );

		if($cpu_not_first){
			$total_2 =$sys_cpu2[1] +	$sys_cpu2[2] + $sys_cpu2[3] + $sys_cpu2[4] + $sys_cpu2[5] + $sys_cpu2[6] + $sys_cpu2[7];

			$user_diff = $sys_cpu2[1] + $sys_cpu2[2] - $sys_cpu1[1] - $sys_cpu1[2];
			$system_diff = $sys_cpu2[3] + $sys_cpu2[6] + $sys_cpu2[7] - $sys_cpu1[3] - $sys_cpu1[6] - $sys_cpu1[7];
			$idle_diff   = $sys_cpu2[4] - $sys_cpu1[4];
			$iowait_diff = $sys_cpu2[5] - $sys_cpu1[5];

			$user_diff_1 = int( $user_diff / ( $total_2 - $total_1 ) * 100 + 0.5 );
			$system_diff_1 = int( $system_diff / ( $total_2 - $total_1 ) * 100 + 0.5 );
			$idle_diff_1 = int( $idle_diff / ( $total_2 - $total_1 ) * 100 + 0.5 );
			$iowait_diff_1 = int( $iowait_diff / ( $total_2 - $total_1 ) * 100 + 0.5 );
        }
		@sys_cpu1 = @sys_cpu2;
		$total_1  = $total_2;
		$cpu_not_first = 1;
	}
	close PROC_CPU or die "Can't close file(/proc/stat)!";
}


# ----------------------------------------------------------------------------------------
#  Func : get NET info
# ----------------------------------------------------------------------------------------
sub get_netinfo {
	open PROC_NET, "cat /proc/net/dev | grep \"\\b$net\\b\" | "
	  or die "Can't open file(/proc/net/dev)!";
	if ( defined( my $line = <PROC_NET> ) ) {
		chomp($line);
		my @net = split( /\s+|:/, $line );
		%net2 = (
			"recv" => $net[2],
			"send" => $net[10]
		);

		if ($net_not_first) {
			$diff_recv = ($net2{"recv"} - $net1{"recv"});
			$diff_send = ($net2{"send"} - $net1{"send"});
		}

		%net1 = %net2;
		$net_not_first= 1;
	}
	close PROC_NET or die "Can't close file(/proc/net/dev)!";
}


# ----------------------------------------------------------------------------------------
#  Func : get v$sysstat info
# ----------------------------------------------------------------------------------------
sub get_sysstat {
	my $result = `sqlplus -S / as sysdba<<!!
	  set echo off
	  set colsep ','
	  set term off
	  set head off
	  set feedback off
	  SET PAGESIZE 1000
	  set linesize 400
	  col name for a100
	  col value for a200	  
	  select name, to_char(value) value from v\\\$sysstat ;
	  exit
	  !!`;
	  
	my $trimline;
	my ($key,$value) ;

    my @result = split( /[\r\n]+/, $result );

 	foreach (@result) {
		chomp($_);
		$trimline=&trim($_);
		#if($trimline ne ""){
	        ($key,$value) = split(/,/,$trimline);
	        $key=&trim($key);
	        $sysstat2{"$key"}=&trim($value);		
			#print "$key:" .$sysstat2{"$key"}. "\n";
		#}
 	}
}

# ----------------------------------------------------------------------------------------
#  Func : get v$system_event info
# ----------------------------------------------------------------------------------------
sub get_systemevent {
	my $result = `sqlplus -S / as sysdba<<!!
	  set echo off
	  set colsep ','
	  set term off
	  set head off
	  set feedback off
	  col event for a80
	  col eventvalue for a200
	  set linesize 350
	  select event,to_char(total_waits) || ';' || to_char(time_waited) || ';' ||  wait_class eventvalue  from v\\\$system_event where wait_class not in ('Idle') ;
	  exit
	  !!`;
	  
	my $trimline;
	my ($key,$value) ;

    my @result = split( /[\r\n]+/, $result );

 	foreach (@result) {
		chomp($_);
		$trimline=&trim($_);

		if($trimline ne ""){
	        ($key,$value) = split(/,/,$trimline);
	        $key=&trim($key);
	        $sysevent2{"$key"}=&trim($value);		
			#print "$key++" .$sysevent2{"$key"}. "\n";
		}
 	}
}

# ----------------------------------------------------------------------------------------
#  Func : get locked_object info
# ----------------------------------------------------------------------------------------
sub get_lockobj {
	print `sqlplus -S / as sysdba<<!!
	  set echo off
	  set term off
	  set head on
	  set feedback on
	  set linesize 140
	  col sid format 9999999
	col serial# format 9999999
	col time for a15
	col ORACLE_USERNAME for a20
	col OS_USER_NAME for a20
	col object_name for a30
	col locked_mode for 9999
	select to_char(sysdate,'mm-dd hh24:mi:ss') time, sen.sid, sen.serial#,lobj.oracle_username,lobj.os_user_name,obj.object_name, lobj.locked_mode
	from v\\\$locked_object lobj, dba_objects obj,v\\\$session sen
	where obj.object_id = lobj.object_id and lobj.session_id = sen.sid;	  
	  exit
	  !!`;
	  
	#print $result;
}

# ----------------------------------------------------------------------------------------
#  Func : get blocking info
# ----------------------------------------------------------------------------------------
sub get_blocking {
	print `sqlplus -S / as sysdba<<!!
	  set echo off
	  set term off
	  set head on
	  set feedback on
		set linesize 200
		SET PAGESIZE 1000
		col username FORMAT A20
		col machine FORMAT A25
		col sid format 9999999
		col serial# format 999999
		col status for a10
		col osuser for a20
		col module for a30
		col time for a15
		col wts for 999999
		SELECT LPAD('+', (level-1)*3, '+') || NVL(s.username, '(oracle)') AS username,s.machine,
		       s.sid,s.serial#, s.seconds_in_wait wts, s.status, s.module,to_char(sysdate,'mm-dd hh24:mi:ss') time
		FROM   v\\\$session s where sid in (select sid from v\\\$session where blocking_session is not null) or sid in
		(select blocking_session from v\\\$session where blocking_session is not null)
		CONNECT BY PRIOR s.sid = s.blocking_session START WITH s.blocking_session IS NULL;
		exit
	  !!`;
	  
	#print $result;
}


# ----------------------------------------------------------------------------------------
#  Func : get blocking info
# ----------------------------------------------------------------------------------------
sub get_activesession {
	print `sqlplus -S / as sysdba<<!!
	set echo off
	set term off
	set head on
	set feedback on
	set linesize 200
	SET PAGESIZE 1000
	col username FORMAT A10
	col machine FORMAT A40
	col ssid format a17
	col status for a2
	col wts for 99999
	col lct for 99999
	col event for a30
	col sql_id for a15
	select a.sid||',' || a.serial# ssid,a.username, a.module || '\@' || a.machine as machine,a.event,a.seconds_in_wait wts,a.sql_id,decode(a.status,'ACTIVE','A','INACTIVE','I','KILLED','K',STATUS) status,last_call_et lct
  	from v\\\$session a
 	where (a.event# not in (select event#  from v\\\$event_name where wait_class='Idle') and a.event not like 'SQL*Net message%'   or a.status='ACTIVE')  and a.type = 'USER'
   	and a.sid <> (select sid from v\\\$mystat where rownum = 1)  order by event;
		exit
	  !!`;
	  
	#print $result;
}

sub trim{
	my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}
