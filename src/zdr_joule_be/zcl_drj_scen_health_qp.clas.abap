CLASS zcl_drj_scen_health_qp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider .

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_drj_scen_health_qp IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    TYPES:
      BEGIN OF ty_result,

        capabilityname            TYPE c LENGTH 64,
        scenarioname              TYPE c LENGTH 255,

        overallstatus             TYPE c LENGTH 40,
        overallstatusstate        TYPE c LENGTH 1,

        odataservicestotal        TYPE i,
        odataservicesactive       TYPE i,
        odataservicesinactive     TYPE i,
        odataservicesauthorized   TYPE i,
        odataservicesunauthorized TYPE i,

        sapui5tmstotal            TYPE i,
        sapui5tmsactive           TYPE i,
        sapui5tmsinactive         TYPE i,
        sapui5tmsauthorized       TYPE i,
        sapui5tmsunauthorized     TYPE i,

        actsummarystate           TYPE c LENGTH 1,
        actsummary                TYPE c LENGTH 100,
        actsummarydescription     TYPE c LENGTH 255,
        actsummarypercentage      TYPE p LENGTH 3 DECIMALS 2,

        authsummarystate          TYPE c LENGTH 1,
        authsummary               TYPE c LENGTH 100,
        authsummarydescription    TYPE c LENGTH 255,
        authsummarypercentage     TYPE p LENGTH 3 DECIMALS 2,

      END OF ty_result.

    DATA lt_result TYPE STANDARD TABLE OF ty_result.
    DATA lt_response TYPE STANDARD TABLE OF ty_result.

    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lv_offset) = lo_paging->get_offset( ).
    DATA(lv_page_size) = lo_paging->get_page_size( ).

    DATA(lo_filter) = io_request->get_filter( ).
    DATA(lt_ranges) = lo_filter->get_as_ranges( ).

    DATA lv_capability_name TYPE zdrj_capability-capability_name.
    DATA lv_scenario_name   TYPE zdrj_cp_scenario-scenario_name.

*--------------------------------------------------------------------
* Read Filters
*--------------------------------------------------------------------
    LOOP AT lt_ranges ASSIGNING FIELD-SYMBOL(<ls_range>).

      IF <ls_range>-range IS INITIAL.
        CONTINUE.
      ENDIF.

      CASE <ls_range>-name.

        WHEN 'CAPABILITYNAME'.

          lv_capability_name =
            CONV #( <ls_range>-range[ 1 ]-low ).

        WHEN 'SCENARIONAME'.

          lv_scenario_name =
            CONV #( <ls_range>-range[ 1 ]-low ).

      ENDCASE.

    ENDLOOP.

*--------------------------------------------------------------------
* Get Scenario Health
*--------------------------------------------------------------------
    DATA(ls_health) =
      zcl_drj_scenario_health=>get_scenario_health(
        iv_capability_name = lv_capability_name
        iv_scenario_name   = lv_scenario_name ).

*--------------------------------------------------------------------
* Map Result
*--------------------------------------------------------------------
    APPEND VALUE ty_result(

      capabilityname = ls_health-capability_name
      scenarioname   = ls_health-scenario_name

      overallstatus      = ls_health-overall_status
      overallstatusstate = ls_health-overall_status_state

      odataservicestotal        = ls_health-odata_services_total
      odataservicesactive       = ls_health-odata_services_active
      odataservicesinactive     = ls_health-odata_services_inactive
      odataservicesauthorized   = ls_health-odata_services_authorized
      odataservicesunauthorized = ls_health-odata_services_unauthorized

      sapui5tmstotal        = ls_health-sapui5_tms_total
      sapui5tmsactive       = ls_health-sapui5_tms_active
      sapui5tmsinactive     = ls_health-sapui5_tms_inactive
      sapui5tmsauthorized   = ls_health-sapui5_tms_authorized
      sapui5tmsunauthorized = ls_health-sapui5_tms_unauthorized

      actsummarystate       = ls_health-act_summary_state
      actsummary            = ls_health-act_summary
      actsummarydescription = ls_health-act_summary_description
      actsummarypercentage  = ls_health-act_summary_percentage

      authsummarystate       = ls_health-auth_summary_state
      authsummary            = ls_health-auth_summary
      authsummarydescription = ls_health-auth_summary_description
      authsummarypercentage  = ls_health-auth_summary_percentage

    ) TO lt_result.

*--------------------------------------------------------------------
* Paging
*--------------------------------------------------------------------
    lt_response = lt_result.

    DATA(lv_offset_i)    = CONV i( lv_offset ).
    DATA(lv_page_size_i) = CONV i( lv_page_size ).

    IF lv_offset_i > 0.
      DELETE lt_response FROM 1 TO lv_offset_i.
    ENDIF.

    IF lv_page_size_i > 0 AND lines( lt_response ) > lv_page_size_i.

      DATA(lv_delete_from) = lv_page_size_i + 1.
      DATA(lv_delete_to)   = lines( lt_response ).

      DELETE lt_response FROM lv_delete_from TO lv_delete_to.

    ENDIF.

*--------------------------------------------------------------------
* Response
*--------------------------------------------------------------------
    io_response->set_total_number_of_records( lines( lt_result ) ).
    io_response->set_data( lt_response ).

  ENDMETHOD.

ENDCLASS.
