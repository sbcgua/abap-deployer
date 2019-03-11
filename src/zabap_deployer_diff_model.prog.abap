class lcl_diff_utils definition final.
  public section.

    types:
      begin of ty_state_one_hot,
        nochange type abap_bool,
        notexist type abap_bool,
        modified type abap_bool,
        added    type abap_bool,
        deleted  type abap_bool,
        mixed    type abap_bool,
      end of ty_state_one_hot,

      begin of ty_state_one_hot_rl,
        l type ty_state_one_hot,
        r type ty_state_one_hot,
      end of ty_state_one_hot_rl.

    types:
      begin of ty_line_state_one_hot,
        non type abap_bool,
        ins type abap_bool,
        upd type abap_bool,
        del type abap_bool,
      end of ty_line_state_one_hot.

    class-methods one_hot_state
      importing
        iv_lstate	type c
        iv_rstate	type c
      returning
        value(rs_state) type ty_state_one_hot_rl.

    class-methods one_hot_line_state
      importing
        iv_result	type c
      returning
        value(rs_state) type ty_line_state_one_hot.

    class-methods get_file_extension
      importing
        iv_filename type string
      returning
        value(rv_ext) type string.

    class-methods is_binary
      importing iv_d1         type xstring
                iv_d2         type xstring
      returning value(rv_yes) type abap_bool.

endclass.

class lcl_diff_utils implementation.

  method get_file_extension.

    data lv_offs type i.

    lv_offs = find( val = reverse( iv_filename ) sub = '.' ).
    if lv_offs < 0.
      return.
    endif.

    lv_offs = strlen( iv_filename ) - lv_offs.
    rv_ext = substring( val = iv_filename off = lv_offs ).

  endmethod.

  method one_hot_line_state.

    case iv_result.
      when zif_abapgit_definitions=>c_diff-update.
        rs_state-upd = abap_true.
      when zif_abapgit_definitions=>c_diff-delete.
        rs_state-del = abap_true.
      when zif_abapgit_definitions=>c_diff-insert.
        rs_state-ins = abap_true.
      when others.
        rs_state-non = abap_true.
    endcase.

  endmethod.

  method one_hot_state.

    field-symbols <state> type char1.
    field-symbols <state_oh> type ty_state_one_hot.

    do 2 times.
      case sy-index.
        when 1.
          assign iv_lstate to <state>.
          assign rs_state-l to <state_oh>.
        when 2.
          assign iv_rstate to <state>.
          assign rs_state-r to <state_oh>.
      endcase.

      case <state>.
        when zif_abapgit_definitions=>c_state-unchanged.  "none or unchanged
          if iv_lstate = zif_abapgit_definitions=>c_state-added or iv_rstate = zif_abapgit_definitions=>c_state-added.
            <state_oh>-notexist = abap_true.
          else.
            <state_oh>-nochange = abap_true.
          endif.
        when zif_abapgit_definitions=>c_state-modified.   "changed
          <state_oh>-modified = abap_true.
        when zif_abapgit_definitions=>c_state-added.      "added new
          <state_oh>-added = abap_true.
        when zif_abapgit_definitions=>c_state-mixed.      "multiple changes (multifile)
          <state_oh>-mixed = abap_true.
        when zif_abapgit_definitions=>c_state-deleted.    "deleted
          <state_oh>-deleted = abap_true.
      endcase.

    enddo.
  endmethod.

  method is_binary.

    data: lv_len type i,
          lv_idx type i,
          lv_x   type x.

    field-symbols <lv_data> like iv_d1.


    if iv_d1 is not initial. " one of them might be new and so empty
      assign iv_d1 to <lv_data>.
    else.
      assign iv_d2 to <lv_data>.
    endif.

    lv_len = xstrlen( <lv_data> ).
    if lv_len = 0.
      return.
    endif.

    if lv_len > 100.
      lv_len = 100.
    endif.

    " simple char range test
    " stackoverflow.com/questions/277521/how-to-identify-the-file-content-as-ascii-or-binary
    do lv_len times. " i'm sure there is more efficient way ...
      lv_idx = sy-index - 1.
      lv_x = <lv_data>+lv_idx(1).

      if not ( lv_x between 9 and 13 or lv_x between 32 and 126 ).
        rv_yes = abap_true.
        exit.
      endif.
    enddo.

  endmethod.

