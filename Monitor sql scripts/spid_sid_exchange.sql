col sid_ser# for a15;
col machine for a20;
col program for a30;
col event for a40;
select sid || ',' ||serial# as sid_ser#, username, machine, program, event, row_wait_obj#
from v$session 
where paddr in (select addr from v$process where spid = &ospid);


col sid_ser# for a15;
col machine for a20;
col program for a30;
col event for a40;
select sid || serial# as sid_ser#, username, machine, program, event, row_wait_obj#
from v$session 
where paddr in (select addr from v$process where pid = &orapid);

col pid for 9999999;
col spid for 999999999999;
select pid, spid, username, decode(background,1,'background',NULL,'normal') as "back_process"
from v$process;


select spid from v$process where addr=(select paddr from v$session where sid=&sid);


set linesize 200;
col sid_ser# for a20;
col username for a15;
col program for a40;
col machine for a40;
select s.sid || ',' ||s.serial# as sid_ser#,p.spid as ospid, s.username, s.machine, s.program
from v$session s, v$process p
where s.username is not null; 


