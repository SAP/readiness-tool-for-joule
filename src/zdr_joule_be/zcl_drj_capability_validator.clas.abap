CLASS zcl_drj_capability_validator DEFINITION

"            Capability
"             ├─ determine_overall_health
"             ├─ validate_capability_act
"             │   ├─ validate_capability_odata_act
"             │   └─ validate_capability_tm_act
"             └─ validate_capability_auth
"                 ├─ validate_capability_odata_auth
"                 └─ validate_capability_tm_auth
"
"            Scenario
"             ├─ determine_scenario_health
"             ├─ validate_scenario_act
"             │   ├─ validate_scenario_odata_act
"             │   └─ validate_scenario_tm_act
"             └─ validate_scenario_auth
"                 ├─ validate_scenario_odata_auth
"                 └─ validate_scenario_tm_auth


  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS:
      gc_success TYPE char1 VALUE 'S',
      gc_warning TYPE char1 VALUE 'W',
      gc_error   TYPE char1 VALUE 'E'.


    CLASS-METHODS determine_overall_health
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.

    CLASS-METHODS determine_scenario_health
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_scenario_name   TYPE zdrj_cp_scenario-scenario_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.


  PROTECTED SECTION.
  PRIVATE SECTION.

    "---------------------------------------------------------
    " Capability specific methods for validating Auth and Act
    "---------------------------------------------------------
    "validate_capability_act (main method)
    "validate_capability_auth (main method)
    "validate_capability_odata_act (helper for main act)
    "validate_capability_tm_act  (helper for main act)
    "validate_capability_odata_auth(helper for main auth)
    "validate_capability_tm_auth (helper for main auth)

    CLASS-METHODS validate_capability_act
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.

    CLASS-METHODS validate_capability_auth
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.

    CLASS-METHODS validate_capability_odata_act
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
      RETURNING
        VALUE(rv_status)   TYPE char1.

    CLASS-METHODS validate_capability_tm_act
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.

    CLASS-METHODS validate_capability_odata_auth
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.



    CLASS-METHODS validate_capability_tm_auth
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.

    "---------------------------------------------------------
    " Scenario specific methods for validating Auth and Act
    "---------------------------------------------------------
    "validate_scenaroi_act (main method)
    "validate_scenaroi_auth (main method)
    "validate_scenaroi_odata_act (helper for main act)
    "validate_scenaroi_tm_act  (helper for main act)
    "validate_scenaroi_odata_auth(helper for main auth)
    "validate_scenaroi_tm_auth (helper for main auth)
    CLASS-METHODS validate_scenario_act
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_scenario_name   TYPE zdrj_cp_scenario-scenario_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.

    CLASS-METHODS validate_scenario_auth
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_scenario_name   TYPE zdrj_cp_scenario-scenario_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.


    CLASS-METHODS validate_scenario_odata_act
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_scenario_name   TYPE zdrj_cp_scenario-scenario_name
      RETURNING
        VALUE(rv_status)   TYPE char1.

    CLASS-METHODS validate_scenario_tm_act
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_scenario_name   TYPE zdrj_cp_scenario-scenario_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.

    CLASS-METHODS validate_scenario_odata_auth
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_scenario_name   TYPE zdrj_cp_scenario-scenario_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.

    CLASS-METHODS validate_scenario_tm_auth
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_scenario_name   TYPE zdrj_cp_scenario-scenario_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rv_status)   TYPE char1.
ENDCLASS.