endclass.


class lcl_diff_model definition final.
  public section.

    types:
      begin of ty_diff_line,
        state      type lcl_diff_utils=>ty_line_state_one_hot,
        new_num    type c length 6,
        old_num    type c length 6,
        new        type string,
        old        type string,
        short      type abap_bool,
        beacon     type i,
      end of ty_diff_line,
      tt_diff_line type standard table of ty_diff_line with default key .

    types:
      begin of ty_diff,
        filename      type string,
        ins_cnt       type i,
        del_cnt       type i,
        upd_cnt       type i,
        changed_by    type string,
        state         type lcl_diff_utils=>ty_state_one_hot_rl,
        both_changed  type abap_bool,
        type          type string,
        o_diff        type ref to zcl_abapgit_diff,
        lines         type tt_diff_line,
      end of ty_diff,

      tt_diff type standard table of ty_diff with key filename.

    methods constructor
      importing
        it_remote type zif_abapgit_definitions=>ty_files_tt
        it_local  type zif_abapgit_definitions=>ty_files_item_tt.

    methods add
      importing
        is_status type zif_abapgit_definitions=>ty_result.

    methods get
      returning
        value(rt_diffs) type tt_diff.

  private section.
    data mt_remote type zif_abapgit_definitions=>ty_files_tt.
    data mt_local  type zif_abapgit_definitions=>ty_files_item_tt.
    data mt_diffs  type tt_diff.

    methods build_diff_head
      importing
        is_status type zif_abapgit_definitions=>ty_result
      returning
        value(rs_diff) type ty_diff.

    methods build_diff_lines
      changing
        cs_diff type ty_diff.

endclass.

