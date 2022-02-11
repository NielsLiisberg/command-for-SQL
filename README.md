# command-for-SQL on IBM i 
CL Commands for SQL procedures and functions

If you as I, are taking stored procedures and user defined table function (UDTF) 
seriously, then this project is aimed for you. You have probably noticed 
that integration between SQL and CL has its limitations.

If you for instance need to submit a stored procedure, then you will
probably use RUNSQL and use string concatenation to set up 
the “call procedure (..) “ and get the parameters right. 
However, that might be quite a challenge to construct a string 
containing all the parameters correctly.

Also if you need to return values from your scalar function, 
then you probably need to write a program that do nothing much - 
except for passing the parameters correctly.

To mitigate these challenges and get rid of the boilerplate 
code, this project might come in handy.

This project is about creating CL command for stored 
procedures and functions to bridge the gap between CL and SQL.

## What it does

After you create a procedure or a function of your own, 
then you can run the **CREATE_CL_COMMAND** procedure 
within this project, and it will produce a CL command that enables 
you to integrate the SQL functionality directly into a CL 
program or even place that command in a SBMJOB or perhaps 
run it directly from a command line. 

## How does it.

The **CREATE_CL_COMMAND** simply retrieves the meta information 
from your procedure or function and compiles this information 
directly into a CL command of your choice. So the command 
generated is all you need !!

When you run your created command it will simply pass 
the meta information along with the CL variables values 
and let it be handled by at generic program that finally 
executes your SQL procedure or function. Easy as that.

## Into action
Let’s play with an example ( it assumes you have done the installation described later) 

Fire up your ACS and open "Run SQL scripts" and past the following ( or open the divide.sql from the examples):


```
-- A simple divide procedure:
-----------------------------
create or replace procedure cmd4sql.divide (
    in  dividend  dec(5, 2),
    in  divisor dec(5, 2)  ,
    out res dec( 5, 2)
) 
begin 
    set res = dividend / divisor ;
end;

-- Try it out
call cmd4sql.divide (dividend =>123, divisor=> 10 , res=>?); 
   
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

-- Now it is ready to be integrated into a CL program
-- prompt the created command - press F4 on the next line:
cl:CMD4SQL/DIVIDE dividend(123) DIVISOR(10) RES(0);

--------------------------------------------------------------------------
-- Functions are also supported 
-------------------------------
create or replace function cmd4sql.divide (
    dividend  dec(5, 2),
    divisor dec(5, 2)  
)
returns dec ( 5, 2) 
begin 
    return dividend/ divisor ;
end;

-- Try it out
values ( 
    cmd4sql.divide (dividend =>123, divisor=>10)
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

-- Now it is ready to be integrated into a CL program
-- prompt the created command - press F4 on the next line:
cl:CMD4SQL/DIVFUNC dividend(123) DIVISOR(10) RTNVAR1(0);

-- note return values don't have a name, so RTNVAR1 is given by default  

```

## The CL code using it

Open your CL editor of choice, create a new CLLE member DIVIDE and past and compile from the following code: 

```
PGM                                                                  
    DCL        VAR(&DIVISOR)  TYPE(*DEC)  LEN(5 2) VALUE(123)      
    DCL        VAR(&DIVIDEND) TYPE(*DEC)  LEN(5 2) VALUE(2.34)      
    DCL        VAR(&RESULT)   TYPE(*DEC)  LEN(5 2) VALUE(0)      
    DCL        VAR(&TEXT)     TYPE(*CHAR) LEN(6)                
                                                            
    /* Do the magic - Call the procedure "divide" */                
    CMD4SQL/DIVIDE  DIVISOR(&DIVISOR) DIVIDEND(&DIVIDEND) RES(&RESULT)                           

    /* Show the result */                                                        
    CHGVAR     VAR(&TEXT) VALUE(&RESULT)                         
    SNDPGMMSG  MSG('Divide by procedure: ' *BCAT &TEXT)                      
                                                            
    /* Do the magic - Call the function "divide" */                
    CMD4SQL/DIVFUNC  DIVISOR(&DIVISOR) DIVIDEND(&DIVIDEND) RTNVAR1(&RESULT)                           
                                                                     
    /* Show the result */                                                        
    CHGVAR     VAR(&TEXT) VALUE(&RESULT)                         
    SNDPGMMSG  MSG('Divide by function: ' *BCAT &TEXT)                      
                                                                     
ENDPGM                                                               

```

The above code showcases the power of this project: You can prompt the 
parameters and the only "thing" that carries the interface information
is the command it self.

## Catching the errors
If you try to modify you code so you by purpose divide by zero - then what 
happens? Well - the SQL traps the error and it will bubble up to your CL where you can 
use the standard MONMSG and detect the error and handle it gracefully as you 
normally would. 

