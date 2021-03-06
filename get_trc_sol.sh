#!/bin/ksh
#========================================================================================================================================
#	FILE:	get_trc.sh
#      USAGE:	bash get_trc.sh  [Oracle Alert Log]
#       DESC:	This script is used to get the trc file occured in Alert log file and ftp to your server(specially on solaris).
#     AUTHOR:	Milo Luo
#    CREATED:	Aug 14, 2011
#    HISTORY:   [ver]   [date]          [modification note]
#		v0.1	Oct 19,2011	Initialize the script and script test pass on 10g, 11g.(Milo)
#		v0.2	Mar 08,2013	Reconstruct some msg info and estimate trace file size function has been added.(Milo)
#		v0.3	Apr 08,2013	Add ftp target directory for uploading target.(Milo)
#		v0.4	Apr 16,2013	Fix bugs on 11.2 when match the tracefile name with keyword 'incident=(xxxxx):".(Milo)
#		v0.5	Apr 16,2013	Fix the ftp CAN not use full path to upload alert log with zip format.(Milo)
#		v0.6	Nov 26,2014	Fix the grep, tail, basename issue on solaris and SUN OS. (Milo)
#
#========================================================================================================================================
 

# If the argument is not correct, then exit the script.
if [ $# -lt 1 ]
then
    echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' | tee -a $TMP_RUNING_LOG; 
    echo 'Argument failure!' | tee -a $TMP_RUNING_LOG;   
    echo "Missing the alert location!" | tee -a $TMP_RUNING_LOG;
    echo "Usage: sh get_trc.sh <alert_log_location>" | tee -a $TMP_RUNING_LOG ;
    echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' | tee -a $TMP_RUNING_LOG;
    exit -1;
 
fi;
 
#--------- POSSIBLE TO MODIFY VARIABLES ----------------
CURRENT_YEAR='2014';   # Match the year of alert log
BEGIN_MONTH='jun';     # Match the month of alert log only allow(jan,feb,mar,apr,may,jun,jul,aug,sep,oct,nov,dec)
FTP_SER='192.168.20.100';  # The tracefile you want to upload to(ftp server)
FTP_USER='milo';           # FTP username 
FTP_PASSWD='milo';         # FTP password
TARGET_DIR='/';            # FTP uploaded directory(added at 2013.4)
GREP='grep';
GREP='/usr/xpg4/bin/grep';
#---------------------------------------------------
 
 
#------------------------- VARABLES ---------------------------
ALERT_LOC=$1;     # Define the alert log location
OFFSET=10;        # More lines to fetched alert
CURRENT_MONTH=`date +%Y%m`;   # Current month(used to generate the tar files name)
 
TMP_RUNING_LOG="tmp_script_log_"`basename $ALERT_LOC .log`".log"; # The log of runing this script:
#echo $TMP_RUNING_LOG;
 
# Add more for oracle 11g incident format:
# Like this one: "Errors in file /u02/diag/rdbms/demo/demo/trace/demo_ckpt_5736.trc  (incident=26497):"
# Filter added on tar command: 
# cat $FETCH_LOG | $GREP ".trc" | sed -e 's/(incident=[0-9].*)://g' -e 's/.trc[.:]/.trc/g' | awk '{print $NF}' | sort -u | wc -l

## Time point match pattern
# style 1: Tue Dec 29 08:23:59 2009
# style 2: Mon Aug 01 05:40:38 BEIST 2011
MATCH_EXP1="[A-Z][a-z]{2} $BEGIN_MONTH {1,2}[0-9]{1,2} {1,2}[0-9]{2}:{1}[0-9]{2}:{1}[0-9]{2}.*$CURRENT_YEAR"
 
FETCH_LOG="tmp_fetch_"`basename $ALERT_LOC .log`".log";		# Fetch specify alert log segment name
TAR_FILE_NAME="trc_from_"`basename $ALERT_LOC .log`"_${CURRENT_MONTH}.tar";    # Tared trace files name
 
# UP_STAT define
#-- Upload state: 
#-> 0 - (Default.All file will upload) Alert log, Fetchlog, trc files
#-> 1 - (No trc file) Alert log, Fetchlog
#-> 2 - (No defined month's alert log found) Alert log 
 
UP_STAT=0;

#---------------------------- END VARIABLE ------------------------------------------------

echo | tee -a $TMP_RUNING_LOG;
echo '****************************' | tee -a $TMP_RUNING_LOG;
echo `date` | tee -a $TMP_RUNING_LOG;
echo '****************************' | tee -a $TMP_RUNING_LOG;
echo | tee -a $TMP_RUNING_LOG;

 
#******************************* Part 1: Analyze Trace File Info ********************************************************

echo "***********************************************" | tee -a $TMP_RUNING_LOG;
echo "Part1 - Analyze Trace file info" | tee -a $TMP_RUNING_LOG;
echo "***********************************************" | tee -a $TMP_RUNING_LOG;
echo | tee -a $TMP_RUNING_LOG;
echo "> Fetching Log from ${CURRENT_YEAR}-${BEGIN_MONTH} !!!!" | tee -a $TMP_RUNING_LOG;
echo | tee -a $TMP_RUNING_LOG;

 
# Fetch the begin line number in alert
BEGIN_LINE_NUM=`$GREP -niE "$MATCH_EXP1" $ALERT_LOC 2> /dev/null | awk -F: NR==1'{print $1}' 2> /dev/null`;
 
# Writing the log
echo "Begin line number: $BEGIN_LINE_NUM" | tee -a $TMP_RUNING_LOG;
 
# Judge if the BEGIN_LINE_NUM is null, if it's null, then not match result.
if [ ${BEGIN_LINE_NUM}abc = "abc" ]
then
    echo | tee -a $TMP_RUNING_LOG;
    echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' | tee -a $TMP_RUNING_LOG;
    echo "No match log found in Alert file!" | tee -a $TMP_RUNING_LOG | tee -a $TMP_RUNING_LOG;
    echo "Only Alert file will upload!" | tee -a $TMP_RUNING_LOG | tee -a $TMP_RUNING_LOG;
    echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' | tee -a $TMP_RUNING_LOG;
    echo | tee -a $TMP_RUNING_LOG;
    UP_STAT=2;

# if there is matched log, then calculate the end lines
else  
    # Fetch the last line number of the alert log
    END_LINE_NUM=`cat -n $ALERT_LOC | tail -1 | awk '{print $1}'`;

    # Writing the log
    echo "End line number: $END_LINE_NUM" | tee -a $TMP_RUNING_LOG;
    echo | tee -a $TMP_RUNING_LOG;
    # Fetch the match log(plus $OFFSET rows at the end) between target month 
    tail -$((${END_LINE_NUM} - ${BEGIN_LINE_NUM} + $OFFSET + 1)) $ALERT_LOC > $FETCH_LOG;
    gzip -c ${FETCH_LOG} >  ${FETCH_LOG}.gz
fi;
 
# gzip the original log
gzip -c ${ALERT_LOC} > ${ALERT_LOC}.gz | tee -a $TMP_RUNING_LOG;
 
 

#******************************* END Part 1: Analyze Trace File Info ********************************************************





#******************************* Part 2: Collect related File Info ********************************************************


echo "***********************************************" | tee -a $TMP_RUNING_LOG ;
echo "Part2 - Collect related files info" | tee -a $TMP_RUNING_LOG ;
echo "***********************************************" | tee -a $TMP_RUNING_LOG ;

# If the current UP_STAT is 0, then filter the trace files in fetched log
if [ $UP_STAT -eq 0 ]
then
 
    # Calulate if there is any trace file in fetched log
    # Added to overcome incident issue on alert log file
    TRC_NUM=`cat $FETCH_LOG | $GREP ".trc" | sed -e 's/(incident=[0-9].*)://g' -e 's/.trc[.:]/.trc/g' | awk '{print $NF}' | sort -u | wc -l `
 
    ## Check if there is trace files in fetched log
    # No trace file found in fetched log
    if [ $TRC_NUM -eq 0 ]
    then
	# Writting the log
        echo | tee -a $TMP_RUNING_LOG;
        echo '> No trace file found in fetched log, please check !' | tee -a $TMP_RUNING_LOG;
 
        # Set upload flag to 1, only upload alert and fetched log
        UP_STAT=1;

    # Found trace file in fetched log
    elif [ $TRC_NUM -gt 0 ]
    then
        # Writting the log
        echo | tee -a $TMP_RUNING_LOG;
        echo "> Trace file number $TRC_NUM ." | tee -a $TMP_RUNING_LOG;

        # Estimate the size of tar pack
        du -sk `cat $FETCH_LOG | $GREP ".trc" | sed -e 's/(incident=[0-9].*)://g' -e 's/.trc[.:]/.trc/g' | awk '{print $NF}' | sort -u` 2> /dev/null | awk '{print $1}' | xargs 1>/dev/null
        ret_code=$?
        
        # Check if the trace file size can be determine
        if [ $ret_code -eq 0 ]
        then
          echo "> Estimating the size of tar pack..." | tee -a $TMP_RUNING_LOG;
          # Calculate the tracefile size 
          size_of_tar=0

          for i in $(du -sk `cat $FETCH_LOG | $GREP ".trc" | sed -e 's/(incident=[0-9].*)://g' -e 's/.trc[.:]/.trc/g' | awk '{print $NF}' | sort -u` 2> /dev/null | awk '{print $1}' | xargs) 
          do
              size_of_tar=$(($size_of_tar+$i));
          done;

          echo "Totally, those trace files takeup $size_of_tar  K. " | tee -a $TMP_RUNING_LOG;
          echo "If you DON'T have enough space, you have 10 seconds to cancel this operation via CTRL+C!" | tee -a $TMP_RUNING_LOG;
	  echo | tee -a $TMP_RUNING_LOG;
          sleep 10;

        # Trace file size CAN'T determine
        else
          echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" | tee -a $TMP_RUNING_LOG;
          echo "Estimate the size of tar pack failed!" | tee -a $TMP_RUNING_LOG;
          echo "There might be a huge file list OR there is some missing files!" | tee -a $TMP_RUNING_LOG;
          echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" | tee -a $TMP_RUNING_LOG;
        fi

        echo "> Taring the trace file..." | tee -a $TMP_RUNING_LOG;
	# Tar the trace files (update for oracle 11.2) 
        cat $FETCH_LOG | $GREP ".trc" | sed -e 's/(incident=[0-9].*)://g' -e 's/.trc[.:]/.trc/g' | awk '{print $NF}' | sort -u | xargs tar cvf $TAR_FILE_NAME | tee -a $TMP_RUNING_LOG;
        gzip -c $TAR_FILE_NAME > ${TAR_FILE_NAME}.gz | tee -a $TMP_RUNING_LOG;
    fi; 
 
fi;
 
#******************************* END Part 2: Collect related File Info ********************************************************




#******************************* Part 3: Upload related File via ftp ********************************************************

echo | tee -a $TMP_RUNING_LOG;
echo "***********************************************" | tee -a $TMP_RUNING_LOG;
echo "Part3 - Upload the collected files" | tee -a $TMP_RUNING_LOG;
echo "***********************************************" | tee -a $TMP_RUNING_LOG;
echo "> Uploading the files..." | tee -a $TMP_RUNING_LOG;
echo;

# Upload the files according to the flag UP_STAT
# Check what kind of files should be uploaded


if [ $UP_STAT -eq 0 ]          # Upload all files
then
 
ftp -i -n << EOF | tee -a $TMP_RUNING_LOG
open $FTP_SER
user $FTP_USER $FTP_PASSWD
bin
cd $TARGET_DIR
mput $FETCH_LOG.gz
mput ${TAR_FILE_NAME}.gz
lcd `sed -e 's/alert_.*.log$//g' <<< $ALERT_LOC`
mput `basename ${ALERT_LOC}.gz`
bye
EOF
 

elif [ $UP_STAT -eq 1 ]       # Upload alert and fetched log
then

ftp -i -n << EOF | tee -a $TMP_RUNING_LOG
open $FTP_SER
user $FTP_USER $FTP_PASSWD
bin
cd $TARGET_DIR
mput $FETCH_LOG.gz
lcd `sed -e 's/alert_.*.log$//g' <<< $ALERT_LOC`
mput `basename ${ALERT_LOC}.gz`
bye
EOF
 

else                          # Upload alert
 
ftp -i -n << EOF | tee -a $TMP_RUNING_LOG
open $FTP_SER
user $FTP_USER $FTP_PASSWD
bin
cd $TARGET_DIR
lcd `sed -e 's/alert_.*.log$//g' <<< $ALERT_LOC`
mput `basename ${ALERT_LOC}.gz`
bye
 
EOF
 
fi;
 
# Writting the script log
echo | tee -a $TMP_RUNING_LOG;
echo "Done! " | tee -a $TMP_RUNING_LOG;
echo | tee -a $TMP_RUNING_LOG;
 
# Print the notice
echo;
echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ NOTE: Check the ftp output @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' | tee -a $TMP_RUNING_LOG;
echo "Please do these:" | tee -a $TMP_RUNING_LOG;
echo "1. Check if there is any error in the screen and see if those files on FTP SERVER correct!" | tee -a $TMP_RUNING_LOG; 
echo "2. Check if there is 'permission denied' in FTP section, please check if the original file is in the old dir OR the permission on FTP SERVER." | tee -a $TMP_RUNING_LOG;
echo "3. Check if there is 'no such file', please try MANULLY UPLOAD these files and report to script owner." | tee -a $TMP_RUNING_LOG;
echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' | tee -a $TMP_RUNING_LOG;
echo | tee -a $TMP_RUNING_LOG;
echo | tee -a $TMP_RUNING_LOG;
 
# Upload the script log
echo "Uploading the script log..." | tee -a $TMP_RUNING_LOG;
ftp -i -n << EOF 
open $FTP_SER
user $FTP_USER $FTP_PASSWD
bin
cd $TARGET_DIR
mput $TMP_RUNING_LOG
bye
EOF
 

# Remove the generate log
echo "Removing the generated logs and info packages..."
rm -f $TMP_RUNING_LOG ${TAR_FILE_NAME}.gz ${TAR_FILE_NAME} $FETCH_LOG ${FETCH_LOG}.gz ${ALERT_LOC}.gz

#******************************* END Part 3: Upload related File via ftp ********************************************************

