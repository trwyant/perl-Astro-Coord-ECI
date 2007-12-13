set	source	sgp4unit.for
set	version	0.010_10

#	Do not enclose the generated Perl in curly brackets.
set	enclose	0

#	Drop the declarations of any variables mapped by 'var' declarations
set	drop_var_declare	1

#	Set the identifier string for commented-out code.
set	comment_out	>>>>trw

#	Wrap at column 73
set	wrap	73

#	COMMENT THIS OUT WHEN PROCESSING REVISED FORTRAN, UNTIL YOU ARE
#	SURE NO COMMON CODE REMAINS.

drop	include	SGP4.CMN

#	Change the method string variable to something that maps to a
#	Perl boolean

subst	\bmethod\s*=\s*'n'	deep_space=0
subst	\bmethod\s*=\s*'d'	deep_space=1
subst	\bmethod\s*\.eq\.\s*'d'	deep_space

#	Since 'method' is in the common, we can map it globally

var	deep_space	$parm->{deep_space}

#	Since the above substitution does not catch everything, we map
#	the original variable as well.

var	method		$parm->{deep_space}

#	Error tracking

var	error	$self->{model_error}
code	begin	use constant SGP4R_ERROR_0 => dualvar (0, '');	# guaranteed false
code	begin	use constant SGP4R_ERROR_MEAN_ECCEN =>
code	begin	'Sgp4r 1: Mean eccentricity < 0 or > 1, or a < .95';
code	begin	use constant SGP4R_ERROR_1 => dualvar (1, SGP4R_ERROR_MEAN_ECCEN);
code	begin	use constant SGP4R_ERROR_MEAN_MOTION =>
code	begin	'Sgp4r 2: Mean motion < 0.0';
code	begin	use constant SGP4R_ERROR_2 => dualvar (2, SGP4R_ERROR_MEAN_MOTION);
code	begin	use constant SGP4R_INST_ECCEN =>
code	begin	'Sgp4r 3: Instantaneous eccentricity < 0 or > 1';
code	begin	use constant SGP4R_ERROR_3 => dualvar (3, SGP4R_INST_ECCEN);
code	begin	use constant SGP4R_ERROR_LATUSRECTUM =>
code	begin	'Sgp4r 4: Semi-latus rectum < 0';
code	begin	use constant SGP4R_ERROR_4 => dualvar (4, SGP4R_ERROR_LATUSRECTUM);
code	begin	use constant SGP4R_ERROR_5 => dualvar (5,
code	begin	'Sgp4r 5: Epoch elements are sub-orbital');
code	begin	use constant SGP4R_ERROR_6 => dualvar (6,
code	begin	'Sgp4r 6: Satellite has decayed');
code	begin
subst	^\s*error\s*=\s*(\d)\s*$	error = &SGP4R_ERROR_$1
var	sgp4r_error_0	SGP4R_ERROR_0
var	sgp4r_error_mean_eccen	SGP4R_ERROR_MEAN_ECCEN
var	sgp4r_error_1	SGP4R_ERROR_1
var	sgp4r_error_mean_motion	SGP4R_ERROR_MEAN_MOTION
var	sgp4r_error_2	SGP4R_ERROR_2
var	sgp4r_inst_eccen	SGP4R_INST_ECCEN
var	sgp4r_error_3	SGP4R_ERROR_3
var	sgp4r_error_latusrectum	SGP4R_ERROR_LATUSRECTUM
var	sgp4r_error_4	SGP4R_ERROR_4
var	sgp4r_error_5	SGP4R_ERROR_5
var	sgp4r_error_6	SGP4R_ERROR_6
before	^\s*call\s*initl	$self->{eccentricity} > 1
before	^\s*call\s*initl	and croak 'Error - Sgp4r TLE eccentricity > 1';
before	^\s*call\s*initl	$self->{eccentricity} < 0
before	^\s*call\s*initl	and croak 'Error - Sgp4r TLE eccentricity < 0';
before	^\s*call\s*initl	$self->{meanmotion} < 0
before	^\s*call\s*initl	and croak 'Error - Sgp4r TLE mean motion < 0';
after	^\s*error\s*=\s*1\s*$	croak 'Error - ', &SGP4R_ERROR_MEAN_ECCEN;
after	^\s*error\s*=\s*2\s*$	croak 'Error - ', &SGP4R_ERROR_MEAN_MOTION;
after	^\s*error\s*=\s*3\s*$	croak 'Error - ', &SGP4R_ERROR_INST_ECCEN;
after	^\s*error\s*=\s*4\s*$	croak 'Error - ', &SGP4R_ERROR_LATUSRECTUM;


