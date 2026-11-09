CLASS zcl_drj_tma_comp_role_qp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_result,
        compositerolekey         TYPE c LENGTH 160,
        sequence                 TYPE i,
        rolename                 TYPE agr_name,
        compositerolename        TYPE agr_name,
        compositeroledescription TYPE c LENGTH 255,
        rolescontained           TYPE i,
        excludeownmenu           TYPE c LENGTH 1,
      END OF ty_result.

    TYPES ty_t_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    CLASS-METHODS get_filter_value
      IMPORTING
        it_filter_ranges TYPE if_rap_query_filter=>tt_name_range_pairs
        iv_name          TYPE string
      RETURNING
        VALUE(rv_value)  TYPE string.

    CLASS-METHODS get_role_description
      IMPORTING
        iv_role                     TYPE agr_name
      RETURNING
        VALUE(rv_role_description)  TYPE string.

    CLASS-METHODS get_roles_contained_count
      IMPORTING
        iv_composite_role TYPE agr_name
      RETURNING
        VALUE(rv_count)   TYPE i.

    CLASS-METHODS apply_paging
      IMPORTING
        it_result        TYPE ty_t_result
        io_request       TYPE REF TO if_rap_query_request
      RETURNING
        VALUE(rt_result) TYPE ty_t_result.

ENDCLASS.



CLASS zcl_drj_tma_comp_role_qp IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_filter_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

    TRY.
        lt_filter_ranges = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter_ranges.
    ENDTRY.

*--------------------------------------------------------------------
* Mandatory filter
*--------------------------------------------------------------------
    DATA(lv_role_name) =
      get_filter_value(
        it_filter_ranges = lt_filter_ranges
        iv_name          = 'ROLENAME' ).

*--------------------------------------------------------------------
* Optional filter
*--------------------------------------------------------------------
    DATA(lv_exclude_own_menu) =
      get_filter_value(
        it_filter_ranges = lt_filter_ranges
        iv_name          = 'EXCLUDEOWNMENU' ).

    IF lv_exclude_own_menu IS INITIAL.
      lv_exclude_own_menu = abap_true.
    ENDIF.

    DATA(lv_exclude_own_menu_bool) =
      xsdbool( lv_exclude_own_menu = abap_true
            OR lv_exclude_own_menu = 'X'
            OR lv_exclude_own_menu = 'x'
            OR lv_exclude_own_menu = 'true'
            OR lv_exclude_own_menu = 'TRUE' ).

*--------------------------------------------------------------------
* Protect backend from full unfiltered calls
*--------------------------------------------------------------------
    IF lv_role_name IS INITIAL.

      DATA lt_empty TYPE ty_t_result.

      IF io_request->is_total_numb_of_rec_requested( ).
        io_response->set_total_number_of_records( 0 ).
      ENDIF.

      IF io_request->is_data_requested( ).
        io_response->set_data( lt_empty ).
      ENDIF.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Build single-role input
*--------------------------------------------------------------------
    DATA lt_role_ids TYPE /ui2/if_nwbc_runtime=>t_role_ids.

    APPEND CONV agr_name( lv_role_name ) TO lt_role_ids.

*--------------------------------------------------------------------
* Resolve composite roles
*--------------------------------------------------------------------
    DATA(lt_composite_role_ids) =
      zcl_drj_flp_start_up_utility=>get_composite_roles_for_roles(
        it_role_ids                 = lt_role_ids
        iv_exclude_roles_w_own_menu = lv_exclude_own_menu_bool ).

*--------------------------------------------------------------------
* Build response
*--------------------------------------------------------------------
    DATA lt_result TYPE ty_t_result.
    DATA lv_sequence TYPE i.

    LOOP AT lt_composite_role_ids INTO DATA(lv_composite_role_id).

      IF lv_composite_role_id IS INITIAL.
        CONTINUE.
      ENDIF.

      lv_sequence += 1.

      APPEND VALUE ty_result(
        compositerolekey         = |CR{ lv_sequence WIDTH = 10 PAD = '0' }|
        sequence                 = lv_sequence
        rolename                 = CONV #( lv_role_name )
        compositerolename        = CONV #( lv_composite_role_id )
        compositeroledescription = CONV #( get_role_description( CONV agr_name( lv_composite_role_id ) ) )
        rolescontained           = get_roles_contained_count( CONV agr_name( lv_composite_role_id ) )
        excludeownmenu           = COND #( WHEN lv_exclude_own_menu_bool = abap_true THEN 'X' ELSE '' ) )
        TO lt_result.

    ENDLOOP.

*--------------------------------------------------------------------
* Total count before paging
*--------------------------------------------------------------------
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.

*--------------------------------------------------------------------
* Data after paging
*--------------------------------------------------------------------
    IF io_request->is_data_requested( ).

      DATA(lt_paged_result) =
        apply_paging(
          it_result  = lt_result
          io_request = io_request ).

      io_response->set_data( lt_paged_result ).

    ENDIF.

  ENDMETHOD.


  METHOD get_filter_value.

    CLEAR rv_value.

    LOOP AT it_filter_ranges INTO DATA(ls_filter_range).

      DATA(lv_name) = ls_filter_range-name.
      TRANSLATE lv_name TO UPPER CASE.

      IF lv_name <> iv_name.
        CONTINUE.
      ENDIF.

      READ TABLE ls_filter_range-range INTO DATA(ls_range) INDEX 1.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

      IF ls_range-sign = 'I'
         AND ls_range-option = 'EQ'.
        rv_value = ls_range-low.
      ENDIF.

      RETURN.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_role_description.

    CLEAR rv_role_description.

    DATA lv_title       TYPE string.
    DATA lv_description TYPE string.

    /ui2/cl_pfcg_utils=>get_role_details_logon(
      EXPORTING
        iv_role              = iv_role
        iv_logon_langu       = sy-langu
      IMPORTING
        ev_logon_title       = lv_title
        ev_logon_description = lv_description ).

    rv_role_description =
      COND string(
        WHEN lv_title IS NOT INITIAL
        THEN lv_title
        ELSE lv_description ).

  ENDMETHOD.


  METHOD get_roles_contained_count.

    CLEAR rv_count.

    DATA(lt_roles) =
      /ui2/cl_pfcg_utils=>get_roles_of_composite_role(
        iv_role_id = iv_composite_role ).

    SORT lt_roles.
    DELETE ADJACENT DUPLICATES FROM lt_roles.

    rv_count = lines( lt_roles ).

  ENDMETHOD.


  METHOD apply_paging.

    DATA(lv_offset) = io_request->get_paging( )->get_offset( ).
    DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).

    IF lv_page_size = if_rap_query_paging=>page_size_unlimited.
      rt_result = it_result.
      RETURN.
    ENDIF.

    DATA(lv_from) = CONV i( lv_offset ) + 1.
    DATA(lv_to)   = CONV i( lv_offset + lv_page_size ).

    IF lv_from < 1.
      lv_from = 1.
    ENDIF.

    IF lv_to > lines( it_result ).
      lv_to = lines( it_result ).
    ENDIF.

    IF lv_from > lv_to.
      RETURN.
    ENDIF.

    LOOP AT it_result INTO DATA(ls_result)
      FROM lv_from TO lv_to.

      APPEND ls_result TO rt_result.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
