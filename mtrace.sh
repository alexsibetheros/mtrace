#!/bin/bash
#std09261
#Complete analysis of code exists in README!!!!

function calculate_date { 		#function that finds smallest date
	touch tempdatescript
       	while IFS= read -r dateline; do		#loop that converts dates in file into seconds
	       	a=`echo $dateline | awk '{ print $1,$2,$3,$4 }' `
                b=`date -d "$a" +%s`
                echo  $b" "`echo $dateline | awk '{print $5}'` >> tempdatescript
        done < $1
	a=` cat tempdatescript | sort -n| head -1 `
        rm tempdatescript
        min_time=`echo $a |awk '{print $1}'`
        host=`echo $a |awk '{print $2}'`
        nowdate=`date +%s`
        diff=$((nowdate-min_time))
        echo -n " " $((diff/60))min $host
}

function calculate_average {		#function that creates gnuplot files and plots
	rm -f gnu_datafile.dat gnu_plot_file.plt
	touch gnu_datafile.dat gnu_plot_file.plt
	xrange=`echo ${#pc_array[@]}`
	xrange=$((xrange-1))
	if [ $xrange -eq "0" ]; then
		xrange=1
	fi
	mkdir -p temp_sib
	echo -e "set title \"Average Load\"\nset style data linespoints\nset ylabel \"Load\"\nset xlabel \"Machines\"\nset yrange [0:]\nset xrange [0:${xrange}]\nset xtics rotate nomirror\nset terminal jpeg\nset output \"temp_sib/plot_pic$1\" ">>gnu_plot_file.plt
		
	linenum=0 
	first_time=0
	my_n=0
	xtics="set xtics("
	for pcfiles in ${pc_array[@]}; do	#for every machine, calculate load averages	
		my_n=`cat ${pcfiles}_average | wc -l`
		fixline=`awk '{a+=$1;b+=$2;c+=$3 } END {print a,b,c}' ${pcfiles}_average`
		afixline=`echo $fixline | awk '{print $1}'`
		bfixline=`echo $fixline | awk '{print $2}'`
		cfixline=`echo $fixline | awk '{print $3}'`
		afixline=` echo "  scale =5; ${afixline}/${my_n} " | bc` 
		bfixline=` echo "  scale =5; ${bfixline}/${my_n} " | bc` 
		cfixline=` echo "  scale =5; ${cfixline}/${my_n} " | bc` 
		echo ${linenum}" "${afixline}" "${bfixline}" "${cfixline}>>gnu_datafile.dat		
		if [ $first_time -eq "0" ]; then
			xtics=${xtics}\"${pcfiles}\"" "${linenum}			
			first_time=1
		else
			xtics=${xtics}","\"${pcfiles}\"" "${linenum}
		fi
		linenum=$((linenum+1))
	done
	echo ${xtics}")" >>gnu_plot_file.plt
	echo "plot \"gnu_datafile.dat\" using 2 w lp lw 2 t \"1min\", \"gnu_datafile.dat\" using 3  w lp lw 2 t \"5min\", \"gnu_datafile.dat\" using 4  w lp lw 2 t \"15min\"">>gnu_plot_file.plt
	gnuplot> plot "gnu_plot_file.plt"  2>/dev/null	
}

