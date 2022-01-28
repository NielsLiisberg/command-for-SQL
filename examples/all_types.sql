-- The add procedure:
---------------------
drop procedure cmd4sql.add;
create or replace procedure cmd4sql.add (
    in  a dec(5, 2),
    in  b dec(5, 2)  ,
    out c dec( 5, 2)
) 
begin 
    set c = a + b ;
end;
call cmd4sql.add (a=>123, b=>456 , c=>?); 
   

call cmd4sql.create_CL_command (
-- Input function 
    routine_type => 'PROCEDURE',
    routine_name => 'ADD',
    routine_schema => 'CMD4SQL',
-- Output command to generate    
    command_name => 'ADD',
    library_name => 'CMD4SQL'
);

select * from xxtempsrc;

-- The inc procedure:
---------------------
create or replace procedure cmd4sql.inc (
    inout a decimal ( 5 , 2)
)
set option output=*print, commit=*none, dbgview = *list 
begin 
    set a = a + 1;
end;

call cmd4sql.create_CL_command (
-- Input function 
    routine_type => 'PROCEDURE',
    routine_name => 'INC',
    routine_schema => 'CMD4SQL',
-- Output command to generate    
    command_name => 'INC',
    library_name => 'CMD4SQL'
);

drop procedure cmd4sql.inc;         
create or replace procedure cmd4sql.inc (
    inout a varchar (256)
)
set option output=*print, commit=*none, dbgview = *list 
begin 
    set a = a concat a;
end;

call inc ('s');

create or replace procedure cmd4sql.inc (
    inout a varchar (256)
)
set option output=*print, commit=*none, dbgview = *list 
begin 
    set a = a concat a;
end;

--------------------
drop procedure cmd4sql.inc;
create or replace procedure cmd4sql.inc (
    inout a int
) 
begin 
    set a = a + 1;
end;



create or replace procedure cmd4sql.alltypes  (
    in ismallint smallint default null,
    in iinteger integer default null,
    in ibigint bigint default null,
    in idecimal decimal (30, 10) default null,
    in inumeric numeric (30, 10) default null,
    in ifloat float default null,
    in ireal real default null,
    in idouble double default null,
    in idecfloat decfloat default null,
    in ichar char (256) default null,
    in ivarchar varchar (256) default null,
    in iclob clob default null,
    in igraphic graphic (256) default null,
    in ivargraphic vargraphic (256) default null,
    in idbclob dbclob  default null,
    in inclob nclob default null,
    in ibinary binary (256) default null,
    in ivarbinary varbinary (256) default null,
    in iblob blob default null,
    in idate date default null,
    in itime time default null,
    in itimestamp timestamp default null, 
    out osmallint smallint,
    out ointeger integer ,
    out obigint bigint ,
    out odecimal decimal (30, 10) ,
    out onumeric numeric (30, 10) ,
    out ofloat float ,
    out oreal real ,
    out odouble double ,
    out odecfloat decfloat,
    out ochar char (256) ,
    out ovarchar varchar (256) ,
    out oclob clob ,
    out ographic graphic (256) ,
    out ovargraphic vargraphic (256) ,
    out odbclob dbclob  ,
    out onclob nclob ,
    out obinary binary (256) ,
    out ovarbinary varbinary (256) ,
    out oblob blob ,
    out odate date ,
    out otime time ,
    out otimestamp timestamp , 
    
    inout iosmallint smallint default null,
    inout iointeger integer default null,
    inout iobigint bigint default null,
    inout iodecimal decimal (30, 10) default null,
    inout ionumeric numeric (30, 10) default null,
    inout iofloat float default null,
    inout ioreal real default null,
    inout iodouble double default null,
    inout iodecfloat decfloat  default null,
    inout iochar char (256) default null,
    inout iovarchar varchar (256) default null,
    inout ioclob clob default null,
    inout iographic graphic (256) default null,
    inout iovargraphic vargraphic (256) default null,
    inout iodbclob dbclob  default null,
    inout ionclob nclob default null,
    inout iobinary binary (256) default null,
    inout iovarbinary varbinary (256) default null,
    inout ioblob blob default null,
    inout iodate date default null,
    inout iotime time default null,
    inout iotimestamp timestamp default null
)
set option output=*print, commit=*none, dbgview = *list 
begin 

    set ismallint = ismallint;
    set iinteger = ismallint;
    set ibigint = ismallint;
    set idecimal  = ismallint;
    set inumeric  = ismallint;
    set ifloat = ismallint;
    set ireal = ismallint;
    set idouble = ismallint;
    set idecfloat = ismallint;
    set ichar = ismallint;
    set ivarchar = ismallint;
    set iclob = ismallint;
    set igraphic = ismallint;
    set ivargraphic = ismallint;
    set idbclob = ismallint;
    set inclob = ismallint;
    set ibinary = x'f1';
    set ivarbinary = x'f1';
    set iblob = x'f1';
    set idate = now();
    set itime = now();
    set itimestamp = now();
    set osmallint = ismallint;
    set ointeger = ismallint;
    set obigint = ismallint;
    set odecimal  = ismallint;
    set onumeric  = ismallint;
    set ofloat = ismallint;
    set oreal = ismallint;
    set odouble = ismallint;
    set odecfloat= ismallint;
    set ochar = ismallint;
    set ovarchar = ismallint;
    set oclob = ismallint;
    set ographic = ismallint;
    set ovargraphic = ismallint;
    set odbclob = ismallint;
    set onclob = ismallint;
    set obinary = x'f1';
    set ovarbinary = x'f1';
    set oblob = x'f1';
    set odate = now();
    set otime = now();
    set otimestamp = now();
    set iosmallint = ismallint;
    set iointeger = ismallint;
    set iobigint = ismallint;
    set iodecimal  = ismallint;
    set ionumeric  = ismallint;
    set iofloat = ismallint;
    set ioreal = ismallint;
    set iodouble = ismallint;
    set iodecfloat = ismallint;
    set iochar  = ismallint;
    set iovarchar = ismallint;
    set ioclob = ismallint;
    set iographic = ismallint;
    set iovargraphic = ismallint;
    set iodbclob = ismallint;
    set ionclob = ismallint;
    set iobinary = x'f1';
    set iovarbinary = x'f1';
    set ioblob = x'f1';
    set iodate = now();
    set iotime = now();
    set iotimestamp = now();
 end;
         
