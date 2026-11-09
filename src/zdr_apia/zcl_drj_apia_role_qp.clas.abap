CLASS zcl_drj_apia_role_qp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_result,
        roleresultkey          TYPE c LENGTH 200,

        sequence               TYPE i,

        apiname                TYPE c LENGTH 255,
        apiversion             TYPE c LENGTH 40,
        apitype                TYPE c LENGTH 30,

        servicename            TYPE c LENGTH 255,
        serviceversion         TYPE c LENGTH 40,
        servicetype            TYPE c LENGTH 30,

        rolename               TYPE agr_name,
        roledescription        TYPE c LENGTH 255,

        authorizationcount     TYPE i,
        servicecount           TYPE i,

        haswildcardauth        TYPE c LENGTH 1,
        authorizationmatchtype TYPE c LENGTH 30,

        compositerolecount     TYPE i,
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



CLASS ZCL_DRJ_APIA_ROLE_QP IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    DATA lt_result TYPE tt_result.

*--------------------------------------------------------------------
*   Filters
*--------------------------------------------------------------------
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

*--------------------------------------------------------------------
*   ApiName drives API -> Role lookup.
*   If ApiName is empty, result remains empty, but we still continue
*   to total count, paging, and set_data to fully satisfy RAP.
*--------------------------------------------------------------------
    IF lv_api_name IS NOT INITIAL.

      DATA(lt_roles) =
        zcl_drj_apia_auth_utility=>get_roles_for_api(
          iv_api_name    = lv_api_name
          iv_api_version = lv_api_version
          iv_api_type    = lv_api_type ).

      SORT lt_roles BY authorization_match_type ASCENDING role_name ASCENDING.

      DATA(lv_sequence) = 0.

      LOOP AT lt_roles ASSIGNING FIELD-SYMBOL(<ls_role>).

        lv_sequence += 1.

        APPEND VALUE ty_result(
          roleresultkey =
            |{ <ls_role>-api_type }#{ <ls_role>-service_name }#{ <ls_role>-service_version }#{ <ls_role>-role_name }|

          sequence               = lv_sequence

          apiname                = <ls_role>-api_name
          apiversion             = <ls_role>-api_version
          apitype                = <ls_role>-api_type

          servicename            = <ls_role>-service_name
          serviceversion         = <ls_role>-service_version
          servicetype            = <ls_role>-service_type

          rolename               = <ls_role>-role_name
          roledescription        = <ls_role>-role_description

          authorizationcount     = <ls_role>-authorization_count
          servicecount           = <ls_role>-service_count

          haswildcardauth        = <ls_role>-has_wildcard_auth
          authorizationmatchtype = <ls_role>-authorization_match_type

          compositerolecount     = <ls_role>-composite_role_count
        ) TO lt_result.

      ENDLOOP.

    ENDIF.

*--------------------------------------------------------------------
*   Always complete RAP query contract
*--------------------------------------------------------------------
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