#	Map the function names to something that will co-exist with
#	the Space Track 3 stuff.

func	dpper		$self->_r_dpper (%19, %34, %35, %36, %37, %38)
arg	dpper		self,t,eccp,inclp,nodep,argpp,mp
byvalue	dpper		self,t

func	dscom		$self->_r_dscom (%3)
arg	dscom		self,tc
byvalue	dscom		self,tc

# func	dsinit		_r_dsinit(%s)
func	dsinit		$self->_r_dsinit (%23, %24)
arg	dsinit		self,t,tc
byvalue	dsinit		self,t,tc

## func	dspace		_r_dspace(%s)
func	dspace		$self->_r_dspace (%21, %22, %27, %28, %29, %30, %31, %32, %33, %34, %35, %36)
arg	dspace		self,t,tc,atime,eccm,argpm,inclm,xli,mm,xni,nodem,dndt,xn
byvalue	dspace		self,t,tc

func	getgravconst	$self->_r_getgravconst()
arg	getgravconst	self

func	gstime		_r_gstime(%s)

func	initl		$self->_r_initl()
arg	initl		self

func	sgp4		$self->sgp4r (%2)
arg	sgp4		self,t
byvalue	sgp4		self,t

func	sgp4init	$self->_r_sgp4init ()
arg	sgp4init	self

#	Model constants

drop	include	ASTMATH.CMN
var	halfpi	&SGP_PIOVER2
var	pi	&SGP_PI
var	twopi	&SGP_TWOPI
var	deg2rad	&SGP_DE2RA
var	x2o3	&SGP_TOTHRD
drop	declare	x2o3
drop	assign	x2o3

#	Globals from getgravconst

var	tumin	$parm->{tumin}
var	mu	$parm->{mu}
var	radiusearthkm	$parm->{radiusearthkm}
var	xke	$parm->{xke}
var	j2	$parm->{j2}
var	j3	$parm->{j3}
var	j4	$parm->{j4}
var	j3oj2	$parm->{j3oj2}

#	Globals from initl

var	satn	$self->{id}
var	ecco	$parm->{eccentricity}
var	epoch	$self->{ds50}
var	inclo	$parm->{inclination}
var	no	$parm->{meanmotion}
var	eccsq	$init->{eccsq}
var	omeosq	$init->{omeosq}
var	rteosq	$init->{rteosq}
var	cosio	$init->{cosio}
var	cosio2	$init->{cosio2}
var	ao	$init->{ao}
var	sinio	$init->{sinio}
var	con42	$init->{con42}
var	con41	$parm->{con41}
var	ainv	$init->{ainv}
var	posq	$init->{posq}
var	rp	$init->{rp}
var	gsto	$parm->{gsto}

#	Globals from sgp4init

