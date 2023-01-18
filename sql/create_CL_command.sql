create or replace procedure cmd4sql.create_CL_command (
    in command_name char(10) ,
    in library_name char(10) default '*SCHEMA',
    in routine_type char(10) default 'FUNCTION', 
    in routine_name varchar(32) ,
    in routine_schema char(10)
)
dynamic result sets 1
specific CRTCMDSQL
set option output=*print, commit=*none, dbgview = *source 
begin
    declare stmt               varchar(256);
    declare cmd                varchar(4096);
    declare msg                varchar(256);
    declare title              varchar(30);
    declare parm_text          varchar(30);
    declare choice_text        varchar(32);
    declare parm_declarartion  varchar(256);
    declare sql_len            varchar(32) ;
    declare allow_mode         varchar(32) default '*ALL';
    declare required           varchar(32);
    declare parm_name_by_comment varchar(32);
    declare keyword_name       varchar(32);
    declare out_parm_counter   int default 0;
    declare dummy              int;
    declare out_type           int; 
    -- declare report  cursor with return for values 'Completed';
        

    -- Allow any parameters in lowercase: 
    set create_CL_command.command_name    = upper(create_CL_command.command_name)  ;
    set create_CL_command.library_name    = upper(create_CL_command.library_name)  ;
    set create_CL_command.routine_type    = upper(create_CL_command.routine_type)  ;
    set create_CL_command.routine_name    = upper(create_CL_command.routine_name)  ;
    set create_CL_command.routine_schema  = upper(create_CL_command.routine_schema);

    for a as 
        select rrn(sysroutines) as id ,sysroutines.*         
        from sysroutines  
        where routine_schema = create_CL_command.routine_schema
        and   routine_name   = create_CL_command.routine_name
        and   routine_type   = create_CL_command.routine_type
    do begin
        declare continue handler for sqlstate '38501' begin
        end;

        -- Human readable version of the prcedure as a command
        if long_comment is not null then
            set title = rtrim(long_comment);
        else                 
            set title = Upper(substr(create_CL_command.routine_name, 1 , 1)) concat lower(substr(create_CL_command.routine_name , 2));
            set title = replace (title , '_' , ' ');
        end if;

        -- Create the source file for the command            
        call qcmdexc('CRTPF FILE(CMD4SQL/EVFEVENT) RCDLEN(300)'); 
        call qcmdexc('crtsrcpf cmd4sql/xxtempsrc rcdlen(240)'); 
        call qcmdexc('addpfm   cmd4sql/xxtempsrc MBR(' || rtrim(command_name) || ')'); 

        -- call qcmdexc ( 'ovrdbf  evfevent  tofile(cmd4sql/evfevent)  MBR(' || rtrim(command_name) || ') ovrscope(*JOB)');
        call qcmdexc ( 'ovrdbf  evfevent  tofile(cmd4sql/evfevent)  MBR(*FIRST) ovrscope(*JOB)');
        call qcmdexc ( 'ovrdbf  XXTEMPSRC tofile(cmd4sql/XXTEMPSRC) MBR(' || rtrim(command_name) || ') ovrscope(*JOB)');
        
        delete from xxtempsrc;
        insert into xxtempsrc (srcdta) values('CMD PROMPT(''' concat trim(title) concat ''')'); 

        -- This is the function or procedure to call, placed 
        -- as a constant in the command and always pased as first parameter
        -- to the generic routine executor  
        -- The first "1;"" is the version
        set stmt = 'PARM KWD(ROUTINETYP) TYPE(*CHAR) LEN(30) MIN(1) CONSTANT(''' concat
            '1;' concat -- version 
            substr(create_CL_command.routine_type , 1 , 1) concat ';' concat 
            rtrim(create_CL_command.routine_schema) concat ';' concat 
            ''')';
        insert into xxtempsrc (srcdta) values(stmt);

        set stmt = 'PARM KWD(ROUTINENAM) TYPE(*CHAR) LEN(30) MIN(1) CONSTANT(''' concat 
            rtrim(create_CL_command.routine_name) concat ';' concat
            ''')';
        insert into xxtempsrc (srcdta) values(stmt);

        -- placeholder for option ( dateformat / commit etc)  TODO
        set stmt = 'PARM KWD(OPTIONS) TYPE(*CHAR) LEN(30) MIN(1) CONSTANT('' '')';
        insert into xxtempsrc (srcdta) values(stmt);

        -- Note: Commands require that parameter with default comes after required parameters; 
        -- hench that odd order by                             
        for c as
            with parm_data_type_map (
                    sql_parm_type, -- Type from SYSPARMS
                    sql_data_type, -- SQLCLI type in procedure/function 
                    cl_data_type,  -- CL datatype as SQLCLI type
                    cl_return_type, -- Datatype for CL in function return
                    cl_parm_type,  -- Parameter type in command
                    is_varying     -- 1=Contains length word,0=Fixed len
                ) 
                as ( values  
                    ('BIGINT'                            , 19   , 3  , 3  ,'DEC' , 0), 
                    ('INTEGER'                           , 4    , 4  , 4  ,'INT4', 0),
                    ('SMALLINT'                          , 5    , 5  , 5  ,'INT2', 0),
                    ('DECIMAL'                           , 3    , 3  , 3  ,'DEC' , 0),
                    ('NUMERIC'                           , 2    , 3  , 3  ,'DEC' , 0),
                    ('DOUBLE PRECISION'                  , 6    , 3  , 3  ,'DEC' , 0),
                    ('REAL'                              , 7    , 3  , 3  ,'DEC' , 0),
                    ('DECFLOAT'                          , -360 , 3  , 3  ,'DEC' , 0),
                    ('CHARACTER'                         , 1    , 1  , 1  ,'CHAR', 0),
                    ('CHARACTER VARYING'                 , 12   , 12 , 1  ,'CHAR', 1),
                    ('CHARACTER LARGE OBJECT'            , 14   , 12 , 1  ,'CHAR', 1), 
                    ('GRAPHIC'                           , 95   , 1  , 1  ,'CHAR', 0), 
                    ('GRAPHIC VARYING'                   , 96   , 12 , 1  ,'CHAR', 1), 
                    ('DOUBLE-BYTE CHARACTER LARGE OBJECT', 96   , 12 , 1  ,'CHAR', 1), 
                    ('BINARY'                            , 452  , 1  , 1  ,'CHAR', 0), 
                    ('BINARY VARYING'                    , 448  , 12 , 1  ,'CHAR', 1), 
                    ('BINARY LARGE OBJECT'               , -2   , 12 , 1  ,'CHAR', 1), 
                    ('DATE'                              , 91   , 91 , 91 ,'DATE', 0),
                    ('TIME'                              , 92   , 92 , 92 ,'TIME', 0),
                    ('TIMESTAMP'                         , 93   , 1  , 1  ,'CHAR', 0),
                    ('DATALINK'                          , 16   , 1  , 1  ,'CHAR', 0),
                    ('ROWID'                             , 496  , 0  , 0  ,'????', 0),
                    ('XML'                               , -370 , 12 , 1  ,'CHAR', 1), 
                    ('DISTINCT'                          , 448  , 0  , 0  ,'????', 0),
                    ('ARRAY'                             , 448  , 0  , 0  ,'????', 0)
                )
             
            Select 
                row_number() over() row_no,
                c.* ,                    
                sql_parm_type,
                cast( cl_parm_type as varchar(64)) cl_parm_type,
                sql_data_type,
                cl_data_type,
                cl_return_type,
                is_varying
            from sysparms c 
            left join parm_data_type_map on c.data_type = parm_data_type_map.sql_parm_type
            where c.specific_schema = a.specific_schema
            and   c.specific_name   = a.specific_name
            order by case 
                when routine_type = 'FUNCTION' and parameter_mode  = 'OUT' -- Note; Functions returnvalues have to come last. because of "values ... into ?"
                    then ordinal_position + 1000 
                when c.default is null 
                    then ordinal_position 
                else 
                    ordinal_position + 1000 
            end

            do
                set out_type = case when routine_type = 'FUNCTION' and parameter_mode  = 'OUT' then cl_return_type else cl_data_type end;
                set parm_declarartion = '';
                set parm_name_by_comment = '';
                set required = case when c.default is null then 'MIN(1) ' else '' end;  


                -- Name from the comment, given i n parentheses: 
                set keyword_name = null;

                if c.long_comment is not null then 
                    set parm_name_by_comment =  regexp_substr (c.long_comment , '\((.*)\)' , 1, 1, 'i' , 1 ); 
                    if  parm_name_by_comment is not null then
                        set keyword_name  = parm_name_by_comment;
                    end if;    
                end if;

                -- Huxi: Fix types: TODO :( 
                -- DATE and TIME is not supported as RTNVAL, we change them to CHAR
                if parameter_mode  in ('OUT' ,'INOUT') then 
                    if cl_parm_type = 'DATE' 
                    or cl_parm_type = 'TIME' then
                        set (out_type , cl_parm_type) = (1 ,'CHAR');
                    end if;
                end if;  
                        
                                                 
                if cl_parm_type = '????' then 
                    set msg = ': Datatype ' concat sql_parm_type concat 'is not supported';
                    signal  sqlstate 'NLI02' set message_text  = msg;
                end if; 

                -- Ajust for CL limitationer: 15,9 is the max:
                if  numeric_precision is not null and numeric_precision > 15 then
                    set numeric_precision = 15;
                end if;

                if  numeric_scale is not null and numeric_scale > 9 then
                    set numeric_scale = 9;
                end if;

                set numeric_scale = ifnull(numeric_scale , 0);

                if substr( cl_parm_type , 1, 3) = 'INT'  
                or cl_parm_type  = 'DATE' 
                or cl_parm_type = 'TIME' then
                    set sql_len =  ifnull ( numeric_precision , 0) concat ';' concat ifnull(numeric_scale, 0);
                    set choice_text = cl_parm_type ;
                elseif numeric_precision is not null then
                    set parm_declarartion = parm_declarartion concat ' LEN(' concat numeric_precision concat ' ' concat numeric_scale concat ') ';
                    set sql_len = numeric_precision concat ';' concat numeric_scale;
                    set choice_text = cl_parm_type concat ' ('concat numeric_precision concat ' ' concat numeric_scale concat ')';
                else   
                    set parm_declarartion = parm_declarartion concat ' LEN(' concat character_maximum_length concat ') ';
                    set sql_len = character_maximum_length concat ';0';
                    set choice_text = cl_parm_type concat ' ('concat character_maximum_length concat ')';
                end if; 
                
              
                case
                    when parameter_mode  = 'IN' then 
                        set parm_declarartion = parm_declarartion concat  ' EXPR(*YES) ';
                        if  c.default is null then 
                            set parm_declarartion = parm_declarartion concat  ' MIN(1) ';
                        end if;

                    when parameter_mode  in ('OUT' ,'INOUT') then 
                        set allow_mode = '*BPGM *IPGM';
                        set parm_declarartion = parm_declarartion concat ' RTNVAL(*YES) ';
                        -- return values must always have varying
                        set is_varying = 1;

                        if parameter_name is null then
                            set out_parm_counter = out_parm_counter + 1;
                            set parameter_name = 'RTNVAR' concat out_parm_counter;
                            -- set is_varying = 0; -- Vary fails on return values in functions since it is blank on input 
                        end if; 

                end case; 
                
                -- Still null ( then IBM i build-in )                        
                if parameter_name is null then 
                    set parameter_name = 'PARM' concat row_no;
                end if;
                
                if keyword_name is null then 
                    set keyword_name = replace(parameter_name , '_' , '');
                end if;
                
                if parameter_name is null then 
                    set parameter_name = 'JOHN';
                end if;
                
                -- First: Put the parameter name as meta info
                set stmt = 'PARM KWD(NAME' concat row_no concat ') '  concat required concat
                    ' TYPE(*CHAR) LEN(30) CONSTANT(''' concat
                    rtrim(parameter_name) concat ';'  concat
                    ''')' ;

                insert into xxtempsrc (srcdta) values(ifnull(stmt, '???')); 
                
                -- Second: Put the meta data
                set stmt = 'PARM KWD(META' concat row_no concat ') '  concat required concat 
                    ' TYPE(*CHAR) LEN(30) CONSTANT(''' concat
                    out_type concat ';' concat 
                    sql_data_type concat ';' concat 
                    sql_len concat ';'  concat 
                    is_varying concat ';' concat 
                    rtrim(parameter_mode) concat ';' concat
                    ''')' ;

                insert into xxtempsrc (srcdta) values(ifnull(stmt, '???')); 


                -- Human readable version of the paramter name
                if long_comment is not null then
                    set parm_text = substr(rtrim(regexp_substr (long_comment , '(.*)\(' , 1, 1, 'i' , 1 )), 1, 30);
                    if parm_text is null then 
                        set parm_text = substr(trim(long_comment), 1, 30);
                    end if ;   
                else                 
                    set parm_text = Upper(substr(parameter_name, 1 , 1)) concat lower(substr(parameter_name , 2));
                    set parm_text = replace (parm_text , '_' , ' ');
                    -- TODO set CL type in the parm text;
                end if;

                -- Build the parameter datatype for the command 
                set parm_declarartion = parm_declarartion concat 'TYPE(*' concat cl_parm_type concat ') ';

                if is_varying = 1 then  
                    set parm_declarartion = parm_declarartion concat 'VARY(*YES *INT2) ';
                end if;

                -- Last: Put the parameter 
                set stmt = 'PARM KWD(' concat rtrim(substr(keyword_name, 1 , 10)) concat ') '  concat
                    parm_declarartion  concat
                    'PROMPT(''' concat trim(parm_text) concat ''') ' concat
                    'PASSATR(*YES) ' concat 
                    'CHOICE(''' concat choice_text concat ''') ';
                insert into xxtempsrc (srcdta) values(ifnull(stmt, '???')); 
                
         end for;            
        end; 
    end for;
    
    if  title is null then
        set msg = 
            ': Routine ' concat rtrim(create_CL_command.routine_name) concat 
            ' In schema ' concat rtrim(create_CL_command.routine_schema) concat 
            ' of type ' concat rtrim(create_CL_command.routine_type) concat ' does not exists'; 
        signal  sqlstate 'NLI02' set message_text  = msg;
    else
        begin 
            declare continue handler for sqlstate '38501' begin
                set msg = 
                    ': Command for  ' concat rtrim(create_CL_command.routine_name) concat 
                    ' In schema ' concat rtrim(create_CL_command.routine_schema) concat 
                    ' of type ' concat rtrim(create_CL_command.routine_type) concat ' failed. Look in spoolfiles'; 
                signal  sqlstate 'NLI03' set message_text  = msg;
            end;
            

            /* for now - we are happy with the compile list if it fails ....
                for 
                    with a as ( 
                       Select 
                           int(substr(evfevent , 20 ,6)) lineno,
                           cast (rtrim(substr(evfevent ,  68 , 2 )) as varchar(30)) error_msg_text ,
                           evfevent all_text 
                       from CMD4SQL.evfevent 
                       where evfevent like 'ERROR%'
                    ) 
                    select *  
                    from a
                    left join qcmdsrc  b
                        on  rrn(b) = lineno 
                do
                
                    set msg = error_msg_text || '+' || srcdta; 
                    signal  sqlstate 'NLI02' set message_text  = msg;
                end for;
            end;
            */ 

            set cmd =  'crtcmd CMD(' concat 
                rtrim(library_name) concat '/' concat 
                rtrim(command_name) concat ')' concat 
               ' PGM(CMD4SQL/CMD4SQL) MODE(*ALL) ALLOW(' concat allow_mode concat 
               ') SRCFILE(cmd4sql/xxtempsrc) OPTION(*EVENTF) REPLACE(*yes)  text(''' concat 
               title concat ''')';
               
             call qcmdexc ( cmd);   
        end; 
    end if;  
    
    -- open report;                                
            
end;

-- test case
call cmd4sql.create_CL_command ( 
    command_name => 'EXCHRATE',
    library_name => 'CMD4SQL',
    routine_type => 'FUNCTION',
    routine_name => 'EXCHANGE_RATE',
    routine_schema => 'CMD4SQL'
);

call cmd4sql.create_CL_command ( 
    command_name => 'ADDLOG',
    library_name => 'NHO',
    routine_type => 'PROCEDURE',
    routine_name => 'ADD_LOG',
    routine_schema => 'YXDB'
);


with a as ( 
   Select 
       int(substr(evfevent , 20 ,6)) lineno,
       substr(evfevent , 66 ) msg
   from cmd4sql.evfevent 
   where evfevent like 'ERROR%'
) 
select * 
from a
left join cmd4sql.XXTEMPSRC b
on  rrn(b) = lineno; 

Select * from cmd4sql.evfevent;


-- Generated source:
-- select * from cmd4sql.xxtempsrc;

-- Generated source:
-- select * from cmd4sql.xxtempsrc;
-- cl: CMD4SQL/EXCHRATE;

--select row_number() over() id, a.* from sysparms a;