CLASS zcl_drj_apia_comp_role_qp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_result,
        compositeroleresultkey   TYPE c LENGTH 200,

        sequence                 TYPE i,

        apiname                  TYPE c LENGTH 255,
        apiversion               TYPE c LENGTH 40,
        apitype                  TYPE c LENGTH 30,

        servicename              TYPE c LENGTH 255,
        serviceversion           TYPE c LENGTH 40,
        servicetype              TYPE c LENGTH 30,

        rolename                 TYPE agr_name,
        compositerolename        TYPE agr_name,

        compositeroledescription TYPE c LENGTH 255,

        rolescontained           TYPE i,

        excludeownmenu           TYPE c LENGTH 1,
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


CLASS zcl_drj_apia_comp_role_qp IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_result TYPE tt_result.

*--------------------------------------------------------------------
*   Main filter for this entity is RoleName
*--------------------------------------------------------------------
    DATA(lv_role_name) =
      get_filter_value(
        io_request     = io_request
        iv_filter_name = 'ROLENAME' ).

*--------------------------------------------------------------------
*   Optional context fields, only echoed back if UI passes them
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

    DATA(lv_service_name) =
      get_filter_value(
        io_request     = io_request
        iv_filter_name = 'SERVICENAME' ).

    DATA(lv_service_version) =
      get_filter_value(
        io_request     = io_request
        iv_filter_name = 'SERVICEVERSION' ).

    DATA(lv_service_type) =
      get_filter_value(
        io_request     = io_request
        iv_filter_name = 'SERVICETYPE' ).

*--------------------------------------------------------------------
*   RoleName drives the composite-role lookup
*--------------------------------------------------------------------
    IF lv_role_name IS NOT INITIAL.

      DATA(lt_comp_roles) =
        zcl_drj_apia_auth_utility=>get_comp_roles_for_role(
          iv_role_name       = CONV agr_name( lv_role_name )
          iv_api_name        = lv_api_name
          iv_api_version     = lv_api_version
          iv_api_type        = lv_api_type
          iv_service_name    = lv_service_name
          iv_service_version = lv_service_version
          iv_service_type    = lv_service_type ).

      DATA(lv_sequence) = 0.

      LOOP AT lt_comp_roles ASSIGNING FIELD-SYMBOL(<ls_comp>).

        lv_sequence += 1.

        APPEND VALUE ty_result(
          compositeroleresultkey =
            |{ <ls_comp>-role_name }#{ <ls_comp>-composite_role_name }|

          sequence                 = lv_sequence

          apiname                  = <ls_comp>-api_name
          apiversion               = <ls_comp>-api_version
          apitype                  = <ls_comp>-api_type

          servicename              = <ls_comp>-service_name
          serviceversion           = <ls_comp>-service_version
          servicetype              = <ls_comp>-service_type

          rolename                 = <ls_comp>-role_name
          compositerolename        = <ls_comp>-composite_role_name

          compositeroledescription = <ls_comp>-composite_role_description

          rolescontained           = <ls_comp>-roles_contained
          excludeownmenu           = <ls_comp>-exclude_own_menu
        ) TO lt_result.

      ENDLOOP.

    ENDIF.

*--------------------------------------------------------------------
*   Important:
*   Always call paging before set_data, even for empty result.
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