call  cmd4sql.alltypes  (
     ismallint => 123
); 

drop procedure cmd4sql.common_types;
create or replace procedure cmd4sql.common_types  (
    in ismallint smallint default null,
    in iinteger integer default null,
    in ibigint bigint default null,
    in idecimal decimal (30, 10) default null,
    in inumeric numeric (30, 10) default null,
    in ifloat float default null,
    in ireal real default null,
    in idouble double default null,
    in ichar char (256) default null,
    in ivarchar varchar (256) default null,
    in idate date default null,
    in itime time default null,
    in itimestamp timestamp default null, 
    out osmallint smallint,
    out ointeger integer ,
    out obigint bigint ,
    out odecimal decimal (30, 10) ,
    out onumeric numeric (30, 10) ,
    out ofloat float ,
    out oreal real ,
    out odouble double ,
    out ochar char (256) ,
    out ovarchar varchar (256) ,
    out odate date ,
    out otime time ,
    out otimestamp timestamp , 
    inout iosmallint smallint default null,
    inout iointeger integer default null,
    inout iobigint bigint default null,
    inout iodecimal decimal (30, 10) default null,
    inout ionumeric numeric (30, 10) default null,
    inout iofloat float default null,
    inout ioreal real default null,
    inout iodouble double default null,
    inout iochar char (256) default null,
    inout iovarchar varchar (256) default null,
    inout iodate date default null,
    inout iotime time default null,
    inout iotimestamp timestamp default null
)
set option output=*print, commit=*none, dbgview = *list 
begin 

    set iinteger = ismallint;
    set ibigint = ismallint;
    set idecimal  = ismallint;
    set inumeric  = ismallint;
    set ifloat = ismallint;
    set ireal = ismallint;
    set idouble = ismallint;
    set ichar = ismallint;
    set ivarchar = ismallint;
    set idate = now();
    set itime = now();
    set itimestamp = now();
    set osmallint = ismallint;
    set ointeger = ismallint;
    set obigint = ismallint;
    set odecimal  = ismallint;
    set onumeric  = ismallint;
    set ofloat = ismallint;
    set oreal = ismallint;
    set odouble = ismallint;
    set ochar = ismallint;
    set ovarchar = ismallint;
    set odate = now();
    set otime = now();
    set otimestamp = now();
    set iosmallint = ismallint;
    set iointeger = ismallint;
    set iobigint = ismallint;
    set iodecimal  = ismallint;
    set ionumeric  = ismallint;
    set iofloat = ismallint;
    set ioreal = ismallint;
    set iodouble = ismallint;
    set iochar  = ismallint;
    set iovarchar = ismallint;
    set iodate = now();
    set iotime = now();
    set iotimestamp = now();
    
end;
         
call  cmd4sql.common_types  (
     ismallint => 123,
    osmallint =>?,
    ointeger =>?,
    obigint =>?,
    odecimal  =>?,
    onumeric  =>?,
    ofloat =>?,
    oreal =>?,
    odouble =>?,
    ochar =>?,
    ovarchar =>?,
    odate =>?,
    otime =>?,
    otimestamp =>?);

) ;



drop procedure cmd4sql.common_types;
create or replace procedure cmd4sql.common_types  (
    in ismallint smallint default null,
    in iclob clob default null,
    out oclob clob,
    inout ioclob clob default null
)
begin 
    set iclob =  ismallint;
    set oclob =  ismallint;
    set ioclob =  ismallint;
end; 



drop specific procedure ADD0000ismallint;




select * from sysprocs
where routine_name like upper('%common%');

drop specific procedure  COMMO0000ismallint;
COMMO00001

create or replace procedure cmd4sql.common_types  (
    inout iochar char (256) default null
)
set option output=*print, commit=*none, dbgview = *list 
begin 

    set iochar  = ismallint;
    
end;    
cl:cd '/prj/noxdb'; 
cl:CRTCMOD MODULE(NOXDB/utl100) SRCSTMF('src/ext/utl100.c') OPTIMIZE(10) ENUM(*INT) TERASPACE(*YES) STGMDL(*INHERIT) SYSIFCOPT(*IFSIO) INCDIR('/QIBM/include' 'headers/' 'headers/ext/') DBGVIEW(*ALL) TGTCCSID(*JOB) TGTRLS(V7R1M0);



with cte as ( select a.specific_name specific_name,parameter_mode,parameter_name,data_type,numeric_scale,numeric_precision,character_maximum_length,numeric_precision_radix,datetime_precision,is_nullable,max(ifnull(numeric_precision , 0) + 2, ifnull(character_maximum_length,0))  buffer_length from sysprocs a left join  sysparms b on a.specific_schema = b.specific_schema and a.specific_name = b.specific_name where a.routine_schema  = upper(?) and   a.routine_name = upper(?) ) select 1 as id, (select count(distinct cte.specific_name) from cte) number_of_implementations  , cte.* from cte ;




create or replace procedure cmd4sql.echo  (
    in  text varchar(256),
    out response varchar(256)
) 
begin 
    set response = text concat text ;
end;

call echo (text=>'Hello' , response => ?);         

	