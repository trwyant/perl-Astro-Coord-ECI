FORTRAN_CODE = 
sgp4unit.pl : sgp4unit.spec FOR/sgp4unit.for
	./for2pl -spec sgp4unit.spec -set source=FOR/sgp4unit.for >sgp4unit.pl

testfor : FOR/ASTMATH.CMN FOR/sgp4.cmn FOR/sgp4ext.for FOR/sgp4io.for \
    FOR/sgp4unit.for FOR/testfor.for
	cd FOR && g77 -o ../testfor testfor.for sgp4ext.for sgp4io.for sgp4unit.for

test : testfor
	perl -e 'print "V\n72\nsgp4-ver.tle\n\n"' | ./testfor

clean :
	if [ -e Sgp4Rec.bak ]; then rm -v Sgp4Rec.bak; fi
	if [ -e sgp4test.dbg ]; then rm -v sgp4test.dbg; fi
	if [ -e tfora.out ]; then rm -v tfora.out; fi
	if [ -e tforver.out ]; then rm -v tforver.out; fi

realclean : clean
	if [ -e testfor ]; then rm -v testfor; fi
	if [ -e sgp4unit.pl ]; then rm -v sgp4unit.pl; fi
