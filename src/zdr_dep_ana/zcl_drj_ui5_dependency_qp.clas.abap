CLASS zcl_drj_ui5_dependency_qp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_result,
        dependencykey  TYPE c LENGTH 120,
        sequence       TYPE i,
        semanticobject TYPE /ui2/semantic_object,
        semanticaction TYPE /ui2/semantic_action,
        catalogid      TYPE c LENGTH 255,
        componentid    TYPE c LENGTH 255,
        dependencytype TYPE c LENGTH 30,
        servicename    TYPE c LENGTH 255,
        serviceversion TYPE c LENGTH 20,
        url            TYPE c LENGTH 500,
        status         TYPE c LENGTH 1,
        success        TYPE c LENGTH 1,
        statustext     TYPE c LENGTH 500,
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



CLASS zcl_drj_ui5_dependency_qp IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

*--------------------------------------------------------------------
* Cover paging request early
*
* Important:
* Even if we later return an empty result because mandatory filters
* are missing, SADL expects the provider to consume paging.
*--------------------------------------------------------------------
    DATA(lo_paging) =
      io_request->get_paging( ).

    DATA(lv_requested_offset) =
      lo_paging->get_offset( ).

    DATA(lv_requested_page_size) =
      lo_paging->get_page_size( ).

    DATA lt_filter_ranges TYPE if_rap_query_filter=>tt_name_range_pairs.

    TRY.
        lt_filter_ranges =
          io_request->get_filter( )->get_as_ranges( ).
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
    DATA(lv_catalog_id) =
      get_filter_value(
        it_filter_ranges = lt_filter_ranges
        iv_name          = 'CATALOGID' ).

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
* Read UI5 dependency activation details
*--------------------------------------------------------------------
    DATA lt_dependency_details
      TYPE zcl_drj_service_checker=>tt_ui5_dependency_act_detail.

    TRY.

        lt_dependency_details =
          zcl_drj_service_checker=>get_ui5_dep_act_details(
            iv_semantic_object = CONV /ui2/semantic_object( lv_semantic_object )
            iv_semantic_action = CONV /ui2/semantic_action( lv_semantic_action )
            iv_catalog_id      = lv_catalog_id
            iv_user            = sy-uname ).

      CATCH cx_root INTO DATA(lx_qp).

        APPEND VALUE #(
          sequence        = 1
          semantic_object = CONV /ui2/semantic_object( lv_semantic_object )
          semantic_action = CONV /ui2/semantic_action( lv_semantic_action )
          catalog_id      = lv_catalog_id
          dependency_type = 'TECHNICAL'
          status          = zcl_drj_service_checker=>gc_warning
          success         = abap_false
          status_text     = |UI5 dependency analyzer failed technically: { lx_qp->get_text( ) }| )
          TO lt_dependency_details.

    ENDTRY.
*--------------------------------------------------------------------
* Build RAP response
*--------------------------------------------------------------------
    DATA lt_result TYPE ty_t_result.

    LOOP AT lt_dependency_details ASSIGNING FIELD-SYMBOL(<ls_detail>).

      APPEND VALUE ty_result(
        dependencykey  = |DEP{ <ls_detail>-sequence WIDTH = 10 PAD = '0' }|
        sequence       = <ls_detail>-sequence
        semanticobject = <ls_detail>-semantic_object
        semanticaction = <ls_detail>-semantic_action
        catalogid      = CONV #( <ls_detail>-catalog_id )
        componentid    = CONV #( <ls_detail>-component_id )
        dependencytype = CONV #( <ls_detail>-dependency_type )
        servicename    = CONV #( <ls_detail>-service_name )
        serviceversion = CONV #( <ls_detail>-service_version )
        url            = CONV #( <ls_detail>-url )
        status         = <ls_detail>-status
        success        = <ls_detail>-success
        statustext     = CONV #( <ls_detail>-status_text ) )
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

        rv_value =
          ls_range-low.

      ENDIF.

      RETURN.

    ENDLOOP.

  ENDMETHOD.


  METHOD apply_paging.

    DATA(lv_offset) =
      io_request->get_paging( )->get_offset( ).

    DATA(lv_page_size) =
      io_request->get_paging( )->get_page_size( ).

    IF lv_page_size = if_rap_query_paging=>page_size_unlimited.

      rt_result =
        it_result.

      RETURN.

    ENDIF.

    DATA(lv_from) =
      CONV i( lv_offset ) + 1.

    DATA(lv_to) =
      CONV i( lv_offset + lv_page_size ).

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
