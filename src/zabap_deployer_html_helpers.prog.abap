class lcl_mustache_page definition final.
  public section.
    interfaces zif_abapgit_gui_renderable.
    class-methods create
      importing
        io_data type ref to zcl_mustache_data
        iv_template_url type string optional
        io_mustache type ref to zcl_mustache optional
      returning
        value(ro_component) type ref to lcl_mustache_page
      raising zcx_mustache_error zcx_abapgit_exception.
  private section.
    data mo_data type ref to zcl_mustache_data.
    data mo_mustache type ref to zcl_mustache.

endclass.

class lcl_mustache_page implementation.

  method zif_abapgit_gui_renderable~render.

    data lv_out     type string.
    try.
      lv_out = mo_mustache->render( mo_data->get( ) ).

      zcl_w3mime_fs=>write_file_x(
        iv_filename = 'mustache.txt'
        iv_data = cl_bcs_convert=>string_to_xstring( iv_string = lv_out ) ).

    catch zcx_mustache_error.
      zcx_abapgit_exception=>raise( 'Error rendering table component' ).
    endtry.

    create object ro_html type zcl_abapgit_html.
    ro_html->add( lv_out ).

  endmethod.

  method create.

    create object ro_component.
    ro_component->mo_data     = io_data.

    if iv_template_url is not initial.
      data lo_asset_man type ref to zif_abapgit_gui_asset_manager.
      data lv_template type string.
      lo_asset_man ?= lcl_gui_factory=>get_asset_man( ).
      lv_template   = lo_asset_man->get_text_asset( iv_template_url ).
      ro_component->mo_mustache = zcl_mustache=>create( lv_template ).
    elseif io_mustache is bound.
      ro_component->mo_mustache = io_mustache.
    else.
      zcx_abapgit_exception=>raise( 'Cannot create mustache page - no template' ).
    endif.

  endmethod.

endclass.
