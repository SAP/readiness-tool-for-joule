CLASS zzcl_drj_scen_excel_proc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS process
      IMPORTING
        iv_xstring   TYPE xstring
        iv_file_name TYPE string
      EXPORTING
        ev_rows      TYPE i
        ev_scenarios TYPE i
        ev_tms       TYPE i
        ev_warnings  TYPE string_table.

  PRIVATE SECTION.

    " Represents one row from scenarios-export.xlsx
    TYPES:
      BEGIN OF ty_row,
        scenario_name        TYPE string,
        description          TYPE string,
        product_id           TYPE string,
        deployment_status    TYPE string,
        skip_reason          TYPE string,
        scenario_type        TYPE string,
        visibility_condition TYPE string,
        supported_languages  TYPE string,
        system_name          TYPE string,
        system_type          TYPE string,
      END OF ty_row,

      tt_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    TYPES tt_string TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_system,
        system_name        TYPE string,
        system_type        TYPE string,
        custom_system_name TYPE string,
        system_title       TYPE string,
        system_description TYPE string,
      END OF ty_system,

      tt_systems TYPE STANDARD TABLE OF ty_system WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_visibility_object,
        type       TYPE string,
        match_mode TYPE string,
        value      TYPE tt_string,
        systems    TYPE tt_systems,
      END OF ty_visibility_object,

      tt_visibility_objects TYPE STANDARD TABLE OF ty_visibility_object
                            WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_visibility,
        objects TYPE tt_visibility_objects,
      END OF ty_visibility.

    CONSTANTS gc_capability_name
  TYPE zdrj_capability-capability_name
  VALUE 'Joule Admin Center - Data'.


    TYPES tt_scenarios TYPE HASHED TABLE OF zdrj_cp_scenario
      WITH UNIQUE KEY capability_name scenario_name.

    TYPES tt_tms TYPE SORTED TABLE OF zdrj_scen_tm
      WITH UNIQUE KEY
        capability_name
        scenario_name
        semantic_object
        semantic_action
        catalog_id.

    TYPES tt_known_sem_objects
      TYPE HASHED TABLE OF string
      WITH UNIQUE KEY table_line.

    TYPES tt_known_sem_actions
      TYPE HASHED TABLE OF string
      WITH UNIQUE KEY table_line.

    TYPES:
      BEGIN OF ty_known_tm,
        semantic_object TYPE string,
        semantic_action TYPE string,
      END OF ty_known_tm.

    TYPES tt_known_tms
      TYPE HASHED TABLE OF ty_known_tm
      WITH UNIQUE KEY semantic_object semantic_action.


    CLASS-METHODS read_excel
      IMPORTING
        iv_xstring     TYPE xstring
      RETURNING
        VALUE(rt_rows) TYPE tt_rows.

    CLASS-METHODS validate_headers
      IMPORTING
        ir_itab         TYPE REF TO data
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    CLASS-METHODS build_data
      IMPORTING
        it_rows      TYPE tt_rows
      EXPORTING
        et_scenarios TYPE tt_scenarios
        et_tms       TYPE tt_tms
        et_warnings  TYPE string_table.

    CLASS-METHODS parse_visibility
      IMPORTING
        iv_scenario_name     TYPE string
        iv_json              TYPE string
        it_known_sem_objects TYPE tt_known_sem_objects
        it_known_sem_actions TYPE tt_known_sem_actions
        it_known_tms         TYPE tt_known_tms
      CHANGING
        ct_tms               TYPE tt_tms
        ct_warnings          TYPE string_table.



    CLASS-METHODS persist_data
      IMPORTING
        it_scenarios TYPE tt_scenarios
        it_tms       TYPE tt_tms.


ENDCLASS.