var	bstar	$self->{bstardrag}
var	ecco	$parm->{eccentricity}
var	argpo	$parm->{argumentofperigee}
var	mo	$parm->{meananomaly}
var	init	$parm->{init}
var	nodeo	$parm->{rightascension}
drop	assign	init
subst	\binit\s*\.eq\.\s*'y'	init
subst	\binit\s*\.eq\.\s*'n'	.not. init
var	isimp	$parm->{isimp}
subst	\bisimp\s*\.ne\.\s*1\b	.not. isimp
var	eta	$parm->{eta}
var	cc1	$parm->{cc1}
var	x1mth2	$parm->{x1mth2}
var	cc4	$parm->{cc4}
var	cc5	$parm->{cc5}
var	mdot	$parm->{mdot}
var	argpdot	$parm->{argpdot}
var	nodedot	$parm->{nodedot}
var	omgcof	$parm->{omgcof}
var	xmcof	$parm->{xmcof}
var	xnodcf	$parm->{xnodcf}
var	t2cof	$parm->{t2cof}
var	xlcof	$parm->{xlcof}
var	aycof	$parm->{aycof}
var	delmo	$parm->{delmo}
var	sinmao	$parm->{sinmao}
var	x7thm1	$parm->{x7thm1}
var	e3	$parm->{e3}
var	ee2	$parm->{ee2}
var	peo	$parm->{peo}
var	pgho	$parm->{pgho}
var	pho	$parm->{pho}
var	pinco	$parm->{pinco}
var	plo	$parm->{plo}
var	se2	$parm->{se2}
var	se3	$parm->{se3}
var	sgh2	$parm->{sgh2}
var	sgh3	$parm->{sgh3}
var	sgh4	$parm->{sgh4}
var	sh2	$parm->{sh2}
var	sh3	$parm->{sh3}
var	si2	$parm->{si2}
var	si3	$parm->{si3}
var	sl2	$parm->{sl2}
var	sl3	$parm->{sl3}
var	sl4	$parm->{sl4}
var	xgh2	$parm->{xgh2}
var	xgh3	$parm->{xgh3}
var	xgh4	$parm->{xgh4}
var	xh2	$parm->{xh2}
var	xh3	$parm->{xh3}
var	xi2	$parm->{xi2}
var	xi3	$parm->{xi3}
var	xl2	$parm->{xl2}
var	xl3	$parm->{xl3}
var	xl4	$parm->{xl4}
var	zmol	$parm->{zmol}
var	zmos	$parm->{zmos}
var	irez	$parm->{irez}
var	atime	$parm->{atime}
var	d2201	$parm->{d2201}
var	d2211	$parm->{d2211}
var	d3210	$parm->{d3210}
var	d3222	$parm->{d3222}
var	d4410	$parm->{d4410}
var	d4422	$parm->{d4422}
var	d5220	$parm->{d5220}
var	d5232	$parm->{d5232}
var	d5421	$parm->{d5421}
var	d5433	$parm->{d5433}
var	dedt	$parm->{dedt}
var	didt	$parm->{didt}
var	dmdt	$parm->{dmdt}
var	dnodt	$parm->{dnodt}
var	domdt	$parm->{domdt}
var	del1	$parm->{del1}
var	del2	$parm->{del2}
var	del3	$parm->{del3}
var	xfact	$parm->{xfact}
var	xlamo	$parm->{xlamo}
var	xli	$parm->{xli}
var	xni	$parm->{xni}
var	d2	$parm->{d2}
var	d3	$parm->{d3}
var	d4	$parm->{d4}
var	t3cof	$parm->{t3cof}
var	t4cof	$parm->{t4cof}
var	t5cof	$parm->{t5cof}
#	End of globals from sgp4init

#	Subroutine _r_dscom

