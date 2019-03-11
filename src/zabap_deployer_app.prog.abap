include zguibp_error.
include zguibp_alv.

include zabap_deployer_diff_model.
include zabap_deployer_diff_view.
include zabap_deployer_status_view.

class lcl_app definition final.
  public section.
    methods constructor
      importing
        iv_package  type devclass
        iv_filepath type string.
    methods run
      raising zcx_abapgit_exception lcx_guibp_error.

    methods on_status_drill_down
      for event on_drill_down of lcl_status_view
      importing
        file
        show_object.

    methods on_pull
      for event on_pull of lcl_status_view.

  private section.
    data mv_package  type devclass.
    data mv_filepath type string.
    data mo_repo type ref to zcl_abapgit_repo_offline.

    class-methods load_repo
      importing
        iv_package type devclass
        iv_xdata type xstring
      returning
        value(ro_repo) type ref to zcl_abapgit_repo_offline
      raising zcx_abapgit_exception.

endclass.

class lcl_app implementation.
  method constructor.
    mv_package = iv_package.
    mv_filepath = iv_filepath.
  endmethod.

  method load_repo.
    data lt_files type zif_abapgit_definitions=>ty_files_tt.
    lt_files = zcl_abapgit_zip=>unzip_file( iv_xdata ).

    field-symbols <f> like line of lt_files.
    read table lt_files assigning <f> with key
      path     = zif_abapgit_definitions=>c_root_dir
      filename = zif_abapgit_definitions=>c_dot_abapgit.

    data lo_dot type ref to zcl_abapgit_dot_abapgit.
    if sy-subrc is initial.
      lo_dot = zcl_abapgit_dot_abapgit=>deserialize( <f>-data ).
    else.
      lo_dot = zcl_abapgit_dot_abapgit=>build_default( ).
    endif.

    data ls_repo type zif_abapgit_persistence=>ty_repo.
    ls_repo-key          = '$'.
    ls_repo-url          = ''.
    ls_repo-package      = iv_package.
    ls_repo-offline      = abap_true.
    ls_repo-dot_abapgit  = lo_dot->get_data( ).

    create object ro_repo exporting is_data = ls_repo.

    ro_repo->rebuild_local_checksums( ).
    ro_repo->set_files_remote( lt_files ).

  endmethod.

  method run.

    data lv_xdata type xstring.
    lv_xdata = zcl_abapgit_factory=>get_frontend_services( )->file_upload( mv_filepath ).

    mo_repo = load_repo(
      iv_xdata   = lv_xdata
      iv_package = mv_package ).

    data lo_log type ref to zcl_abapgit_log.
    create object lo_log.

    data lt_status type zif_abapgit_definitions=>ty_results_tt.
    lt_status = zcl_abapgit_file_status=>status(
      io_repo = mo_repo
      io_log  = lo_log ).

    " TODO process log !

    data lo_view type ref to lcl_status_view.
    create object lo_view
      exporting
        iv_package  = mv_package
        it_contents = lt_status.

    set handler on_status_drill_down for lo_view.
    set handler on_pull for lo_view.
    lo_view->display( ).

  endmethod.

  method on_status_drill_down.

    data lo_diff_model type ref to lcl_diff_model.
    create object lo_diff_model
      exporting
        it_remote = mo_repo->get_files_remote( )
        it_local  = mo_repo->get_files_local( ).

    lo_diff_model->add( file ).

    data lo_html type ref to lcl_diff_view.
    data lx type ref to cx_root.
    create object lo_html.
    try .
      lo_html->run( lo_diff_model ).
    catch lcx_guibp_error zcx_mustache_error zcx_abapgit_exception into lx.
      message lx type 'E' display like 'S'.
    endtry.

  endmethod.

  method on_pull.

    zcl_abapgit_services_repo=>gui_deserialize( mo_repo ).
    mo_repo->refresh( ).

*    update_content( )

  endmethod.

endclass.
