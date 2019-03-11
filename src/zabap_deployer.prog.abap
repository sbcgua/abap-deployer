report zabap_deployer.

include zabap_deployer_app.

**********************************************************************
* ENTRY POINT
**********************************************************************

form main using pv_path pv_package.
  data lx type ref to cx_static_check.

  if pv_path is initial.
    message 'Path is mandatory' type 'S' display like 'E'. "#EC NOTEXT
  endif.

  if pv_package is initial.
    message 'Package is mandatory' type 'S' display like 'E'. "#EC NOTEXT
  endif.

  try.
    data lo_app type ref to lcl_app.
    create object lo_app
      exporting
        iv_filepath = |{ pv_path }|
        iv_package  = pv_package.
    lo_app->run( ).
  catch zcx_abapgit_exception lcx_guibp_error into lx.
    message lx type 'E'.
  endtry.

endform.

form f4_file_path changing c_path.
  data:
        lt_files type filetable,
        lv_rc    type i,
        lv_uact  type i.

  field-symbols <file> like line of lt_files.
  clear c_path.

  cl_gui_frontend_services=>file_open_dialog(
    changing
      file_table  = lt_files
      rc          = lv_rc
      user_action = lv_uact
    exceptions others = 4 ).

  if sy-subrc > 0 OR lv_uact <> cl_gui_frontend_services=>action_ok.
    return. " Empty value
  endif.

  read table lt_files assigning <file> index 1.
  if sy-subrc = 0.
    c_path = <file>-filename.
  endif.
endform.

**********************************************************************
* SELECTION SCREEN
**********************************************************************

selection-screen begin of block b1 with frame title txt_b1.

selection-screen begin of line.
selection-screen comment (24) t_path for field p_path.
parameters p_path type char255 visible length 40.
selection-screen end of line.

selection-screen begin of line.
selection-screen comment (24) t_pkg for field p_pkg.
parameters p_pkg type devclass visible length 40.
selection-screen end of line.

selection-screen end of block b1.

**********************************************************************
* ENTRY POINT
**********************************************************************

initialization.
  txt_b1   = 'Deploy package'.            "#EC NOTEXT
  t_path   = 'Path to zip file'.          "#EC NOTEXT
  t_pkg    = 'Package to update'.         "#EC NOTEXT

  p_path = 'C:\USERS\ALEX\DOCUMENTS\SAP\SAP GUI\ZGIT_TRANSLATE_TEST_1.ZIP'.
  p_pkg = 'ZGIT_TRANSLATE_TEST'.

at selection-screen on value-request for p_path.
  perform f4_file_path changing p_path.

start-of-selection.
  perform main using p_path p_pkg.
