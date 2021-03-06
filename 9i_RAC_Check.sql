-- ##################################################################################
-- Script Name: RAC Oracle 9i Check
-- ################################################################################## 
-- Purpose: This script is used to diagnose or check Oracle 9i RAC database
-- Maintainers: Jet, Milo
-- Version change and reason:
---- v0.1   Script initial (Jet, Milo)
---- v0.2   Script modify (Jet)
---- v0.2.1 Added the script header and modify need manually part (Milo)
----        modify nls_date_format=english to avoid spool file issue (Milo) 
----        modify the comments in wait and related sql (Milo) 

-- ##################################################################################



-- ################################################################################## 
----------- Part 1: Need manually ------------
-- ################################################################################## 

--#1. snapshot of report
--#--statspack report
--#SQL> execute statspack.snap;

--#SQL> @ ?/rdbms/admin/spreport.sql


--#2. Check datafile type
--#SELECT name
--#FROM   v$datafile;  

--#ls -lrt <datafile_dir>

--#3. Log check:
--#tail alert.log
--#tail listener.log


-- ##################################################################################
--------------Part 2: Sql Query -----------------
-- ##################################################################################

-- Generate a spool file name

set echo off 
set feedback off 
alter session set nls_date_language=english;
column timecol new_value timestamp 
column spool_extension new_value suffix 
select to_char(sysdate,'Mondd_hhmi') timecol, 
'.out' spool_extension from sys.dual; 
column output new_value dbname 
select value || '_' output 
from v$parameter where name = 'db_name'; 
spool 9i_rac_&&dbname&&timestamp&&suffix 

set linesize 79
set pagesize 180
set long 1000
set trim on 
set trims on 
alter session set nls_date_format = 'MM/DD HH24:MI:SS'; 
set feedback on 
select to_char(sysdate) time from dual; 
 
set echo on 




-------------------------------
-- Check GSD status
! gsdctl stat
! srvctl status instance -d cfcacadb -i cfcacadb1, cfcacadb2


-- Check instance running status

set linesize 120;
col inst_id for 999;
col instance_name for a15;
col host_name for a10;
col version for a10;
col startup_time for a20;
col status for a8;
col archiver for a10;
col database_status for a15;
SELECT inst_id,
       instance_name,
       host_name,
       VERSION,
       TO_CHAR(startup_time, 'yyyy-mm-dd hh24:mi:ss') startup_time,
       status,
       archiver,
       database_status
  FROM gv$instance;



-- Check DB version

SELECT *
FROM   v$version;  


-- Check DB properties

set linesize 120;
col property_name for a30;
col property_value for a40;
col description for a40;
SELECT *
FROM   database_properties; 



-- Check DB option and feature

set linesize 100;
col parameter for a40;
col value for a8;
SELECT *
FROM   v$option; 


-- Check components are loaded in DB
---- Check if all loaded component are valid 
---- Normally, all component status should be "VALID"

col comp_name for a40;
SELECT comp_name,
       status 
FROM   dba_registry; 



-- Check Total size of Datafile 

col Total(GB) for 999999.999;
col Total(TB) for 999999.999;
SELECT ( d1 + d2 ) / 1024 / 1024 / 1024        "Total(GB)",
       ( d1 + d2 ) / 1024 / 1024 / 1024 / 1024 "Total(TB)"
FROM   (SELECT Sum(bytes) d1
        FROM   v$datafile),
       (SELECT Sum(bytes) d2
        FROM   v$tempfile); 



-- Check availabe space of each tablespace
---- If the USE(%) > 85%, 
---- then the tablespace should be consider to extented. 

set linesize 120;
col tablespace_name for a20;
SELECT D.TABLESPACE_NAME,
       SPACE "Total(M)",
       SPACE - NVL(FREE_SPACE, 0) "USED(M)",
       ROUND((1 - NVL(FREE_SPACE, 0) / SPACE) * 100, 2) "USED(%)",
       FREE_SPACE "FREE(M)"
  FROM (SELECT TABLESPACE_NAME,
               ROUND(SUM(BYTES) / (1024 * 1024), 2) SPACE,
               SUM(BLOCKS) BLOCKS
          FROM DBA_DATA_FILES
         GROUP BY TABLESPACE_NAME) D,
       (SELECT TABLESPACE_NAME,
               ROUND(SUM(BYTES) / (1024 * 1024), 2) FREE_SPACE
          FROM DBA_FREE_SPACE
         GROUP BY TABLESPACE_NAME) F
 WHERE D.TABLESPACE_NAME = F.TABLESPACE_NAME(+)