CLASS zzcl_drj_scen_excel_proc IMPLEMENTATION.

  METHOD process.

    DATA(lt_rows) = read_excel( iv_xstring ).

    ev_rows = lines( lt_rows ).

    " Safety: never replace existing Admin Center data
    " if no usable Excel rows were read.
    IF lt_rows IS INITIAL.

      APPEND
        |No usable scenario rows found in file '{ iv_file_name }'. No database changes made.|
        TO ev_warnings.

      RETURN.

    ENDIF.


    DATA:
      lt_scenarios TYPE tt_scenarios,
      lt_tms       TYPE tt_tms,
      lt_warnings  TYPE string_table.

    build_data(
      EXPORTING
        it_rows      = lt_rows
      IMPORTING
        et_scenarios = lt_scenarios
        et_tms       = lt_tms
        et_warnings  = lt_warnings ).


    ev_scenarios = lines( lt_scenarios ).
    ev_tms       = lines( lt_tms ).
    ev_warnings  = lt_warnings.


    " Safety: do not delete existing data if we failed
    " to construct any scenarios.
    IF lt_scenarios IS INITIAL.

      APPEND
        |No valid scenarios could be built from file '{ iv_file_name }'. No database changes made.|
        TO ev_warnings.

      RETURN.

    ENDIF.


    " Everything has been successfully prepared in memory.
    " Replace only the Joule Admin Center capability data.
    persist_data(
      it_scenarios = lt_scenarios
      it_tms       = lt_tms ).

  ENDMETHOD.


  METHOD read_excel.

    DATA(lo_xl) = NEW cl_fdt_xl_spreadsheet(
      document_name = `upload`
      xdocument     = iv_xstring ).

    DATA lt_sheet_names TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    lo_xl->if_fdt_doc_spreadsheet~get_worksheet_names(
      IMPORTING
        worksheet_names = lt_sheet_names ).

    IF NOT line_exists( lt_sheet_names[ table_line = `Scenarios` ] ).
      RETURN.
    ENDIF.

    DATA(lr_itab) =
  lo_xl->if_fdt_doc_spreadsheet~get_itab_from_worksheet(
    worksheet_name = `Scenarios` ).

    IF lr_itab IS NOT BOUND.
      RETURN.
    ENDIF.

    IF validate_headers( lr_itab ) = abap_false.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS:
      <lt_data>      TYPE STANDARD TABLE,
      <ls_excel_row> TYPE any.

    ASSIGN lr_itab->* TO <lt_data>.

    IF <lt_data> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS:
      <lv_excel_value>  TYPE any,
      <lv_target_value> TYPE any.

    DATA ls_row TYPE ty_row.

    " Row 1 contains the column headings
    LOOP AT <lt_data> ASSIGNING <ls_excel_row> FROM 2.

      CLEAR ls_row.


      " Copy the 10 Excel columns into TY_ROW
      DO 10 TIMES.

        UNASSIGN:
          <lv_excel_value>,
          <lv_target_value>.

        ASSIGN COMPONENT sy-index
          OF STRUCTURE <ls_excel_row>
          TO <lv_excel_value>.

        IF sy-subrc <> 0.
          EXIT.
        ENDIF.

        ASSIGN COMPONENT sy-index
          OF STRUCTURE ls_row
          TO <lv_target_value>.

        IF sy-subrc = 0.
          <lv_target_value> = CONV string( <lv_excel_value> ).
        ENDIF.

      ENDDO.

      ls_row-scenario_name = condense( ls_row-scenario_name ).

      " Ignore completely invalid rows without a Scenario Name
      IF ls_row-scenario_name IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND ls_row TO rt_rows.

    ENDLOOP.

  ENDMETHOD.

  METHOD validate_headers.

    rv_valid = abap_false.

    FIELD-SYMBOLS:
      <lt_data>   TYPE STANDARD TABLE,
      <ls_header> TYPE any,
      <lv_cell>   TYPE any.

    ASSIGN ir_itab->* TO <lt_data>.

    IF <lt_data> IS NOT ASSIGNED OR <lt_data> IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE <lt_data>
      ASSIGNING <ls_header>
      INDEX 1.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.


    DATA lt_expected_headers TYPE STANDARD TABLE OF string WITH EMPTY KEY.


    lt_expected_headers = VALUE #(
      ( `Scenario Name` )
      ( `Description` )
      ( `Product ID` )
      ( `Deployment Status` )
      ( `Skip Reason` )
      ( `Scenario Type` )
      ( `Visibility Condition` )
      ( `Supported Languages` )
      ( `System Name` )
      ( `System Type` )
    ).


    LOOP AT lt_expected_headers INTO DATA(lv_expected_header).

      ASSIGN COMPONENT sy-tabix
        OF STRUCTURE <ls_header>
        TO <lv_cell>.

      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

      DATA(lv_actual_header) =
        condense( CONV string( <lv_cell> ) ).

      IF lv_actual_header <> lv_expected_header.
        RETURN.
      ENDIF.

    ENDLOOP.


    rv_valid = abap_true.

  ENDMETHOD.

  METHOD build_data.

    DATA lt_known_sem_objects TYPE tt_known_sem_objects.
    DATA lt_known_sem_actions TYPE tt_known_sem_actions.
    DATA lt_known_tms         TYPE tt_known_tms.

    DATA(lt_all_system_tms) =
      zcl_drj_flp_start_up_utility=>lookup_all_tms( ).

    LOOP AT lt_all_system_tms ASSIGNING FIELD-SYMBOL(<ls_system_tm>).

      IF <ls_system_tm>-object IS NOT INITIAL.
        INSERT CONV string( <ls_system_tm>-object )
          INTO TABLE lt_known_sem_objects.
      ENDIF.

      IF <ls_system_tm>-action IS NOT INITIAL.
        INSERT CONV string( <ls_system_tm>-action )
          INTO TABLE lt_known_sem_actions.
      ENDIF.

      IF <ls_system_tm>-object IS NOT INITIAL
         AND <ls_system_tm>-action IS NOT INITIAL.

        INSERT VALUE #(
          semantic_object = CONV string( <ls_system_tm>-object )
          semantic_action = CONV string( <ls_system_tm>-action )
        ) INTO TABLE lt_known_tms.

      ENDIF.

    ENDLOOP.

    LOOP AT it_rows INTO DATA(ls_row).

      DATA(lv_scenario_name) = condense( ls_row-scenario_name ).

      IF lv_scenario_name IS INITIAL.
        CONTINUE.
      ENDIF.

      " ------------------------------------------------------------
      " One unique Scenario Name = one scenario in ZDRJ_CP_SCENARIO.
      " Duplicate rows in Excel will therefore contribute additional
      " target mappings to the same logical scenario.
      " ------------------------------------------------------------
        INSERT VALUE #(
          capability_name      = gc_capability_name
          scenario_name        = CONV #( lv_scenario_name )
         "scenario_description = CONV #( ls_row-description )
          scenario_description = CONV #( lv_scenario_name )
        ) INTO TABLE et_scenarios.

      " Duplicate scenario names are expected in the Admin Center
      " export, therefore duplicate-key here is intentionally ignored.

      parse_visibility(
        EXPORTING
          iv_scenario_name     = lv_scenario_name
          iv_json              = ls_row-visibility_condition
          it_known_sem_objects = lt_known_sem_objects
          it_known_sem_actions = lt_known_sem_actions
          it_known_tms         = lt_known_tms
        CHANGING
          ct_tms               = et_tms
          ct_warnings          = et_warnings ).

    ENDLOOP.

  ENDMETHOD.


  METHOD parse_visibility.

    DATA(lv_json) = condense( iv_json ).

    " Some Admin Center rows contain the literal value 12 instead
    " of a Visibility Condition JSON structure.
    IF lv_json IS INITIAL OR lv_json = `12`.

      APPEND
        |Scenario '{ iv_scenario_name }': no usable Visibility Condition|
        TO ct_warnings.

      RETURN.

    ENDIF.


    DATA ls_visibility TYPE ty_visibility.

    TRY.

        /ui2/cl_json=>deserialize(
          EXPORTING
            json = iv_json
          CHANGING
            data = ls_visibility ).

      CATCH cx_root INTO DATA(lx_json).

        APPEND
          |Scenario '{ iv_scenario_name }': invalid Visibility Condition JSON - { lx_json->get_text( ) }|
          TO ct_warnings.

        RETURN.

    ENDTRY.


    LOOP AT ls_visibility-objects INTO DATA(ls_object).

      DATA(lv_type) = ls_object-type.
      TRANSLATE lv_type TO LOWER CASE.

      " We currently only process intent-based-navigation targets.
      IF lv_type <> `ibn_targets`.
        CONTINUE.
      ENDIF.


      DATA(lv_operator) = condense( ls_object-match_mode ).
      TRANSLATE lv_operator TO UPPER CASE.

      " Only ANY / ALL are currently meaningful for Joule scenario dependencies.
      " If Admin Center provides something else, leave OPERATOR empty.
      IF lv_operator <> 'ANY' AND lv_operator <> 'ALL'.
        CLEAR lv_operator.
      ENDIF.


      LOOP AT ls_object-value INTO DATA(lv_target).

        lv_target = condense( lv_target ).

        IF lv_target IS INITIAL.
          CONTINUE.
        ENDIF.


        " IBN target format:
        " SemanticObject-Action
        "
        " Example:
        " BusinessPartner-maintain

        DATA(lv_dash) = find(
          val = lv_target
          sub = `-` ).

        DATA(lv_target_length) = strlen( lv_target ).

        IF lv_dash <= 0 OR
           lv_dash >= lv_target_length - 1.

          APPEND
            |Scenario '{ iv_scenario_name }': invalid IBN target '{ lv_target }'|
            TO ct_warnings.

          CONTINUE.

        ENDIF.


        DATA(lv_semantic_object) =
          substring(
            val = lv_target
            len = lv_dash ).

        DATA(lv_semantic_action) =
          substring(
            val = lv_target
            off = lv_dash + 1 ).

        lv_semantic_object = condense( lv_semantic_object ).

        lv_semantic_action = condense( lv_semantic_action ).


        IF lv_semantic_object IS INITIAL OR

           lv_semantic_action IS INITIAL.

          CONTINUE.

        ENDIF.


        DATA(lv_semantic_object_exists) =
          xsdbool(
            line_exists(
              it_known_sem_objects[
                table_line = lv_semantic_object ] ) ).

        DATA(lv_semantic_action_exists) =
          xsdbool(
            line_exists(
              it_known_sem_actions[
                table_line = lv_semantic_action ] ) ).

        DATA(lv_tm_exists) =
          xsdbool(
            line_exists(
              it_known_tms[
                semantic_object = lv_semantic_object
                semantic_action = lv_semantic_action ] ) ).


        IF lv_semantic_object_exists = abap_false.

          APPEND
            |[SEMANTIC OBJECT] Scenario '{ iv_scenario_name }': semantic object '{ lv_semantic_object }' not found in system for Target Mapping '{ lv_target }'|
            TO ct_warnings.

        ENDIF.


        IF lv_semantic_action_exists = abap_false.

          APPEND
            |[SEMANTIC ACTION] Scenario '{ iv_scenario_name }': semantic action '{ lv_semantic_action }' not found in system for Target Mapping '{ lv_target }'|
            TO ct_warnings.

        ENDIF.


        IF lv_tm_exists = abap_false
           AND lv_semantic_object_exists = abap_true
           AND lv_semantic_action_exists = abap_true.

          APPEND
            |[TARGET MAPPING] Scenario '{ iv_scenario_name }': Target Mapping '{ lv_target }' not found in system|
            TO ct_warnings.

        ENDIF.


        " Check whether this exact TM already exists.
        READ TABLE ct_tms
          ASSIGNING FIELD-SYMBOL(<ls_existing_tm>)
          WITH TABLE KEY
            capability_name = gc_capability_name
            scenario_name   = iv_scenario_name
            semantic_object = lv_semantic_object
            semantic_action = lv_semantic_action
            catalog_id      = ``.

        IF sy-subrc = 0.
          " Same TM should normally have the same visibility operator.
          IF <ls_existing_tm>-operator <> lv_operator.
            APPEND
              |Scenario '{ iv_scenario_name }': target '{ lv_target }' has conflicting operators '{ <ls_existing_tm>-operator }' and '{ lv_operator }'|
              TO ct_warnings.
          ENDIF.

          CONTINUE.
        ENDIF.


        INSERT VALUE #(
          capability_name        = gc_capability_name
          scenario_name          = CONV #( iv_scenario_name )
          semantic_object        = CONV #( lv_semantic_object )
          semantic_action        = CONV #( lv_semantic_action )

          semantic_object_exists = lv_semantic_object_exists
          semantic_action_exists = lv_semantic_action_exists

          " Admin Center export does not provide a catalog.
          catalog_id             = ``
          catalog_exists         = abap_false
          tm_exists_in_catalog   = abap_false

          " Visibility Condition from Joule Admin Center:
            " ANY = at least one dependency must be available
            " ALL = all dependencies must be available
            operator        = CONV #( lv_operator )

          ) INTO TABLE ct_tms.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

  METHOD persist_data.

    " ------------------------------------------------------------
    " Full replacement of Joule reference data,
    " same behaviour as the existing Excel importer.
    " ------------------------------------------------------------

    DELETE FROM zdrj_capability.
    DELETE FROM zdrj_cap_brole.
    DELETE FROM zdrj_cp_scenario.
    DELETE FROM zdrj_scen_api.
    DELETE FROM zdrj_scen_tm.


    " Create the single dummy capability for Admin Center scenarios
    DATA(ls_capability) = VALUE zdrj_capability(
      capability_name        = gc_capability_name
      capability_displayname = gc_capability_name
    ).

    INSERT zdrj_capability FROM @ls_capability.


    IF it_scenarios IS NOT INITIAL.

      INSERT zdrj_cp_scenario
        FROM TABLE @it_scenarios.

    ENDIF.


    IF it_tms IS NOT INITIAL.

      INSERT zdrj_scen_tm
        FROM TABLE @it_tms.

    ENDIF.

  ENDMETHOD.

ENDCLASS.
