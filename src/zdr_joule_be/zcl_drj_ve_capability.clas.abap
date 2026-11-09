CLASS zcl_drj_ve_capability DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_sadl_exit.
    INTERFACES if_sadl_exit_calc_element_read .
  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS calculate_overall_health
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
      RETURNING
        VALUE(rv_health)   TYPE abap_char1.
ENDCLASS.



CLASS zcl_drj_ve_capability IMPLEMENTATION.
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

      ASSIGN COMPONENT 'CAPABILITYNAME'
        OF STRUCTURE <ls_original>
        TO FIELD-SYMBOL(<lv_capability_name>).

      ASSIGN COMPONENT 'OVERALLHEALTH'
        OF STRUCTURE <ls_calc>
        TO FIELD-SYMBOL(<lv_health>).

      IF sy-subrc = 0.

        <lv_health> = calculate_overall_health(
                        iv_capability_name =
                          CONV #( <lv_capability_name> ) ).

      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.

    LOOP AT it_requested_calc_elements ASSIGNING FIELD-SYMBOL(<fs_calc_element>).
      CASE <fs_calc_element>.
        WHEN 'OVERALLHEALTH'.
          INSERT CONV string( 'CAPABILITYNAME' )
            INTO TABLE et_requested_orig_elements.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD calculate_overall_health.

      rv_health =
    zcl_drj_capability_validator=>determine_overall_health(
      iv_capability_name = iv_capability_name ).

  ENDMETHOD.

ENDCLASS.
