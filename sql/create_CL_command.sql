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
    declare stmt            varchar(256);
    declare msg             varchar(256);
    declare title           varchar(50);
    declare parm_text       varchar(50);
    declare parm_options    varchar(256);
    declare sql_len         varchar(32);
    declare allow_mode      varchar(32);
    declare out_parm_counter int default 0;
    declare dummy            int;

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
        set stmt = 'PARM KWD(ROUTINE) TYPE(*CHAR) LEN(30) CONSTANT(''' concat 
            substr(create_CL_command.routine_type , 1 , 1) concat ';' concat 
            rtrim(create_CL_command.routine_schema) concat ';' concat 
            rtrim(create_CL_command.routine_name) concat ';' concat
            ''')';
        insert into qtemp.xxtempsrc (srcdta) values(stmt);

        -- placeholder for option TODO
        set stmt = 'PARM KWD(OPTIONS) TYPE(*CHAR) LEN(30) CONSTANT('' '')';
        insert into qtemp.xxtempsrc (srcdta) values(stmt);
                                      
        for c as
            with parm_data_types (
                    sql_parm_type,
                    cl_parm_type,
                    sql_data_type,
                    cl_data_type
                ) 
                as ( values  
                    ('BIGINT'                , 'TYPE(*DEC)'     , 19 ,  3) , 
                    ('INTEGER'               , 'TYPE(*INT4)'    , 4 , 4) ,
                    ('SMALLINT'              , 'TYPE(*INT2)'    , 5 , 5) ,
                    ('DECIMAL'               , 'TYPE(*DEC)'     , 3 , 3) ,
                    ('NUMERIC'               , 'TYPE(*DEC)'     , 2 , 3) ,
                    ('DOUBLE PRECISION'      , 'TYPE(*DEC)'     , 6 , 3) ,
                    ('REAL'                  , 'TYPE(*DEC)'     , 7 , 3) ,
                    ('DECFLOAT'              , 'TYPE(*DEC)'     , -360 , 3) ,
                    ('CHARACTER'             , 'TYPE(*CHAR)'    , 1 , 1) ,
                    ('CHARACTER VARYING'     , 'TYPE(*CHAR) VARY(*YES *INT2)', 12 , 12) ,
                    ('CHARACTER LARGE OBJECT', 'TYPE(*CHAR) VARY(*YES *INT2)', 14 , 12) , 
                    ('GRAPHIC'               , 'TYPE(*CHAR)'    , 95 , 1) , 
                    ('GRAPHIC VARYING'       , 'TYPE(*CHAR) VARY(*YES *INT2)', 96 , 12) , 
                    ('DOUBLE-BYTE CHARACTER LARGE OBJECT' ,'TYPE(*CHAR) VARY(*YES *INT2)', 96 , 12) , 
                    ('BINARY'                , 'TYPE(*CHAR)'    , 452 , 1) , 
                    ('BINARY VARYING'        , 'TYPE(*CHAR) VARY(*YES *INT2)', 448 , 12) , 
                    ('BINARY LARGE OBJECT'   , 'TYPE(*CHAR) VARY(*YES *INT2)', -2 , 12) , 
                    ('DATE'                  , 'TYPE(*DATE)'    , 91 , 91) ,
                    ('TIME'                  , 'TYPE(*TIME)'    , 92 , 92) ,
                    ('TIMESTAMP'             , 'TYPE(*CHAR)'    , 93 , 1) ,
                    ('DATALINK'              , 'TYPE(*CHAR)'    , 16 , 1) ,
                    ('ROWID'                 , '*UNSUPPORTED'   , 496 , 0) ,
                    ('XML'                   , 'TYPE(*CHAR) VARY(*YES *INT2)', -370 , 12) , 
                    ('DISTINCT'              , '*UNSUPPORTED'   , 448 , 0) ,
                    ('ARRAY'                 , '*UNSUPPORTED'   , 448 , 0)
                )
             
            Select 
                c.* ,                    
                sql_parm_type,
                cast( cl_parm_type as varchar(64)) cl_parm_type,
                sql_data_type,
                cl_data_type
            from sysparms c 
            left join parm_data_types on c.data_type = parm_data_types.sql_parm_type
            where c.specific_schema = a.specific_schema
            and   c.specific_name   = a.specific_name
            order by ordinal_position
            do
                set parm_options = '';
                set allow_mode = '*ALL';
                
                    
                if cl_parm_type = '*UNSUPPORTED' then 
                    set msg = 'Datatype ' concat sql_parm_type concat 'is not supported';
                    signal  sqlstate 'NLI02' set message_text  = msg;
                end if; 

                if numeric_scale is not null then
                    set parm_options = parm_options concat ' LEN(' concat numeric_precision concat ' ' concat numeric_scale concat ') ';
                    set sql_len = numeric_precision concat ';' concat numeric_scale;
                elseif numeric_precision is not null then
                    set parm_options = parm_options concat ' LEN(' concat numeric_precision concat ') ';
                    set sql_len = numeric_precision concat ';0' ;
                else   
                    set parm_options = parm_options concat ' LEN(' concat character_maximum_length concat ') ';
                    set sql_len = character_maximum_length concat ';0';
                end if; 
                
              
                case parameter_mode  

                    when 'IN' then 
                        set parm_options = parm_options concat  ' EXPR(*YES) ';
                        if  c.default is null then 
                            set parm_options = parm_options concat  ' MIN(1) ';
                        end if;

                    when 'OUT' or 'INOUT' then 
                        set allow_mode = '*BPGM *IPGM';
                        set parm_options = parm_options concat ' RTNVAL(*YES) ';
                        -- return values must always have varying
                        if locate('VARY(*YES)' , parm_options) <= 0 then   
                            set parm_options = parm_options concat ' VARY(*YES) ';
                        end if;    
                        if parameter_name is null then
                            set out_parm_counter = out_parm_counter + 1;
                            set parameter_name = 'RTNVAR' concat out_parm_counter;
                        end if; 

                    --when 'INOUT' then 
                    --    signal  sqlstate 'NLI02' set message_text  = 'INOUT parameters is not suported';
                end case; 
                
                -- Still null ( IBM i build-in )                        
                set parameter_name = ifnull(parameter_name , 'PARM' concat ordinal_position);

                -- First: Put the meta data
                set stmt = 'PARM KWD(META' concat ordinal_position concat ') '  concat
                    ' TYPE(*CHAR) LEN(30) CONSTANT(''' concat
                    rtrim(parameter_name) concat ';' concat 
                    cl_data_type concat ';' concat 
                    sql_data_type concat ';' concat 
                    sql_len concat ';'  concat  
                    rtrim(parameter_mode) concat ';' concat
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

                -- Second: Pput the meta data
                set stmt = 'PARM KWD(' concat rtrim(substr(parameter_name, 1 , 10)) concat ') '  concat
                    ' ' concat cl_parm_type concat parm_options  concat
                    ' PROMPT(''' concat parm_text concat ''') ' concat
                    ' PASSATR(*YES)';
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
        call qcmdexc ( 'crtcmd CMD(' concat   rtrim(library_name) concat '/' concat rtrim(command_name) concat ')' concat 
        ' PGM(CMD4SQL/CMD4SQL) MODE(*ALL) ALLOW(' concat allow_mode concat') SRCFILE(qtemp/xxtempsrc) REPLACE(*yes) SRCMBR(xxtempsrc) text(''' concat title concat ''')');
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
-- select * from qtemp.xxtempsrc;