within	sub	dscom
code	begin	my $parm = $self->{&TLE_INIT}{TLE_sgp4r}
code	begin	or croak "Error - Sgp4r not initialized";
code	begin	my $init = $parm->{init}
code	begin	or croak "Error - Sgp4r initialization not in progress";
#	Map formal parameters to actual parameters
#	Input parameters
var	eccp	$parm->{eccentricity}
var	argpp	$parm->{argumentofperigee}
# var	tc	????
var	inclp	$parm->{inclination}
var	nodep	$parm->{rightascension}
var	np	$parm->{meanmotion}
#	Output parameters
#	snodm and cnodm appear not to be used outside dscom.
var	snodm	$init->{snodm}
var	cnodm	$init->{cnodm}
#	sinim cosim appears as local variables in sgp4
var	sinim	$init->{sinim}
var	cosim	$init->{cosim}
#	sinomm and cosomm appear not to be used outside dscom.
var	sinomm	$init->{sinomm}
var	cosomm	$init->{cosomm}
#	day appears not to be used outside dscom.
var	day	$init->{day}
# var	e3	$parm->{e3}
# var	ee2	$parm->{ee2}
#	eccm and emsq are also local variables in sgp4
var	eccm	$init->{eccm}
var	emsq	$init->{emsq}
#	gam appears not to be used outside dscom.
var	gam	$init->{gam}
#	peo, pgho, pho, pinco, and plo appear only to be set to zero.
# var	peo	$parm->{peo}
# var	pgho	$parm->{pgho}
# var	pho	$parm->{pho}
# var	pinco	$parm->{pinco}
# var	plo	$parm->{plo}
#	rtemsq appears not to be used outside dscom.
var	rtemsq	$init->{rtemsq}
# var	se2	$parm->{se2}
# var	se3	$parm->{se3}
# var	sgh2	$parm->{sgh2}
# var	sgh3	$parm->{sgh3}
# var	sgh4	$parm->{sgh4}
# var	sh2	$parm->{sh2}
# var	sh3	$parm->{sh3}
# var	si2	$parm->{si2}
# var	si3	$parm->{si3}
# var	sl2	$parm->{sl2}
# var	sl3	$parm->{sl3}
# var	sl4	$parm->{sl4}
var	s1	$init->{s1}
var	s2	$init->{s2}
var	s3	$init->{s3}
var	s4	$init->{s4}
var	s5	$init->{s5}
#	s6 and s7 appear not to be used outside dscom.
var	s6	$init->{s6}
var	s7	$init->{s7}
var	ss1	$init->{ss1}
var	ss2	$init->{ss2}
var	ss3	$init->{ss3}
var	ss4	$init->{ss4}
var	ss5	$init->{ss5}
#	ss6 and ss7 appear not to be used outside dscom.
var	ss6	$init->{ss6}
var	ss7	$init->{ss7}
var	sz1	$init->{sz1}
#	sz2 appears not to be used outside dscom.
var	sz2	$init->{sz2}
var	sz3	$init->{sz3}
var	sz11	$init->{sz11}
#	sz12 appears not to be used outside dscom.
var	sz12	$init->{sz12}
var	sz13	$init->{sz13}
var	sz21	$init->{sz21}
#	sz22 appears not to be used outside dscom.
var	sz22	$init->{sz22}
var	sz23	$init->{sz23}
var	sz31	$init->{sz31}
#	sz32 appears not to be used outside dscom.
var	sz32	$init->{sz32}
var	sz33	$init->{sz33}
# var	xgh2	$parm->{xgh2}
# var	xgh3	$parm->{xgh3}
# var	xgh4	$parm->{xgh4}
# var	xh2	$parm->{xh2}
# var	xh3	$parm->{xh3}
# var	xi2	$parm->{xi2}
# var	xi3	$parm->{xi3}
# var	xl2	$parm->{xl2}
# var	xl3	$parm->{xl3}
# var	xl4	$parm->{xl4}
#	xn is also an OUTPUT variable from dspace in sgp4.
var	xn	$init->{xn}
var	z1	$init->{z1}
#	z2 appears not to be used outside dscom.
var	z2	$init->{z2}
var	z3	$init->{z3}
var	z11	$init->{z11}
#	z12 appears not to be used outside dscom.
var	z12	$init->{z12}
var	z13	$init->{z13}
var	z21	$init->{z21}
#	z22 appears not to be used outside dscom.
var	z22	$init->{z22}
var	z23	$init->{z23}
var	z31	$init->{z31}
#	z32 appears not to be used outside dscom.
var	z32	$init->{z32}
var	z33	$init->{z33}
# var	zmol	$parm->{zmol}
# var	zmos	$parm->{zmos}
#	output parameters through this point already dropped into sgp4init
#	End map formal parameters to actual parameters. These need to be
#	brought into sgp4init just to prove we mapped them.

#	subroutine _r_dsinit

