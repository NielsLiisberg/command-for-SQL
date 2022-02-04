create or replace procedure cmd4sql.create_CL_command (
    in command_name char(10) ,
    in library_name char(10) default '*SCHEMA',
    in routine_type char(10) default 'FUNCTION', 
    in routine_name varchar(32) ,
    in routine_schema char(10)
)
specific CRTCMDSQL
set option output=*print, commit=*none, dbgview = *source 
begin
    declare stmt               varchar(256);
    declare msg                varchar(256);
    declare title              varchar(50);
    declare parm_text          varchar(50);
    declare choice_text        varchar(32);
    declare parm_declarartion  varchar(256);
    declare sql_len            varchar(32) ;
    declare allow_mode         varchar(32) default '*ALL';
    declare required           varchar(32);
    declare out_parm_counter   int default 0;
    declare dummy              int;

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
        call qcmdexc('crtsrcpf qtemp/xxtempsrc mbr(xxtempsrc) rcdlen(240)'); 
        truncate qtemp.xxtempsrc;
        insert into qtemp.xxtempsrc (srcdta) values('CMD PROMPT(''' concat title concat ''')'); 

        -- This is the function or procedure to call, placed 
        -- as a constant in the command and always pased as first parameter
        -- to the generic routine executor  
        -- The first "1;"" is the version
        set stmt = 'PARM KWD(ROUTINE) TYPE(*CHAR) LEN(30) MIN(1) CONSTANT(''1;' concat 
            substr(create_CL_command.routine_type , 1 , 1) concat ';' concat 
            rtrim(create_CL_command.routine_schema) concat ';' concat 
            rtrim(create_CL_command.routine_name) concat ';' concat
            ''')';
        insert into qtemp.xxtempsrc (srcdta) values(stmt);

        -- placeholder for option ( dateformat / commit etc)  TODO
        set stmt = 'PARM KWD(OPTIONS) TYPE(*CHAR) LEN(30) MIN(1) CONSTANT('' '')';
        insert into qtemp.xxtempsrc (srcdta) values(stmt);

        -- Note: Commands require that parameter with default comes after required parameters; 
        -- hench that odd order by                             
        for c as
            with parm_data_type_map (
                    sql_parm_type, -- Type from SYSPARMS
                    sql_data_type, -- SQLCLI type in procedure/function
                    cl_data_type,  -- CL datatype as SQLCLI type
                    cl_parm_type,  -- Parameter type in command
                    is_varying     -- 1=Contains length word,0=Fixed len
                ) 
                as ( values  
                    ('BIGINT'                            ,19  ,3 ,'DEC'  ,0), 
                    ('INTEGER'                           ,4   ,4 ,'INT4' ,0),
                    ('SMALLINT'                          ,5   ,5 ,'INT2' ,0),
                    ('DECIMAL'                           ,3   ,3 ,'DEC'  ,0),
                    ('NUMERIC'                           ,2   ,3 ,'DEC'  ,0),
                    ('DOUBLE PRECISION'                  ,6   ,3 ,'DEC'  ,0),
                    ('REAL'                              ,7   ,3 ,'DEC'  ,0),
                    ('DECFLOAT'                          ,-360,3 ,'DEC'  ,0),
                    ('CHARACTER'                         ,1   ,1 ,'CHAR' ,0),
                    ('CHARACTER VARYING'                 ,12  ,12,'CHAR' ,1),
                    ('CHARACTER LARGE OBJECT'            ,14  ,12,'CHAR' ,1), 
                    ('GRAPHIC'                           ,95  ,1 ,'CHAR' ,0), 
                    ('GRAPHIC VARYING'                   ,96  ,12,'CHAR' ,1), 
                    ('DOUBLE-BYTE CHARACTER LARGE OBJECT',96  ,12,'CHAR' ,1), 
                    ('BINARY'                            ,452 ,1 ,'CHAR' ,0), 
                    ('BINARY VARYING'                    ,448 ,12,'CHAR' ,1), 
                    ('BINARY LARGE OBJECT'               ,-2  ,12,'CHAR' ,1), 
                    ('DATE'                              ,91  ,91,'DATE' ,0),
                    ('TIME'                              ,92  ,92,'TIME' ,0),
                    ('TIMESTAMP'                         ,93  ,1 ,'CHAR' ,0),
                    ('DATALINK'                          ,16  ,1 ,'CHAR' ,0),
                    ('ROWID'                             ,496 ,0 ,'????' ,0),
                    ('XML'                               ,-370,12,'CHAR' ,1), 
                    ('DISTINCT'                          ,448 ,0 ,'????' ,0),
                    ('ARRAY'                             ,448 ,0 ,'????' ,0)
                )
             
            Select 
                row_number() over() row_no,
                c.* ,                    
                sql_parm_type,
                cast( cl_parm_type as varchar(64)) cl_parm_type,
                sql_data_type,
                cl_data_type,
                is_varying
            from sysparms c 
            left join parm_data_type_map on c.data_type = parm_data_type_map.sql_parm_type
            where c.specific_schema = a.specific_schema
            and   c.specific_name   = a.specific_name
            order by case when c.default is null then ordinal_position else ordinal_position + 1000 end

            do
                set parm_declarartion = '';
                set required = case when c.default is null then 'MIN(1) ' else '' end;    
                                
                if cl_parm_type = '????' then 
                    set msg = 'Datatype ' concat sql_parm_type concat 'is not supported';
                    signal  sqlstate 'NLI02' set message_text  = msg;
                end if; 

                if  numeric_precision is not null and numeric_precision > 15 then
                    set numeric_precision = 15;
                end if;

                set numeric_scale = ifnull(numeric_scale , 0);

                if substr( cl_parm_type , 1, 3) = 'INT'  then
                    set sql_len = numeric_precision concat ';' concat numeric_scale;
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
                        if locate('VARY(*YES)' , parm_declarartion) <= 0 then   
                            set parm_declarartion = parm_declarartion concat ' VARY(*YES) ';
                        end if;    
                        if parameter_name is null then
                            set out_parm_counter = out_parm_counter + 1;
                            set parameter_name = 'RTNVAR' concat out_parm_counter;
                        end if; 

                end case; 
                
                -- Still null ( then IBM i build-in )                        
                set parameter_name = ifnull(parameter_name , 'PARM' concat row_no);
                
                -- First: Put the meta data
                set stmt = 'PARM KWD(META' concat row_no concat ') '  concat required concat 
                    ' TYPE(*CHAR) LEN(30) CONSTANT(''' concat
                    cl_data_type concat ';' concat 
                    sql_data_type concat ';' concat 
                    sql_len concat ';'  concat 
                    is_varying concat ';' concat 
                    rtrim(parameter_mode) concat ';' concat
                    ''')' ;

                insert into qtemp.xxtempsrc (srcdta) values(ifnull(stmt, '???')); 

                -- Second: Put the parameter name 
                set stmt = 'PARM KWD(NAME' concat row_no concat ') '  concat required concat
                    ' TYPE(*CHAR) LEN(30) CONSTANT(''' concat
                    rtrim(parameter_name) concat ';'  concat
                    ''')' ;

                insert into qtemp.xxtempsrc (srcdta) values(ifnull(stmt, '???')); 

                -- Human readable version of the paramter name
                if long_comment is not null then
                    set parm_text = rtrim(long_comment);
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

                -- Second: Put the parameter 
                set stmt = 'PARM KWD(' concat rtrim(substr(parameter_name, 1 , 10)) concat ') '  concat
                    parm_declarartion  concat
                    'PROMPT(''' concat parm_text concat ''') ' concat
                    'PASSATR(*YES) ' concat 
                    'CHOICE(''' concat choice_text concat ''') ';
                insert into qtemp.xxtempsrc (srcdta) values(ifnull(stmt, '???')); 
                
         end for;            
        end; 
    end for;
    
    if  title is null then
        set msg = 
            'Routine ' concat rtrim(create_CL_command.routine_name) concat 
            ' In schema ' concat rtrim(create_CL_command.routine_schema) concat 
            ' of type ' concat rtrim(create_CL_command.routine_type) concat ' does not exists'; 
        signal  sqlstate 'NLI02' set message_text  = msg;
    else
        call joblog(allow_mode);
        call qcmdexc ( 'crtcmd CMD(' concat 
            rtrim(library_name) concat '/' concat 
            rtrim(command_name) concat ')' concat 
           ' PGM(CMD4SQL/CMD4SQL) MODE(*ALL) ALLOW(' concat allow_mode concat 
           ') SRCFILE(qtemp/xxtempsrc) REPLACE(*yes) SRCMBR(xxtempsrc) text(''' concat 
           title concat ''')');
    end if;                                  
            
end;

-- test case
call cmd4sql.create_CL_command ( 
    command_name => 'EXCHRATE',
    library_name => 'CMD4SQL',
    routine_type => 'FUNCTION',
    routine_name => 'EXCHANGE_RATE',
    routine_schema => 'CMD4SQL'
);

-- Generated source:
select * from qtemp.xxtempsrc;
cl: CMD4SQL/EXCHRATE;

select row_number() over() id, a.* from sysparms a;