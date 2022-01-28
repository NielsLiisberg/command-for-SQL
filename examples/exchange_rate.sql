create or replace function cmd4sql.exchange_rate (
    currency_code char(3) 
) 
returns
  dec(15,5)
begin 

    return (  
        Select rate from  
        xmltable ('$doc/exchangerates/dailyrates/currency' 
            passing xmlparse(
                document
                    systools.httpgetblob(
                		'https://www.nationalbanken.dk/_vti_bin/DN/DataService.svc/CurrencyRatesXML?lang=en'
                		, null
                	)
                ) as "doc"
            columns
                date  date path '../@id',  
                code  char(3) path '@code',
                desc  varchar(64) path '@desc',
                rate  dec(15 , 5) path '@rate'
        )
        where code = currency_code
    );
end;

values (
    cmd4sql.exchange_rate ('USD')
);

call cmd4sql.create_CL_command (
-- Input function 
    routine_type => 'FUNCTION',
    routine_name => 'EXCHANGE_RATE',
    routine_schema => 'NLI',
-- Output command    
    command_name => 'GETEXCRTE',
    library_name => 'NLI'
);