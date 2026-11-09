CLASS zcl_drj_ve_capabilityscenariou DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit.
    INTERFACES if_sadl_exit_calc_element_read.
  PRIVATE SECTION.
    METHODS calculate_scenario_health
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_scenario_name   TYPE zdrj_cp_scenario-scenario_name
        iv_context_user    TYPE syuname
      RETURNING
        VALUE(rv_health)   TYPE abap_char1.
ENDCLASS.

CLASS zcl_drj_ve_capabilityscenariou IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~calculate.
    FIELD-SYMBOLS:
      <ls_original> TYPE any,
      <ls_calc>     TYPE any.

    LOOP AT it_original_data ASSIGNING <ls_original>.
      READ TABLE ct_calculated_data ASSIGNING <ls_calc> INDEX sy-tabix.
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      ASSIGN COMPONENT 'CAPABILITYNAME' OF STRUCTURE <ls_original>
        TO FIELD-SYMBOL(<lv_cap>).
      ASSIGN COMPONENT 'SCENARIONAME' OF STRUCTURE <ls_original>
        TO FIELD-SYMBOL(<lv_scen>).
      ASSIGN COMPONENT 'CONTEXTUSER' OF STRUCTURE <ls_original>
        TO FIELD-SYMBOL(<lv_user>).
      ASSIGN COMPONENT 'SCENARIOHEALTHSTATE' OF STRUCTURE <ls_calc>
        TO FIELD-SYMBOL(<lv_health>).

      IF <lv_health> IS ASSIGNED.
        DATA(lv_context_user) = COND syuname(
          WHEN <lv_user> IS ASSIGNED AND <lv_user> IS NOT INITIAL
          THEN CONV #( <lv_user> )
          ELSE sy-uname ).

        <lv_health> = calculate_scenario_health(
          iv_capability_name = CONV #( <lv_cap> )
          iv_scenario_name   = CONV #( <lv_scen> )
          iv_context_user    = lv_context_user ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    LOOP AT it_requested_calc_elements ASSIGNING FIELD-SYMBOL(<fs>).
      CASE <fs>.
        WHEN 'SCENARIOHEALTHSTATE'.
          INSERT CONV string( 'CAPABILITYNAME' ) INTO TABLE et_requested_orig_elements.
          INSERT CONV string( 'SCENARIONAME' )   INTO TABLE et_requested_orig_elements.
          INSERT CONV string( 'CONTEXTUSER' )    INTO TABLE et_requested_orig_elements.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD calculate_scenario_health.
    rv_health = zcl_drj_capability_validator=>determine_scenario_health(
      iv_capability_name = iv_capability_name
      iv_scenario_name   = iv_scenario_name
      iv_user            = iv_context_user ).
  ENDMETHOD.

ENDCLASS.