function calculate_user_info {	#function that finds total time spent for each user and occurances of each host
	user_file=$1
	write_file=$2
	h_list=$3
	u_time=0.0
	while read get_user_line; do		#for every line, depending on wether it is (...:...) or "still logged in" calculate time
		line_temp=`echo $get_user_line | awk '{ print $4,$5,$6,$7,$8,$9,$(10),$(11) }'`
		line_temp_logged=`echo $line_temp | grep "still logged" | awk '{print $1,$2,$3,$4}'`		
		if [ "$line_temp_logged" = "" ]; then
			temp_just_time=`echo $line_temp | awk '{print $7}'| sed ' s/[()]//g' | sed 's/[+:]/ /g'	`	
			count_temp=`echo $temp_just_time | awk '{print NF}'	`
			if [ "$count_temp" -eq "2" ]; then			
				just_time=`echo $temp_just_time | awk '{sum=$1*60+$2} END{print sum} '`
			else		
				just_time=`echo $temp_just_time | awk '{sum=$1*1440+$2*60+$3} END{print sum} '`
			fi
			u_time=` echo "  scale =5; ${u_time}+${just_time} " | bc | awk '{printf "%05f\n", $0}'` 
		else
			run_date=`date -d "$line_temp_logged" +%s`
			nowdate=`date +%s`
        		diff=$((nowdate-run_date))	
			just_time=`echo $(($diff/60)).$(($diff%60))`
			u_time=` echo "  scale =5; ${u_time}+${just_time} " | bc | awk '{printf "%05f\n", $0}'` 
		fi
	done < $user_file
	echo -n "$user_file " | sed ' s/_log//g' >> $write_file	
	echo $u_time >> $write_file
	cat $user_file | awk '{ print $1,$3 }' | awk '{arr[$2]++} END {for(i in arr) print $1,i,arr[i]}' | sort -rn +2 -3>> $h_list
	#awk that prints out the user, the host and the number of occurances
}
function calculate_session {		#function creates gnuplot files and plots
					#function explained well in README
	sess_file=$1
	cat $sess_file | awk '{arr2[$3]++} END {for(i in arr2) print i,arr2[i]}' >temp_sess #number of sessions per day	
	cp temp_sess temp_sess2	
	cat temp_sess2 | sort -rn +1 -2 | head -5 > temp_sess
	rm -f temp_sess2
	cat $sess_file | awk -v s=$see_bo '{ if($3 ~ s){print $1,$2,$3 }}' | sort -u -k1,3  >get_date #assosiaction of day with correct date
	cat temp_sess | awk '{print "/^"$1"/w "$1".log"}' >see_bob	#sed function that breaks file into multiple files
	cat $sess_file | awk '{print $3,$1,$2,$4,$5,$6}' > after_sess
	sed -nf see_bob after_sess	#create multiple files, based on date
	touch final_session.dat
	rm -f see_bob after_sess
	echo -e "
	set terminal jpeg      
	set output \"top5.jpeg\"
	set ylabel \"Number of Sessions\"
	set xlabel \"Day\"
	set xrange [:]    
	set yrange [0:]
	set xtics 0,1,4   
	set style fill solid  
	set boxwidth 0.5">top5.plt
	xtics="set xtics("
	first_time=0
	while read layer1; do	#for each day, from the top 5 days picked earlier
		just=`echo ${layer1} | awk '{print $1} '`
		best=0
		tempo=`cat get_date | grep $just`
		if [ $first_time -eq "0" ]; then
			xtics=${xtics}\"$tempo\"" "$just
			first_time=1
		else
			xtics=${xtics}","\"$tempo\"" "$just
		fi
		echo -n $layer1 | awk '{print $1}'| tr -d '\n'>> final_session.dat
		echo -n " ">> final_session.dat		
		echo -n $layer1 | awk '{print $2}'| tr -d '\n'>> final_session.dat
		while read layer2; do		#for each line in file of day, calculate best time
			l_temp=`echo $layer2 | grep "logged" | awk '{print $1,$2,$3,$4}'`
			if [ "$l_temp" = "" ]; then
				temp_just_time=`echo $layer2 | awk '{print $6}'| sed ' s/[()]//g' | sed 's/[+:]/ /g'`	
				count_temp=`echo $temp_just_time | awk '{print NF}'	`
				if [ "$count_temp" -eq "2" ]; then			
					just_time=`echo $temp_just_time | awk '{sum=$1*60+$2} END{print sum}'`					
				else		
					just_time=`echo $temp_just_time | awk '{sum=$1*1440+$2*60+$3} END{print sum}'`
				fi				
				if [ "$(echo "$best < $just_time"|bc)" -eq "1" ]; then			
					best=$just_time
				fi				
			else
				fix_temp=`echo $l_temp | awk '{print $2,$3,$1,$4}'`
				run_date=`date -d "$fix_temp" +%s`
				nowdate=`date +%s`
        			diff=$((nowdate-run_date))	
				just_time=`echo $(($diff/60)).$(($diff%60))`
				if [ "$(echo "$best < $just_time"|bc)" -eq "1" ]; then			
					best=$just_time
				fi
			fi
		done < ${just}.log
		rm -f ${just}.log
		echo " ""$best" >> final_session.dat 
	done < temp_sess
	rm -f get_date temp_sess
	echo ${xtics}")" >>top5.plt
	echo -e " plot \"final_session.dat\" using 1:2  with boxes title \" \",\"final_session.dat\" using 1:(\$2+1.0):3 with labels title \" \" ">>top5.plt
	gnuplot < plot "top5.plt"  2>/dev/null
	rm -f final_session.dat top5.plt
}