CLASS zcl_drj_capability_validator IMPLEMENTATION.

  METHOD determine_overall_health.

    DATA(lv_context_user) = COND syuname(
                              WHEN iv_user IS NOT INITIAL
                              THEN iv_user
                              ELSE sy-uname ).


    "---------------------------------------------------------
    " Step 1 - Validate Capability activation
    "
    " Activation Error   -> overall Error
    " Activation Warning -> overall Warning
    " Activation Success -> continue with authorization
    "---------------------------------------------------------
    DATA(lv_act_status) =
      validate_capability_act(
        iv_capability_name = iv_capability_name
        iv_user            = lv_context_user ).


    CASE lv_act_status.

      WHEN gc_error.

        rv_status = gc_error.
        RETURN.


      WHEN gc_warning.

        "Activation Warning already fixes the overall result
        "at Warning. Authorization cannot make it Error because
        "authorization problems are represented as overall Warning.
        rv_status = gc_warning.
        RETURN.

    ENDCASE.


    "---------------------------------------------------------
    " Step 2 - Validate Capability authorization
    "
    " Authorization Error or Warning both result in overall
    " Warning because the Capability is technically active.
    "---------------------------------------------------------
    DATA(lv_auth_status) =
      validate_capability_auth(
        iv_capability_name = iv_capability_name
        iv_user            = lv_context_user ).


    IF lv_auth_status = gc_error
       OR lv_auth_status = gc_warning.

      rv_status = gc_warning.
      RETURN.

    ENDIF.


    "---------------------------------------------------------
    " Step 3 - Activation and authorization are successful
    "---------------------------------------------------------
    rv_status = gc_success.

  ENDMETHOD.

  METHOD validate_capability_act.

    "Step 1 - Validate OData activation
    IF validate_capability_odata_act(
         iv_capability_name = iv_capability_name ) = gc_error.
      "If the Capability contains inactive OData service,
      "We halt and return overall error (inactive status)
      rv_status = gc_error.
      RETURN.

    ENDIF.


    "Step 2 - Validate Target Mapping activation
    DATA(lv_tm_status) =
      validate_capability_tm_act(
        iv_capability_name = iv_capability_name
        iv_user            = iv_user ).


    CASE lv_tm_status.

      WHEN gc_error.

        rv_status = gc_error.
        RETURN.


      WHEN gc_warning.

        rv_status = gc_warning.
        RETURN.

    ENDCASE.

    rv_status = gc_success.

  ENDMETHOD.

  METHOD validate_capability_auth.

    "Step 1 - Validate OData authorization
    IF validate_capability_odata_auth(
         iv_capability_name = iv_capability_name
         iv_user            = iv_user ) = gc_error.

      rv_status = gc_error.
      RETURN.

    ENDIF.


    "Step 2 - Validate Target Mapping authorization
    DATA(lv_tm_status) =
      validate_capability_tm_auth(
        iv_capability_name = iv_capability_name
        iv_user            = iv_user ).


    CASE lv_tm_status.

      WHEN gc_error.

        rv_status = gc_error.
        RETURN.


      WHEN gc_warning.

        rv_status = gc_warning.
        RETURN.

    ENDCASE.

    rv_status = gc_success.

  ENDMETHOD.

  METHOD validate_capability_odata_act.

    rv_status = gc_success.

    SELECT
        capabilityname,
        scenarioname,
        odataservicename,
        apiversion
      FROM zi_drj_scenarioapi
      WHERE capabilityname = @iv_capability_name
      INTO TABLE @DATA(lt_apis).

    "No APIs found.
    "This is not necessarily an error because some capabilities
    "may not require any backend service.
    IF lt_apis IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_apis ASSIGNING FIELD-SYMBOL(<ls_api>).
      CASE <ls_api>-apiversion.
        WHEN 'V2'.
          DATA(ls_v2_status) =
            zcl_drj_service_checker=>check_odata_v2_service_act(
              iv_service_name = CONV #( <ls_api>-odataservicename )
            ).
          IF ls_v2_status-gw_active <> abap_true  OR ( ls_v2_status-icf_exists = abap_true AND ls_v2_status-icf_active <> abap_true ).
            rv_status = gc_error.
            RETURN.
          ENDIF.
        WHEN 'V4'.
          DATA(ls_v4_status) =
            zcl_drj_service_checker=>check_odata_v4_service_act(
              iv_group_id = CONV #( <ls_api>-odataservicename )
            ).
          IF ls_v4_status-gw_active <> abap_true.
            rv_status = gc_error.
            RETURN.
          ENDIF.
        WHEN OTHERS.
          rv_status = gc_error.
          RETURN.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_capability_odata_auth.

    rv_status = gc_success.

    SELECT
        capabilityname,
        scenarioname,
        odataservicename,
        apiversion
      FROM zi_drj_scenarioapi
      WHERE capabilityname = @iv_capability_name
      INTO TABLE @DATA(lt_apis).

    "No APIs found.
    "This is not necessarily an error because some capabilities
    "may not require any backend service.
    IF lt_apis IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_apis ASSIGNING FIELD-SYMBOL(<ls_api>).
      CASE <ls_api>-apiversion.
        WHEN 'V2'.
          DATA(ls_v2_auth) =
            zcl_drj_service_checker=>check_odata_v2_service_auth(
              iv_service_name = CONV #( <ls_api>-odataservicename )
              iv_user         = iv_user
            ).
          "Both IWSG and IWSV must be missing to count as error;
          "partial auth (one of two) is acceptable here
          IF ls_v2_auth-iwsg_auth = abap_false AND ls_v2_auth-iwsv_auth = abap_false.
            rv_status = gc_error.
            RETURN.
          ENDIF.
        WHEN 'V4'.
          DATA(ls_v4_auth) =
            zcl_drj_service_checker=>check_odata_v4_service_auth(
              iv_group_id = CONV #( <ls_api>-odataservicename )
              iv_user     = iv_user
            ).
          IF ls_v4_auth-service_auth = abap_false.
            rv_status = gc_error.
            RETURN.
          ENDIF.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_capability_tm_act.

    rv_status = gc_success.

    "Read all Target Mappings for the Capability in one DB call.
    SELECT
        scenarioname,
        semanticobject,
        semanticaction,
        catalogid,
        operator
      FROM zi_drj_scenariotargetmapping
      WHERE capabilityname = @iv_capability_name
      INTO TABLE @DATA(lt_tms).

    "No TMs means no TM-related activation problem.
    IF lt_tms IS INITIAL.
      RETURN.
    ENDIF.


    "Capability may contain multiple Scenarios.
    "A Warning must be remembered because a later Scenario
    "can still produce Error.
    DATA lv_capability_has_warning TYPE abap_bool.


    "---------------------------------------------------------
    " Group all Capability TMs by Scenario.
    "
    " Important:
    " - DB was accessed only once.
    " - Each Scenario evaluates its own ANY / ALL semantics.
    "---------------------------------------------------------
    LOOP AT lt_tms ASSIGNING FIELD-SYMBOL(<ls_group_member>)
         GROUP BY <ls_group_member>-scenarioname
         ASSIGNING FIELD-SYMBOL(<scenario_group>).


      DATA:
        lv_operator        TYPE zdrj_scen_tm-operator,
        lv_has_success     TYPE abap_bool,
        lv_has_non_success TYPE abap_bool,
        lv_scenario_status TYPE char1.


      CLEAR:
        lv_operator,
        lv_has_success,
        lv_has_non_success,
        lv_scenario_status.


      "-------------------------------------------------------
      " Evaluate the Target Mappings belonging to this Scenario
      "-------------------------------------------------------
      LOOP AT GROUP <scenario_group>
           ASSIGNING FIELD-SYMBOL(<ls_tm>).


        "Use the first TM as the Scenario operator.
        IF lv_operator IS INITIAL.
          lv_operator = <ls_tm>-operator.
        ENDIF.


        DATA(ls_tm_status) =
          zcl_drj_service_checker=>check_target_mapping_act(
            iv_semantic_object = CONV #( <ls_tm>-semanticobject )
            iv_semantic_action = CONV #( <ls_tm>-semanticaction )
            iv_catalog_id      = CONV string( <ls_tm>-catalogid )
            iv_user            = VALUE syuname( ) ). "No user context: activation is system-wide


        "-----------------------------------------------------
        " ANY = OR semantics
        "-----------------------------------------------------
        IF lv_operator = 'ANY'.

          IF ls_tm_status-status = gc_success.

            lv_has_success = abap_true.

          ELSE.

            lv_has_non_success = abap_true.

          ENDIF.


          "As soon as both states exist, this Scenario
          "is definitively Warning.
          "
          "No need to inspect the remaining TMs of this Scenario.
          IF lv_has_success = abap_true
             AND lv_has_non_success = abap_true.

            lv_scenario_status = gc_warning.
            EXIT.

          ENDIF.


          "-----------------------------------------------------
          " ALL / blank / unexpected operator
          "-----------------------------------------------------
        ELSE.

          "Strict semantics:
          "one failing TM makes the Scenario fail.
          IF ls_tm_status-status = gc_error.

            "One Scenario Error makes the whole Capability Error.
            rv_status = gc_error.
            RETURN.

          ENDIF.

        ENDIF.

      ENDLOOP.


      "-------------------------------------------------------
      " Finalize ANY Scenario if it did not already become mixed
      "-------------------------------------------------------
      IF lv_operator = 'ANY'
         AND lv_scenario_status IS INITIAL.

        IF lv_has_success = abap_true.

          "Reached the end and never saw a non-success.
          lv_scenario_status = gc_success.

        ELSE.

          "Reached the end without finding one successful TM.
          lv_scenario_status = gc_error.

        ENDIF.

      ENDIF.


      "-------------------------------------------------------
      " Propagate Scenario result to Capability
      "-------------------------------------------------------
      CASE lv_scenario_status.

        WHEN gc_error.

          "One bad Scenario is enough to make Capability Error.
          rv_status = gc_error.
          RETURN.


        WHEN gc_warning.

          "Remember Warning, but continue because another
          "Scenario may still be Error.
          lv_capability_has_warning = abap_true.

      ENDCASE.

    ENDLOOP.


    "---------------------------------------------------------
    " No Scenario produced Error.
    " Return the most severe state encountered.
    "---------------------------------------------------------
    IF lv_capability_has_warning = abap_true.

      rv_status = gc_warning.

    ELSE.

      rv_status = gc_success.

    ENDIF.

  ENDMETHOD.

  METHOD validate_capability_tm_auth.

    rv_status = gc_success.

    "Read all Target Mappings for the Capability in one DB call.
    SELECT
        scenarioname,
        semanticobject,
        semanticaction,
        catalogid,
        operator
      FROM zi_drj_scenariotargetmapping
      WHERE capabilityname = @iv_capability_name
      INTO TABLE @DATA(lt_tms).

    "No TMs means no TM-related authorization problem.
    IF lt_tms IS INITIAL.
      RETURN.
    ENDIF.


    "Capability may contain multiple Scenarios.
    "A Warning must be remembered because a later Scenario
    "can still produce Error.
    DATA lv_capability_has_warning TYPE abap_bool.


    "---------------------------------------------------------
    " Group all Capability TMs by Scenario.
    "
    " Important:
    " - DB was accessed only once.
    " - Each Scenario evaluates its own ANY / ALL semantics.
    "---------------------------------------------------------
    LOOP AT lt_tms ASSIGNING FIELD-SYMBOL(<ls_group_member>)
         GROUP BY <ls_group_member>-scenarioname
         ASSIGNING FIELD-SYMBOL(<scenario_group>).


      DATA:
        lv_operator        TYPE zdrj_scen_tm-operator,
        lv_has_success     TYPE abap_bool,
        lv_has_non_success TYPE abap_bool,
        lv_scenario_status TYPE char1.


      CLEAR:
        lv_operator,
        lv_has_success,
        lv_has_non_success,
        lv_scenario_status.


      "-------------------------------------------------------
      " Evaluate the Target Mappings belonging to this Scenario
      "-------------------------------------------------------
      LOOP AT GROUP <scenario_group>
           ASSIGNING FIELD-SYMBOL(<ls_tm>).


        "Use the first TM as the Scenario operator.
        IF lv_operator IS INITIAL.
          lv_operator = <ls_tm>-operator.
        ENDIF.


        DATA(ls_tm_auth) =
          zcl_drj_service_checker=>check_target_mapping_auth(
            iv_semantic_object = CONV #( <ls_tm>-semanticobject )
            iv_semantic_action = CONV #( <ls_tm>-semanticaction )
            iv_catalog_id      = CONV string( <ls_tm>-catalogid )
            iv_user            = iv_user ).


        "-----------------------------------------------------
        " ANY = OR semantics
        "-----------------------------------------------------
        IF lv_operator = 'ANY'.

          IF ls_tm_auth-status = gc_success.

            lv_has_success = abap_true.

          ELSE.

            lv_has_non_success = abap_true.

          ENDIF.


          "As soon as both states exist, this Scenario
          "is definitively Warning.
          "
          "No need to inspect the remaining TMs of this Scenario.
          IF lv_has_success = abap_true
             AND lv_has_non_success = abap_true.

            lv_scenario_status = gc_warning.
            EXIT.

          ENDIF.


          "-----------------------------------------------------
          " ALL / blank / unexpected operator
          "-----------------------------------------------------
        ELSE.

          "Strict semantics:
          "one failing TM makes the Scenario authorization fail.
          IF ls_tm_auth-status = gc_error.

            "One Scenario Error makes Capability authorization Error.
            rv_status = gc_error.
            RETURN.

          ENDIF.

        ENDIF.

      ENDLOOP.


      "-------------------------------------------------------
      " Finalize ANY Scenario if it did not already become mixed
      "-------------------------------------------------------
      IF lv_operator = 'ANY'
         AND lv_scenario_status IS INITIAL.

        IF lv_has_success = abap_true.

          "Reached the end and never saw a non-success.
          lv_scenario_status = gc_success.

        ELSE.

          "Reached the end without finding one authorized TM.
          lv_scenario_status = gc_error.

        ENDIF.

      ENDIF.


      "-------------------------------------------------------
      " Propagate Scenario authorization result to Capability
      "-------------------------------------------------------
      CASE lv_scenario_status.

        WHEN gc_error.

          rv_status = gc_error.
          RETURN.


        WHEN gc_warning.

          "Remember Warning, but continue because another
          "Scenario may still be Error.
          lv_capability_has_warning = abap_true.

      ENDCASE.

    ENDLOOP.


    "---------------------------------------------------------
    " No Scenario produced Error.
    " Return the most severe state encountered.
    "---------------------------------------------------------
    IF lv_capability_has_warning = abap_true.

      rv_status = gc_warning.

    ELSE.

      rv_status = gc_success.

    ENDIF.

  ENDMETHOD.

  METHOD determine_scenario_health.

    DATA(lv_context_user) = COND syuname(
                              WHEN iv_user IS NOT INITIAL
                              THEN iv_user
                              ELSE sy-uname ).


    "---------------------------------------------------------
    " Step 1 - Validate scenario activation
    "
    " Activation Error   -> overall Error
    " Activation Warning -> overall Warning
    " Activation Success -> continue with authorization
    "---------------------------------------------------------
    DATA(lv_act_status) =
      validate_scenario_act(
        iv_capability_name = iv_capability_name
        iv_scenario_name   = iv_scenario_name
        iv_user            = lv_context_user ).


    CASE lv_act_status.

      WHEN gc_error.

        rv_status = gc_error.
        RETURN.


      WHEN gc_warning.

        "The scenario is usable because at least one ANY
        "alternative works, but not all alternatives work.
        "
        "Authorization cannot increase the overall severity
        "beyond Warning, so we can stop here.
        rv_status = gc_warning.
        RETURN.

    ENDCASE.


    "---------------------------------------------------------
    " Step 2 - Validate scenario authorization
    "
    " Authorization Error or Warning both result in an
    " overall Warning because activation itself is healthy.
    "---------------------------------------------------------
    DATA(lv_auth_status) =
      validate_scenario_auth(
        iv_capability_name = iv_capability_name
        iv_scenario_name   = iv_scenario_name
        iv_user            = lv_context_user ).


    IF lv_auth_status = gc_error
       OR lv_auth_status = gc_warning.

      rv_status = gc_warning.
      RETURN.

    ENDIF.


    "---------------------------------------------------------
    " Step 3 - Activation and authorization are successful
    "---------------------------------------------------------
    rv_status = gc_success.

  ENDMETHOD.

  METHOD validate_scenario_act.

    "Step 1 - Validate OData activation
    IF validate_scenario_odata_act(
         iv_capability_name = iv_capability_name
         iv_scenario_name   = iv_scenario_name ) = gc_error.

      rv_status = gc_error.
      RETURN.

    ENDIF.


    "Step 2 - Validate Target Mapping activation
    DATA(lv_tm_status) =
      validate_scenario_tm_act(
        iv_capability_name = iv_capability_name
        iv_scenario_name   = iv_scenario_name
        iv_user            = iv_user ).


    CASE lv_tm_status.

      WHEN gc_error.

        rv_status = gc_error.
        RETURN.

      WHEN gc_warning.

        rv_status = gc_warning.
        RETURN.

    ENDCASE.

    rv_status = gc_success.

  ENDMETHOD.

  METHOD validate_scenario_auth.

    "Step 1 - Validate OData authorization
    IF validate_scenario_odata_auth(
         iv_capability_name = iv_capability_name
         iv_scenario_name   = iv_scenario_name
         iv_user            = iv_user ) = gc_error.

      rv_status = gc_error.
      RETURN.

    ENDIF.


    "Step 2 - Validate Target Mapping authorization
    DATA(lv_tm_status) =
      validate_scenario_tm_auth(
        iv_capability_name = iv_capability_name
        iv_scenario_name   = iv_scenario_name
        iv_user            = iv_user ).


    CASE lv_tm_status.

      WHEN gc_error.

        rv_status = gc_error.
        RETURN.

      WHEN gc_warning.

        rv_status = gc_warning.
        RETURN.

    ENDCASE.

    rv_status = gc_success.

  ENDMETHOD.

  METHOD validate_scenario_odata_act.

    rv_status = gc_success.

    SELECT
        capabilityname,
        scenarioname,
        odataservicename,
        apiversion
      FROM zi_drj_scenarioapi
      WHERE capabilityname = @iv_capability_name
        AND scenarioname   = @iv_scenario_name
      INTO TABLE @DATA(lt_apis).

    "No APIs found.
    "This is not necessarily an error because some scenarios
    "may not require any backend service.
    IF lt_apis IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_apis ASSIGNING FIELD-SYMBOL(<ls_api>).

      CASE <ls_api>-apiversion.

        WHEN 'V2'.

          DATA(ls_v2_status) =
            zcl_drj_service_checker=>check_odata_v2_service_act(
              iv_service_name = CONV #( <ls_api>-odataservicename )
            ).

          IF ls_v2_status-gw_active <> abap_true
             OR ( ls_v2_status-icf_exists = abap_true
                  AND ls_v2_status-icf_active <> abap_true ).

            rv_status = gc_error.
            RETURN.

          ENDIF.

        WHEN 'V4'.

          DATA(ls_v4_status) =
            zcl_drj_service_checker=>check_odata_v4_service_act(
              iv_group_id = CONV #( <ls_api>-odataservicename )
            ).

          IF ls_v4_status-gw_active <> abap_true.

            rv_status = gc_error.
            RETURN.

          ENDIF.

        WHEN OTHERS.

          rv_status = gc_error.
          RETURN.

      ENDCASE.

    ENDLOOP.

  ENDMETHOD.

  METHOD validate_scenario_odata_auth.

    rv_status = gc_success.

    SELECT
        capabilityname,
        scenarioname,
        odataservicename,
        apiversion
      FROM zi_drj_scenarioapi
      WHERE capabilityname = @iv_capability_name
        AND scenarioname   = @iv_scenario_name
      INTO TABLE @DATA(lt_apis).

    "No APIs found.
    "This is not necessarily an error because some scenarios
    "may not require any backend service.
    IF lt_apis IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_apis ASSIGNING FIELD-SYMBOL(<ls_api>).

      CASE <ls_api>-apiversion.

        WHEN 'V2'.

          DATA(ls_v2_auth) =
            zcl_drj_service_checker=>check_odata_v2_service_auth(
              iv_service_name = CONV #( <ls_api>-odataservicename )
              iv_user         = iv_user
            ).

          "Both IWSG and IWSV must be missing to count as error;
          "partial auth (one of two) is acceptable here
          IF ls_v2_auth-iwsg_auth = abap_false AND ls_v2_auth-iwsv_auth = abap_false.
            rv_status = gc_error.
            RETURN.
          ENDIF.

        WHEN 'V4'.

          DATA(ls_v4_auth) =
            zcl_drj_service_checker=>check_odata_v4_service_auth(
              iv_group_id = CONV #( <ls_api>-odataservicename )
              iv_user     = iv_user
            ).

          IF ls_v4_auth-service_auth = abap_false.
            rv_status = gc_error.
            RETURN.
          ENDIF.

        WHEN OTHERS.
          rv_status = gc_error.
          RETURN.

      ENDCASE.

    ENDLOOP.

  ENDMETHOD.

  METHOD validate_scenario_tm_act.

    rv_status = gc_success.

    SELECT
        capabilityname,
        scenarioname,
        semanticobject,
        semanticaction,
        catalogid,
        operator
      FROM zi_drj_scenariotargetmapping
      WHERE capabilityname = @iv_capability_name
        AND scenarioname   = @iv_scenario_name
      INTO TABLE @DATA(lt_tms).

    "No TMs found.
    "This is not necessarily an error because some scenarios
    "may not require navigation.
    IF lt_tms IS INITIAL.
      RETURN.
    ENDIF.


    "All TMs belonging to one scenario are expected to use
    "the same operator. Therefore the first record determines
    "how the TM group is evaluated.
    DATA(lv_operator) = lt_tms[ 1 ]-operator.


    "---------------------------------------------------------
    " ANY = OR semantics
    "
    " We continue only until the final result is known.
    "
    " All success             -> Success
    " All non-success         -> Error
    " Success + non-success   -> Warning
    "---------------------------------------------------------
    IF lv_operator = 'ANY'.

      DATA:
        lv_has_success     TYPE abap_bool,
        lv_has_non_success TYPE abap_bool.

      LOOP AT lt_tms ASSIGNING FIELD-SYMBOL(<ls_tm_any>).

        DATA(ls_tm_status_any) =
            zcl_drj_service_checker=>check_target_mapping_act(
              iv_semantic_object = CONV #( <ls_tm_any>-semanticobject )
              iv_semantic_action = CONV #( <ls_tm_any>-semanticaction )
              iv_catalog_id      = CONV string( <ls_tm_any>-catalogid )
              iv_user            = VALUE syuname( ) ). "No user context: activation is system-wide

        IF ls_tm_status_any-status = gc_success.

          lv_has_success = abap_true.

        ELSE.

          lv_has_non_success = abap_true.

        ENDIF.


        "Once both states have been found, the result can
        "only be Warning. Remaining TMs cannot change it.
        IF lv_has_success     = abap_true
           AND lv_has_non_success = abap_true.

          rv_status = gc_warning.
          RETURN.

        ENDIF.

      ENDLOOP.


      "If we reached the end, the result was not mixed.
      IF lv_has_success = abap_true.

        "Every evaluated TM was successful.
        rv_status = gc_success.

      ELSE.

        "No TM was successful.
        rv_status = gc_error.

      ENDIF.

      RETURN.

    ENDIF.


    "---------------------------------------------------------
    " ALL / blank / unexpected operator
    "
    " Strict behaviour: i.e stop immediately when the first Error is found.
    "---------------------------------------------------------
    LOOP AT lt_tms ASSIGNING FIELD-SYMBOL(<ls_tm>).

      DATA(ls_tm_status) =
    zcl_drj_service_checker=>check_target_mapping_act(
      iv_semantic_object = CONV #( <ls_tm>-semanticobject )
      iv_semantic_action = CONV #( <ls_tm>-semanticaction )
      iv_catalog_id      = CONV string( <ls_tm>-catalogid )
      iv_user            = VALUE syuname( ) ). "No user context: activation is system-wide

      IF ls_tm_status-status = gc_error.

        rv_status = gc_error.
        RETURN.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validate_scenario_tm_auth.

    rv_status = gc_success.

    SELECT
        capabilityname,
        scenarioname,
        semanticobject,
        semanticaction,
        catalogid,
        operator
      FROM zi_drj_scenariotargetmapping
      WHERE capabilityname = @iv_capability_name
        AND scenarioname   = @iv_scenario_name
      INTO TABLE @DATA(lt_tms).

    "No TMs found.
    "This is not necessarily an error because some scenarios
    "may not require navigation.
    IF lt_tms IS INITIAL.
      RETURN.
    ENDIF.


    "All TMs belonging to one scenario are expected to use
    "the same operator.
    DATA(lv_operator) = lt_tms[ 1 ]-operator.


    "---------------------------------------------------------
    " ANY = OR semantics
    "---------------------------------------------------------
    IF lv_operator = 'ANY'.

      DATA:
        lv_has_success     TYPE abap_bool,
        lv_has_non_success TYPE abap_bool.

      LOOP AT lt_tms ASSIGNING FIELD-SYMBOL(<ls_tm_any>).

        DATA(ls_tm_auth_any) =
          zcl_drj_service_checker=>check_target_mapping_auth(
            iv_semantic_object = CONV #( <ls_tm_any>-semanticobject )
            iv_semantic_action = CONV #( <ls_tm_any>-semanticaction )
            iv_catalog_id      = CONV string( <ls_tm_any>-catalogid )
            iv_user            = iv_user ).

        IF ls_tm_auth_any-status = gc_success.

          lv_has_success = abap_true.

        ELSE.

          lv_has_non_success = abap_true.

        ENDIF.


        "As soon as at least one TM is authorized and at least
        "one is not fully authorized, the result is fixed.
        IF lv_has_success     = abap_true
           AND lv_has_non_success = abap_true.

          rv_status = gc_warning.
          RETURN.

        ENDIF.

      ENDLOOP.


      "No mixed result was found.
      IF lv_has_success = abap_true.

        rv_status = gc_success.

      ELSE.

        rv_status = gc_error.

      ENDIF.

      RETURN.

    ENDIF.


    "---------------------------------------------------------
    " ALL / blank / unexpected operator
    "
    " Preserve existing strict behaviour.
    "---------------------------------------------------------
    LOOP AT lt_tms ASSIGNING FIELD-SYMBOL(<ls_tm>).

      DATA(ls_tm_auth) =
          zcl_drj_service_checker=>check_target_mapping_auth(
            iv_semantic_object = CONV #( <ls_tm>-semanticobject )
            iv_semantic_action = CONV #( <ls_tm>-semanticaction )
            iv_catalog_id      = CONV string( <ls_tm>-catalogid )
            iv_user            = iv_user ).

      IF ls_tm_auth-status = gc_error.

        rv_status = gc_error.
        RETURN.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
