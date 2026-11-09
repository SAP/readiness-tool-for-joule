CLASS zcl_drj_cap_api_qp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_drj_cap_api_qp IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    TYPES:
      BEGIN OF ty_result,
        capabilityname      TYPE zdrj_capability-capability_name,
        servicename         TYPE string,
        serviceurl          TYPE string,
        activationstatus    TYPE char1,
        authorizationstatus TYPE char1,
        lastchecked         TYPE timestampl,
      END OF ty_result.

    DATA lt_result TYPE STANDARD TABLE OF ty_result.

    DATA(lo_filter) = io_request->get_filter( ).
    DATA(lt_ranges) = lo_filter->get_as_ranges( ).

    DATA lv_capability_name TYPE zdrj_capability-capability_name.

    LOOP AT lt_ranges ASSIGNING FIELD-SYMBOL(<ls_range>).

      IF <ls_range>-name = 'CAPABILITYNAME'.

        lv_capability_name =
          CONV #( <ls_range>-range[ 1 ]-low ).

        EXIT.

      ENDIF.

    ENDLOOP.

    DATA(ls_health) =
      zcl_drj_capability_health=>get_capability_health(
        iv_capability_name = lv_capability_name ).

    LOOP AT ls_health-odata_services ASSIGNING FIELD-SYMBOL(<ls_api>).

      APPEND VALUE ty_result(

        capabilityname      = lv_capability_name
        servicename         = <ls_api>-name
        serviceurl          = <ls_api>-service_url
        activationstatus    = <ls_api>-activation_status
        authorizationstatus = <ls_api>-authorization_status
        lastchecked         = <ls_api>-last_checked

      ) TO lt_result.

    ENDLOOP.

    io_response->set_total_number_of_records(
      lines( lt_result ) ).

    io_response->set_data( lt_result ).

  ENDMETHOD.
ENDCLASS.
