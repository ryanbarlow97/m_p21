%* **************************************************************
%* Program Name: m_p21.sas
%* Initial Author: Ryan Barlow
%* Initial Creation Date: 10-Sep-2024
%* Purpose: To allow for auto running of the p21

%macro m_p21(help,
             domain=, 
             library=, 
             engine=FDA 2304.3,
             jarpath=%str(C:\Program Files (x86)\Pinnacle 21 Community\resources\app.asar.unpacked\components\lib), 
             jarfile=%str(p21-client-1.0.8.jar),
             cleanup=Y);
  
  %put NOTE: %upcase(&sysmacroname.).SAS is executing.;

  %let sasfile=%sysget(sas_execfilepath);

  %* Store Current Options Used in Macro;
  %let m_options = %sysfunc(getoption(source));
  %let m_moptions = %sysfunc(getoption(mprint)) %sysfunc(getoption(mlogic)) %sysfunc(getoption(symbolgen));

  %* Print HELP text;
  %if %length(&help.) > 0 %then %do;
    options nosource nomprint nomlogic nosymbolgen;
    %put %sysfunc(repeat(*, %eval(%sysfunc(getoption(ls))-10)));
    %put MACRO: %upcase(&sysmacroname.).sas;
    %put %sysfunc(repeat(=, %eval(%sysfunc(getoption(ls))-10))); 
    %put %str(PARAMETER       | RULE  | DETAILS);
    %put %str(DOMAIN          | REQ.  | The name of the domain to validate. It must exist in the specified library.);
    %put %str(LIBRARY         | REQ.  | The library where the domain resides. Must be either "SDTM" or "ADAM".);
    %put %str(ENGINE          | REQ.  | The engine version which relates to P21 engine. Default: FDA 2304.3.);
    %put %str(JARPATH         | REQ.  | Path to the Pinnacle 21 Java libraries, defaulting to a typical installation.);
    %put %str(JARFILE         | REQ.  | The specific jar file used for validation. Default: p21-client-1.0.8.jar);
    %put %str(CLEANUP         | REQ.  | determines whether all work dataset / variables are removed,);
    %put %str(                |       | the macro DEFAULT=Y.);
    %put %sysfunc(repeat(=, %eval(%sysfunc(getoption(ls))-10)));
    options &m_options. &m_moptions. minoperator;
    %return;
  %end;

  %*------ CHECKS --------------------------------------;
  %* DOMAIN checks;
  %* Is DOMAIN parameter defined?;
  %if %length(&DOMAIN.) = 0 %then %do;
    %put WARN%STR(ING:) domain parameter is required.;
    %return;
  %end;

  %* LIBRARY checks;
  %* Is LIBRARY parameter defined?;
  %if %length(&library.) = 0 %then %do;
    %put WARN%STR(ING:) library parameter is required.;
    %return;
  %end;

  %* ENGINE checks;
  %* Is ENGINE parameter defined?;
  %if %length(&engine.) = 0 %then %do;
    %put WARN%STR(ING:) engine parameter is required.;
    %return;
  %end;

  %* JARPATH checks;
  %* Is JARPATH parameter defined?;
  %if %length(&jarpath.) = 0 %then %do;
    %put WARN%STR(ING:) jarpath parameter is required.;
    %return;
  %end;

  %* JARFILE checks;
  %* Is JARFILE parameter defined?;
  %if %length(&jarfile.) = 0 %then %do;
    %put WARN%STR(ING:) jarfile parameter is required.;
    %return;
  %end;

  %* SASFILE checks;
  %* Is it a runall?;
  %if %index(%upcase(&sasfile), RUNALL) > 0 %then %do;
    %put P21: [%upcase(&sysmacroname.)] SAS file is a runall, skipping p21.;
    %return;
  %end;

  %* Validate the Library parameter to ensure it is either "SDTM" or "ADAM";
  %if %upcase(%str(&library)) ne SDTM and %upcase(%str(&library)) ne ADAM  and %upcase(%str(&library)) ne ADAMQ  and %upcase(%str(&library)) ne SDTMQ %then %do;
    %put WARNING: Invalid library specified. Use either SDTM(Q) or ADAM(Q);
    %return;
  %end;

  %* Check if the dataset exists in the specified library;
  %if %sysfunc(exist(&library..&domain)) = 0 %then %do;
    %put WARN%STR(ING: )Dataset &library..&domain does not exist.;
    %return;
  %end;

  %*--- Check if the specified JARPATH folder exists;
  %if %sysfunc(fileexist(&jarpath.)) = 0 %then %do;
      %put WARNING: The specified JARPATH folder "&jarpath." does not exist.;
      %return;
  %end;

  %*--- Check if the specified JARPATH folder exists;
  %if %sysfunc(fileexist(&jarpath.)) = 0 %then %do;
      %put WARNING: The specified JARPATH folder "&jarpath." does not exist.;
      %return;
  %end;

  %*--- Check if the specified JARFILE exists within the JARPATH folder;
  %let full_jarfile_path = &jarpath.\&jarfile.;
  %if %sysfunc(fileexist(&full_jarfile_path.)) = 0 %then %do;
      %put WARNING: The specified JARFILE "&jarfile." does not exist in the folder "&jarpath.";
      %return;
  %end;

  %*--- Check if the specified SASFILE exists;
  %if %sysfunc(fileexist(&sasfile.)) = 0 %then %do;
      %put WARNING: The specified SASFILE "&sasfile." does not exist.;
      %return;
  %end;

  %* CLEANUP checks;
  %* Is it defined?;
  %else %if %length(&cleanup.)=0 %then %do;
    %put WARN%STR(ING:) [%upcase(&sysmacroname.)] Please provide the clean-up parameter value (CLEANUP).;
    %return;
  %end;

  %* Is it defined as expected - Y or N?;
  %else %if %upcase(&cleanup.) ne N and %upcase(&cleanup.) ne Y %then %do;
    %put WARN%STR(ING:) [%upcase(&sysmacroname.)] Please ensure the clean-up parameter value is either N or Y (CLEANUP=&CLEANUP.).;
    %return;
  %end;

  %* Extract the program name from SASFILE and validate against DOMAIN;
  data _null_;
    length program_name $200 domain_name $200;

    sasfile_path = "&sasfile.";
    program_name = scan(scan(sasfile_path, -1, '\'), 1, '.');

    /* Compare the DOMAIN and program_name */
    domain_name = upcase("&domain.");
    program_name = upcase(program_name);

    if index(strip(program_name), strip(domain_name)) = 0 then do;
      call symputx('domain_mismatch', '1');
    end;
    else call symputx('domain_mismatch', '0');
  run;

  %* Exit the macro if DOMAIN does not match the program name;
  %if &domain_mismatch. = 1 %then %do;
    %put WARN%STR(ING:) [%upcase(&sysmacroname.)] Program name in the SASFILE does not contain the DOMAIN. (Domain/File mismatch);
    %return;
  %end;

  %*--- Check if ENGINE version is valid;
  %if %sysfunc(fileexist(&jarpath.\engines\versions)) = 1 %then %do;
    %let jsonpath1=&jarpath.\engines\engines.json;
    %let jsonpath2=&jarpath.\engines\engines_v4.json;

    libname jsonlib1 json "&jsonpath1";
    libname jsonlib2 json "&jsonpath2";

    data combined_engines;
      length id 8. engine engine2 $200;;
      set jsonlib1.alldata jsonlib2.alldata;
      retain id engine engine2;

      if p1="id" then id+1;

      if p1="name" then engine=value;
      if p1="version" then engine2=strip(engine) || " " || strip(value);

      if missing(engine2) then delete;

      engine3 = "&engine.";
      
      keep engine2 engine3;
    run;  

    proc sort data=combined_engines nodup;
      by engine2;
    run;

    data combined_engines2;
      set combined_engines;
      retain match_found 0;
      if engine2 = engine3 then match_found = 1;

      call symputx('match_found', match_found);

    run;

    proc datasets library=work nolist;
      delete combined_engines combined_engines2;
    quit;

    %if &match_found. = 0 %then %do;
      %put WARNING: The specified ENGINE "&engine." does not exist.;
      %return;
    %end;
  %end;

  %let jarpath2 = &jarpath.;
  %let jarfile2 = &jarfile.;
  %let model = &library.;

  %*--- options to not hang on windows OS;
  options noxsync noxwait;

  %*--- temp work path;
  %let work_path = %sysfunc(getoption(work));

  %* Fix global variables to match intended - or .;
  %let sdtm_ig2 = %sysfunc(tranwrd(&sdtm_ig, _, .));
  %let sdtm_ct2 = %sysfunc(tranwrd(&sdtm_ct, _, -));
  %let adam_ig2 = %sysfunc(tranwrd(&adam_ig, _, .));
  %let adam_ct2 = %sysfunc(tranwrd(&adam_ct, _, -));

  %*--- remove sortedby to avoid warn-ing;
  data &domain. (sortedby=_null_);
    set &model..&domain.;
  run;

  %*--- options to hang on windows OS;
  options xsync xwait;

  %* Check mode and configure options accordingly;
  %if %upcase(&library.) = SDTM or %upcase(&library.) = SDTMQ %then %do;
    %*--- SDTM mode settings;
    %let standard = sdtm;
    %let standard_version = &sdtm_ig2.;
    %let ct_version = &sdtm_ct2.;
  %end;
  %else %if %upcase(&library.) = ADAM or %upcase(&library.) = ADAMQ %then %do;
    %*--- ADaM mode settings;
    %let standard = adam;
    %let standard_version = &adam_ig2.;
    %let ct_version = &adam_ct2.;
  %end;

  %*--- Check if the specified &sdtm_ct2. file exists in the folder;
  %let sdtm_ct2_path = C:\Program Files (x86)\Pinnacle 21 Community\resources\app.asar.unpacked\components\lib\configs\data\CDISC\SDTM\&sdtm_ct2.;
  %if %sysfunc(fileexist(&sdtm_ct2_path.)) = 0 %then %do;
      %put WARN%STR(ING:) [%upcase(&sysmacroname.)] The specified Controlled Terminology "&sdtm_ct2." does not exist in the folder "&sdtm_ct2_path.", please add to the remote desktop.;
      %return;
  %end;
  
  %*--- Check if the specified &adam_ct2. file exists in the folder;
  %let adam_ct2_path = C:\Program Files (x86)\Pinnacle 21 Community\resources\app.asar.unpacked\components\lib\configs\data\CDISC\ADaM\&adam_ct2.;
  %if %sysfunc(fileexist(&adam_ct2_path.)) = 0 %then %do;
      %put WARN%STR(ING:) [%upcase(&sysmacroname.)] The specified Controlled Terminology "&adam_ct2." does not exist in the folder "&adam_ct2_path.", please add to the remote desktop.;
      %return;
  %end;

  %* List of datasets to process;
  %let datasets = &domain. supp&domain.;

  %local i ds_to_check ds_all;
  %let ds_all = ;

  %do i = 1 %to %sysfunc(countw(&datasets.));
    %let ds_to_check = %scan(&datasets., &i);

    %* Check if the dataset exists;
    %if %sysfunc(exist(&library..&ds_to_check.)) %then %do;
      %put NOTE: Dataset &library..&ds_to_check. exists. Processing...;

      %*--- Prepare temporary work path and XPT export;
      %let work_path = %sysfunc(getoption(work));

      data &ds_to_check. (sortedby=_null_);
        set &library..&ds_to_check.;
      run;

    %if %upcase(%substr(&library., %length(&library.))) = Q %then %do;
        %*--- Append the current dataset path to ds_all;
        %if %length(&ds_all) > 0 %then %let ds_all = &ds_all.%str(;);
        %let ds_all = &ds_all.&study_path\Deliverable\Data\%sysfunc(compress(&library., qQ))\qc\xpt\&ds_to_check..xpt;
        %put &ds_all.;
     %end;
    %if %upcase(%substr(&library., %length(&library.))) ^= Q %then %do;
        %*--- Append the current dataset path to ds_all;
        %if %length(&ds_all) > 0 %then %let ds_all = &ds_all.%str(;);
        %let ds_all = &ds_all.&study_path\Deliverable\Data\&library\xpt\&ds_to_check..xpt;
        %put &ds_all.;
     %end;
    %end;
  %end;

    %*--- engine version may need updating in the future;
    x javaw -Xmx1024M -Xms1024M 
      -jar "&jarpath2.\&jarfile2." ^
      --engine.version="&engine." ^
      --standard=&standard ^
      --standard.version="&standard_version." ^
      --source.&standard.="&ds_all." ^
      --cdisc.ct.&standard..version="&ct_version." ^
      --report="&work_path\&domain..xlsx"
    ;

    %*--- import validation checks - summary;
    proc import datafile="&work_path\&domain..xlsx"
      out=&domain._summary
      dbms=xlsx
      replace;
      sheet="Issue Summary";
      getnames=yes;
    run;

    %*--- import validation checks - details;

    proc import datafile="&work_path\&domain..xlsx"
    out=&domain._details (where=(
        upcase(domain) = upcase("&domain.") or
        upcase(domain) = upcase("supp&domain.")
      ) drop=severity category count)
      dbms=xlsx
      replace;
      sheet="Details";
      getnames=yes;
    run;

    %*--- import validation checks - rules;
    proc import datafile="&work_path\&domain..xlsx"
      out=&domain._rules (drop=severity category)
      dbms=xlsx
      replace;
      sheet="Rules";
      getnames=yes;
    run;

    %*--- merge on description for p21 ID;
    proc sql noprint;
      create table &domain._p21 as
      select a.*, 
        b.description
      from &domain._details as a
      left join &domain._rules as b
      on a.PINNACLE_21_ID = b.PINNACLE_21_ID;
    quit;


    %*---- validation checks specific to domain;
    data &domain._summary2;
      set &domain._summary;
      retain pinnacle_21_validator_report2;
      if pinnacle_21_validator_report ne "" then 
        pinnacle_21_validator_report2 = pinnacle_21_validator_report;
      
      if (pinnacle_21_validator_report2 = "%upcase(&domain.)" or 
          pinnacle_21_validator_report2 = "%upcase(supp&domain.)") and 
         c ne "" then output;

      drop pinnacle_21_validator_report2;
      rename b = p21_id
             c = message
             d = severity
             e = count;
    run;

    %if %upcase(%substr(&library., %length(&library.))) = Q %then %do;
    data &library.21.&domain.;
       set &domain._p21;
    run;
   %end;
    %if %upcase(%substr(&library., %length(&library.))) ^= Q %then %do;
    data &library.P21.&domain.;
       set &domain._p21;
    run;
   %end;

    %if %upcase(&cleanup.)=Y %then %do;
      /* delete the temporary dataset */

      data _null_;
        fname = "tempfile";
        rc = filename(fname, "&work_path\&domain..xlsx");
          if rc = 0 and fexist(fname) then do;
            rc = fdelete(fname);
          end;

        rc2 = filename(fname, "&work_path\supp&domain..xlsx");
          if rc2 = 0 and fexist(fname) then do;
            rc2 = fdelete(fname);
          end;
      run;
  %end;

  %if %upcase(&cleanup.)=Y %then %do;
    /* Silently delete the temporary libs */
    options nonotes;
    libname jsonlib1 clear;
    libname jsonlib2 clear;
    *libname temp_xpt clear;
    options notes;
  %end;

  %*---- output to console;
  data _null_;
    set &domain._summary2;
    put "P21: Domain=&domain., " Message=;
  run;

  %put NOTE: %upcase(&sysmacroname.).SAS has executed.;

%mend m_p21;
