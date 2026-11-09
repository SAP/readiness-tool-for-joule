CLASS zcl_drj_tma_role_qp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_result,
        rolekey            TYPE c LENGTH 160,
        sequence           TYPE i,
        targetmappingkey   TYPE c LENGTH 120,
        semanticobject     TYPE /ui2/semantic_object,
        semanticaction     TYPE /ui2/semantic_action,
        catalogid          TYPE c LENGTH 255,
        chipid             TYPE c LENGTH 255,
        rolename           TYPE agr_name,
        roledescription    TYPE c LENGTH 255,
        catalogcount       TYPE i,
        appcount           TYPE i,
        compositerolecount TYPE i,
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
        iv_role                    TYPE agr_name
      RETURNING
        VALUE(rv_role_description) TYPE string.

    CLASS-METHODS get_catalog_count_for_role
      IMPORTING
        iv_role         TYPE agr_name
      RETURNING
        VALUE(rv_count) TYPE i.

    CLASS-METHODS apply_paging
      IMPORTING
        it_result        TYPE ty_t_result
        io_request       TYPE REF TO if_rap_query_request
      RETURNING
        VALUE(rt_result) TYPE ty_t_result.

    CLASS-METHODS get_role_catalogs
      IMPORTING
        iv_role            TYPE agr_name
      RETURNING
        VALUE(rt_catalogs) TYPE /ui2/cl_pfcg_utils=>tt_catalog_ids.

    CLASS-METHODS get_app_count_for_role
      IMPORTING
        it_catalogs     TYPE /ui2/cl_pfcg_utils=>tt_catalog_ids
      RETURNING
        VALUE(rv_count) TYPE i.

ENDCLASS.



CLASS zcl_drj_tma_role_qp IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_filter_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

    TRY.
        lt_filter_ranges = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter_ranges.
    ENDTRY.

*--------------------------------------------------------------------
* Mandatory for this entity
*--------------------------------------------------------------------
    DATA(lv_catalog_id) =
      get_filter_value(
        it_filter_ranges = lt_filter_ranges
        iv_name          = 'CATALOGID' ).

*--------------------------------------------------------------------
* Optional context filters
*--------------------------------------------------------------------
    DATA(lv_semantic_object) =
      get_filter_value(
        it_filter_ranges = lt_filter_ranges
        iv_name          = 'SEMANTICOBJECT' ).

    DATA(lv_semantic_action) =
      get_filter_value(
        it_filter_ranges = lt_filter_ranges
        iv_name          = 'SEMANTICACTION' ).

    DATA(lv_chip_id) =
      get_filter_value(
        it_filter_ranges = lt_filter_ranges
        iv_name          = 'CHIPID' ).

    DATA(lv_target_mapping_key) =
      get_filter_value(
        it_filter_ranges = lt_filter_ranges
        iv_name          = 'TARGETMAPPINGKEY' ).

*--------------------------------------------------------------------
* Protect backend from full unfiltered calls
*--------------------------------------------------------------------
    IF lv_catalog_id IS INITIAL.

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
* Build catalog input
*--------------------------------------------------------------------
    DATA lt_catalogs TYPE /ui2/cl_pfcg_utils=>tt_catalog_ids.

    INSERT lv_catalog_id INTO TABLE lt_catalogs.

*--------------------------------------------------------------------
* Resolve roles for selected catalog
*--------------------------------------------------------------------
    DATA(lt_role_ids) =
      zcl_drj_flp_start_up_utility=>get_roles_for_catalogs(
        it_catalogs = lt_catalogs ).

