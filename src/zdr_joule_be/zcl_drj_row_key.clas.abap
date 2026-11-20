
CLASS zcl_drj_row_key DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS for_scen_api
      IMPORTING
        is_api TYPE zdrj_scen_api
      RETURNING
        VALUE(rv_hash) TYPE zdrj_scen_api-row_hash
      RAISING
        cx_abap_message_digest.

    CLASS-METHODS for_scen_tm
      IMPORTING
        is_tm TYPE zdrj_scen_tm
      RETURNING
        VALUE(rv_hash) TYPE zdrj_scen_tm-row_hash
      RAISING
        cx_abap_message_digest.

    CLASS-METHODS for_cra_missing
      IMPORTING
        is_missing TYPE zdrj_cra_missing
      RETURNING
        VALUE(rv_hash) TYPE zdrj_cra_missing-row_hash
      RAISING
        cx_abap_message_digest.

  PRIVATE SECTION.

    CLASS-METHODS append_field
      IMPORTING
        iv_value TYPE string
      CHANGING
        cv_data TYPE string.

    CLASS-METHODS calculate_sha256
      IMPORTING
        iv_data TYPE string
      RETURNING
        VALUE(rv_hash) TYPE zdrj_scen_api-row_hash
      RAISING
        cx_abap_message_digest.

ENDCLASS.


CLASS zcl_drj_row_key IMPLEMENTATION.

  METHOD append_field.

    "Length-prefix encoding prevents ambiguous
    "combinations of multiple business-key fields.

    cv_data = cv_data &&
      |{ strlen( iv_value ) }:{ iv_value }|.

  ENDMETHOD.


  METHOD calculate_sha256.

    DATA lv_digest TYPE xstring.

    cl_abap_message_digest=>calculate_hash_for_char(
      EXPORTING
        if_algorithm = 'SHA256'
        if_data      = iv_data
      IMPORTING
        ef_hashxstring = lv_digest
    ).

    rv_hash = lv_digest.

  ENDMETHOD.


  METHOD for_scen_api.

    DATA(lv_data) = `SCEN_API_V1`.

    append_field(
      EXPORTING
        iv_value = CONV string( is_api-capability_name )
      CHANGING
        cv_data = lv_data ).

    append_field(
      EXPORTING
        iv_value = CONV string( is_api-scenario_name )
      CHANGING
        cv_data = lv_data ).

    append_field(
      EXPORTING
        iv_value = CONV string( is_api-odata_service_name )
      CHANGING
        cv_data = lv_data ).

    rv_hash = calculate_sha256( lv_data ).

  ENDMETHOD.


  METHOD for_scen_tm.

    DATA(lv_data) = `SCEN_TM_V1`.

    append_field(
      EXPORTING
        iv_value = CONV string( is_tm-capability_name )
      CHANGING
        cv_data = lv_data ).

    append_field(
      EXPORTING
        iv_value = CONV string( is_tm-scenario_name )
      CHANGING
        cv_data = lv_data ).

    append_field(
      EXPORTING
        iv_value = CONV string( is_tm-semantic_object )
      CHANGING
        cv_data = lv_data ).

    append_field(
      EXPORTING
        iv_value = CONV string( is_tm-semantic_action )
      CHANGING
        cv_data = lv_data ).

    append_field(
      EXPORTING
        iv_value = CONV string( is_tm-catalog_id )
      CHANGING
        cv_data = lv_data ).

    rv_hash = calculate_sha256( lv_data ).

  ENDMETHOD.


  METHOD for_cra_missing.

    DATA(lv_data) = `CRA_MISSING_V1`.

    append_field(
      EXPORTING
        iv_value = CONV string( is_missing-role_name )
      CHANGING
        cv_data = lv_data ).

    append_field(
      EXPORTING
        iv_value = CONV string( is_missing-capability_name )
      CHANGING
        cv_data = lv_data ).

    append_field(
      EXPORTING
        iv_value = CONV string( is_missing-scenario_name )
      CHANGING
        cv_data = lv_data ).

    append_field(
      EXPORTING
        iv_value = CONV string( is_missing-requirement_type )
      CHANGING
        cv_data = lv_data ).

    append_field(
      EXPORTING
        iv_value = CONV string( is_missing-requirement_key )
      CHANGING
        cv_data = lv_data ).

    rv_hash = calculate_sha256( lv_data ).

  ENDMETHOD.

ENDCLASS.

