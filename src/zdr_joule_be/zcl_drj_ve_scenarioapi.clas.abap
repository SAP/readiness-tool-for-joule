CLASS zcl_drj_ve_scenarioapi DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_sadl_exit.
    INTERFACES if_sadl_exit_calc_element_read.

  PRIVATE SECTION.

    METHODS get_activation_status
      IMPORTING
        iv_service_name  TYPE string
        iv_api_version   TYPE string
      RETURNING
        VALUE(rv_status) TYPE abap_char1.

    METHODS get_authorization_status
      IMPORTING
        iv_service_name  TYPE string
        iv_api_version   TYPE string
      RETURNING
        VALUE(rv_status) TYPE abap_char1.

ENDCLASS.



CLASS zcl_drj_ve_scenarioapi IMPLEMENTATION.


  METHOD if_sadl_exit_calc_element_read~calculate.

    FIELD-SYMBOLS:
      <ls_original> TYPE any,
      <ls_calc>     TYPE any.

    LOOP AT it_original_data ASSIGNING <ls_original>.

      READ TABLE ct_calculated_data
        ASSIGNING <ls_calc>
        INDEX sy-tabix.

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      ASSIGN COMPONENT 'ODATASERVICENAME'
        OF STRUCTURE <ls_original>
        TO FIELD-SYMBOL(<lv_service_name>).

      ASSIGN COMPONENT 'APIVERSION'
        OF STRUCTURE <ls_original>
        TO FIELD-SYMBOL(<lv_api_version>).

      ASSIGN COMPONENT 'ACTIVATIONSTATUS'
        OF STRUCTURE <ls_calc>
        TO FIELD-SYMBOL(<lv_activation>).

      ASSIGN COMPONENT 'AUTHORIZATIONSTATUS'
        OF STRUCTURE <ls_calc>
        TO FIELD-SYMBOL(<lv_authorization>).

      IF sy-subrc = 0.

        <lv_activation> =
          get_activation_status(
            iv_service_name = CONV #( <lv_service_name> )
            iv_api_version  = CONV #( <lv_api_version> ) ).

        <lv_authorization> =
          get_authorization_status(
            iv_service_name = CONV #( <lv_service_name> )
            iv_api_version  = CONV #( <lv_api_version> ) ).

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.

    LOOP AT it_requested_calc_elements
      ASSIGNING FIELD-SYMBOL(<fs_calc_element>).

      CASE <fs_calc_element>.

        WHEN 'ACTIVATIONSTATUS'.

          INSERT CONV string( 'ODATASERVICENAME' )
            INTO TABLE et_requested_orig_elements.

          INSERT CONV string( 'APIVERSION' )
            INTO TABLE et_requested_orig_elements.

        WHEN 'AUTHORIZATIONSTATUS'.

          INSERT CONV string( 'ODATASERVICENAME' )
            INTO TABLE et_requested_orig_elements.

          INSERT CONV string( 'APIVERSION' )
            INTO TABLE et_requested_orig_elements.

      ENDCASE.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_activation_status.

    rv_status = 'E'.

    CASE iv_api_version.

      WHEN 'V2'.

        DATA(ls_v2_status) =
          zcl_drj_service_checker=>check_odata_v2_service_act(
            iv_service_name = CONV #( iv_service_name )
          ).

        IF ls_v2_status-gw_active = abap_true
           AND ( ls_v2_status-icf_exists = abap_false
                 OR ls_v2_status-icf_active = abap_true ).

          rv_status = 'S'.

        ENDIF.

      WHEN 'V4'.

        DATA(ls_v4_status) =
          zcl_drj_service_checker=>check_odata_v4_service_act(
            iv_group_id = CONV #( iv_service_name )
          ).

        IF ls_v4_status-gw_active = abap_true.

          rv_status = 'S'.

        ENDIF.

    ENDCASE.

  ENDMETHOD.

  METHOD get_authorization_status.

    rv_status = 'E'.

    CASE iv_api_version.

      WHEN 'V2'.

        DATA(ls_auth_v2) =
  zcl_drj_service_checker=>check_odata_v2_service_auth(
    iv_service_name = CONV #( iv_service_name )
  ).

        IF ls_auth_v2-iwsg_auth = abap_true
           AND ls_auth_v2-iwsv_auth = abap_true.

          rv_status = 'S'.

        ELSEIF ls_auth_v2-iwsg_auth = abap_true
            OR ls_auth_v2-iwsv_auth = abap_true.

          rv_status = 'W'.

        ELSE.

          rv_status = 'E'.

        ENDIF.
      WHEN 'V4'.

        DATA(ls_auth_v4) =
  zcl_drj_service_checker=>check_odata_v4_service_auth(
    iv_group_id = CONV #( iv_service_name )
  ).

        IF ls_auth_v4-service_auth = abap_true.
          rv_status = 'S'.
        ELSE.
          rv_status = 'E'.
        ENDIF.

    ENDCASE.

  ENDMETHOD.

ENDCLASS.