## The interface
The **CREATE_CL_COMMAND** procedure is quite powerful. Let me explain it into 
details.

When you invoke **CREATE_CL_COMMAND** it will query the parameters for the given 
function or procedure you gives it. Now; CL and SQL does not share 
the complete same data types, however a runtime table is set for mapping 
the data types in your CL program and how they are declared in the function 
or procedure in SQL ( more precise in SQLCLI).

Then **CREATE_CL_COMMAND** produces a temporary source where each parameter
comes in pairs of three: 

### FIRST: ### 
The first command constant contains 
the real name of the parameter in your SQL function 
or procedure, since CL has the limitation of 10 chars for parameter names.
That gives us up to 30 as maximum for the parameter name.  

Note: (command constant is not visible when prompting).


### SECOND: ### 
A meta parameter - declaring a command constant ( that is not visible when prompting) 
Then the CL data type and and SQLCLI equivalent - Here we let SQL handle the
conversion of data types under the hood, where it is possible, 
but some like ROW_ID is not supported (yet).

### THIRD: ###
This is a normal parameter description as you will use it in any 
other command definition, shown when prompting. The parameter is 
defined with some extra keywords: 

Pass attribute byte: This gives the runtime CMD4SQL program the possibility 
to determine if the parameter is passed by the CL program or command line.

The RTNVAR is set for OUT and INOUT parameters to support that SQL can 
deliver data back to the calling CL program. 

### Besides parameters: ### 

Also the kind and name of function or procedure are stored, so it 
knows how and what to call.

After producing the temporary command source is compiles it 
with a standard CRTCMD command. The produced command will always run the 
program CMD4SQL in library CMD4SQL - that effectively means you don't 
the CMD4SQL in your library list when using the created commands. 

If a given parameter in SQL has a default value, then it
is set to be an *optional* in the command. The later CMD4SQL program  
figures out at runtime if the parameter is given or not and
let SQL deal with the default value. So no defaults is the command it self.

Please notice: That CL requires that **required** parameters 
have to be listed first, so the order of parameters is 
rearrange in ordinal position but with required parameters first.

Also notice that; if you have any OUT or INOUT or calling a scalar 
function, then your command will be compiled with the options to allow it to run 
only in *IPGM and *BPGM since CL has no idea how to return 
values if it is started from i.e. the command line.

Since CL commands have the limitation of max 100 parameters and we are 
using three parameters for each SQL parameter. Then the limit of parameters 
will be 32. 

### Parameter naming ###
Function and procedure parameters can have names up to 32 chars long. This is not supported 
in CL. Perhaps you also need to give the parameter a more descriptive prompt. 

To mitigate this you can add **comment on parameter** . You cat suffix the description 
with tha parameter name of your choice given in parenthesis. 

```
comment on parameter schema.procedure is 'Nice parameter description (PARMNAME)';
```

### the CMD4SQL program
I have used SQLCLI for this task. SQLCLI - *callable interface* 
allows you to *bind* any parameter types as pointers to a buffer, 
which makes it easy to simply *bind* to the parameter pointer that the 
command processor is handling you. 

So the CMD4SQL will simply slurp up the meta information 
given by command processor . Then CMD4SQL wil prepare 
either a *call* or a *values into* statement and then bind 
each parameter with a give parameter marker - and finally call you 
procedure of function with a **SQLexecute** ... simple as that.

## Installation

This project also contains a "release" folder where you will find a savefile. So 
simply transfer that your IFS and restore the library CMD4SQL, and you are up 
and running.

The simplest way: In the SQL directory you will find **install.sql** Simply
Paste that content into you *ACS Run SQL script* 

But you can also do that manually:

First download this to i.e. /tmp on your IFS:

https://github.com/NielsLiisberg/command-for-SQL/raw/main/release/release.savf

Then run this:

```
CRTLIB CMD4SQL 
CPYFRMSTMF FROMSTMF('/tmp/release.savf') TOMBR('/QSYS.lib/CMD4SQL.lib/RELEASE.FILE') MBROPT(*REPLACE) CVTDTA(*NONE)
RSTLIB SAVLIB(CMD4SQL) DEV(*SAVF) SAVF(CMD4SQL/RELEASE)
```


## Build from scratch
Please also be involved, and let's make this project even better together:

Clone this project into **/prj** on your IFS on your **IBM i** and 
run a **gmake all** and it will compile and build everything. 

## Final thoughts
What if your procedure was returning a open cursor? or what if you are 
using a UDTF that returns a table. Well I haven't figured that out yet - 
still room for improvements and lots of corners not tested yet. 
Nevertheless, what I have solved so far is already extremely useful for 
simple integration between SQL and CL, and perhaps IBM will 
take a look at this project and integrate it in IBM i releases to come. 

This project is made available under the Apache license for this particular reason.





 
