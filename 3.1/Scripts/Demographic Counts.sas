/* Define path to your PCORnet CDM Data Sets */
libname CDM 'CHANGE ME'; *Y:/DirectoryA/DirectoryB/;

/* Define the Date to calculate Age off of */
%let age_calc = 03/30/2018;

/* Define date range to check for patient data */
%let min_date = 01/01/2004;
%let max_date = 03/30/2018;

/* BELOW HERE RUNS THE BREAKDOWNS
		DON'T CHANGE
*/


PROC FORMAT;
	value $ethnicf
	'Y' = 'Hispanic / Latino'
	'N' = 'Not Hispanic / Latino'
	'R' = 'Refuse to Answer'
 	'NI' = 'No Information'
	'UN' = 'Unknown'
	'OT' = 'Other';
	
	invalue ethnOrdf
	'Y'=1
	'N'=2
	'UN'=3
	'NI'=4
	'OT'=4
	.M = 4;

	value $racef
	'01' = 'American Indian or Alaska Native'
 	'02' = 'Asian'
	'03' = 'Black or African American'
	'04' = 'Native Hawaiian or Other Pacific islander'
	'05' = 'White'
	'06' = 'Multiple Race'
	'07' = 'Refuse to Answer'
	'OT' = 'Other / Unknown'
	'NI' = 'No Information'
	'UN' = 'Other / Unknown';

	invalue raceOrdf
	'01' = 1
 	'02' = 2
	'04' = 3
	'03' = 4
	'05' = 5
	'OT' = 6
	'UN' = 6
	'06' = 10
	'07' = 10
	'NI' = 10;

	value $sexf
	'F' = 'Female'
	'M' = 'Male'
	'UN' = 'Unknown'
 	'OT' = 'Other'
	'NI' = 'No Information';
	
	invalue sexOrdf
    'Female'=2
    'F'=2
    'Male'=1
    'M'=1
    'Unknown'=3
    'UN' =3;

	value agef
	low - <0 = '<0'
	0-17 = '0-17 Years'
	18-44 = '18-44 Years'
	45-64 = '45-64 Years'
	65 - high = '>65 Years';

	invalue ageOrdf
	low - <0 = 1
	0-17 = 2
	18-44 = 3
	45-64 = 4
	65 - high = 5;
	
	value nthresh 
	1-9 = '<10'
	10 - 10000 = comma8.;

	value thresh (default=9) 1 - 9 = '<10';
	PICTURE threshold 
		0 = '000,000,000'
		1 - 9 = [thresh.]
		10 - high = '000,000,000';
RUN;

PROC SQL;
	CREATE TABLE ENC_LIST AS
	SELECT PATID, ENCOUNTERID
	FROM CDM.ENCOUNTER ENC 
	WHERE ENC.ADMIT_DATE BETWEEN input("&min_date", ANYDTDTE10.) and input("&max_date", ANYDTDTE10.)
;

proc sql;
	CREATE TABLE DEMO_DIST AS
	SELECT DISTINCT DEM.PATID, 
		DEM.SEX, DEM.RACE, DEM.HISPANIC, 
		floor ((intck('month',DEM.birth_date,input("&age_calc", ANYDTDTE10.)) - (day(input("&age_calc", ANYDTDTE10.)) < day(DEM.birth_date))) / 12) AS AGE
	FROM CDM.DEMOGRAPHIC DEM 
	WHERE DEM.PATID IN 
	(
		SELECT DISTINCT PATID
		FROM ENC_LIST 
	)
;

proc sql;
	CREATE TABLE RAW_COUNT AS
	SELECT COUNT(DISTINCT PATID) as RAW_COUNT, 'UNIQUE PATIENTS' AS COUNT_TYPE FROM DEMO_DIST
		UNION
	SELECT COUNT(ENCOUNTERID), 'UNIQUE ENCOUNTERS'
	FROM ENC_LIST
;

data demoRanked;
	set DEMO_DIST;
	rownum = _n_;
	ageRank = input(age, ageOrdf.);
	raceRank = input(race, raceOrdf.);
	ethnRank = input(hispanic, ethnOrdf.);
	gendRank = input(sex, sexOrdf.);
run;

proc sort data=demoRanked;
	by raceRank ageRank ethnRank gendRank ;

title '3 Way Demographic Distrubtion';
proc tabulate data=demoRanked f=8.0 missing order=data;
	class race / order=data;
	class hispanic
		sex;
	var rownum;
	tables race=' '*F=pct. all='Total'*F=threshold., hispanic='Ethnic Categories'*(sex=' ')*F=threshold. all='Total'*F=threshold.
		/ BOX='Racial Categories'
			MISSTEXT='0'
			PRINTMISS;
	format sex $genderf. 
		hispanic $ethnicf. 
		race $racef. ;
	Keylabel N=' ';
run;

title 'Age Breakdown';
proc tabulate data=demoRanked f=8.0 missing order=data;
	class age;
	var rownum;
	tables age='Current Age' , rownum*(N*F=threshold.)
		/ MISSTEXT='0'
          PRINTMISS;
	format age agef. ;
	label rownum="Unique Patients";
	Keylabel N=' ';
run;

title 'Gender Breakdown';
proc tabulate data=demoRanked f=8.0 missing order=data;
	class sex;
	var rownum;
	tables sex='Gender' , rownum*(N*F=threshold.)
		/ MISSTEXT='0'
          PRINTMISS;
	format sex $sexf. ;
	label rownum="Unique Patients";
	Keylabel N=' ';
run;

title 'Race Breakdown';
proc tabulate data=demoRanked f=8.0 missing order=data;
	class race;
	var rownum;
	tables race='Race' , rownum*(N*F=threshold.)
		/ MISSTEXT='0'
          PRINTMISS;
	format race $racef. ;
	label rownum="Unique Patients";
	Keylabel N=' ';
run;

title 'Ethnicity Breakdown';
proc tabulate data=demoRanked f=8.0 missing order=data;
	class hispanic;
	var rownum;
	tables hispanic='Ethnicity' , rownum*(N*F=threshold.)
		/ MISSTEXT='0'
          PRINTMISS;
	format hispanic $ethnicf. ;
	label rownum="Unique Patients";
	Keylabel N=' ';
run;

title 'Raw Total Counts';
proc print data=RAW_COUNT;
	var count_type raw_count ;
	label raw_count="Unique IDs";
run;
