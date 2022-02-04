-- A simple divide procedure:
-----------------------------
create or replace procedure cmd4sql.divide (
    in  dividend  dec(5, 2),
    in  divisor dec(5, 2)  ,
    out res dec( 5, 2)
) 
set option dbgview = *source , output=*print, commit=*NONE                                                                          
begin 
    set res = dividend / divisor ;
end;

-- Try it out
call cmd4sql.divide (dividend=>123, divisor=> 10 , res=>?); 
   
-- Building the command for you procedure:
call cmd4sql.create_CL_command (
-- Input function 
    routine_type => 'PROCEDURE',
    routine_name => 'DIVIDE',
    routine_schema => 'CMD4SQL',
-- Output command to generate    
    command_name => 'DIVIDE',
    library_name => 'CMD4SQL'
);

-- This is the command source; 
-- only for your info; 
-- never save it or compile it - it is auto created    
select * from qtemp.xxtempsrc;

-- Now it is ready to be integraed into a CL program
-- prompt the created command - press F4 on the next line:
cl:CMD4SQL/DIVIDE DIVIDEND(123) DIVISOR(10) RES(0);

--------------------------------------------------------------------------
-- Functions is also supported 
------------------------------
create or replace function cmd4sql.divide (
    dividend  dec(5, 2),
    divisor dec(5, 2)  
)
returns dec ( 5, 2) 
set option dbgview = *source , output=*print, commit=*NONE                                                                          

begin 
    return dividend/ divisor ;
end;

-- Try it out
values ( 
    cmd4sql.divide (dividend=>123, divisor=>10)
);
   
-- Build the command for you scalar function
call cmd4sql.create_CL_command (
-- Input function 
    routine_type => 'FUNCTION',
    routine_name => 'DIVIDE',
    routine_schema => 'CMD4SQL',
-- Output command to generate    
    command_name => 'DIVFUNC',
    library_name => 'CMD4SQL'
);

-- Now it is ready to be integraed into a CL program
-- prompt the created command - press F4 on the next line:
cl:CMD4SQL/DIVFUNC DIVIDEND(123) DIVISOR(10) RTNVAR1(0);

-- note return values dont have a name, so RTNVAR1 is given by default  

-- Look in "divide.clle" how to use it


