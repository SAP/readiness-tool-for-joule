CLASS zcl_drj_cra_bg_operation DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_bgmc_op_single.

    METHODS constructor
      IMPORTING
        iv_analysis_uuid TYPE sysuuid_x16.

  PRIVATE SECTION.

    DATA mv_analysis_uuid TYPE sysuuid_x16.

ENDCLASS.


CLASS zcl_drj_cra_bg_operation IMPLEMENTATION.

  METHOD constructor.

    mv_analysis_uuid = iv_analysis_uuid.

  ENDMETHOD.


  METHOD if_bgmc_op_single~execute.

    "------------------------------------------------------------
    " 1. Validate that this analysis is still waiting for
    "    background processing
    "------------------------------------------------------------

    SELECT SINGLE status
      FROM zdrj_cra_hdr
      WHERE analysis_uuid = @mv_analysis_uuid
      INTO @DATA(lv_status).

    IF sy-subrc <> 0
       OR lv_status <> 'RUNNING'.
      RETURN.
    ENDIF.


    "------------------------------------------------------------
    " 2. Read the roles persisted for this AnalysisUUID
    "------------------------------------------------------------

    SELECT role_name
      FROM zdrj_cra_role
      WHERE analysis_uuid = @mv_analysis_uuid
      INTO TABLE @DATA(lt_persisted_roles).


    "Prepare the exact input expected by the existing CRA analyzer.
    DATA(lt_analyzer_roles) =
      VALUE zcl_drj_custom_role_analyzer=>tt_roles(
        FOR ls_role IN lt_persisted_roles
        (
          role_name = ls_role-role_name
        )
      ).


    "Do not execute a meaningless analysis without roles.
    IF lt_analyzer_roles IS INITIAL.

      cl_abap_tx=>save( ).

      UPDATE zdrj_cra_hdr
        SET status = 'FAILED'
        WHERE analysis_uuid = @mv_analysis_uuid.

      RETURN.

    ENDIF.


    "------------------------------------------------------------
    " 3. Run the EXISTING analyzer
    "
    " Still in bgPF MODIFY phase:
    " calculations / DB reads are allowed here.
    "------------------------------------------------------------

    TRY.

        zcl_drj_custom_role_analyzer=>analyze(
          EXPORTING
            it_roles   = lt_analyzer_roles
          IMPORTING
            et_results = DATA(lt_cra_results)
            et_missing = DATA(lt_cra_missing)
        ).

      CATCH cx_root INTO DATA(lx_error).

        "The analyzer failed before we entered SAVE phase.
        "Persist FAILED so the history table does not remain RUNNING forever.
        cl_abap_tx=>save( ).

        UPDATE zdrj_cra_hdr
          SET status = 'FAILED'
          WHERE analysis_uuid = @mv_analysis_uuid.

        RETURN.

    ENDTRY.


    "Same scenario-count logic as the productive synchronous path.
    SELECT capability_name,
           scenario_name
      FROM zdrj_cp_scenario
      INTO TABLE @DATA(lt_scenarios).

    DATA(lv_role_count)     = lines( lt_analyzer_roles ).
    DATA(lv_scenario_count) = lines( lt_scenarios ).
    DATA(lv_result_count)   = lines( lt_cra_results ).


    "------------------------------------------------------------
    " 4. Prepare DB rows while still in MODIFY phase
    "------------------------------------------------------------

    DATA lt_db_results TYPE STANDARD TABLE OF zdrj_cra_result
      WITH EMPTY KEY.

    lt_db_results =
      VALUE #(
        FOR ls_result IN lt_cra_results
        (
          mandt           = sy-mandt
          analysis_uuid   = mv_analysis_uuid
          role_name       = ls_result-role_name
          capability_name = ls_result-capability_name
          scenario_name   = ls_result-scenario_name
          coverage        = ls_result-coverage
          required_tm     = ls_result-required_tm
          covered_tm      = ls_result-covered_tm
          required_api    = ls_result-required_api
          covered_api     = ls_result-covered_api
        )
      ).


    DATA lt_db_missing TYPE STANDARD TABLE OF zdrj_cra_missing
      WITH EMPTY KEY.

    lt_db_missing =
      VALUE #(
        FOR ls_missing IN lt_cra_missing
        (
          mandt              = sy-mandt
          analysis_uuid      = mv_analysis_uuid
          role_name          = ls_missing-role_name
          capability_name    = ls_missing-capability_name
          scenario_name      = ls_missing-scenario_name
          requirement_type   = ls_missing-requirement_type
          requirement_key    = ls_missing-requirement_key
          odata_service_name = ls_missing-odata_service_name
          api_version        = ls_missing-api_version
          semantic_object    = ls_missing-semantic_object
          semantic_action    = ls_missing-semantic_action
          catalog_id         = ls_missing-catalog_id
        )
      ).


    "------------------------------------------------------------
    " 5. Enter bgPF SAVE phase
    "
    " From this point DB modifications are allowed.
    "------------------------------------------------------------

    cl_abap_tx=>save( ).


    "------------------------------------------------------------
    " 6. Persist results
    "------------------------------------------------------------

    IF lt_db_results IS NOT INITIAL.

      INSERT zdrj_cra_result
        FROM TABLE @lt_db_results.

    ENDIF.


    "------------------------------------------------------------
    " 7. Persist missing requirements
    "------------------------------------------------------------

    IF lt_db_missing IS NOT INITIAL.

      INSERT zdrj_cra_missing
        FROM TABLE @lt_db_missing.

    ENDIF.


    "------------------------------------------------------------
    " 8. Complete the analysis
    "------------------------------------------------------------

    UPDATE zdrj_cra_hdr
      SET role_count     = @lv_role_count,
          scenario_count = @lv_scenario_count,
          result_count   = @lv_result_count,
          status         = 'DONE'
      WHERE analysis_uuid = @mv_analysis_uuid.

  ENDMETHOD.

ENDCLASS.
