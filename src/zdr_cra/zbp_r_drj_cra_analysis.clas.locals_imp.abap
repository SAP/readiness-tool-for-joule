CLASS lsc_zr_drj_cra_analysis DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zr_drj_cra_analysis IMPLEMENTATION.

  METHOD save_modified.

    LOOP AT update-analysis ASSIGNING FIELD-SYMBOL(<ls_analysis>).

      "Only the experimental background action sets Status to RUNNING.
      "Normal synchronous Analyze finishes with DONE and therefore
      "does not enter this block.
      IF <ls_analysis>-%control-status <> if_abap_behv=>mk-on
         OR <ls_analysis>-status <> 'RUNNING'.
        CONTINUE.
      ENDIF.

      TRY.

          DATA(lo_operation) =
            NEW zcl_drj_cra_bg_operation(
              iv_analysis_uuid = <ls_analysis>-analysisuuid
            ).

          cl_bgmc_process_factory=>get_default(
            )->create(
            )->set_name(
              'CRA Background Test'
            )->set_operation(
              lo_operation
            )->save_for_execution( ).

        CATCH cx_bgmc.
          "Temporary for infrastructure test only.
          "Proper FAILED/error handling comes after bgPF is proven.
      ENDTRY.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lhc_analysis DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR analysis RESULT result.
    METHODS setinitialvalues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR analysis~setinitialvalues.
    METHODS analyze FOR MODIFY
      IMPORTING keys FOR ACTION analysis~analyze RESULT result.
    METHODS analyzebackground FOR MODIFY
      IMPORTING keys FOR ACTION analysis~analyzebackground RESULT result.
    METHODS uploadrolesfromexcel FOR MODIFY
      IMPORTING keys FOR ACTION analysis~uploadrolesfromexcel RESULT result.

ENDCLASS.