class lcl_diff_model implementation.

  method constructor.
    mt_local  = it_local.
    mt_remote = it_remote.
  endmethod.

  method get.
    rt_diffs = mt_diffs.
  endmethod.

  method build_diff_head.

    field-symbols <remote> like line of mt_remote.
    field-symbols <local>  like line of mt_local.

    rs_diff-filename = is_status-path && is_status-filename.
    rs_diff-state = lcl_diff_utils=>one_hot_state(
      iv_lstate = is_status-lstate
      iv_rstate = is_status-rstate ).

    data ls_r_dummy like line of mt_remote ##needed.
    data ls_l_dummy like line of mt_local  ##needed.

    read table mt_remote assigning <remote>
      with key
        filename = is_status-filename
        path     = is_status-path.
    if sy-subrc <> 0.
      assign ls_r_dummy to <remote>.
    endif.

    read table mt_local assigning <local>
      with key
        file-filename = is_status-filename
        file-path     = is_status-path.
    if sy-subrc <> 0.
      assign ls_l_dummy to <local>.
    endif.

    if <local> is initial and <remote> is initial.
      zcx_abapgit_exception=>raise( |diff: file not found { is_status-filename }| ).
    endif.

    " changed by
    if <local>-item-obj_type is not initial.
      rs_diff-changed_by = to_lower( zcl_abapgit_objects=>changed_by( <local>-item ) ).
    endif.

    " extension
    rs_diff-type = lcl_diff_utils=>get_file_extension( is_status-filename ).

    if rs_diff-type <> 'xml' and rs_diff-type <> 'abap'.
      if lcl_diff_utils=>is_binary( iv_d1 = <remote>-data iv_d2 = <local>-file-data ) = abap_true. " TODO reuse abapgit
        rs_diff-type = 'binary'.
      else.
        rs_diff-type = 'other'.
      endif.
    endif.

    " diff data
    if rs_diff-type <> 'binary'.
      if is_status-lstate is initial and is_status-rstate is not initial. " remote file leading changes
        create object rs_diff-o_diff
          exporting
            iv_new = <remote>-data
            iv_old = <local>-file-data.
      else.             " local leading changes or both were modified
        create object rs_diff-o_diff
          exporting
            iv_new = <local>-file-data
            iv_old = <remote>-data.
      endif.
    endif.

    " Both changed
    rs_diff-both_changed = boolc( is_status-lstate is not initial and is_status-rstate is not initial ).

    " counts
    data ls_stats type zif_abapgit_definitions=>ty_count.
    ls_stats = rs_diff-o_diff->stats( ).
    if is_status-lstate is not initial and is_status-rstate is not initial. " merge stats into 'update' if both were changed
      ls_stats-update = ls_stats-update + ls_stats-insert + ls_stats-delete.
      clear: ls_stats-insert, ls_stats-delete.
    endif.
    rs_diff-ins_cnt = ls_stats-insert.
    rs_diff-del_cnt = ls_stats-delete.
    rs_diff-upd_cnt = ls_stats-update.

  endmethod.

  method build_diff_lines.

    " diff lines
    data lt_diffs      type zif_abapgit_definitions=>ty_diffs_tt.
    data lv_insert_nav type abap_bool.
    data lt_beacons    type string_table.

    field-symbols <src> like line of lt_diffs.
    field-symbols <dst> like line of cs_diff-lines.

    lt_diffs = cs_diff-o_diff->get( ).
    lt_beacons = cs_diff-o_diff->get_beacons( ).

    data lo_highlighter type ref to zcl_abapgit_syntax_highlighter.
    lo_highlighter = zcl_abapgit_syntax_highlighter=>create( cs_diff-filename ).

    loop at lt_diffs assigning <src>.

      if cs_diff-both_changed = abap_true.
        <src>-result = zif_abapgit_definitions=>c_diff-update.
      endif.

      if <src>-short = abap_false.
        lv_insert_nav = abap_true.
        continue.
      endif.

      if lv_insert_nav = abap_true. " insert separator line with navigation
        append initial line to cs_diff-lines assigning <dst>.
        <dst>-beacon = 1. " Mark beacons with non zero value
        if <src>-beacon > 0.
          read table lt_beacons into <dst>-new index <src>-beacon.
          <dst>-new = |@@ { <src>-new_num } @@ { <dst>-new }|.
        else.
          <dst>-new = '@@ ---'.
        endif.
        lv_insert_nav = abap_false.
      endif.

      append initial line to cs_diff-lines assigning <dst>.
      move-corresponding <src> to <dst>.
      clear <dst>-beacon. " Mark non-beacons with zero value
      <dst>-state = lcl_diff_utils=>one_hot_line_state( <src>-result ).

      if lo_highlighter is bound.
        <dst>-new = lo_highlighter->process_line( <dst>-new ).
        <dst>-old = lo_highlighter->process_line( <dst>-old ).
      else.
        <dst>-new = escape( val = <dst>-new format = cl_abap_format=>e_html_attr ).
        <dst>-old = escape( val = <dst>-old format = cl_abap_format=>e_html_attr ).
      endif.

      condense <dst>-new_num. "get rid of leading spaces
      condense <dst>-old_num.

*      if mv_unified = abap_true.
*        ro_html->add( render_line_unified( is_diff_line = <ls_diff> ) ).
*      else.
*        ro_html->add( render_line_split( is_diff_line = <ls_diff>
*                                         iv_filename  = is_diff-filename
*                                         iv_fstate    = is_diff-fstate
*                                         iv_index     = lv_tabix ) ).
*      endif.

    endloop.

  endmethod.

  method add.

    field-symbols <remote> like line of mt_remote.
    field-symbols <local>  like line of mt_local.
    field-symbols <diff>   like line of mt_diffs.

    if is_status-match = abap_true.
      return.
    endif.

    append initial line to mt_diffs assigning <diff>.
    <diff> = build_diff_head( is_status ).
    build_diff_lines( changing cs_diff = <diff> ).

  endmethod.

endclass.