UNION ALL --if have tempfile
SELECT D.TABLESPACE_NAME,
       SPACE "Total(M)",
       USED_SPACE "USED(M)",
       ROUND(NVL(USED_SPACE, 0) / SPACE * 100, 2) "USED(%)",
       NVL(FREE_SPACE, 0) "FREE(M)"
  FROM (SELECT TABLESPACE_NAME,
               ROUND(SUM(BYTES) / (1024 * 1024), 2) SPACE,
               SUM(BLOCKS) BLOCKS
          FROM DBA_TEMP_FILES
         GROUP BY TABLESPACE_NAME) D,
       (SELECT TABLESPACE_NAME,
               ROUND(SUM(BYTES_USED) / (1024 * 1024), 2) USED_SPACE,
               ROUND(SUM(BYTES_FREE) / (1024 * 1024), 2) FREE_SPACE
          FROM V$TEMP_SPACE_HEADER
         GROUP BY TABLESPACE_NAME) F
 WHERE D.TABLESPACE_NAME = F.TABLESPACE_NAME(+)
 ORDER BY 4;


-- Check datafile type along with ls -l check

SELECT name
FROM   v$datafile;  


-- Check tables and indexes in system tablespace  
-- that NOT belong to SYS OR SYSTEM
---- Check if there are many other objects,
---- place in system tablespace, 
---- if so, then performance might be affected

SELECT DISTINCT owner 
FROM   dba_tables
WHERE  tablespace_name = 'SYSTEM'
       AND owner NOT IN ('SYS', 'SYSTEM', 'MDSYS', 'OLAPSYS', 'OUTLN')
UNION
SELECT DISTINCT owner 
FROM   dba_indexes
WHERE  tablespace_name = 'SYSTEM'
       AND owner NOT IN ('SYS', 'SYSTEM', 'MDSYS', 'OLAPSYS', 'OUTLN') ; 



-- Check tablespace status
---- Normal status should be "ONLINE"

SELECT tablespace_name,
       status
FROM   dba_tablespaces; 


-- Check IO status of each datafile
---- To find out which datafile is in high write/read status

set linesize 100;
col file_name for a46
SELECT df.name                                          file_name,
       fs.phyrds                                        reads,
       fs.phywrts                                       writes,
       ( fs.readtim / Decode(fs.phyrds, 0, -1,
                                        fs.phyrds) )    readtime,
       ( fs.writetim / Decode(fs.phywrts, 0, -1,
                                          fs.phywrts) ) writetime
FROM   v$datafile df,
       v$filestat fs
WHERE  df.file# = fs.file#
ORDER  BY df.name; 



-- Check log file status
---- Check basic info of redo log
---- Status column may be the listed value:
---- UNUSED, CURRENT, ACTIVE, INACTIVE,
---- CLEARING, CLEARING_CURRENT,

col group# for 999999;
col member# for 999;
col "log file path" for a30;
col "MB" for 99999;
SELECT l.group#,
       l.members           AS "member#",
       lf.member           AS "log file path",
       bytes / 1024 / 1024 "MB",
       sequence#,
       l.status
FROM   v$log l,
       v$logfile lf
WHERE  l.group# = lf.group#
ORDER  BY group#,
          members;   



-- Check switch time of redo log
---- Statistik the frequency,normally is close to 30mins

alter session set nls_date_format='yyyy-mm-dd hh24:mi:ss';
col thread# for 9999;
col sequence# for 999999;
SELECT thread#,
       sequence#,
       first_time
FROM   v$log_history
ORDER  BY thread#, sequence#; 



-- Check controlfile status

set linesize 120;
col status for a10;
col name for a40;
col block_size for 99999;
col file_size_blks for 9999999;
SELECT *
FROM   v$controlfile; 


-- Check if there is invalid objects
---- Affirm the status of the objects

SELECT OWNER,
       OBJECT_NAME,
       OBJECT_TYPE
FROM   DBA_OBJECTS
WHERE  STATUS = 'INVALID'; 


-- Check if there is unusable indexes
---- Affirm the use of the indexes

SELECT OWNER,
       INDEX_NAME,
       INDEX_TYPE,
       TABLE_NAME,
       STATUS
FROM   DBA_INDEXES
WHERE  STATUS = 'UNUSABLE'; 


-- Unindexed tables
---- Only a check for necessary index creation

set linesize 80;
col owner for a10;
col segment_name for a30;
col segment_type for a10;
col tablespace_name for a15;
col size_mb for 9999999;
SELECT   /*+ rule */
        owner, segment_name, segment_type, tablespace_name,
        TRUNC (BYTES / 1024 / 1024, 1) size_mb
   FROM dba_segments t
  WHERE NOT EXISTS (
              SELECT 'x'
               FROM dba_indexes i
               WHERE t.owner = i.table_owner
                     AND t.segment_name = i.table_name)
    AND t.segment_type IN ('TABLE', 'TABLE PARTITION')
    AND t.owner NOT IN ('SYS', 'SYSTEM', 'SCOTT')
ORDER BY 5 DESC;