CLASS lhc_analysis IMPLEMENTATION.

  METHOD get_global_authorizations.

    "Allow creation of a new analysis
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.

    "Authorization used by RAP for creating dependent _Roles
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.

    "Allow execution of the analysis
    IF requested_authorizations-%action-analyze = if_abap_behv=>mk-on.
      result-%action-analyze = if_abap_behv=>auth-allowed.
    ENDIF.

    "Allow execution of the analysis in background
    IF requested_authorizations-%action-analyzebackground = if_abap_behv=>mk-on.
      result-%action-analyzebackground = if_abap_behv=>auth-allowed.
    ENDIF.

    "Allow CRA Excel role upload
    IF requested_authorizations-%action-uploadrolesfromexcel = if_abap_behv=>mk-on.
      result-%action-uploadrolesfromexcel = if_abap_behv=>auth-allowed.
    ENDIF.

  ENDMETHOD.

  METHOD setinitialvalues.

    DATA lv_timestamp TYPE timestampl.
    GET TIME STAMP FIELD lv_timestamp.

    MODIFY ENTITIES OF zr_drj_cra_analysis
      IN LOCAL MODE

      ENTITY analysis
        UPDATE FIELDS (
          createdby
          createdat
          status
        )

        WITH VALUE #(
          FOR key IN keys
          (
            %tky      = key-%tky
            createdby = sy-uname
            createdat = lv_timestamp
            status    = 'NEW'
          )
        ).

  ENDMETHOD.

  METHOD analyze.

    "A completed analysis is immutable - do not execute it again
    READ ENTITIES OF zr_drj_cra_analysis
      IN LOCAL MODE
      ENTITY analysis
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_existing_analysis).

    READ TABLE lt_existing_analysis
      ASSIGNING FIELD-SYMBOL(<ls_existing_analysis>)
      INDEX 1.

    IF sy-subrc = 0
       AND <ls_existing_analysis>-status = 'DONE'.

      result = VALUE #(
        (
          %tky   = <ls_existing_analysis>-%tky
          %param = <ls_existing_analysis>
        )
      ).

      RETURN.
    ENDIF.



    "Read the roles belonging to this analysis
    READ ENTITIES OF zr_drj_cra_analysis
      IN LOCAL MODE
      ENTITY analysis
        BY \_roles
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_roles).

    DATA(lv_role_count) = lines( lt_roles ).

    "Prepare selected roles for the CRA processor
    DATA(lt_analyzer_roles) =
      VALUE zcl_drj_custom_role_analyzer=>tt_roles(
        FOR ls_role IN lt_roles
        ( role_name = ls_role-rolename )
      ).

    "Run the Custom Role Analyzer
    zcl_drj_custom_role_analyzer=>analyze(
      EXPORTING
        it_roles   = lt_analyzer_roles
      IMPORTING
        et_results = DATA(lt_cra_results)
        et_missing = DATA(lt_cra_missing)
    ).

    "Persist Role x Scenario analysis results
    MODIFY ENTITIES OF zr_drj_cra_analysis
      IN LOCAL MODE

      ENTITY analysis
        CREATE BY \_results
        AUTO FILL CID
        FIELDS (
          rolename
          capabilityname
          scenarioname
          coverage
          requiredtm
          coveredtm
          requiredapi
          coveredapi
        )

        WITH VALUE #(
          FOR key IN keys
          (
            %tky = key-%tky

            %target = VALUE #(
              FOR ls_cra_result IN lt_cra_results
              (
                rolename       = ls_cra_result-role_name
                capabilityname = ls_cra_result-capability_name
                scenarioname   = ls_cra_result-scenario_name
                coverage       = ls_cra_result-coverage
                requiredtm     = ls_cra_result-required_tm
                coveredtm      = ls_cra_result-covered_tm
                requiredapi    = ls_cra_result-required_api
                coveredapi     = ls_cra_result-covered_api
              )
            )
          )
        ).

    "Persist detailed missing TM/API requirements
    MODIFY ENTITIES OF zr_drj_cra_analysis
      IN LOCAL MODE

      ENTITY analysis
        CREATE BY \_missing
        AUTO FILL CID
        FIELDS (
          rolename
          capabilityname
          scenarioname
          requirementtype
          requirementkey
          odataservicename
          apiversion
          semanticobject
          semanticaction
          catalogid
        )

        WITH VALUE #(
          FOR key IN keys
          (
            %tky = key-%tky

            %target = VALUE #(
              FOR ls_cra_missing IN lt_cra_missing
              (
                rolename          = ls_cra_missing-role_name
                capabilityname    = ls_cra_missing-capability_name
                scenarioname      = ls_cra_missing-scenario_name
                requirementtype   = ls_cra_missing-requirement_type
                requirementkey    = ls_cra_missing-requirement_key
                odataservicename  = ls_cra_missing-odata_service_name
                apiversion        = ls_cra_missing-api_version
                semanticobject    = ls_cra_missing-semantic_object
                semanticaction    = ls_cra_missing-semantic_action
                catalogid         = ls_cra_missing-catalog_id
              )
            )
          )
        ).

    "Read the static Joule scenarios once
    SELECT capability_name,
           scenario_name
      FROM zdrj_cp_scenario
      INTO TABLE @DATA(lt_scenarios).

    DATA(lv_scenario_count) = lines( lt_scenarios ).
    DATA(lv_result_count)   = lines( lt_cra_results ).

    "Store analysis counts and mark the run as completed
    MODIFY ENTITIES OF zr_drj_cra_analysis
      IN LOCAL MODE
      ENTITY analysis
        UPDATE FIELDS (
          rolecount
          scenariocount
          resultcount
          status
        )
        WITH VALUE #(
          FOR key IN keys
          (
            %tky          = key-%tky
            rolecount     = lv_role_count
            scenariocount = lv_scenario_count
            resultcount   = lv_result_count
            status        = 'DONE'
          )
        ).


    "Return the updated analysis
    READ ENTITIES OF zr_drj_cra_analysis
      IN LOCAL MODE
      ENTITY analysis
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_analysis).

    result = VALUE #(
      FOR ls_analysis IN lt_analysis
      (
        %tky   = ls_analysis-%tky
        %param = ls_analysis
      )
    ).

  ENDMETHOD.


  METHOD analyzebackground.

    "Read current analysis
    READ ENTITIES OF zr_drj_cra_analysis
      IN LOCAL MODE
      ENTITY analysis
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_existing_analysis).


    "For now only NEW analyses may enter the experimental
    "background execution path.
    READ TABLE lt_existing_analysis
      ASSIGNING FIELD-SYMBOL(<ls_existing_analysis>)
      INDEX 1.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.


    IF <ls_existing_analysis>-status <> 'NEW'.

      result = VALUE #(
        (
          %tky   = <ls_existing_analysis>-%tky
          %param = <ls_existing_analysis>
        )
      ).

      RETURN.

    ENDIF.


    "Mark it for background execution.
    "This modification is handled by RAP normally.
    MODIFY ENTITIES OF zr_drj_cra_analysis
      IN LOCAL MODE

      ENTITY analysis
        UPDATE FIELDS (
          status
        )

        WITH VALUE #(
          FOR key IN keys
          (
            %tky   = key-%tky
            status = 'RUNNING'
          )
        ).


    "Return updated state
    READ ENTITIES OF zr_drj_cra_analysis
      IN LOCAL MODE
      ENTITY analysis
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_analysis).


    result = VALUE #(
      FOR ls_analysis IN lt_analysis
      (
        %tky   = ls_analysis-%tky
        %param = ls_analysis
      )
    ).

  ENDMETHOD.

  METHOD uploadrolesfromexcel.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).

      DATA(ls_param) = <ls_key>-%param.

      "Accept either raw Base64 or a browser Data URL.
      DATA(lv_content) = CONV string( ls_param-filecontent ).

      FIND REGEX '^data:[^;]+;base64,' IN lv_content.

      IF sy-subrc = 0.
        REPLACE REGEX '^data:[^;]+;base64,'
          IN lv_content
          WITH ``.
      ENDIF.


      "Convert the uploaded Base64 file to XSTRING.
      DATA lv_xstring TYPE xstring.

      CALL FUNCTION 'SCMS_BASE64_DECODE_STR'
        EXPORTING
          input  = lv_content
        IMPORTING
          output = lv_xstring
        EXCEPTIONS
          failed = 1
          OTHERS = 2.

      IF sy-subrc <> 0.

        "Return an empty result if the payload itself cannot be decoded.
        APPEND VALUE #(
          %cid = <ls_key>-%cid
          %param = VALUE #(
            rolesjson        = `[]`
            invalidrolesjson = `[]`
            parsedcount      = 0
            resolvedcount    = 0
            invalidcount     = 0
            duplicatecount   = 0
          )
        ) TO result.

        CONTINUE.

      ENDIF.


      "Parse the first Excel worksheet and resolve all role names in bulk.
      zcl_drj_cra_excel_proc=>process(
        EXPORTING
          iv_xstring          = lv_xstring
        IMPORTING
          et_roles            = DATA(lt_roles)
          et_invalid_roles    = DATA(lt_invalid_roles)
          ev_parsed_count     = DATA(lv_parsed_count)
          ev_resolved_count   = DATA(lv_resolved_count)
          ev_invalid_count    = DATA(lv_invalid_count)
          ev_duplicate_count  = DATA(lv_duplicate_count)
      ).


      "The OData V2 action result is flat, therefore return the role
      "collections as JSON strings inside the result structure.
      DATA(lv_roles_json) =
        /ui2/cl_json=>serialize(
          data     = lt_roles
          compress = abap_true
        ).

      DATA(lv_invalid_roles_json) =
        /ui2/cl_json=>serialize(
          data     = lt_invalid_roles
          compress = abap_true
        ).


      APPEND VALUE #(
        %cid = <ls_key>-%cid
        %param = VALUE #(
          rolesjson        = lv_roles_json
          invalidrolesjson = lv_invalid_roles_json
          parsedcount      = lv_parsed_count
          resolvedcount    = lv_resolved_count
          invalidcount     = lv_invalid_count
          duplicatecount   = lv_duplicate_count
        )
      ) TO result.

    ENDLOOP.

  ENDMETHOD.


ENDCLASS.
