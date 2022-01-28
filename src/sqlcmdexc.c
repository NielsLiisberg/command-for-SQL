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

SQLHENV       henv = -1;
SQLHDBC       hdbc = 0;
SQLHSTMT      hstmt = 0 ;

typedef struct _PARMS {
   SQLSMALLINT parmNo;
   UCHAR name[32] ;
   SQLSMALLINT cltype;
   SQLSMALLINT sqltype;
   SQLINTEGER  len;
   SQLSMALLINT dec;
   SQLSMALLINT usage;
   UCHAR  attr;
   SQLPOINTER data;
   SQLINTEGER bufLenIn;
   SQLINTEGER bufLenOut;
} PARMS , *PPARMS;

// -------------------------------------------------------------
// TODO Put prototypes in H file
// -------------------------------------------------------------
SQLRETURN cleanUp(int rc);
void checkError (
   SQLHENV    henv,
   SQLHDBC    hdbc,
   SQLHSTMT   hstmt,
   SQLRETURN  rc
);
void buildSQLstatement (int argc, char ** argv, PUCHAR sqlStmt , int parmNum, PPARMS pParms);
SQLRETURN run (int argc, char ** argv, PUCHAR sqlStmt, int parmNum, PPARMS pParms);

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
   for (i=3 ; i < argc ; i += 2) {
      PPARMS pParm = &pParms [parmNum++];
      PUCHAR pMeta = argv[i];
      PUCHAR pValue = argv[i+1];
      UCHAR  temp [32];
      PUCHAR pTemp = temp;
      pParm->parmNo = parmNum; // stored so number will match id CL parm is not passed
      slurp   (pParm->name     ,  &pMeta);
      pParm->cltype  = atoi(slurp   (temp, &pMeta));
      pParm->sqltype = atoi(slurp   (temp, &pMeta));
      pParm->len     = atoi(slurp   (temp, &pMeta));
      pParm->dec     = atoi(slurp   (temp, &pMeta));
      slurp   (temp ,  &pMeta);
      if      (strcmp (temp, "IN") == 0)  pParm->usage = SQL_PARAM_INPUT;
      else if (strcmp (temp, "OUT") == 0) pParm->usage = SQL_PARAM_OUTPUT;
      else                                pParm->usage = SQL_PARAM_INPUT_OUTPUT;

      pParm->attr = *pValue;
      pParm->data = pValue +1;

      // Return values always pase the len in commands
      if (pParm->usage == SQL_PARAM_OUTPUT) {
         // All data not having "VARRYING" - we insert space
         if (pParm->sqltype != SQL_VARCHAR
         &&  pParm->sqltype != SQL_WVARCHAR
         &&  pParm->sqltype != SQL_VARGRAPHIC
         &&  pParm->sqltype != SQL_VARBINARY) {
            pParm->data = pValue +3;
         }
         // Decimal have precision and size on VARRYING parameter
         // Yes - but you can not use it from a CL program :(
         // if (pParm->sqltype == SQL_DECIMAL) {
         //    pParm->dec     = pValue[1];
         //    pParm->len     = pValue[2];
         // }
      }

      if  (pParm->sqltype == SQL_DECIMAL) {
         pParm->bufLenOut = pParm->bufLenIn = (pParm->len / 2) +1;
      } else {
         pParm->bufLenOut = pParm->bufLenIn =pParm->len; // TODO !!
      }

   }
   return parmNum;
}

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
      // TODO Send Escape
   }
}

// -------------------------------------------------------------
void buildSQLstatement (int argc, char ** argv, PUCHAR sqlStmt , int parmNum , PPARMS pParms )
{
   int i;
   PUCHAR pMeta = argv[1];
   UCHAR  routineType [32];
   UCHAR  schemaName  [32];
   UCHAR  routineName [32];
   PUCHAR pSqlStmt = sqlStmt; // To traverse it
   BOOL isFunction;
   PUCHAR comma;


   // first the procedure / function call
   slurp (routineType     ,  &pMeta );
   slurp (schemaName      ,  &pMeta );
   slurp (routineName     ,  &pMeta );

   isFunction = *routineType = 'F';

   if (isFunction) {
      pSqlStmt += sprintf (pSqlStmt,"values  %s.%s (",
         schemaName,
         routineName
      );
   } else {
      pSqlStmt += sprintf (pSqlStmt, "call %s.%s (",
         schemaName,
         routineName
      );
   }

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

   if (isFunction) {
      comma = "";
      pSqlStmt += sprintf (pSqlStmt, ") into ");
      for (i=0 ; i < parmNum ;  i++) {
         PPARMS pParm = &pParms [i];
         if (pParm->usage == SQL_PARAM_OUTPUT ) {
            pSqlStmt += sprintf (pSqlStmt,"%s?", comma);
            comma = ",";
         }
      }
   } else {
      pSqlStmt += sprintf (pSqlStmt ,")");
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
         pParm->cltype ,    // data type here in C  !! TODO from command
         pParm->sqltype,    // datatype in SQL      !! TODO from command
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
// TODO !! Put into joblog with and finally send ESCAPE// for now just print
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
   while ( SQLError(henv, hdbc, hstmt, sqlstate, &sqlcode, buffer,
                     SQL_MAX_MESSAGE_LENGTH + 1, &length) == SQL_SUCCESS ){
      printf("\n **** ERROR *****\n");
      printf("         SQLSTATE: %s\n", sqlstate);
      printf("Native Error Code: %ld\n", sqlcode);
      printf("%s \n", buffer);
   };
}
// -------------------------------------------------------------
/* TODO !! process the command:

// TODO Convert this to clean C-code:

**free
               dcl-ds CMDD0100data ;
                 BytesReturned int(10) ;
                 ByteAvailable int(10) ;
                 XMLdata char(10240) ccsid(1208) ;
               end-ds ;

               dcl-pr QCDRCMDD extpgm ;
                 *n char(20) const ;                   //Command & library
                 *n int(10) const;                     // size
                 *n char(8) const ;                    //Destination format name
                 *n char(32767) options(*varsize) ;    //Returned DS
                 *n char(8) const ;                    //Receiver format name
                 *n int(20) const;                     //API error DS
               end-pr ;

               /include qsysinc/qrpglesrc,qusec        //API error DS
               ByteAvailable = %size(xmldata);

               XMLdata = ' ' ;

               QCDRCMDD('CMDJOBLOG *LIBL     ':
                        %size(xmldata):
                        'DEST0100' :
                        CMDD0100data :
                        'CMDD0100' :
                        0    ) ;


               return ;
               *INLR= *ON;

// Returns XML like this

<QcdCLCmd DTDVersion="1.0">
        <Cmd CmdName="CMDJOBLOG" CmdLib="__LIBL" CCSID="277" MaxPos="99" Prompt="Call SQL procedure joblog" MsgF="QCPFMS
                <Parm Kwd="MESSAGE" PosNbr="1" KeyParm="NO" Type="CHAR" Min="0" Max="1" Prompt="Message" Len="256" Rstd=
                </Parm>
        </Cmd>
</QcdCLCmd>


*/
