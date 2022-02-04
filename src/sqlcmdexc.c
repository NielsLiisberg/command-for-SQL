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
#include "sqlcli.h"
#include "ostypes.h"
#include "sndpgmmsg.h"
#include "sqlcmdexc.h"


SQLHENV       henv = -1;
SQLHDBC       hdbc = 0;
SQLHSTMT      hstmt = 0 ;

// -------------------------------------------------------------
int main(int argc, char ** argv) {

   SQLRETURN rc;
   SQLCHAR   sqlStmt[32768];
   PARMS     parms [256];
   int       parmNum;

   parmNum = parseMeta  (argc, argv,  sqlStmt, parms );

   // Getparameter from XML definition
   buildSQLstatement (argc, argv, sqlStmt ,parmNum ,parms);

   rc = run(argc, argv , sqlStmt , parmNum , parms);

   if (rc != SQL_SUCCESS ) {
      sndpgmmsg ( "CPF9898", QCPFMSG , ESCAPE , 3,  "CMD4SQL Failed: %s. See previous messages", argv[0]);
   }
}
// -------------------------------------------------------------
PUCHAR  slurp  (PUCHAR out  , PUCHAR * buf)                  {
   PUCHAR ret  = out;
   PUCHAR p = *buf;
   while (*p && *p != ';'      ) {
      *(out ++) = *(p ++);
   }
   *out = '\0';
   *buf = p + 1; // After the delimiter
   return ret;
}
// -------------------------------------------------------------
int  parseMeta  (int argc, char ** argv, PUCHAR sqlStmt, PPARMS pParms )
{
   int i;
   int parmNum =0;
   // Parameter and data comes in pairs from parameter 3 and to the end
   for (i=3 ; i < argc ; i += 3) {
      PUCHAR pMeta  = argv[i];
      PUCHAR pName  = argv[i+1];
      PUCHAR pValue = argv[i+2];
      UCHAR  temp [32];
      PUCHAR pTemp = temp;
      PPARMS pParm;

      // When parameter is not give, the omit is both in SQL statement AND bind parameter;
      if (pValue == NULL )         continue; // RTVVAR is not given ( pointer to null-buffer)
      if (((*pValue) & 0x40) != 0) continue; // Not passed  (the attribute byte) 

      pParm = &pParms [parmNum++];
      
      pParm->parmNo = parmNum; // stored so number will match id CL parm is not passed
      slurp   (pParm->name     ,  &pName);
      pParm->clType    = atoi(slurp   (temp, &pMeta));
      pParm->sqlType   = atoi(slurp   (temp, &pMeta));
      pParm->len       = atoi(slurp   (temp, &pMeta));
      pParm->dec       = atoi(slurp   (temp, &pMeta));
      pParm->isVarying = atoi(slurp   (temp, &pMeta));
      
      slurp   (temp ,  &pMeta);
      if      (strcmp (temp, "IN") == 0)  pParm->usage = SQL_PARAM_INPUT;
      else if (strcmp (temp, "OUT") == 0) pParm->usage = SQL_PARAM_OUTPUT;
      else                                pParm->usage = SQL_PARAM_INPUT_OUTPUT;

      pParm->attr = *pValue;
      pParm->data = pValue +1;

      // Return values always passes the len in commands
      if (pParm->usage == SQL_PARAM_OUTPUT
      || pParm->usage  == SQL_PARAM_INPUT_OUTPUT) {
         // All data not having "VARRYING" - we insert space for the varying length
         if  (! pParm->isVarying)  {
            pParm->data = pValue +3;
         }
         // Decimal have precision and size on VARRYING parameter
         // Yes - but you can not use it from a CL program :(
         // if (pParm->sqlType == SQL_DECIMAL) {
         //    pParm->dec     = pValue[1];
         //    pParm->len     = pValue[2];
         // }
      }

      if  (pParm->sqlType == SQL_DECIMAL) {
         pParm->bufLenOut = pParm->bufLenIn = (pParm->len / 2) +1;
      } else {
         pParm->bufLenOut = pParm->bufLenIn =pParm->len; // TODO !!
      }

   }
   return parmNum;
}