within	sub	dsinit
code	begin	my $parm = $self->{&TLE_INIT}{TLE_sgp4r}
code	begin	or croak "Error - Sgp4r not initialized";
code	begin	my $init = $parm->{init}
code	begin	or croak "Error - Sgp4r initialization not in progress";
drop	call	getgravconst
drop	declare	whichconst
var	cosim	$init->{cosim}
var	emsq	$init->{emsq}
var	s1	$init->{s1}
var	s2	$init->{s2}
var	s3	$init->{s3}
var	s4	$init->{s4}
var	s5	$init->{s5}
var	sinim	$init->{sinim}
var	ss1	$init->{ss1}
var	ss2	$init->{ss2}
var	ss3	$init->{ss3}
var	ss4	$init->{ss4}
var	ss5	$init->{ss5}
var	sz1	$init->{sz1}
var	sz3	$init->{sz3}
var	sz11	$init->{sz11}
var	sz13	$init->{sz13}
var	sz21	$init->{sz21}
var	sz23	$init->{sz23}
var	sz31	$init->{sz31}
var	sz33	$init->{sz33}
# var	t	???
# var	tc	???
# var	gsto	$parm->{gsto}
# var	mo	$parm->{meananomaly}
# var	mdot	$parm->{mdot}
# var	no	$parm->{meanmotion}
# var	nodeo	$parm->{rightascension}
# var	nodedot	$parm->{nodedot}
var	xpidot	$init->{xpidot}
var	z1	$init->{z1}
var	z3	$init->{z3}
var	z11	$init->{z11}
var	z13	$init->{z13}
var	z21	$init->{z21}
var	z23	$init->{z23}
var	z31	$init->{z31}
var	z33	$init->{z33}
# var	ecco	$parm->{eccentricity}
var	eccsq	$init->{eccsq}
var	eccm	$init->{eccm}
#	argpm is set 0 and not used, as nearly as I can determine
var	argpm	$init->{argpm}
#	inclm is set to inclination and not used, as nearly as I can determine
var	inclm	$init->{inclm}
#	mm is set 0 and not used, as nearly as I can determine
var	mm	$init->{mm}
var	xn	$init->{xn}
#	nodem is set 0 and not used, as nearly as I can determine
var	nodem	$init->{nodem}
# var	irez	$parm->{irez}
# var	atime	$parm->{atime}
# var	d2201	$parm->{d2201}
# var	d2211	$parm->{d2211}
# var	d3210	$parm->{d3210}
# var	d3222	$parm->{d3222}
# var	d4410	$parm->{d4410}
# var	d4422	$parm->{d4422}
# var	d5220	$parm->{d5220}
# var	d5232	$parm->{d5232}
# var	d5421	$parm->{d5421}
# var	d5433	$parm->{d5433}
# var	dedt	$parm->{dedt}
# var	didt	$parm->{didt}
# var	dmdt	$parm->{dmdt}
#	dndt is also a a local in sgp4, but unused either way I believe
var	dndt	$init->{dndt}
# var	dnodt	$parm->{dnodt}
# var	domdt	$parm->{domdt}
# var	del1	$parm->{del1}
# var	del2	$parm->{del2}
# var	del3	$parm->{del3}
# var	xfact	$parm->{xfact}
# var	xlamo	$parm->{xlamo}
# var	xli	$parm->{xli}
# var	xni	$parm->{xni}

#	End of subroutine _r_dsinit

#	subroutine _r_initl

within	sub	initl
code	begin	my $parm = $self->{&TLE_INIT}{TLE_sgp4r}
code	begin	or croak "Error - Sgp4r not initialized";
code	begin	my $init = $parm->{init}
code	begin	or croak "Error - Sgp4r initialization not in progress";
drop	declare	whichconst
drop	call	getgravconst
drop	declare	radperday
drop	declare	ak
drop	declare	d1
drop	declare	del
drop	declare	adel
drop	declare	po
drop	declare	temp
drop	declare	tut1
# var	satn	$self->{id}
# var	ecco	$parm->{eccentricity}
# var	epoch	$self->{ds50}
# var	inclo	$parm->{inclination}
# var	no	$parm->{meanmotion}
# var	eccsq	$init->{eccsq}
# var	omeosq	$init->{omeosq}
# var	rteosq	$init->{rteosq}
# var	cosio	$init->{cosio}
# var	cosio2	$init->{cosio2}
# var	ao	$init->{ao}
# var	sinio	$init->{sinio}
# var	con42	$init->{con42}
# var	con41	$parm->{con41}
# var	ainv	$init->{ainv}
# var	posq	$init->{posq}
# var	rp	$init->{rp}
# var	gsto	$parm->{gsto}

#	subroutine _r_sgp4init