function control_c_trap {	#handel the control c
	home=`echo $HOME`
	echo
	echo "Saving to tar ball:"
	tar -cvf ${home}/gnu_plot_pics.tar "temp_sib"	
	for killing in ${pc_array[@]}; do
		rm -f ${killing}_average
	done	
	rm -f gnu_plot_file.plt gnu_datafile.dat 
	rm -fr temp_sib	
	exit 115
}

args=("$@")
flag=0
k=0
i=1
domain_name=""
no_pc=0
status_flag=0
t=10
stop=0
stop2=0
for argum ; do	#loop that checks all inline arguments, sets all variables and exists if problems arise
	if [ 1 -le $flag ]; then
		flag=$((flag-1))
		i=$((i+1))
		continue
	fi
	case $argum in
	-s)  	
		if [ "$stop2" -eq "1" ]; then
			echo "Please give: -s OR -st OR -c!"
			exit 6
		fi
		status_flag=1
		stop2=1	;;
	-c)	
		if [ "$stop2" -eq "1" ]; then
			echo "Please give: -s OR -st OR -c!"
			exit 6
		fi
		status_flag=2
		stop2=1;;
	-st)	
		if [ "$stop2" -eq "1" ]; then
			echo "Please give: -s OR -st OR -c!"
			exit 6
		fi
		status_flag=3
		stop2=1;;
	-t)	
		temp=$((i+1))
		if [ $temp -le $# ]; then
			t=${args[$temp-1]}
			flag=1
		else
			echo "Didnt give time after t"
			exit 4
		fi;;		
	-d)	
		temp=$((i+1))
		if [ $temp -le $# ]; then
			domain_name=${args[$temp-1]}
			flag=1
		else 
			echo "Not enough parameters for domain"
			exit 1
		fi;;
	-l)		
		if [ "$stop" -eq "1" ]; then
			echo "Both -l and -f given, please rerun with only 1."
			exit 5
		fi	
		no_pc=1
		temp=$((i+1))
		if [ $temp -le $# ]; then
			for (( j = i ; j < ${#args[@]} ; j++ )); do
				if [ "${args[$j]:0:1}" = "-" ]; then
					break;
				fi	
				pc_array[k]=${args[$j]}				
				k=$((k+1))
				flag=$((flag+1))
			done
				stop=1
		else
			echo "Please give atleast 1 pc in list"
			exit 2
		fi;;
	-f)
		if [ "$stop" -eq "1" ]; then
			echo "Both -l and -f given, please rerun with only 1."
			exit 5
		fi
		no_pc=1
		temp=$((i+1))
		if [ $temp -le $# ]; then
			pc_file=${args[$i]}	
			pc_array=( `cat "$pc_file"`)
			stop=1			
			flag=1
		else
			exit 3
		fi;;
	*)	
		echo "Wrong Inline Parameters";;
	esac	
	i=$((i+1))
done
if [ "$t" -ne "10" ]; then
	if [ "${status_flag}" -ne "2" ]; then
		echo "The parameter "t" only applies to output2(-c flag), please try again."
		exit 7
	fi
fi
pc_array=($(for getting in ${pc_array[@]}; do	#only uniq machines, duplicats not allowed
		echo $getting
		done | sort | uniq))
if [ $no_pc -eq 0 ]; then	#if no machiens given, use current
	pc_array[0]=`hostname`
fi
if [ "${domain_name}" != "" ]; then
	domain_name=.${domain_name}
fi
if [ "${status_flag}" -eq "0" ]; then
	echo "Rerun with -s -c or -st."
fi
if [ "${status_flag}" -eq "1" ]; then	# Output 1
	for each in ${pc_array[@]}; do
		echo ${each}":"
		pc=${each}${domain_name}
		uniqfinger=($(rsh ${pc} finger 2>/dev/null | sed 1d | sort +2 -3 |awk '{print $1}' | uniq))  #get all users
		for line in ${uniqfinger[@]}; do
			omg=`rsh -n ${pc} finger -m $line 2>/dev/null` #get user specific info
			datafile=`echo $omg | head -1 | awk '{a=$5;b=$4;c=$2; if ( $5 == "" ){ a="-"} ; print a,b,c }' | sed ' s/\r//' `" "
			temp_ps=`rsh -n ${pc} ps r -U $line -o %cpu,comm | sed 1d |  sort -rn +0 -1 | head -1 | cut -c 6- ` #get users process info
			if [ "${temp_ps}" = "" ]; then
				temp_ps=" "
			fi
			echo "$omg" | awk '$1=="On" && $2=="since" {print $3,$4,$5,$6,$11}'| sed 's/\r//' > tempdate
			datafile=${datafile}`calculate_date tempdate` #call function that finds smallest date(and returns the assosciated host)
			rm tempdate
			datafile=${datafile}`echo  " "$temp_ps`
			echo $datafile | awk '{ a=$1; if(a=="-"){ a=" "}; b=$5; if(b==":0"){b="(:0)"}; printf("%-20s %-20s %-12s %-7s %-15s %-15s\n",a, $2 , $3 , $4,$6,b)}'|  sed ' s/\r//'
		done
		echo
	done
	exit 0
fi

trap control_c_trap SIGINT
for get in ${pc_array[@]}; do
	touch ${get}_average;
	done

if [ "${status_flag}" -eq "2" ]; then 	# Output 2
	echo "-----------------Starting Demon-----------------"
	echo "-----------------[Refresh Rate:"$t"'s]----------"
	num=0
	loop_num=0	
	othernum=0
	total=`echo ${#pc_array[@]}`
	while true ; do		#loop until control+c
		for each in ${pc_array[@]}; do
	                echo -n ${each}": "
			pc=${each}${domain_name}
               		uniqfinger=($(rsh ${pc} finger 2>/dev/null | sed 1d | sort +2 -3 |awk '{print $1}' | uniq)) #get uniq users on current machine
			echo ${uniqfinger[@]}
			echo `rsh -n ${pc} w | head -1 |  sed -n "s/.*load average: \(.*\).*/\1/p"`>>${each}_average	#get average load time for machine
			if [ `cat ${each}_average | wc -l` -eq "21" ]; then	#if more than 20 lines in file , remove the first line
                                sed -i '1d' ${each}_average
                        fi
			othernum=$((othernum+1))
			for thing in ${uniqfinger[@]}; do	#add to total users
				uniq_array[num]=$thing
				num=$((num+1))
			done
		done
		uniqnumber=`for thingy in ${uniq_array[@]}; do
			echo ${thingy}
		done | sort | uniq | wc -l`	#calculate total uniq users for all machines
		echo "-->>There are ""${uniqnumber}"" unique users logged in at this time." 
		result=` echo "  scale =5; ${uniqnumber}/${total} " | bc` 
		echo "-->>On average: "${result}" users logged in per machine."
		num=0
		unset uniq_array
		echo
		calculate_average $loop_num	#call function that will create gnuplot based on the .plt,.dat files it creates
		loop_num=$((loop_num+1))
		sleep $t
	done
	
fi

if [ "${status_flag}" -eq "3" ]; then 	# Output 3
	touch reboot_file.txt down_file.txt last_file user_host_list.txt last_10_sess;	
	for pc in ${pc_array[@]}; do	#collect "last -x" from all machines
		rsh -n ${pc} last -x >temp_last_file
		cat temp_last_file >> last_file
		sed -i '$d' last_file
		cat temp_last_file | grep reboot > temp_reboot	#calculate total number of reboots(and when they occured)
		c_num=`cat temp_reboot | wc -l`
		cat temp_reboot | awk '{print $5,$6,$7,$8}'> re_times
		echo "-------------------">>reboot_file.txt
		echo ${pc}" rebooted: "${c_num}" times">>reboot_file.txt		
		cat re_times >>reboot_file.txt
		echo >> reboot_file.txt
		cat temp_last_file | grep shutdown > temp_reboot	#likewise for shutdowns
		c_num=`cat temp_reboot | wc -l`
		cat temp_reboot | awk '{print $5,$6,$7,$8}'> re_times
		echo "-------------------">>down_file.txt
		echo ${pc}" shutdown: "${c_num}" times">>down_file.txt		
		cat re_times >>down_file.txt
		echo >> down_file.txt
	done
	rm -f temp_reboot re_times temp_last_file	
	sed -i '/root/d' last_file	#remove from file with last's all bad information
	sed -i '/gone - no logout/d' last_file
	sed -i '/reboot/d' last_file
	sed -i '/shutdown/d' last_file
	sed -i '/down/d' last_file
	sed -i '/runlevel/d' last_file	
	templ=($(cat last_file | awk '{print $1}' | sort | uniq ))	#uniq users
	touch temp_user_times	
	for stuff in  ${templ[@]}; do	#break file into seperate file for each user
		cat last_file | grep $stuff > ${stuff}_log
		calculate_user_info ${stuff}_log temp_user_times user_host_list.txt
		#calculate for each user total time spent and host occurances	
	done
	cat temp_user_times | sort -nr +1 -2 | head -100 >final_times.txt #keep only the top 100 users	
	nowdate=`date +%s`
	maxdate=`date -d "-10 day" +%s `	#find the date 10 days ago
	cat last_file | awk '{print $4,$5,$6,$7,$9,$10}' >session_file
	while read get_session; do	#loop that keeps only lines that maximum 10 days old
		cur_time=`echo $get_session | awk '{print $1" "$2" "$3" "$4}' | sed ' s/\r//' `
		cur_changed=`date -d "${cur_time}" +%s`
		if [ "$cur_changed" -gt "$maxdate" ] ; then	
			echo $get_session >> last_10_sess
		fi
	done < session_file
	rm -f session_file last_file 
	calculate_session last_10_sess	#using the last 10 days, create the gnuplot with the best 5
	home=`echo $HOME`
	echo "Saving to tar ball:"	#create tar ball with all reports
	tar -cvf ${home}/email_attachment.tar top5.jpeg final_times.txt user_host_list.txt down_file.txt reboot_file.txt
	current_user=`whoami`
	current_domain=`hostname -d`	#send tar ball as attachment to users email
	echo | mutt -s "Output3 Report" -a ${home}/email_attachment.tar  ${current_user}@${current_domain}
	rm -f last_10_sess top5.jpeg final_times.txt user_host_list.txt reboot_file.txt down_file.txt temp_user_times;			
	for die in ${pc_array[@]}; do
		rm -f ${die}_average;
	done
	for stuff in  ${templ[@]}; do
		rm -f ${stuff}_log
	done
	exit 0
fi