*--------------------------------------------------------------------
* Build response
*--------------------------------------------------------------------
    DATA lt_result TYPE ty_t_result.
    DATA lv_sequence TYPE i.

    LOOP AT lt_role_ids INTO DATA(lv_role_id).

      IF lv_role_id IS INITIAL.
        CONTINUE.
      ENDIF.

      lv_sequence += 1.

      DATA lt_single_role TYPE /ui2/if_nwbc_runtime=>t_role_ids.
      CLEAR lt_single_role.
      APPEND lv_role_id TO lt_single_role.

      DATA(lt_composite_role_ids) =
        zcl_drj_flp_start_up_utility=>get_composite_roles_for_roles(
          it_role_ids                 = lt_single_role
          iv_exclude_roles_w_own_menu = abap_true ).

      DATA(lt_role_catalogs) = get_role_catalogs(
    iv_role = CONV agr_name( lv_role_id ) ).

      DATA(lv_catalog_count) = lines( lt_role_catalogs ).

      DATA(lv_app_count) =
        get_app_count_for_role(
          it_catalogs = lt_role_catalogs ).


      APPEND VALUE ty_result(
        rolekey            = |BR{ lv_sequence WIDTH = 10 PAD = '0' }|
        sequence           = lv_sequence
        targetmappingkey   = CONV #( lv_target_mapping_key )
        semanticobject     = CONV #( lv_semantic_object )
        semanticaction     = CONV #( lv_semantic_action )
        catalogid          = CONV #( lv_catalog_id )
        chipid             = CONV #( lv_chip_id )
        rolename           = CONV #( lv_role_id )
        roledescription    = CONV #( get_role_description( CONV agr_name( lv_role_id ) ) )
        catalogcount       = lv_catalog_count
        appcount           = lv_app_count
        compositerolecount = lines( lt_composite_role_ids ) )
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

  METHOD get_catalog_count_for_role.

    DATA(lt_catalogs) =
      get_role_catalogs(
        iv_role = iv_role ).

    rv_count = lines( lt_catalogs ).

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

  METHOD get_app_count_for_role.

    CLEAR rv_count.

    IF it_catalogs IS INITIAL.
      RETURN.
    ENDIF.

*--------------------------------------------------------------------
* Count unique app/TM identities for all catalogs assigned to the role.
*
* Do NOT use SORT_AND_COMPRESS_TMS here. That helper is useful for
* SO/action reference-catalog compression, but it is not a safe role
* app counter.
*--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_app_key,
        app_key TYPE string,
      END OF ty_app_key.

    DATA lt_seen_apps TYPE HASHED TABLE OF ty_app_key
      WITH UNIQUE KEY app_key.

    LOOP AT it_catalogs ASSIGNING FIELD-SYMBOL(<lv_catalog>).

      IF <lv_catalog> IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lt_catalog_tms) =
        zcl_drj_flp_start_up_utility=>lookup_all_tms_no_buffer(
          iv_catalog_id = CONV /ui2/page_id( <lv_catalog> ) ).

      LOOP AT lt_catalog_tms ASSIGNING FIELD-SYMBOL(<ls_tm>).

        DATA(lv_app_key) = ``.

*------------------------------------------------------------------
* Preferred stable app identity
*------------------------------------------------------------------
        IF <ls_tm>-uiad_id IS NOT INITIAL.

          lv_app_key =
            |UIAD:{ CONV string( <ls_tm>-uiad_id ) }|.

        ELSEIF <ls_tm>-mapping_id IS NOT INITIAL.

          lv_app_key =
            |MAP:{ CONV string( <ls_tm>-mapping_id ) }|.

        ELSEIF <ls_tm>-target_id IS NOT INITIAL.

          lv_app_key =
            |TGT:{ CONV string( <ls_tm>-target_id ) }|.

        ELSEIF <ls_tm>-chip_id IS NOT INITIAL.

          lv_app_key =
            |CHIP:{ CONV string( <ls_tm>-chip_id ) }|.

        ELSE.

          lv_app_key =
            |SOA:{ CONV string( <ls_tm>-object ) }:{ CONV string( <ls_tm>-action ) }:{ CONV string( <ls_tm>-catalog_id ) }|.

        ENDIF.

        INSERT VALUE ty_app_key(
          app_key = lv_app_key )
          INTO TABLE lt_seen_apps.

      ENDLOOP.

    ENDLOOP.

    rv_count = lines( lt_seen_apps ).

  ENDMETHOD.

  METHOD get_role_catalogs.

    CLEAR rt_catalogs.

    IF iv_role IS INITIAL.
      RETURN.
    ENDIF.

    DATA lr_roles TYPE /ui2/cl_pfcg_utils=>tr_roles.

    lr_roles =
      VALUE #(
        (
          sign   = 'I'
          option = 'EQ'
          low    = iv_role
        )
      ).

    DATA lt_catalogs_full TYPE /ui2/cl_pfcg_utils=>tt_catalogs.
    DATA lt_groups        TYPE /ui2/cl_pfcg_utils=>tt_groups.

    /ui2/cl_pfcg_utils=>get_catalogs_groups_for_roles(
      EXPORTING
        ir_roles         = lr_roles
        iv_bypass_buffer = abap_true
      IMPORTING
        et_catalogs      = lt_catalogs_full
        et_groups        = lt_groups ).

    LOOP AT lt_catalogs_full ASSIGNING FIELD-SYMBOL(<ls_catalog>).

      IF <ls_catalog>-catalog_id IS INITIAL.
        CONTINUE.
      ENDIF.

      INSERT CONV string( <ls_catalog>-catalog_id )
        INTO TABLE rt_catalogs.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