// -------------------------------------------------------------
void buildSQLstatement (int argc, char ** argv, PUCHAR sqlStmt , int parmNum , PPARMS pParms )
{
   int i;
   PUCHAR pMeta = argv[1];
   UCHAR  version     [5];
   UCHAR  routineType [32];
   UCHAR  schemaName  [32];
   UCHAR  routineName [32];
   PUCHAR pSqlStmt = sqlStmt; // To traverse it
   PUCHAR comma;


   // first the how and what to call (procedure / function call)
   slurp (version         ,  &pMeta );
   slurp (routineType     ,  &pMeta );
   slurp (schemaName      ,  &pMeta );
   slurp (routineName     ,  &pMeta );

   switch (*routineType) {
      
      // UDTF - Function 
      case 'F': {
         pSqlStmt += sprintf (pSqlStmt,"values  %s.%s (",
            schemaName,
            routineName
         );

         comma = "";
         for (i=0 ; i < parmNum ;  i++) {
            PPARMS pParm = &pParms [i];
            if (pParm->usage == SQL_PARAM_INPUT ) {
               pSqlStmt += sprintf (pSqlStmt ,"%s%s => ?" ,
                  comma , pParm->name
               );
               comma = ",";
            }
         }

         comma = "";
         pSqlStmt += sprintf (pSqlStmt, ") into ");
         for (i=0 ; i < parmNum ;  i++) {
            PPARMS pParm = &pParms [i];
            if (pParm->usage == SQL_PARAM_OUTPUT ) {
               pSqlStmt += sprintf (pSqlStmt,"%s?", comma);
               comma = ",";
            }
         }
         break;
      }

      // Procedures 
      case 'P': {
         pSqlStmt += sprintf (pSqlStmt, "call %s.%s (",
            schemaName,
            routineName
         );

         comma = "";
         for (i=0 ; i < parmNum ;  i++) {
            PPARMS pParm = &pParms [i];
            pSqlStmt += sprintf (pSqlStmt ,"%s%s => ?" ,
               comma , pParm->name
            );
            comma = ",";
         }
         pSqlStmt += sprintf (pSqlStmt ,")");
         break;
      }

   } 

}
// -------------------------------------------------------------
SQLRETURN run (int argc, char ** argv, PUCHAR sqlStmt ,int parmNum , PPARMS pParms )
{
   SQLRETURN      rc;
   PUCHAR         server = "*LOCAL";
   SQLINTEGER     attrParm;
   SQLINTEGER     i;

   // allocate an environment handle
   rc = SQLAllocEnv (&henv);
   if (rc != SQL_SUCCESS ) {
     checkError (henv, hdbc, SQL_NULL_HSTMT, rc);
     return cleanUp(rc);
   }
   // Allow use of *LIBL
   attrParm = SQL_TRUE;
   rc = SQLSetEnvAttr  (henv, SQL_ATTR_SYS_NAMING,&attrParm, 0);
   if (rc != SQL_SUCCESS) {
     checkError (henv, hdbc, SQL_NULL_HSTMT, rc);
     return cleanUp(rc);
   }

   rc = SQLAllocConnect (henv, &hdbc);  // allocate a connection handle
   if (rc != SQL_SUCCESS ) {
     checkError (henv, hdbc, SQL_NULL_HSTMT, rc);
     return cleanUp(rc);
   }

   rc = SQLConnect (hdbc, server , SQL_NTS, NULL, SQL_NTS, NULL, SQL_NTS);
   if (rc != SQL_SUCCESS ) {
     checkError (henv, hdbc, SQL_NULL_HSTMT, rc);
     return cleanUp(rc);
   }

   rc = SQLAllocStmt(hdbc, &hstmt);
   if (rc != SQL_SUCCESS ) {
     checkError (henv, hdbc, SQL_NULL_HSTMT, rc);
     return cleanUp(rc);
   }

   rc  = SQLPrepare( hstmt, sqlStmt, SQL_NTS );
   if (rc != SQL_SUCCESS ) {
     checkError (henv, hdbc, hstmt, rc);
     return cleanUp(rc);
   }

   // This will be an iteration for all parameters and markers made
   for (i=0 ; i<parmNum ; i ++) {
      PPARMS pParm = &pParms [i];
      rc  = SQLBindParameter (
         hstmt,             // hstmt
         pParm->parmNo,               // Parm number
         pParm->usage  ,    // fParamType           !! TODO from command
         pParm->clType ,    // data type here in C  !! TODO from command
         pParm->sqlType,    // datatype in SQL      !! TODO from command
         pParm->len,        // precision - ignored for strings
         pParm->dec,        // decimals
         pParm->data,       // buffer ,
         pParm->bufLenIn,   // Buffer length
         &pParm->bufLenOut  // Buffer length input/output
      );
      if (rc != SQL_SUCCESS ) {
         checkError (henv, hdbc, hstmt, rc);
         return cleanUp(rc);
      }
   }

   rc = SQLExecute(hstmt);
   if (rc != SQL_SUCCESS &&  rc != SQL_SUCCESS_WITH_INFO) {
      checkError (henv, hdbc, hstmt, rc);
      return cleanUp(rc);
   }

   return cleanUp(SQL_SUCCESS);
}
// -------------------------------------------------------------
SQLRETURN cleanUp(orgrc)
{
   SQLRETURN      rc;

   if (hstmt) {
     SQLFreeStmt(hstmt, SQL_CLOSE);
   }

   // disconnect from database
   if (hdbc) {
      rc = SQLDisconnect (hdbc);
      if (rc != SQL_SUCCESS ) {
         //  checkError (henv, hdbc, SQL_NULL_HSTMT, rc);
      }

      // free connection handle
      rc = SQLFreeConnect (hdbc);
      if (rc != SQL_SUCCESS ) {
         //  checkError (henv, hdbc, SQL_NULL_HSTMT, rc);
      }
   }

   // free environment handle
   if (henv) {
      rc = SQLFreeEnv (henv);
      if (rc != SQL_SUCCESS ) {
      //  checkError (henv, SQL_NULL_HDBC, SQL_NULL_HSTMT, rc);
      }
   }
   return orgrc; // The original

}
// -------------------------------------------------------------
// Put into joblog with and finally send ESCAPE// for now just print
// -------------------------------------------------------------
void checkError (
   SQLHENV    henv,
   SQLHDBC    hdbc,
   SQLHSTMT   hstmt,
   SQLRETURN  rc)
{
   SQLCHAR     buffer[SQL_MAX_MESSAGE_LENGTH + 1];
   SQLCHAR     sqlstate[SQL_SQLSTATE_SIZE + 1];
   SQLINTEGER  sqlcode;
   SQLSMALLINT length;
   while (SQL_SUCCESS == SQLError(henv, hdbc, hstmt, sqlstate, &sqlcode, buffer,
                     SQL_MAX_MESSAGE_LENGTH + 1, &length)  ){
      sndpgmmsg ( "CPF9898", QCPFMSG, DIAG, 1,  "%s. sqlstate: %s, sqlcode: %ld" , 
         buffer , sqlstate, sqlcode 
      );
   };
}