-- Check if there have disabled constraints
---- Enable the disabled constraints

set linesize 100;
col owner for a20;
col constraint_name for a30;
col table_name for a30;
SELECT OWNER,
       CONSTRAINT_NAME,
       CONSTRAINT_TYPE,
       TABLE_NAME
FROM   DBA_CONSTRAINTS
WHERE  STATUS = 'DISABLED'; 





-- Check if there have disabled triggers
---- Recompile the disabled triggers

col owner for a20;
SELECT OWNER,
       TRIGGER_NAME,
       TRIGGER_TYPE
FROM   DBA_TRIGGERS
WHERE  STATUS = 'DISABLED'; 



-- Check active Session Count
---- Monitor the workload

SELECT Count(*) "ACTIVE Session Count" ,INST_ID 
FROM   gv$session
where  status = 'ACTIVE'
       AND username NOT IN ( 'SYS', 'SYSTEM' )
group by INST_ID ; 



-- Check Buffer Cache hit ratio
---- This value should greater than 95%


SELECT (1 - (SUM(DECODE(NAME, 'physical reads', VALUE, 0)) /
       (SUM(DECODE(NAME, 'db block gets', VALUE, 0)) +
       SUM(DECODE(NAME, 'consistent gets', VALUE, 0))))) * 100 "Buffer Cache Hit Ratio(%)"
FROM V$SYSSTAT;



-- Check Sorting Efficiency - Memory Sorting(%)
---- This value should greater than 95%

SELECT a.VALUE        "Disk Sorting",
       b.VALUE        "Memory Sorting",
       ROUND(( 100 * b.VALUE ) / DECODE(( a.VALUE + b.VALUE ), 0, 1,
       ( a.VALUE + b.VALUE )), 2) "Memory Sorting (%)"
FROM   v$sysstat a,
       v$sysstat b
WHERE  a.name = 'sorts (disk)'
       AND b.name = 'sorts (memory)';




-- Check Redo Log Hit Ratio
---- This value should greater than 95%

col name for a20;
col gets for 999999;
col misses for 99999;
SELECT name,
       gets,
       misses,
       immediate_gets,
       immediate_misses,
       100 - ROUND(DECODE(gets, 0, 0,
                          misses / ( gets + misses )), 2) * 100 ratio1,
       100 - ROUND(DECODE(immediate_gets + immediate_misses, 0, 0,
                                                       immediate_misses / (
             immediate_gets + immediate_misses )), 2) * 100     ratio2
FROM   v$latch
WHERE  name IN ( 'redo allocation', 'redo copy' ); 



-- Check Dictionary Hit Ratio
---- This value should greater than 95%

SELECT ROUND(( 1 - ( Sum(GETMISSES) / Sum(GETS) ) ), 2) * 100 "Dictionary Hit Ratio(%)"
FROM   V$ROWCACHE;



-- Check Labrary Cache Hit Ratio
---- This value should greater than 95%

SELECT ROUND(SUM(PINS) / (SUM(PINS) + SUM(RELOADS)), 2) * 100 "Labrary Cache Hit Ratio(%)"
FROM V$LIBRARYCACHE;



-- Check if there lock exists
---- Attention the lock rows last long time

col user_name for a15;
col owner for a15;
col object_name for a15;
col object_type for a15;
col sid for 999999;
col serial# for 999999;
SELECT /*+ rule */ Lpad(' ', DECODE(l.xidusn, 0, 3,
                                              0))
                    || l.oracle_username user_name,
                   o.owner,
                   o.object_name,
                   o.object_type,
                   s.sid,
                   s.serial#
FROM   gv$locked_object l,
       dba_objects o,
       gv$session s
WHERE  l.object_id = o.object_id
       AND l.session_id = s.sid
ORDER  BY o.object_id,
          xidusn DESC; 




-- Check the wait events
---- Attention the top wait events

col event for a40;
col time_waited for 99999999999999999999;
SELECT *
FROM   (SELECT event,
               time_waited
        FROM   v$system_event
        ORDER  BY time_waited DESC)
WHERE  rownum < 11;  



-- Query which sql experience the wait
---- Attention the always appeared SQL

set linesize 120;
col sql_text for a60;
col event for a30;
select s.sql_text, sw.event 
from v$session b,v$session_wait sw,v$sqltext s 
where b.sid=sw.sid 
	and sw.event not like '%SQL*Net%' 
	and sw.EVENT NOT LIKE 'rdbms%' 
	and s.hash_value=b.sql_hash_value 
	and s.sql_id=b.sql_id 
order by s.address,s.piece;



-- Check which new feature has been enabled
---- This section displays the summary of Usage for Database Features.
---- The Currently Used column is TRUE if usage was detected for the feature at the last sample time.

SELECT output
FROM   TABLE(dbms_feature_usage_report.display_text); 

spool off
exit;