within	sub	sgp4init
code	begin	my $parm = $self->{&TLE_INIT}{TLE_sgp4r} = {};
code	begin	my $init = $parm->{init} = {};
code	begin	# The following is modified in _r_initl
code	begin	$parm->{meanmotion} = $self->{meanmotion};
code	begin	# The following may be modified for deep space
code	begin	$parm->{eccentricity} = $self->{eccentricity};
code	begin	$parm->{inclination} = $self->{inclination};
code	begin	$parm->{rightascension} = $self->{rightascension};
code	begin	$parm->{argumentofperigee} = $self->{argumentofperigee};
code	begin	$parm->{meananomaly} = $self->{meananomaly};
code	end	delete $parm->{init};
code	end	$ENV{DEVELOPER_TEST} and $self->_r_dump ();
code	end	return $parm;
drop	declare	whichconst
drop	assign	bstar
drop	assign	ecco
drop	assign	argpo
drop	assign	inclo
drop	assign	mo
drop	assign	no
drop	assign	nodeo
var	satn	$self->{id}
var	xbstar	$self->{bstardrag}
var	xecco	$parm->{eccentricity}
var	epoch	$self->{ds50}
var	xargpo	$parm->{argumentofperigee}
var	xinclo	$parm->{inclination}
var	xmo	$parm->{meananomaly}
var	xno	$parm->{meanmotion}
var	xnodeo	$parm->{rightascension}
# var	bstar	$self->{bstardrag}
# var	ecco	$parm->{eccentricity}
# var	argpo	$parm->{argumentofperigee}
# var	inclo	$parm->{inclination}
# var	mo	$parm->{meananomaly}
# var	no	$parm->{meanmotion}
# var	nodeo	$parm->{rightascension}
#	The following come from getgravconst in the original
# var	tumin	$parm->{tumin}
# var	mu	$parm->{mu}
# var	radiusearthkm	$parm->{radiusearthkm}
# var	xke	$parm->{xke}
# var	j2	$parm->{j2}
# var	j3	$parm->{j3}
# var	j4	$parm->{j4}
# var	j3oj2	$parm->{j3oj2}
#	The preceding come from getgravconst in the original
# var	eccsq	$init->{eccsq}
# var	omeosq	$init->{omeosq}
# var	rteosq	$init->{rteosq}
# var	cosio	$init->{cosio}
# var	cosio2	$init->{cosio2}
# var	ao	$init->{ao}
# var	sinio	$init->{sinio}
# var	con42	$init->{con42}
# var	con41	$parm->{con41}
# var	ainv	$init->{ainv}
# var	posq	$init->{posq}
# var	rp	$init->{rp}
# var	gsto	$parm->{gsto}
var	xpidot	$init->{xpidot}
#	Output arguments from dscom
#	snodm and cnodm appear not to be used outside dscom.
var	snodm	$init->{snodm}
var	cnodm	$init->{cnodm}
#	sinim cosim appears as local variables in sgp4
var	sinim	$init->{sinim}
var	cosim	$init->{cosim}
#	sinomm and cosomm appear not to be used outside dscom.
var	sinomm	$init->{sinomm}
var	cosomm	$init->{cosomm}
#	day appears not to be used outside dscom.
var	day	$init->{day}
# var	e3	$parm->{e3}
# var	ee2	$parm->{ee2}
#	eccm and emsq are also local variables in sgp4
var	eccm	$init->{eccm}
var	emsq	$init->{emsq}
#	gam appears not to be used outside dscom.
var	gam	$init->{gam}
#	rtemsq appears not to be used outside dscom.
var	rtemsq	$init->{rtemsq}
# var	se2	$parm->{se2}
# var	se3	$parm->{se3}
# var	sgh2	$parm->{sgh2}
# var	sgh3	$parm->{sgh3}
# var	sgh4	$parm->{sgh4}
# var	sh2	$parm->{sh2}
# var	sh3	$parm->{sh3}
# var	si2	$parm->{si2}
# var	si3	$parm->{si3}
# var	sl2	$parm->{sl2}
# var	sl3	$parm->{sl3}
# var	sl4	$parm->{sl4}
var	s1	$init->{s1}
var	s2	$init->{s2}
var	s3	$init->{s3}
var	s4	$init->{s4}
var	s5	$init->{s5}
#	s6 and s7 appear not to be used outside dscom.
var	s6	$init->{s6}
var	s7	$init->{s7}
var	ss1	$init->{ss1}
var	ss2	$init->{ss2}
var	ss3	$init->{ss3}
var	ss4	$init->{ss4}
var	ss5	$init->{ss5}
#	ss6 and ss7 appear not to be used outside dscom.
var	ss6	$init->{ss6}
var	ss7	$init->{ss7}
var	sz1	$init->{sz1}
#	sz2 appears not to be used outside dscom.
var	sz2	$init->{sz2}
var	sz3	$init->{sz3}
var	sz11	$init->{sz11}
#	sz12 appears not to be used outside dscom.
var	sz12	$init->{sz12}
var	sz13	$init->{sz13}
var	sz21	$init->{sz21}
#	sz22 appears not to be used outside dscom.
var	sz22	$init->{sz22}
var	sz23	$init->{sz23}
var	sz31	$init->{sz31}
#	sz32 appears not to be used outside dscom.
var	sz32	$init->{sz32}
var	sz33	$init->{sz33}
var	xn	$init->{xn}
var	z1	$init->{z1}
#	z2 appears not to be used outside dscom.
var	z2	$init->{z2}
var	z3	$init->{z3}
var	z11	$init->{z11}
#	z12 appears not to be used outside dscom.
var	z12	$init->{z12}
var	z13	$init->{z13}
var	z21	$init->{z21}
#	z22 appears not to be used outside dscom.
var	z22	$init->{z22}
var	z23	$init->{z23}
var	z31	$init->{z31}
#	z32 appears not to be used outside dscom.
var	z32	$init->{z32}
var	z33	$init->{z33}
#	End of output arguments from dscom.
#	Inputs to (/outputs from) dsinit
#	argpm is set 0 and not used, as nearly as I can determine
var	argpm	$init->{argpm}
#	inclm is set to inclination and not used, as nearly as I can determine
var	inclm	$init->{inclm}
#	mm is set 0 and not used, as nearly as I can determine
var	mm	$init->{mm}
#	nodem is set 0 and not used, as nearly as I can determine
var	nodem	$init->{nodem}
#	dndt is also a a local in sgp4, but unused either way I believe
var	dndt	$init->{dndt}

