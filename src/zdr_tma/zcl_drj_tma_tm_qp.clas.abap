CLASS zcl_drj_tma_tm_qp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    TYPES:
      BEGIN OF ty_catalog_counter,
        catalog_id           TYPE string,
        role_count           TYPE i,
        composite_role_count TYPE i,
      END OF ty_catalog_counter.

    DATA lt_catalog_counter TYPE HASHED TABLE OF ty_catalog_counter
      WITH UNIQUE KEY catalog_id.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_result,
        targetmappingkey   TYPE c LENGTH 120,
        sequence           TYPE i,
        semanticobject     TYPE /ui2/semantic_object,
        semanticaction     TYPE /ui2/semantic_action,
        text               TYPE c LENGTH 255,
        catalogid          TYPE c LENGTH 255,
        originalcatalogid  TYPE c LENGTH 255,
        catalogorigin      TYPE c LENGTH 20,
        tmtype             TYPE c LENGTH 30,
        applicationtype    TYPE c LENGTH 30,
        targetid           TYPE c LENGTH 255,
        mappingid          TYPE c LENGTH 255,
        chipid             TYPE c LENGTH 255,
        refchipid          TYPE c LENGTH 255,
        systemalias        TYPE c LENGTH 120,
        shortguid          TYPE c LENGTH 80,
        scope              TYPE c LENGTH 1,
        refscope           TYPE c LENGTH 1,
        uiadid             TYPE /ui2/ad_mm_app_id,
        rolecount          TYPE i,
        compositerolecount TYPE i,
      END OF ty_result.

    TYPES ty_t_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    CLASS-METHODS get_filter_value
      IMPORTING
        it_filter_ranges TYPE if_rap_query_filter=>tt_name_range_pairs
        iv_name          TYPE string
      RETURNING
        VALUE(rv_value)  TYPE string.

    CLASS-METHODS apply_paging
      IMPORTING
        it_result        TYPE ty_t_result
        io_request       TYPE REF TO if_rap_query_request
      RETURNING
        VALUE(rt_result) TYPE ty_t_result.

ENDCLASS.



CLASS zcl_drj_tma_tm_qp IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_filter_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

    TRY.
        lt_filter_ranges = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter_ranges.
    ENDTRY.

*--------------------------------------------------------------------
* Mandatory filters
*--------------------------------------------------------------------
    DATA(lv_semantic_object) =
      get_filter_value(
        it_filter_ranges = lt_filter_ranges
        iv_name          = 'SEMANTICOBJECT' ).

    DATA(lv_semantic_action) =
      get_filter_value(
        it_filter_ranges = lt_filter_ranges
        iv_name          = 'SEMANTICACTION' ).

*--------------------------------------------------------------------
* Optional filter
*--------------------------------------------------------------------
    DATA(lv_chip_id) =
      get_filter_value(
        it_filter_ranges = lt_filter_ranges
        iv_name          = 'CHIPID' ).

*--------------------------------------------------------------------
* Protect backend from full unfiltered calls
*--------------------------------------------------------------------
    IF lv_semantic_object IS INITIAL
       OR lv_semantic_action IS INITIAL.

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
* Read detailed TM/catalog/reference information
*--------------------------------------------------------------------
    DATA(lt_tm_info) =
      zcl_drj_flp_start_up_utility=>get_all_cat_ref_for_so_sa(
        iv_object = CONV /ui2/semantic_object( lv_semantic_object )
        iv_action = CONV /ui2/semantic_action( lv_semantic_action ) ).

*--------------------------------------------------------------------
* Build response
*--------------------------------------------------------------------
    DATA lt_result TYPE ty_t_result.
    DATA lv_sequence TYPE i.

    LOOP AT lt_tm_info ASSIGNING FIELD-SYMBOL(<ls_tm_info>).

      IF lv_chip_id IS NOT INITIAL
         AND <ls_tm_info>-chip_id <> lv_chip_id.
        CONTINUE.
      ENDIF.

      lv_sequence += 1.

      DATA(lv_original_catalog_id) =
        COND string(
          WHEN <ls_tm_info>-ref_catalog_id IS NOT INITIAL
          THEN <ls_tm_info>-ref_catalog_id
          ELSE <ls_tm_info>-catalog_id ).

      DATA(lv_catalog_origin) =
        COND string(
          WHEN <ls_tm_info>-uiad_id IS NOT INITIAL
          THEN 'LADI'
          ELSE 'Classical' ).

      DATA(lv_tm_type) =
        COND string(
          WHEN <ls_tm_info>-ref_catalog_id IS NOT INITIAL
          THEN 'Reference Catalog'
          ELSE 'Base Catalog' ).

*--------------------------------------------------------------------
* Counter Stats
*--------------------------------------------------------------------

      DATA ls_catalog_counter TYPE ty_catalog_counter.

      READ TABLE lt_catalog_counter
        INTO ls_catalog_counter
        WITH TABLE KEY catalog_id = <ls_tm_info>-catalog_id.

      IF sy-subrc <> 0.

        DATA lt_catalogs TYPE /ui2/cl_pfcg_utils=>tt_catalog_ids.

        CLEAR lt_catalogs.

        INSERT CONV string( <ls_tm_info>-catalog_id )
          INTO TABLE lt_catalogs.

        DATA(lt_role_ids) =
          zcl_drj_flp_start_up_utility=>get_roles_for_catalogs(
            it_catalogs = lt_catalogs ).

        DATA(lt_composite_role_ids) =
          zcl_drj_flp_start_up_utility=>get_composite_roles_for_roles(
            it_role_ids                 = lt_role_ids
            iv_exclude_roles_w_own_menu = abap_true ).

        ls_catalog_counter = VALUE #(
          catalog_id           = <ls_tm_info>-catalog_id
          role_count           = lines( lt_role_ids )
          composite_role_count = lines( lt_composite_role_ids ) ).

        INSERT ls_catalog_counter INTO TABLE lt_catalog_counter.

      ENDIF.


      APPEND VALUE ty_result(
        targetmappingkey   = |TM{ lv_sequence WIDTH = 10 PAD = '0' }|
        sequence           = lv_sequence
        semanticobject     = CONV /ui2/semantic_object( <ls_tm_info>-object )
        semanticaction     = CONV /ui2/semantic_action( <ls_tm_info>-action )
        text               = CONV #( <ls_tm_info>-text )
        catalogid          = CONV #( <ls_tm_info>-catalog_id )
        originalcatalogid  = CONV #( lv_original_catalog_id )
        catalogorigin      = CONV #( lv_catalog_origin )
        tmtype             = CONV #( lv_tm_type )
        applicationtype    = CONV #( <ls_tm_info>-application_type )
        targetid           = CONV #( <ls_tm_info>-target_id )
        mappingid          = CONV #( <ls_tm_info>-mapping_id )
        chipid             = CONV #( <ls_tm_info>-chip_id )
        refchipid          = CONV #( <ls_tm_info>-ref_chip_id )
        systemalias        = CONV #( <ls_tm_info>-system_alias )
        shortguid          = CONV #( <ls_tm_info>-short_guid )
        scope              = CONV #( <ls_tm_info>-scope )
        refscope           = CONV #( <ls_tm_info>-ref_scope )
        uiadid             = <ls_tm_info>-uiad_id
        rolecount          = ls_catalog_counter-role_count
        compositerolecount = ls_catalog_counter-composite_role_count )
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
