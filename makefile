#-----------------------------------------------------------
# User-defined part start
#

# NOTE - UTF is not allowed for ILE source (yet) - so convert to WIN-1252

# BIN_LIB is the destination library for the service program.
# the rpg modules and the binder source file are also created in BIN_LIB.
# binder source file and rpg module can be remove with the clean step (make clean)
BIN_LIB=CMD4SQL
DBGVIEW=*ALL
TARGET_CCSID=500
TARGET_RLS=V7R2M0

# Do not touch below
INCLUDE='/QIBM/include' 'headers/' 'headers/ext/' 

CCFLAGS=OPTIMIZE(10) ENUM(*INT) TERASPACE(*YES) STGMDL(*INHERIT) SYSIFCOPT(*IFSIO) INCDIR($(INCLUDE)) DBGVIEW($(DBGVIEW)) DEFINE($(DEFINE)) TGTCCSID($(TARGET_CCSID)) TGTRLS($(TARGET_RLS))

# For current compile:
CCFLAGS2=OPTION(*STDLOGMSG) OUTPUT(*none) $(CCFLAGS)
DB2=/QSYS.LIB/QZDFMDB2.PGM

#
# User-defined part end
#-----------------------------------------------------------

# Dependency list
.ONESHELL:

all:  $(BIN_LIB).lib create_CL_command.sql cmd4sql.pgm 

cmd4sql.pgm: sndpgmmsg.c sqlcmdexc.c 

#-----------------------------------------------------------

%.lib:
	-system -q "CRTLIB $* TYPE(*TEST) TEXT('CMD4SQL: Command for SQL functions and procedures')" 
	

%.sql:
	-system "RUNSQLSTM SRCSTMF('sql/$*.sql') COMMIT(*NONE)  "

    
#	$(DB2) ../sql/$*.sql

%.c:
	system -q "CHGATR OBJ('src/$*.c') ATR(*CCSID) VALUE(1252)"
	system "CRTCMOD MODULE($(BIN_LIB)/$(notdir $*)) SRCSTMF('src/$*.c') $(CCFLAGS)"

%.clle:
	system -q "CHGATR OBJ('src/$*.clle') ATR(*CCSID) VALUE(1252)"
	-system -q "CRTSRCPF FILE($(BIN_LIB)/QCLLESRC) RCDLEN(132)"
	system "CPYFRMSTMF FROMSTMF('src/$*.clle') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QCLLESRC.file/$(notdir $*).mbr') MBROPT(*ADD)"
	system "CRTCLMOD MODULE($(BIN_LIB)/$(notdir $*)) SRCFILE($(BIN_LIB)/QCLLESRC) DBGVIEW($(DBGVIEW)) TGTRLS($(TARGET_RLS))"

%.pgm:
	
	# You may be wondering what this ugly string is. It's a list of module objects created from the dep list that end with .c or .clle.
	$(eval modules := $(patsubst %,$(BIN_LIB)/%,$(basename $(filter %.c %.clle,$(notdir $^)))))
	
	system -q -kpieb "CRTPGM PGM($(BIN_LIB)/$*) MODULE($(modules)) ACTGRP(QILE) TGTRLS($(TARGET_RLS))"



all:
	@echo Build success!

clean:
	-system -q "DLTOBJ OBJ($(BIN_LIB)/*ALL) OBJTYPE(*MODULE)"
	-system -q "DLTOBJ OBJ($(BIN_LIB)/XMP*) OBJTYPE(*PGM)"
	-system -q "DLTOBJ OBJ($(BIN_LIB)/CMD4SQL) OBJTYPE(*PGM)"
	

	
release: clean
	@echo " -- Creating CMD4SQL release. --"
	@echo " -- Creating save file. --"
	system "CRTSAVF FILE($(BIN_LIB)/RELEASE)"
	system "SAVLIB LIB($(BIN_LIB)) DEV(*SAVF) SAVF($(BIN_LIB)/RELEASE) OMITOBJ((RELEASE *FILE))"
	-rm -r release
	-mkdir release
	system "CPYTOSTMF FROMMBR('/QSYS.lib/$(BIN_LIB).lib/RELEASE.FILE') TOSTMF('./release/release.savf') STMFOPT(*REPLACE) STMFCCSID(1252) CVTDTA(*NONE)"
	@echo " -- Cleaning up... --"
	system "DLTOBJ OBJ($(BIN_LIB)/RELEASE) OBJTYPE(*FILE)"
	@echo " -- Release created! --"
	@echo ""
	@echo "To install the release, run:"
	@echo "  > CRTLIB $(BIN_LIB)"
	@echo "  > CPYFRMSTMF FROMSTMF('./release/release.savf') TOMBR('/QSYS.lib/$(BIN_LIB).lib/RELEASE.FILE') MBROPT(*REPLACE) CVTDTA(*NONE)"
	@echo "  > RSTLIB SAVLIB($(BIN_LIB)) DEV(*SAVF) SAVF($(BIN_LIB)/RELEASE)"
	@echo ""

# For vsCode / single file then i.e.: gmake current sqlio.c  
current: 
	system -i "CRTCMOD MODULE($(BIN_LIB)/$(SRC)) SRCSTMF('src/$(SRC).c') $(CCFLAGS2) "
	system -i "UPDPGM PGM($(BIN_LIB)/cmd4sql) MODULE($(BIN_LIB)/*ALL)"  

# For vsCode / single file then i.e.: gmake current sqlio.c  
example: 
	system -i "CRTBNDRPG PGM($(BIN_LIB)/$(SRC)) SRCSTMF('examples/$(SRC).rpgle') DBGVIEW(*ALL)" > error.txt

compile: 
	system -q "CHGATR OBJ('examples/$(SRC)') ATR(*CCSID) VALUE(1252)"
	-system -q "CRTSRCPF FILE($(BIN_LIB)/QCLLESRC) RCDLEN(132)"
	system "CPYFRMSTMF FROMSTMF('examples/$(SRC)') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QCLLESRC.file/$(OBJ).mbr') MBROPT(*REPLACE)"
	system -i "CRTBNDCL PGM($(BIN_LIB)/$(OBJ)) SRCFILE($(BIN_LIB)/QCLLESRC) DBGVIEW($(DBGVIEW)) TGTRLS($(TARGET_RLS))" > error.txt

test: 

	system -i "CRTBNDRPG PGM($(BIN_LIB)/$(SRC)) SRCSTMF('test/$(SRC).rpgle') DBGVIEW(*ALL)" > error.txt

       
.PHONY: compile