# at end of sgp4init ...
## subst	^\s*(call\s*sgp4\s*\()	#>>>>trw\t$1
drop	call	sgp4

within	sub	dpper
code	begin	my $parm = $self->{&TLE_INIT}{TLE_sgp4r}
code	begin	or croak "Error - Sgp4r not initialized";

#	subroutine _r_dspace

within	sub	dspace
code	begin	my $parm = $self->{&TLE_INIT}{TLE_sgp4r}
code	begin	or croak "Error - Sgp4r not initialized";
var	atime	$$atime
var	xli	$$xli
var	xni	$$xni

#	subroutine sgp4r

within	sub	sgp4
code	begin	my $parm = $self->{&TLE_INIT}{TLE_sgp4r} ||= $self->_r_sgp4init ();
code	begin	my $time = $t;
code	begin	$t = ($t - $self->{epoch}) / 60;
# code	end	return (@r[1..3], @v[1..3]);
code	end	$self->universal ($time);
code	end	$self->eci (@r[1..3], @v[1..3]);
code	end	$self->equinox_dynamical ($self->{epoch_dynamical});
code	end	return $self;
# code	end	@_ = ($self, @r[1..3], @v[1..3], $time);
# code	end	goto &_convert_out;
drop	call	getgravconst
# drop	declare	error
# drop	assign	error
drop	declare	whichconst

#	subroutine _r_getgravconst

within	sub	getgravconst
code	begin	my $parm = $self->{&TLE_INIT}{TLE_sgp4r}
code	begin	or croak "Error - Sgp4r not initialized";
var	whichconst	$self->{gravconst_r}
# var	tumin	$parm->{tumin}
# var	mu	$parm->{mu}
# var	radiusearthkm	$parm->{radiusearthkm}
# var	xke	$parm->{xke}
# var	j2	$parm->{j2}
# var	j3	$parm->{j3}
# var	j4	$parm->{j4}
# var	j3oj2	$parm->{j3oj2}

end

### sgp4io.for calculates also:
#        a      = (No*TUMin)**(-2.0D0/3.0D0)
#        IF (DABS(Ecco-1.0D0) .gt. 0.000001D0) THEN
#            Altp= (a*(1.0D0-Ecco))-1.0D0
#            Alta= (a*(1.0D0+Ecco))-1.0D0
#          ELSE
#            Alta= 999999.9D0
#            Altp= 2.0D0* (4.0D0/(No*No)**(1.0D0/3.0D0))
#          ENDIF
#        ! ---- Ballistic Coefficient ----
#        IF (DABS(BStar) .gt. 0.00000001D0) THEN
#            BC= 1.0D0/(12.741621D0*BStar)
#          ELSE
#            BC= 1.111111111111111D0
#          ENDIF

