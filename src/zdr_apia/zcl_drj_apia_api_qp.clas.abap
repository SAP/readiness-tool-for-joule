CLASS zcl_drj_apia_api_qp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_result,
        apiresultkey       TYPE c LENGTH 200,

        sequence           TYPE i,

        apiname            TYPE c LENGTH 255,
        apiversion         TYPE c LENGTH 40,
        apitype            TYPE c LENGTH 30,

        apidescription     TYPE c LENGTH 255,

        servicename        TYPE c LENGTH 255,
        serviceversion     TYPE c LENGTH 40,
        servicetype        TYPE c LENGTH 30,

        servicenamespace   TYPE c LENGTH 255,
        servicepath        TYPE c LENGTH 255,

        systemalias        TYPE c LENGTH 120,

        rolecount          TYPE i,
        compositerolecount TYPE i,
      END OF ty_result.

    TYPES tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    CLASS-METHODS get_filter_value
      IMPORTING
        io_request      TYPE REF TO if_rap_query_request
        iv_filter_name  TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.

    CLASS-METHODS apply_paging
      IMPORTING
        io_request TYPE REF TO if_rap_query_request
      CHANGING
        ct_result  TYPE tt_result.

ENDCLASS.


CLASS zcl_drj_apia_api_qp IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_result TYPE tt_result.

    DATA(lv_api_name) =
      get_filter_value(
        io_request     = io_request
        iv_filter_name = 'APINAME' ).

    DATA(lv_api_version) =
      get_filter_value(
        io_request     = io_request
        iv_filter_name = 'APIVERSION' ).

    DATA(lv_api_type) =
      get_filter_value(
        io_request     = io_request
        iv_filter_name = 'APITYPE' ).

    IF lv_api_name IS INITIAL.

      IF io_request->is_total_numb_of_rec_requested( ).
        io_response->set_total_number_of_records( 0 ).
      ENDIF.

      IF io_request->is_data_requested( ).
        io_response->set_data( lt_result ).
      ENDIF.

      RETURN.

    ENDIF.

    DATA(lt_api) =
      zcl_drj_apia_auth_utility=>get_api_usages(
        iv_api_name    = lv_api_name
        iv_api_version = lv_api_version
        iv_api_type    = lv_api_type ).

    DATA(lv_sequence) = 0.

    LOOP AT lt_api ASSIGNING FIELD-SYMBOL(<ls_api>).

      lv_sequence += 1.

      APPEND VALUE ty_result(
        apiresultkey       =
          |{ <ls_api>-api_type }#{ <ls_api>-service_name }#{ <ls_api>-service_version }|

        sequence           = lv_sequence

        apiname            = <ls_api>-api_name
        apiversion         = <ls_api>-api_version
        apitype            = <ls_api>-api_type

        apidescription     = <ls_api>-api_description

        servicename        = <ls_api>-service_name
        serviceversion     = <ls_api>-service_version
        servicetype        = <ls_api>-service_type

        servicenamespace   = <ls_api>-service_namespace
        servicepath        = <ls_api>-service_path

        systemalias        = <ls_api>-system_alias

        rolecount          = <ls_api>-role_count
        compositerolecount = <ls_api>-composite_role_count
      ) TO lt_result.

    ENDLOOP.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.

    apply_paging(
      EXPORTING
        io_request = io_request
      CHANGING
        ct_result  = lt_result ).

    IF io_request->is_data_requested( ).
      io_response->set_data( lt_result ).
    ENDIF.

  ENDMETHOD.


  METHOD get_filter_value.

    CLEAR rv_value.

    TRY.

        DATA(lt_ranges) =
          io_request->get_filter( )->get_as_ranges( ).

        DATA(lv_name) = to_upper( iv_filter_name ).

        LOOP AT lt_ranges ASSIGNING FIELD-SYMBOL(<ls_range>)
          WHERE name = lv_name.

          READ TABLE <ls_range>-range ASSIGNING FIELD-SYMBOL(<ls_value>) INDEX 1.

          IF sy-subrc = 0.
            rv_value = CONV string( <ls_value>-low ).
            RETURN.
          ENDIF.

        ENDLOOP.

      CATCH cx_rap_query_filter_no_range.
        CLEAR rv_value.

      CATCH cx_root.
        CLEAR rv_value.

    ENDTRY.

  ENDMETHOD.


  METHOD apply_paging.

    DATA lt_paged TYPE tt_result.

    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lv_offset) = lo_paging->get_offset( ).
    DATA(lv_page_size) = lo_paging->get_page_size( ).

    IF lv_page_size = if_rap_query_paging=>page_size_unlimited.
      RETURN.
    ENDIF.

    DATA(lv_from) = lv_offset + 1.
    DATA(lv_to)   = lv_offset + lv_page_size.

    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<ls_result>)
      FROM lv_from TO lv_to.

      APPEND <ls_result> TO lt_paged.

    ENDLOOP.

    ct_result = lt_paged.

  ENDMETHOD.

ENDCLASS.
