CLASS zcl_drj_overall_health_qpu DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.


CLASS zcl_drj_overall_health_qpu IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    TYPES:
      BEGIN OF ty_result,

        healthid               TYPE char20,

        contextuser            TYPE syuname,

        overallstatus          TYPE string,
        overallstatusstate     TYPE char1,

        numberofapis           TYPE i,
        apisactive             TYPE i,
        apisauthorized         TYPE i,

        numberoftms            TYPE i,
        tmsactive              TYPE i,
        tmsauthorized          TYPE i,

        authsummary            TYPE string,
        authsummarydescription TYPE string,

      END OF ty_result.

    DATA lt_result TYPE STANDARD TABLE OF ty_result.

    DATA(lo_filter) = io_request->get_filter( ).
    DATA(lt_ranges) = lo_filter->get_as_ranges( ).

    DATA lv_context_user TYPE syuname.

    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lv_offset) = lo_paging->get_offset( ).
    DATA(lv_page_size) = lo_paging->get_page_size( ).

*--------------------------------------------------------------------
* Read filter values
*--------------------------------------------------------------------
    LOOP AT lt_ranges ASSIGNING FIELD-SYMBOL(<ls_range>).

      CASE <ls_range>-name.

        WHEN 'CONTEXTUSER'.

          lv_context_user =
            CONV syuname(
              <ls_range>-range[ 1 ]-low ).

      ENDCASE.

    ENDLOOP.

*--------------------------------------------------------------------
* Default to logged-on user
*--------------------------------------------------------------------
    IF lv_context_user IS INITIAL.

      lv_context_user = sy-uname.

    ENDIF.

*--------------------------------------------------------------------
* Read overall health
*--------------------------------------------------------------------
    DATA(ls_health) =
      zcl_drj_overall_health=>get_overall_health(
        iv_user = lv_context_user ).

*--------------------------------------------------------------------
* Build RAP result
*--------------------------------------------------------------------
    APPEND VALUE ty_result(

      healthid                = ls_health-health_id

      contextuser            = ls_health-context_user

      overallstatus          = ls_health-overall_status
      overallstatusstate     = ls_health-overall_status_state

      numberofapis           = ls_health-number_of_apis
      apisactive             = ls_health-apis_active
      apisauthorized         = ls_health-apis_authorized

      numberoftms            = ls_health-number_of_tms
      tmsactive              = ls_health-tms_active
      tmsauthorized          = ls_health-tms_authorized

      authsummary            = ls_health-auth_summary
      authsummarydescription = ls_health-auth_summary_description

    ) TO lt_result.

*--------------------------------------------------------------------
* RAP response
*--------------------------------------------------------------------
    io_response->set_total_number_of_records(
      lines( lt_result ) ).

    io_response->set_data(
      lt_result ).

  ENDMETHOD.

ENDCLASS.
