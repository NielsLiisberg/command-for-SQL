-- copy and paste the following into ACS, Run SQL script:
-- This will create and restore the library directly from the Git repos release folder. 
begin 
    declare savf blob;
    declare continue handler for sqlstate '38501' begin
    end;

    set savf = systools.httpgetblob ( 
        url => 'https://github.com/NielsLiisberg/command-for-SQL/raw/main/release/release.savf',
        httpheader => cast(null as clob(1k))
    );
    
    call qsys2.ifs_write_binary(
        path_name => '/tmp/release.savf',
        line => savf ,
        file_ccsid => 1252,
        overwrite => 'REPLACE'
    );
    
    call qcmdexc ('CRTLIB LIB(CMD4SQL) TYPE(*TEST) TEXT(''Commands for SQL procedures and functions'')'); 
    call qcmdexc ('CPYFRMSTMF FROMSTMF(''/tmp/release.savf'') TOMBR(''/QSYS.lib/CMD4SQL.lib/RELEASE.FILE'') MBROPT(*REPLACE) CVTDTA(*NONE)');
    call qcmdexc ('RSTLIB SAVLIB(CMD4SQL) DEV(*SAVF) SAVF(CMD4SQL/RELEASE)');

end;