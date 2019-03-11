class lcl_status_view definition final inheriting from lcl_view_base.
  public section.

    methods constructor
      importing
        iv_package  type devclass
        it_contents type zif_abapgit_definitions=>ty_results_tt.

    methods display redefinition.
    methods on_user_command redefinition.
    methods on_double_click redefinition.

    events on_drill_down
      exporting
        value(file) type zif_abapgit_definitions=>ty_result
        value(show_object) type abap_bool.

    events on_pull.

  private section.
    data mv_package type devclass.

    methods build_toolbar
      returning
        value(rt_buttons) type ttb_button.

endclass.

class lcl_status_view implementation.

  method constructor.
    super->constructor( ).
    copy_content( it_contents ).
    mv_package = iv_package.
  endmethod.

  method display.

    create_alv( ).
    set_column_tech_names( ).
    set_default_handlers( ).
    set_default_layout( |Status found for package { mv_package }| ).
    set_sorting( 'obj_type, obj_name' ).
    set_toolbar( build_toolbar( ) ).
    mo_alv->display( ).

  endmethod.

  method on_user_command.

    data lv_msg type string.
    lv_msg = |User asked for: { iv_cmd }|.
    message lv_msg type 'I'.

    if iv_cmd = 'ZPULL'.
      raise event on_pull.
    endif.

  endmethod.                    "on_user_command

  method on_double_click.

    field-symbols <tab> type zif_abapgit_definitions=>ty_results_tt.
    field-symbols <line> like line of <tab>.

    assign mr_data->* to <tab>.
    read table <tab> assigning <line> index iv_row.

    if <line>-match is not initial.
      message 'Objects match' type 'I'.
      return.
    endif.

    data lv_show_object type abap_bool.
    lv_show_object = boolc( iv_column = 'OBJ_TYPE' or iv_column = 'OBJ_NAME' ).

    raise event on_drill_down
      exporting
        file = <line>
        show_object = lv_show_object.

  endmethod.

  method build_toolbar.

    field-symbols <b> like line of rt_buttons.

*    " toolbar seperator
*    clear ls_toolbar.
*    ls_toolbar-butn_type = 3.
*    append ls_toolbar to rt_buttons.

    " Custom command
    append initial line to rt_buttons assigning <b>.
    <b>-function  = 'ZHELLO'.
    <b>-quickinfo = 'Custom command'.
    <b>-icon      = icon_failure.
    <b>-disabled  = space.
    <b>-text      = 'Hello button'.

    append initial line to rt_buttons assigning <b>.
    <b>-function  = 'ZPULL'.
    <b>-quickinfo = 'Import code'.
    <b>-icon      = icon_set_state.
    <b>-disabled  = space.
    <b>-text      = 'Import'.

  endmethod.

endclass.
