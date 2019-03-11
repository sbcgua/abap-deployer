include zguibp_html.
include zabap_deployer_html_helpers.

class lcl_diff_view definition final.
  public section.

    methods run
      importing
        io_diff_model type ref to lcl_diff_model
      raising
        lcx_guibp_error zcx_mustache_error zcx_abapgit_exception.
    methods create_asset_manager
      returning
        value(ro_asset_man) type ref to zcl_abapgit_gui_asset_manager.
    methods build_data
      importing
        io_diff_model type ref to lcl_diff_model
      returning
        value(ro_data) type ref to zcl_mustache_data.

  private section.

endclass.

class lcl_diff_view implementation.
  method run.
    lcl_gui_factory=>init( ii_asset_man = create_asset_manager( ) ).

    data lo_asset_man type ref to zif_abapgit_gui_asset_manager.
    lo_asset_man ?= lcl_gui_factory=>get_asset_man( ).
    data lo_mustache type ref to zcl_mustache.
    lo_mustache = zcl_mustache=>create(
      iv_template = lo_asset_man->get_text_asset( 'templates/diff.mustache' )
      iv_x_format = '' ). " No escaping

    data lo_diff_page type ref to lcl_mustache_page.
    lo_diff_page = lcl_mustache_page=>create(
      io_mustache = lo_mustache
      io_data     = build_data( io_diff_model ) ).

    lcl_gui_factory=>run( lcl_page_hoc=>wrap(
      iv_page_title = 'Diff page'
      iv_add_styles = 'css/diff.css'
      ii_child      = lo_diff_page ) ).
  endmethod.

  method create_asset_manager.
    " used by abapmerge
    define _inline.
      append &1 to lt_data.
    end-of-definition.

    data lt_inline type string_table.

    create object ro_asset_man type zcl_abapgit_gui_asset_manager.

    clear lt_inline.
    " @@abapmerge include zgui_boilerplate_css_common.w3mi.data.css > _inline '$$'.
    ro_asset_man->register_asset(
      iv_url       = 'css/common.css'
      iv_type      = 'text/css'
      iv_mime_name = 'ZGUIBP_CSS_COMMON'
      iv_inline    = concat_lines_of( table = lt_inline sep = cl_abap_char_utilities=>newline ) ).

    clear lt_inline.
    " @@abapmerge include zgui_boilerplate_js_common.w3mi.data.js > _inline '$$'.
    ro_asset_man->register_asset(
      iv_url       = 'js/common.js'
      iv_type      = 'text/javascript'
      iv_mime_name = 'ZGUIBP_JS_COMMON'
      iv_inline    = concat_lines_of( table = lt_inline sep = cl_abap_char_utilities=>newline ) ).

    clear lt_inline.
    " @@abapmerge include zabap_deployer_diff_css.w3mi.data.css > _inline '$$'.
    ro_asset_man->register_asset(
      iv_url       = 'css/diff.css'
      iv_type      = 'text/css'
      iv_mime_name = 'ZABAP_DEPLOYER_DIFF_CSS'
      iv_inline    = concat_lines_of( table = lt_inline sep = cl_abap_char_utilities=>newline ) ).

    clear lt_inline.
    " @@abapmerge include zabap_deployer_diff_mustache.w3mi.data.mustache > _inline '$$'.
    ro_asset_man->register_asset(
      iv_url       = 'templates/diff.mustache'
      iv_type      = 'text/plain'
      iv_mime_name = 'ZABAP_DEPLOYER_DIFF_MUSTACHE'
      iv_cachable  = abap_false
      iv_inline    = concat_lines_of( table = lt_inline sep = cl_abap_char_utilities=>newline ) ).

  endmethod.

  method build_data. " Create some dummy data

    create object ro_data.
    ro_data->add( iv_name = 'diffs' iv_val = io_diff_model->get( ) ).

  endmethod.

endclass.
