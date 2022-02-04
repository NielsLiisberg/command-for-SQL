/* SYSIFCOPT(*IFSIO) TERASPACE(*YES *TSIFC) STGMDL(*SNGLVL)      */
/* COMPILEOPT('OUTPUT(*PRINT) OPTION(*EXPMAC *SHOWINC)')         */
/* Program . . . : RUNSQLFUNC                                    */
/* Design  . . . : Niels Liisberg                                */
/* Copyright . . : System & Metod A/S 2022 (C)                   */
/* Function  . . : Command to SQL interface ideas                */
/*                                                               */
/* By     Date       PTF     Description                         */
/* NL     12.01.2022 0000000 New program                         */
/* ------------------------------------------------------------- */
#include <unistd.h>
#include <wchar.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <decimal.h>
#include <stdarg.h>
#include <ctype.h>
#include "ostypes.h"
#include "sqlcli.h"


typedef struct _PARMS {
   SQLSMALLINT parmNo;
   UCHAR       name[32] ;
   SQLSMALLINT clType;
   SQLSMALLINT sqlType;
   SQLINTEGER  len;
   SQLSMALLINT dec;
   BOOL        isVarying;
   SQLSMALLINT usage;
   UCHAR       attr;
   SQLPOINTER  data;
   SQLINTEGER  bufLenIn;
   SQLINTEGER  bufLenOut;
} PARMS , *PPARMS;

// -------------------------------------------------------------
//  Prototypes
// -------------------------------------------------------------
PUCHAR  slurp  (PUCHAR out  , PUCHAR * buf);
int  parseMeta  (int argc, char ** argv, PUCHAR sqlStmt, PPARMS pParms );
void buildSQLstatement (int argc, char ** argv, PUCHAR sqlStmt , int parmNum , PPARMS pParms );
SQLRETURN run (int argc, char ** argv, PUCHAR sqlStmt ,int parmNum , PPARMS pParms );
SQLRETURN cleanUp(int orgrc);
void checkError (SQLHENV henv, SQLHDBC hdbc,SQLHSTMT hstmt,SQLRETURN rc);
