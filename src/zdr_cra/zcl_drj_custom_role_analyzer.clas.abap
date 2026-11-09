CLASS zcl_drj_custom_role_analyzer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    "Input: selected custom/business roles
    TYPES:
      BEGIN OF ty_role,
        role_name TYPE zdrj_cra_role-role_name,
      END OF ty_role,

      tt_roles TYPE SORTED TABLE OF ty_role
        WITH UNIQUE KEY role_name.


    "One Scenario x Role matrix result
    TYPES:
      BEGIN OF ty_result,
        role_name       TYPE zdrj_cra_result-role_name,
        capability_name TYPE zdrj_cra_result-capability_name,
        scenario_name   TYPE zdrj_cra_result-scenario_name,
        coverage        TYPE zdrj_cra_result-coverage,
        required_tm     TYPE zdrj_cra_result-required_tm,
        covered_tm      TYPE zdrj_cra_result-covered_tm,
        required_api    TYPE zdrj_cra_result-required_api,
        covered_api     TYPE zdrj_cra_result-covered_api,
      END OF ty_result,

      tt_results TYPE STANDARD TABLE OF ty_result
        WITH EMPTY KEY.


    "Detailed missing requirements for CSV/drill-down
    TYPES:
      BEGIN OF ty_missing,
        role_name          TYPE zdrj_cra_missing-role_name,
        capability_name    TYPE zdrj_cra_missing-capability_name,
        scenario_name      TYPE zdrj_cra_missing-scenario_name,
        requirement_type   TYPE zdrj_cra_missing-requirement_type,
        requirement_key    TYPE zdrj_cra_missing-requirement_key,
        odata_service_name TYPE zdrj_cra_missing-odata_service_name,
        api_version        TYPE zdrj_cra_missing-api_version,
        semantic_object    TYPE zdrj_cra_missing-semantic_object,
        semantic_action    TYPE zdrj_cra_missing-semantic_action,
        catalog_id         TYPE zdrj_cra_missing-catalog_id,
      END OF ty_missing,

      tt_missing TYPE STANDARD TABLE OF ty_missing
                   WITH EMPTY KEY.

    CLASS-METHODS analyze
      IMPORTING
        it_roles   TYPE tt_roles
      EXPORTING
        et_results TYPE tt_results
        et_missing TYPE tt_missing.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_drj_custom_role_analyzer IMPLEMENTATION.
  METHOD analyze.

    CLEAR:
      et_results,
      et_missing.

    "All Joule scenarios - read once
    SELECT capability_name,
           scenario_name
      FROM zdrj_cp_scenario
      INTO TABLE @DATA(lt_scenarios).

    "All Target Mapping requirements - read once
    SELECT capability_name,
           scenario_name,
           semantic_object,
           semantic_action,
           catalog_id,
           operator
      FROM zdrj_scen_tm
      INTO TABLE @DATA(lt_scenario_tms).

    "All API requirements - read once
    SELECT capability_name,
           scenario_name,
           odata_service_name,
           api_version
      FROM zdrj_scen_api
      INTO TABLE @DATA(lt_scenario_apis).

    DATA(lt_role_ids) =
      VALUE /ui2/if_nwbc_runtime=>t_role_ids(
        FOR ls_role IN it_roles
        ( ls_role-role_name )
      ).

    DATA(lt_role_catalogs) =
      zcl_drj_flp_start_up_utility=>get_catalogs_for_roles(
        it_role_ids = lt_role_ids
      ).

    "--------------------------------------------------------------------
    " Collect the unique catalogs assigned to the selected input roles.
    "
    " Multiple roles may contain the same catalog. We resolve each
    " catalog only once and later retain the Role -> Catalog relation
    " separately in LT_ROLE_CATALOGS.
    "--------------------------------------------------------------------
    DATA lt_unique_catalogs TYPE SORTED TABLE OF string
      WITH UNIQUE KEY table_line.

    LOOP AT lt_role_catalogs ASSIGNING FIELD-SYMBOL(<ls_role_catalog>).

      IF <ls_role_catalog>-catalog_id IS INITIAL.
        CONTINUE.
      ENDIF.

      INSERT <ls_role_catalog>-catalog_id
   INTO TABLE lt_unique_catalogs.

    ENDLOOP.


    "--------------------------------------------------------------------
    " Mapping between logical catalog IDs and the actual catalog IDs
    " used inside the FLP Target Mapping index.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_catalog_tm_id,
        catalog_id    TYPE string,
        tm_catalog_id TYPE string,
      END OF ty_catalog_tm_id.

    DATA lt_catalog_tm_ids TYPE SORTED TABLE OF ty_catalog_tm_id
      WITH UNIQUE KEY catalog_id tm_catalog_id.

    LOOP AT lt_unique_catalogs INTO DATA(lv_catalog).

      DATA(lt_tm_catalog_ids) =
        zcl_drj_flp_start_up_utility=>resolve_tm_catalog_ids(
          iv_catalog_id = CONV #( lv_catalog )
        ).

      LOOP AT lt_tm_catalog_ids INTO DATA(lv_tm_catalog_id).

        "Keep the relationship between the logical PFCG catalog
        "and the actual catalog identifier used inside the TM index.
        INSERT VALUE #(
          catalog_id    = lv_catalog
          tm_catalog_id = lv_tm_catalog_id
        ) INTO TABLE lt_catalog_tm_ids.

      ENDLOOP.

    ENDLOOP.


    "--------------------------------------------------------------------
    " Load the complete Target Mapping index once.
    "
    " LOOKUP_ALL_TMS uses the shared in-memory cache in
    " ZCL_DRJ_FLP_START_UP_UTILITY, so the expensive SAP TM read happens
    " only once per ABAP session. All following CRA matching will work
    " against this in-memory table.
    "--------------------------------------------------------------------
    DATA(lt_all_tms) =
  zcl_drj_flp_start_up_utility=>lookup_all_tms( ).


    "--------------------------------------------------------------------
    " Build a compact Target Mapping lookup table.
    "
    " The universal TM cache contains the complete SAP TM structures,
    " but CRA only needs Catalog + Semantic Object + Semantic Action.
    " Keeping a small sorted table makes the later Role -> TM matching
    " cheaper and automatically removes duplicate TM combinations.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_tm_key,
        tm_catalog_id   TYPE string,
        ref_catalog_id  TYPE string,
        semantic_object TYPE /ui2/semantic_object,
        semantic_action TYPE /ui2/semantic_action,
      END OF ty_tm_key.

    "REF_CATALOG_ID is part of the key because two TMs with the same
    "intent may point to different referenced catalogs. We must preserve
    "that relationship for the later indirect-catalog traversal.
    DATA lt_tm_index TYPE SORTED TABLE OF ty_tm_key
      WITH UNIQUE KEY
        tm_catalog_id
        ref_catalog_id
        semantic_object
        semantic_action.


    "Convert the full SAP TM structures into the compact CRA lookup.
    LOOP AT lt_all_tms ASSIGNING FIELD-SYMBOL(<ls_tm>).

      "A TM without a catalog cannot belong to one of the selected
      "role/catalog relationships, so it is irrelevant for this analysis.
      IF <ls_tm>-catalog_id IS INITIAL.
        CONTINUE.
      ENDIF.

      "Keep both the containing catalog and its referenced catalog.
      "The reference is required later when a scenario specifies a
      "standard technical catalog and the role contains an indirect TM.
      INSERT VALUE #(
        tm_catalog_id   = CONV string( <ls_tm>-catalog_id )
        ref_catalog_id  = CONV string( <ls_tm>-ref_catalog_id )
        semantic_object = <ls_tm>-object
        semantic_action = <ls_tm>-action
      ) INTO TABLE lt_tm_index.

    ENDLOOP.


    "--------------------------------------------------------------------
    " Build the effective Target Mapping content of every selected role.
    "
    " Join the three in-memory relationships:
    "
    "   Role -> assigned PFCG catalog
    "        -> actual TM-index catalog
    "        -> Semantic Object + Semantic Action
    "
    " No further database or SAP API calls are required here.
    " The sorted result also removes duplicate TMs automatically, for
    " example when multiple assigned catalogs expose the same intent.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_role_tm,
        role_name       TYPE agr_name,
        tm_catalog_id   TYPE string,
        ref_catalog_id  TYPE string,
        semantic_object TYPE /ui2/semantic_object,
        semantic_action TYPE /ui2/semantic_action,
      END OF ty_role_tm.

    "--------------------------------------------------------------------
    " Effective Target Mappings available to every selected role.
    "
    " REF_CATALOG_ID is retained so a TM can later be traced through
    " referenced catalogs when the scenario specifies a technical catalog.
    "
    " Secondary key K_ROLE_INTENT supports the common CRA lookup:
    "   Role + Semantic Object + Semantic Action
    " This also supports the fallback case where catalog is ignored.
    "--------------------------------------------------------------------
    DATA lt_role_tms TYPE SORTED TABLE OF ty_role_tm
      WITH UNIQUE KEY
        role_name
        tm_catalog_id
        ref_catalog_id
        semantic_object
        semantic_action
      WITH NON-UNIQUE SORTED KEY k_role_intent
        COMPONENTS
          role_name
          semantic_object
          semantic_action.


    "Start with every Role -> logical catalog assignment.
    LOOP AT lt_role_catalogs ASSIGNING <ls_role_catalog>.

      "Find the actual TM-index catalog ID(s) belonging to this catalog.
      LOOP AT lt_catalog_tm_ids
        ASSIGNING FIELD-SYMBOL(<ls_catalog_tm>)
        WHERE catalog_id = <ls_role_catalog>-catalog_id.

        "Read all TMs belonging to that actual TM-index catalog.
        LOOP AT lt_tm_index
          ASSIGNING FIELD-SYMBOL(<ls_tm_key>)
          WHERE tm_catalog_id = <ls_catalog_tm>-tm_catalog_id.

          "Store the complete TM relationship for this role.
          "REF_CATALOG_ID is needed later for indirect catalog tracing.
          INSERT VALUE #(
            role_name       = <ls_role_catalog>-role_id
            tm_catalog_id   = <ls_tm_key>-tm_catalog_id
            ref_catalog_id  = <ls_tm_key>-ref_catalog_id
            semantic_object = <ls_tm_key>-semantic_object
            semantic_action = <ls_tm_key>-semantic_action
          ) INTO TABLE lt_role_tms.

        ENDLOOP.

      ENDLOOP.

    ENDLOOP.


    "--------------------------------------------------------------------
    " Build the Scenario -> Target Mapping requirement buffer.
    "
    " Each row represents one TM requirement from ZDRJ_SCEN_TM.
    "
    " CATALOG_ID is kept exactly as stored:
    "   - blank catalog -> match Object + Action anywhere in the role
    "   - filled catalog -> catalog-aware matching will be done later
    "
    " OPERATOR is also preserved. Blank means ALL; ANY/ALL semantics
    " are applied only when the complete scenario is evaluated.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_scenario_tm_req,
        capability_name TYPE zdrj_scen_tm-capability_name,
        scenario_name   TYPE zdrj_scen_tm-scenario_name,
        semantic_object TYPE zdrj_scen_tm-semantic_object,
        semantic_action TYPE zdrj_scen_tm-semantic_action,
        catalog_id      TYPE zdrj_scen_tm-catalog_id,
        operator        TYPE zdrj_scen_tm-operator,
      END OF ty_scenario_tm_req.

    DATA lt_scenario_tm_req TYPE SORTED TABLE OF ty_scenario_tm_req
      WITH UNIQUE KEY
        capability_name
        scenario_name
        semantic_object
        semantic_action
        catalog_id.


    "Create the compact requirement index from the data already read once
    "from ZDRJ_SCEN_TM at the beginning of the analysis.
    LOOP AT lt_scenario_tms
      ASSIGNING FIELD-SYMBOL(<ls_scenario_tm>).

      INSERT VALUE #(
        capability_name = <ls_scenario_tm>-capability_name
        scenario_name   = <ls_scenario_tm>-scenario_name
        semantic_object = <ls_scenario_tm>-semantic_object
        semantic_action = <ls_scenario_tm>-semantic_action
        catalog_id      = <ls_scenario_tm>-catalog_id
        operator        = <ls_scenario_tm>-operator
      ) INTO TABLE lt_scenario_tm_req.

    ENDLOOP.


    "--------------------------------------------------------------------
    " Cache whether each scenario technical catalog exists on this system.
    "
    " A catalog may be referenced by many scenarios and roles, so check
    " it only once. Blank catalogs are intentionally ignored here.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_scenario_catalog,
        catalog_id TYPE zdrj_scen_tm-catalog_id,
        exists     TYPE abap_bool,
      END OF ty_scenario_catalog.

    DATA lt_scenario_catalogs TYPE SORTED TABLE OF ty_scenario_catalog
      WITH UNIQUE KEY catalog_id.

    LOOP AT lt_scenario_tm_req ASSIGNING FIELD-SYMBOL(<ls_catalog_req>).

      IF <ls_catalog_req>-catalog_id IS INITIAL
         OR line_exists(
              lt_scenario_catalogs[
                catalog_id = <ls_catalog_req>-catalog_id ] ).
        CONTINUE.
      ENDIF.

      INSERT VALUE #(
        catalog_id = <ls_catalog_req>-catalog_id
        exists     =
          zcl_drj_flp_start_up_utility=>catalog_exists(
            iv_catalog_id = CONV #( <ls_catalog_req>-catalog_id ) )
      ) INTO TABLE lt_scenario_catalogs.

    ENDLOOP.


    "--------------------------------------------------------------------
    " Store the result of each Role -> Scenario -> TM requirement check.
    "
    " We keep individual requirement results first. This is important
    " because ALL / ANY is evaluated only after all TMs of the scenario
    " have been checked.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_tm_check,
        role_name       TYPE agr_name,
        capability_name TYPE zdrj_scen_tm-capability_name,
        scenario_name   TYPE zdrj_scen_tm-scenario_name,
        semantic_object TYPE zdrj_scen_tm-semantic_object,
        semantic_action TYPE zdrj_scen_tm-semantic_action,
        catalog_id      TYPE zdrj_scen_tm-catalog_id,
        operator        TYPE zdrj_scen_tm-operator,
        matched         TYPE abap_bool,
      END OF ty_tm_check.

    DATA lt_tm_checks TYPE SORTED TABLE OF ty_tm_check
      WITH UNIQUE KEY
        role_name
        capability_name
        scenario_name
        semantic_object
        semantic_action
        catalog_id.


    "--------------------------------------------------------------------
    " First TM rule:
    "
    " If the scenario does NOT specify a technical catalog, simply check
    " whether the current role contains the required Object + Action in
    " any of its assigned catalogs.
    "--------------------------------------------------------------------
    LOOP AT it_roles ASSIGNING FIELD-SYMBOL(<ls_role>).

      LOOP AT lt_scenarios ASSIGNING FIELD-SYMBOL(<ls_scenario>).

        LOOP AT lt_scenario_tm_req
          ASSIGNING FIELD-SYMBOL(<ls_tm_requirement>)
          WHERE capability_name = <ls_scenario>-capability_name
            AND scenario_name   = <ls_scenario>-scenario_name.

          "----------------------------------------------------------------
          " Current Joule TM matching rule:
          "
          " CATALOG_ID is deliberately NOT used for determining whether
          " the role satisfies the TM requirement.
          "
          " A requirement is satisfied when the current role contains the
          " same Semantic Object + Semantic Action in any assigned catalog.
          "
          " Catalog-aware validation is retained separately for testing
          " and possible future use, but does not affect this result.
          "----------------------------------------------------------------
          DATA(lv_tm_matched) =
            xsdbool(
                line_exists(
                  lt_role_tms[
                    KEY k_role_intent
                    role_name       = <ls_role>-role_name
                    semantic_object = <ls_tm_requirement>-semantic_object
                    semantic_action = <ls_tm_requirement>-semantic_action
                  ]
                )
              ).

          INSERT VALUE #(
            role_name       = <ls_role>-role_name
            capability_name = <ls_tm_requirement>-capability_name
            scenario_name   = <ls_tm_requirement>-scenario_name
            semantic_object = <ls_tm_requirement>-semantic_object
            semantic_action = <ls_tm_requirement>-semantic_action
            catalog_id      = <ls_tm_requirement>-catalog_id
            operator        = <ls_tm_requirement>-operator
            matched         = lv_tm_matched
          ) INTO TABLE lt_tm_checks.

        ENDLOOP.

      ENDLOOP.

    ENDLOOP.


    "--------------------------------------------------------------------
    " Aggregate TM checks for every Role -> Scenario combination.
    "
    " RequiredTM = number of TM requirements defined for the scenario.
    " CoveredTM  = number of those requirements found in the role.
    "
    " Operator semantics:
    "   blank / ALL -> every TM must be available
    "   ANY         -> one matching TM is sufficient, but the TM result
    "                  is marked as warning rather than fully satisfied.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_tm_summary,
        role_name       TYPE agr_name,
        capability_name TYPE zdrj_scen_tm-capability_name,
        scenario_name   TYPE zdrj_scen_tm-scenario_name,
        required_tm     TYPE i,
        covered_tm      TYPE i,
        tm_satisfied    TYPE abap_bool,
        tm_warning      TYPE abap_bool,
      END OF ty_tm_summary.

    DATA lt_tm_summary TYPE SORTED TABLE OF ty_tm_summary
      WITH UNIQUE KEY
        role_name
        capability_name
        scenario_name.


    DATA:
      lv_required_tm  TYPE i,
      lv_covered_tm   TYPE i,
      lv_has_any      TYPE abap_bool,
      lv_tm_satisfied TYPE abap_bool,
      lv_tm_warning   TYPE abap_bool.


    LOOP AT it_roles ASSIGNING <ls_role>.

      LOOP AT lt_scenarios ASSIGNING <ls_scenario>.

        CLEAR:
          lv_required_tm,
          lv_covered_tm,
          lv_has_any,
          lv_tm_satisfied,
          lv_tm_warning.

        "Read only the TM checks belonging to the current Role + Scenario.
        LOOP AT lt_tm_checks
          ASSIGNING FIELD-SYMBOL(<ls_tm_check>)
          WHERE role_name       = <ls_role>-role_name
            AND capability_name = <ls_scenario>-capability_name
            AND scenario_name   = <ls_scenario>-scenario_name.

          lv_required_tm += 1.

          IF <ls_tm_check>-matched = abap_true.
            lv_covered_tm += 1.
          ENDIF.

          IF <ls_tm_check>-operator = 'ANY'.
            lv_has_any = abap_true.
          ENDIF.

        ENDLOOP.


        "No TM requirement means TM validation is neutral for this scenario.
        IF lv_required_tm = 0.

          lv_tm_satisfied = abap_true.

          "ANY: one successful TM is enough, but intentionally produces
          "a warning state as defined by the scenario metadata.
        ELSEIF lv_has_any = abap_true.

          IF lv_covered_tm > 0.
            lv_tm_satisfied = abap_true.
            lv_tm_warning   = abap_true.
          ENDIF.

          "Blank operator and ALL both require every TM.
        ELSEIF lv_covered_tm = lv_required_tm.

          lv_tm_satisfied = abap_true.

        ENDIF.


        INSERT VALUE #(
          role_name       = <ls_role>-role_name
          capability_name = <ls_scenario>-capability_name
          scenario_name   = <ls_scenario>-scenario_name
          required_tm     = lv_required_tm
          covered_tm      = lv_covered_tm
          tm_satisfied    = lv_tm_satisfied
          tm_warning      = lv_tm_warning
        ) INTO TABLE lt_tm_summary.

      ENDLOOP.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Read API authorization values for all selected roles in one DB call.
    "
    " S_SERVICE:
    "   SRV_NAME contains the USOBHASH value for OData V2 IWSG / IWSV.
    "
    " S_START:
    "   AUTHPGMID  = R3TR
    "   AUTHOBJTYP = G4BA
    "   AUTHOBJNAM = OData V4 service group
    "
    " AUTH is retained because the S_START fields must belong to the
    " same authorization instance.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_role_api_auth,
        role_name TYPE agr_1251-agr_name,
        auth      TYPE agr_1251-auth,
        object    TYPE agr_1251-object,
        field     TYPE agr_1251-field,
        low       TYPE agr_1251-low,
      END OF ty_role_api_auth.

    DATA lt_role_api_auth TYPE SORTED TABLE OF ty_role_api_auth
      WITH NON-UNIQUE KEY
        role_name
        object
        auth
        field
        low.


    "FOR ALL ENTRIES must never run with an empty input table.
    IF it_roles IS NOT INITIAL.

      SELECT agr_name AS role_name,
             auth,
             object,
             field,
             low
        FROM agr_1251
        FOR ALL ENTRIES IN @it_roles
        WHERE agr_name = @it_roles-role_name
          AND deleted  <> 'X'
          AND ( object = 'S_SERVICE'
             OR object = 'S_START' )
        INTO TABLE @lt_role_api_auth.

    ENDIF.

    "--------------------------------------------------------------------
    " Build a compact Role -> S_SERVICE / SRV_NAME lookup.
    "
    " For OData V2 the LOW value contains either:
    "   - the exact IWSG / IWSV USOBHASH value
    "   - '*' for wildcard authorization
    "
    " Keep this separate from the general authorization buffer so the
    " later V2 checks are simple in-memory lookups.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_role_s_service,
        role_name TYPE agr_1251-agr_name,
        srv_name  TYPE agr_1251-low,
      END OF ty_role_s_service.

    DATA lt_role_s_service TYPE SORTED TABLE OF ty_role_s_service
      WITH UNIQUE KEY
        role_name
        srv_name.


    LOOP AT lt_role_api_auth
      ASSIGNING FIELD-SYMBOL(<ls_api_auth>)
      WHERE object = 'S_SERVICE'
        AND field  = 'SRV_NAME'.

      INSERT VALUE #(
        role_name = <ls_api_auth>-role_name
        srv_name  = <ls_api_auth>-low
      ) INTO TABLE lt_role_s_service.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Collect the unique APIs required by all Joule scenarios.
    "
    " The same API may be referenced by multiple capabilities/scenarios.
    " Resolve each technical API only once and later reuse the result
    " for every Role -> Scenario evaluation.
    "
    " Keep the database values unchanged here. V2/V4 resolution and
    " authorization-object mapping are done in the next step.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_api_requirement,
        odata_service_name TYPE zdrj_scen_api-odata_service_name,
        api_type           TYPE zdrj_scen_api-api_version,
      END OF ty_api_requirement.

    DATA lt_unique_apis TYPE SORTED TABLE OF ty_api_requirement
      WITH UNIQUE KEY
        odata_service_name
        api_type.


    LOOP AT lt_scenario_apis
      ASSIGNING FIELD-SYMBOL(<ls_scenario_api>).

      "An empty service name cannot be resolved technically.
      IF <ls_scenario_api>-odata_service_name IS INITIAL.
        CONTINUE.
      ENDIF.

      INSERT VALUE #(
        odata_service_name = <ls_scenario_api>-odata_service_name
        api_type           = <ls_scenario_api>-api_version
      ) INTO TABLE lt_unique_apis.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Resolve the unique OData V2 requirements to their Gateway service
    " registrations.
    "
    " ZDRJ_SCEN_API-API_VERSION contains the API type ('V2' / 'V4'),
    " not the technical OData service version.
    "
    " Therefore, for V2 we resolve the service name against
    " /IWFND/I_MED_SRH and retain the actual registered version and
    " SRV_IDENTIFIER. SRV_IDENTIFIER is needed later for the IWSG hash.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_v2_service,
        odata_service_name TYPE zdrj_scen_api-odata_service_name,
        namespace          TYPE /iwfnd/med_mdl_namespace,
        service_name       TYPE /iwfnd/med_mdl_service_grp_id,
        service_version    TYPE /iwfnd/med_mdl_version,
        srv_identifier     TYPE /iwfnd/i_med_srh-srv_identifier,
        iwsg_hash          TYPE agr_1251-low,
        iwsv_hash          TYPE agr_1251-low,
      END OF ty_v2_service.

    DATA lt_v2_services TYPE SORTED TABLE OF ty_v2_service
      WITH UNIQUE KEY
        odata_service_name
        namespace
        service_name
        service_version.


    "--------------------------------------------------------------------
    " Normalize V2 requirements into Namespace + Service Name.
    "
    " Examples:
    "   API_SALES_ORDER_SRV
    "       -> Namespace    = ''
    "       -> Service Name = API_SALES_ORDER_SRV
    "
    "   /IWPGW/TASKPROCESSING
    "       -> Namespace    = /IWPGW/
    "       -> Service Name = TASKPROCESSING
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_v2_lookup,
        odata_service_name TYPE zdrj_scen_api-odata_service_name,
        namespace          TYPE /iwfnd/med_mdl_namespace,
        service_name       TYPE /iwfnd/med_mdl_service_grp_id,
      END OF ty_v2_lookup.

    DATA lt_v2_lookup TYPE SORTED TABLE OF ty_v2_lookup
      WITH UNIQUE KEY
        namespace
        service_name.


    LOOP AT lt_unique_apis
      ASSIGNING FIELD-SYMBOL(<ls_unique_api>)
      WHERE api_type = 'V2'.

      DATA(lv_v2_api_name) =
        condense( CONV string( <ls_unique_api>-odata_service_name ) ).

      DATA lv_v2_namespace TYPE /iwfnd/med_mdl_namespace.
      DATA lv_v2_service_name TYPE /iwfnd/med_mdl_service_grp_id.
      DATA lt_v2_parts TYPE STANDARD TABLE OF string WITH EMPTY KEY.

      CLEAR:
        lv_v2_namespace,
        lv_v2_service_name,
        lt_v2_parts.

      IF lv_v2_api_name CP '/\*/\*'.

        SPLIT lv_v2_api_name AT '/' INTO TABLE lt_v2_parts.

        IF lines( lt_v2_parts ) >= 3.

          lv_v2_namespace =
            '/' &&
            lt_v2_parts[ 2 ] &&
            '/'.

          lv_v2_service_name =
            CONV #( lt_v2_parts[ 3 ] ).

        ENDIF.

      ELSE.

        lv_v2_service_name =
          CONV #( lv_v2_api_name ).

      ENDIF.

      IF lv_v2_service_name IS INITIAL.
        CONTINUE.
      ENDIF.

      INSERT VALUE #(
        odata_service_name = <ls_unique_api>-odata_service_name
        namespace          = lv_v2_namespace
        service_name       = lv_v2_service_name
      ) INTO TABLE lt_v2_lookup.

    ENDLOOP.


    "--------------------------------------------------------------------
    " Read matching V2 Gateway registrations.
    "
    " This deliberately follows the existing APIA behaviour:
    "
    "   Explicit namespace:
    "     Match Namespace + Service Name.
    "
    "   No namespace:
    "     Match Service Name regardless of the registered namespace.
    "
    " All technical service versions are retained.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_v2_unqualified,
        service_name TYPE /iwfnd/med_mdl_service_grp_id,
      END OF ty_v2_unqualified.

    DATA lt_v2_unqualified TYPE SORTED TABLE OF ty_v2_unqualified
      WITH UNIQUE KEY service_name.


    "First read exact Namespace + Service combinations.
    IF lt_v2_lookup IS NOT INITIAL.

      SELECT namespace,
             service_name,
             service_version,
             srv_identifier
        FROM /iwfnd/i_med_srh
        FOR ALL ENTRIES IN @lt_v2_lookup
        WHERE namespace    = @lt_v2_lookup-namespace
          AND service_name = @lt_v2_lookup-service_name
        INTO TABLE @DATA(lt_v2_registrations).

    ENDIF.


    "Collect requirements where no namespace was explicitly supplied.
    LOOP AT lt_v2_lookup
      ASSIGNING FIELD-SYMBOL(<ls_v2_no_ns>)
      WHERE namespace IS INITIAL.

      INSERT VALUE #(
        service_name = <ls_v2_no_ns>-service_name
      ) INTO TABLE lt_v2_unqualified.

    ENDLOOP.


    "For an unqualified API name, APIA searches by Service Name only.
    IF lt_v2_unqualified IS NOT INITIAL.

      SELECT namespace,
             service_name,
             service_version,
             srv_identifier
        FROM /iwfnd/i_med_srh
        FOR ALL ENTRIES IN @lt_v2_unqualified
        WHERE service_name = @lt_v2_unqualified-service_name
        APPENDING TABLE @lt_v2_registrations.

    ENDIF.


    "Map each Gateway registration back to the Joule API requirement.
    LOOP AT lt_v2_registrations
      ASSIGNING FIELD-SYMBOL(<ls_v2_registration>).

      READ TABLE lt_v2_lookup
        ASSIGNING FIELD-SYMBOL(<ls_v2_lookup>)
        WITH TABLE KEY
          namespace    = <ls_v2_registration>-namespace
          service_name = <ls_v2_registration>-service_name.

      "If Joule stored the API without a namespace, fall back to the
      "unqualified Service Name entry.
      IF sy-subrc <> 0.
        READ TABLE lt_v2_lookup
          ASSIGNING <ls_v2_lookup>
          WITH TABLE KEY
            namespace    = ''
            service_name = <ls_v2_registration>-service_name.
      ENDIF.

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      INSERT VALUE #(
        odata_service_name = <ls_v2_lookup>-odata_service_name
        namespace          = <ls_v2_registration>-namespace
        service_name       = <ls_v2_registration>-service_name
        service_version    = <ls_v2_registration>-service_version
        srv_identifier     = <ls_v2_registration>-srv_identifier
      ) INTO TABLE lt_v2_services.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Build the USOBHASH lookup keys required for every resolved V2
    " service registration.
    "
    " IWSG:
    "   OBJ_NAME = SRV_IDENTIFIER
    "
    " IWSV:
    "   OBJ_NAME = Namespace + Service Name, with the technical service
    "              version written into positions 36-39.
    "
    " This follows the same construction used by the existing APIA logic.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_v2_hash_key,
        object   TYPE usobhash-object,
        obj_name TYPE usobhash-obj_name,
      END OF ty_v2_hash_key.

    DATA lt_v2_hash_keys TYPE SORTED TABLE OF ty_v2_hash_key
      WITH UNIQUE KEY
        object
        obj_name.


    LOOP AT lt_v2_services
      ASSIGNING FIELD-SYMBOL(<ls_v2_service>).

      "IWSG uses the Gateway service registration identifier directly.
      IF <ls_v2_service>-srv_identifier IS NOT INITIAL.

        INSERT VALUE #(
          object   = 'IWSG'
          obj_name = CONV usobhash-obj_name(
                       <ls_v2_service>-srv_identifier )
        ) INTO TABLE lt_v2_hash_keys.

      ENDIF.


      "Build the technical IWSV object name exactly as SAP expects it.
      DATA(lv_iwsv_obj_name) =
        CONV usobhash-obj_name(
          <ls_v2_service>-namespace &&
          <ls_v2_service>-service_name ).

      DATA(lv_v2_service_version) =
        |{ <ls_v2_service>-service_version WIDTH = 4 PAD = '0' }|.

      lv_iwsv_obj_name+35(4) = lv_v2_service_version.

      INSERT VALUE #(
        object   = 'IWSV'
        obj_name = lv_iwsv_obj_name
      ) INTO TABLE lt_v2_hash_keys.

    ENDLOOP.


    "--------------------------------------------------------------------
    " Read all required IWSG / IWSV hashes in one database operation.
    "--------------------------------------------------------------------
    IF lt_v2_hash_keys IS NOT INITIAL.

      SELECT object,
             obj_name,
             name
        FROM usobhash
        FOR ALL ENTRIES IN @lt_v2_hash_keys
        WHERE object   = @lt_v2_hash_keys-object
          AND obj_name = @lt_v2_hash_keys-obj_name
        INTO TABLE @DATA(lt_v2_hashes).

    ENDIF.

    "--------------------------------------------------------------------
    " Attach the resolved IWSG and IWSV hashes to every V2 service.
    "
    " If a USOBHASH entry cannot be resolved, the corresponding hash
    " remains initial. We keep that information and let the later API
    " evaluation decide the coverage state.
    "--------------------------------------------------------------------
    LOOP AT lt_v2_services
      ASSIGNING <ls_v2_service>.

      "--------------------------------------------------------------
      " IWSG hash
      "--------------------------------------------------------------
      DATA(lv_iwsg_lookup_name) =
        CONV usobhash-obj_name(
          <ls_v2_service>-srv_identifier ).

      READ TABLE lt_v2_hashes
        ASSIGNING FIELD-SYMBOL(<ls_iwsg_hash>)
        WITH KEY
          object   = 'IWSG'
          obj_name = lv_iwsg_lookup_name.

      IF sy-subrc = 0.
        <ls_v2_service>-iwsg_hash =
          CONV agr_1251-low( <ls_iwsg_hash>-name ).
      ENDIF.


      "--------------------------------------------------------------
      " IWSV hash
      "--------------------------------------------------------------
      DATA(lv_iwsv_lookup_name) =
        CONV usobhash-obj_name(
          <ls_v2_service>-namespace &&
          <ls_v2_service>-service_name ).

      DATA(lv_iwsv_lookup_version) =
        |{ <ls_v2_service>-service_version WIDTH = 4 PAD = '0' }|.

      lv_iwsv_lookup_name+35(4) = lv_iwsv_lookup_version.

      READ TABLE lt_v2_hashes
        ASSIGNING FIELD-SYMBOL(<ls_iwsv_hash>)
        WITH KEY
          object   = 'IWSV'
          obj_name = lv_iwsv_lookup_name.

      IF sy-subrc = 0.
        <ls_v2_service>-iwsv_hash =
          CONV agr_1251-low( <ls_iwsv_hash>-name ).
      ENDIF.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Evaluate OData V2 authorization for every selected Role -> API.
    "
    " Both IWSG and IWSV must match for FULL authorization.
    " If only one matches, the API is PARTIAL.
    "
    " A wildcard S_SERVICE / SRV_NAME = '*' satisfies a resolved hash.
    " IWSG and IWSV must belong to the SAME technical registration.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_v2_role_api_check,
        role_name          TYPE agr_name,
        odata_service_name TYPE zdrj_scen_api-odata_service_name,
        full_match         TYPE abap_bool,
        partial_match      TYPE abap_bool,
      END OF ty_v2_role_api_check.

    DATA lt_v2_role_api_checks TYPE SORTED TABLE OF ty_v2_role_api_check
      WITH UNIQUE KEY
        role_name
        odata_service_name.


    LOOP AT it_roles ASSIGNING <ls_role>.

      LOOP AT lt_unique_apis
        ASSIGNING <ls_unique_api>
        WHERE api_type = 'V2'.

        DATA lv_v2_full_match    TYPE abap_bool.
        DATA lv_v2_partial_match TYPE abap_bool.

        CLEAR:
          lv_v2_full_match,
          lv_v2_partial_match.

        "Wildcard belongs to the role and can satisfy either resolved hash.
        DATA(lv_v2_has_wildcard) =
          xsdbool(
            line_exists(
              lt_role_s_service[
                role_name = <ls_role>-role_name
                srv_name  = '*' ] )
          ).


        "One logical API may resolve to several technical registrations.
        "IWSG and IWSV must match within the same registration.
        LOOP AT lt_v2_services
          ASSIGNING <ls_v2_service>
          WHERE odata_service_name =
                <ls_unique_api>-odata_service_name.

          DATA lv_has_iwsg TYPE abap_bool.
          DATA lv_has_iwsv TYPE abap_bool.

          CLEAR:
            lv_has_iwsg,
            lv_has_iwsv.


          "Check IWSG only when its USOBHASH was successfully resolved.
          IF <ls_v2_service>-iwsg_hash IS NOT INITIAL.

            lv_has_iwsg =
              xsdbool(
                lv_v2_has_wildcard = abap_true
                OR line_exists(
                     lt_role_s_service[
                       role_name = <ls_role>-role_name
                       srv_name  = <ls_v2_service>-iwsg_hash ] )
              ).

          ENDIF.


          "Check IWSV only when its USOBHASH was successfully resolved.
          IF <ls_v2_service>-iwsv_hash IS NOT INITIAL.

            lv_has_iwsv =
              xsdbool(
                lv_v2_has_wildcard = abap_true
                OR line_exists(
                     lt_role_s_service[
                       role_name = <ls_role>-role_name
                       srv_name  = <ls_v2_service>-iwsv_hash ] )
              ).

          ENDIF.


          "Best possible result wins for this logical API.
          IF lv_has_iwsg = abap_true
             AND lv_has_iwsv = abap_true.

            lv_v2_full_match    = abap_true.
            lv_v2_partial_match = abap_false.
            EXIT.

          ELSEIF lv_has_iwsg = abap_true
              OR lv_has_iwsv = abap_true.

            lv_v2_partial_match = abap_true.

          ENDIF.

        ENDLOOP.


        INSERT VALUE #(
          role_name          = <ls_role>-role_name
          odata_service_name = <ls_unique_api>-odata_service_name
          full_match         = lv_v2_full_match
          partial_match      = lv_v2_partial_match
        ) INTO TABLE lt_v2_role_api_checks.

      ENDLOOP.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Resolve the unique OData V4 service groups.
    "
    " For V4, ZDRJ_SCEN_API-ODATA_SERVICE_NAME contains the Service Group
    " name directly. Validate the required groups once against
    " /IWFND/C_V4_MSGR and reuse this buffer for all selected roles.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_v4_group,
        odata_service_name TYPE zdrj_scen_api-odata_service_name,
        group_id           TYPE /iwfnd/v4_med_group_id,
      END OF ty_v4_group.

    DATA lt_v4_required TYPE SORTED TABLE OF ty_v4_group
      WITH UNIQUE KEY group_id.

    DATA lt_v4_groups TYPE SORTED TABLE OF ty_v4_group
      WITH UNIQUE KEY group_id.


    LOOP AT lt_unique_apis
      ASSIGNING <ls_unique_api>
      WHERE api_type = 'V4'.

      DATA(lv_v4_group_id) =
        CONV /iwfnd/v4_med_group_id(
          condense( <ls_unique_api>-odata_service_name ) ).

      IF lv_v4_group_id IS INITIAL.
        CONTINUE.
      ENDIF.

      INSERT VALUE #(
        odata_service_name = <ls_unique_api>-odata_service_name
        group_id           = lv_v4_group_id
      ) INTO TABLE lt_v4_required.

    ENDLOOP.


    "Validate all required V4 groups in one database read.
    IF lt_v4_required IS NOT INITIAL.

      SELECT group_id
        FROM /iwfnd/c_v4_msgr
        FOR ALL ENTRIES IN @lt_v4_required
        WHERE group_id = @lt_v4_required-group_id
        INTO TABLE @DATA(lt_v4_registered).

    ENDIF.


    LOOP AT lt_v4_registered
      ASSIGNING FIELD-SYMBOL(<ls_v4_registered>).

      READ TABLE lt_v4_required
        ASSIGNING FIELD-SYMBOL(<ls_v4_required>)
        WITH TABLE KEY
          group_id = <ls_v4_registered>-group_id.

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      INSERT VALUE #(
        odata_service_name = <ls_v4_required>-odata_service_name
        group_id           = <ls_v4_registered>-group_id
      ) INTO TABLE lt_v4_groups.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Evaluate OData V4 authorization for every selected Role -> API.
    "
    " A V4 API is authorized when one S_START AUTH instance contains:
    "
    "   AUTHPGMID  = 'R3TR' or '*'
    "   AUTHOBJTYP = 'G4BA' or '*'
    "   AUTHOBJNAM = Service Group or '*'
    "
    " All three fields must belong to the SAME AUTH instance.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_v4_role_api_check,
        role_name          TYPE agr_name,
        odata_service_name TYPE zdrj_scen_api-odata_service_name,
        full_match         TYPE abap_bool,
      END OF ty_v4_role_api_check.

    DATA lt_v4_role_api_checks TYPE SORTED TABLE OF ty_v4_role_api_check
      WITH UNIQUE KEY
        role_name
        odata_service_name.


    LOOP AT it_roles ASSIGNING <ls_role>.

      LOOP AT lt_v4_required
        ASSIGNING <ls_v4_required>.

        DATA lv_v4_full_match TYPE abap_bool.
        CLEAR lv_v4_full_match.


        "If the service group itself is not registered on the system,
        "the role cannot satisfy this V4 API requirement.
        IF line_exists(
             lt_v4_groups[
               group_id = <ls_v4_required>-group_id ] ).

          DATA(lv_v4_group_auth_value) =
            CONV agr_1251-low(
              <ls_v4_required>-group_id ).


          "AUTHOBJNAM identifies candidate S_START authorization instances.
          LOOP AT lt_role_api_auth
            ASSIGNING FIELD-SYMBOL(<ls_v4_auth_candidate>)
            WHERE role_name = <ls_role>-role_name
              AND object    = 'S_START'
              AND field     = 'AUTHOBJNAM'.

            IF <ls_v4_auth_candidate>-low <> lv_v4_group_auth_value
               AND <ls_v4_auth_candidate>-low <> '*'.
              CONTINUE.
            ENDIF.


            "AUTHPGMID must be R3TR or wildcard in the SAME AUTH instance.
            DATA(lv_has_v4_pgmid) =
              xsdbool(
                line_exists(
                  lt_role_api_auth[
                    role_name = <ls_role>-role_name
                    object    = 'S_START'
                    auth      = <ls_v4_auth_candidate>-auth
                    field     = 'AUTHPGMID'
                    low       = 'R3TR' ] )
                OR
                line_exists(
                  lt_role_api_auth[
                    role_name = <ls_role>-role_name
                    object    = 'S_START'
                    auth      = <ls_v4_auth_candidate>-auth
                    field     = 'AUTHPGMID'
                    low       = '*' ] )
              ).

            IF lv_has_v4_pgmid = abap_false.
              CONTINUE.
            ENDIF.


            "AUTHOBJTYP must be G4BA or wildcard in the SAME AUTH instance.
            DATA(lv_has_v4_objtyp) =
              xsdbool(
                line_exists(
                  lt_role_api_auth[
                    role_name = <ls_role>-role_name
                    object    = 'S_START'
                    auth      = <ls_v4_auth_candidate>-auth
                    field     = 'AUTHOBJTYP'
                    low       = 'G4BA' ] )
                OR
                line_exists(
                  lt_role_api_auth[
                    role_name = <ls_role>-role_name
                    object    = 'S_START'
                    auth      = <ls_v4_auth_candidate>-auth
                    field     = 'AUTHOBJTYP'
                    low       = '*' ] )
              ).

            IF lv_has_v4_objtyp = abap_false.
              CONTINUE.
            ENDIF.


            "All three required S_START fields were satisfied inside
            "the same authorization instance.
            lv_v4_full_match = abap_true.
            EXIT.

          ENDLOOP.

        ENDIF.


        INSERT VALUE #(
          role_name          = <ls_role>-role_name
          odata_service_name = <ls_v4_required>-odata_service_name
          full_match         = lv_v4_full_match
        ) INTO TABLE lt_v4_role_api_checks.

      ENDLOOP.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Build one common Role -> Scenario -> API requirement result table.
    "
    " V2:
    "   FULL    = IWSG + IWSV
    "   PARTIAL = only IWSG or only IWSV
    "
    " V4:
    "   FULL    = complete S_START authorization
    "   PARTIAL is currently not applicable.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_api_check,
        role_name          TYPE agr_name,
        capability_name    TYPE zdrj_scen_api-capability_name,
        scenario_name      TYPE zdrj_scen_api-scenario_name,
        odata_service_name TYPE zdrj_scen_api-odata_service_name,
        api_type           TYPE zdrj_scen_api-api_version,
        full_match         TYPE abap_bool,
        partial_match      TYPE abap_bool,
      END OF ty_api_check.

    DATA lt_api_checks TYPE SORTED TABLE OF ty_api_check
      WITH UNIQUE KEY
        role_name
        capability_name
        scenario_name
        odata_service_name
        api_type.


    LOOP AT it_roles ASSIGNING <ls_role>.

      LOOP AT lt_scenario_apis
        ASSIGNING <ls_scenario_api>.

        DATA lv_api_full_match    TYPE abap_bool.
        DATA lv_api_partial_match TYPE abap_bool.

        CLEAR:
          lv_api_full_match,
          lv_api_partial_match.


        CASE <ls_scenario_api>-api_version.

          WHEN 'V2'.

            READ TABLE lt_v2_role_api_checks
              ASSIGNING FIELD-SYMBOL(<ls_v2_api_check>)
              WITH TABLE KEY
                role_name          = <ls_role>-role_name
                odata_service_name = <ls_scenario_api>-odata_service_name.

            IF sy-subrc = 0.
              lv_api_full_match    = <ls_v2_api_check>-full_match.
              lv_api_partial_match = <ls_v2_api_check>-partial_match.
            ENDIF.


          WHEN 'V4'.

            READ TABLE lt_v4_role_api_checks
              ASSIGNING FIELD-SYMBOL(<ls_v4_api_check>)
              WITH TABLE KEY
                role_name          = <ls_role>-role_name
                odata_service_name = <ls_scenario_api>-odata_service_name.

            IF sy-subrc = 0.
              lv_api_full_match = <ls_v4_api_check>-full_match.
            ENDIF.

        ENDCASE.


        INSERT VALUE #(
          role_name          = <ls_role>-role_name
          capability_name    = <ls_scenario_api>-capability_name
          scenario_name      = <ls_scenario_api>-scenario_name
          odata_service_name = <ls_scenario_api>-odata_service_name
          api_type           = <ls_scenario_api>-api_version
          full_match         = lv_api_full_match
          partial_match      = lv_api_partial_match
        ) INTO TABLE lt_api_checks.

      ENDLOOP.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Aggregate API checks for every Role -> Scenario combination.
    "
    " RequiredAPI = number of API requirements defined for the scenario.
    " CoveredAPI  = number of API requirements fully authorized.
    "
    " A V2 partial authorization does NOT count as covered, but is kept
    " as a warning so it can later produce PARTIAL scenario coverage.
    "--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_api_summary,
        role_name       TYPE agr_name,
        capability_name TYPE zdrj_scen_api-capability_name,
        scenario_name   TYPE zdrj_scen_api-scenario_name,
        required_api    TYPE i,
        covered_api     TYPE i,
        api_satisfied   TYPE abap_bool,
        api_warning     TYPE abap_bool,
      END OF ty_api_summary.

    DATA lt_api_summary TYPE SORTED TABLE OF ty_api_summary
      WITH UNIQUE KEY
        role_name
        capability_name
        scenario_name.


    DATA:
      lv_required_api  TYPE i,
      lv_covered_api   TYPE i,
      lv_api_satisfied TYPE abap_bool,
      lv_api_warning   TYPE abap_bool.


    LOOP AT it_roles ASSIGNING <ls_role>.

      LOOP AT lt_scenarios ASSIGNING <ls_scenario>.

        CLEAR:
          lv_required_api,
          lv_covered_api,
          lv_api_satisfied,
          lv_api_warning.


        LOOP AT lt_api_checks
          ASSIGNING FIELD-SYMBOL(<ls_api_check>)
          WHERE role_name       = <ls_role>-role_name
            AND capability_name = <ls_scenario>-capability_name
            AND scenario_name   = <ls_scenario>-scenario_name.

          lv_required_api += 1.

          IF <ls_api_check>-full_match = abap_true.

            lv_covered_api += 1.

          ELSEIF <ls_api_check>-partial_match = abap_true.

            "For V2 this means only IWSG or only IWSV was authorized.
            lv_api_warning = abap_true.

          ENDIF.

        ENDLOOP.


        "No API requirement means API validation is neutral.
        IF lv_required_api = 0.

          lv_api_satisfied = abap_true.

        ELSEIF lv_covered_api = lv_required_api.

          "Every API requirement is fully authorized.
          lv_api_satisfied = abap_true.

        ENDIF.


        INSERT VALUE #(
          role_name       = <ls_role>-role_name
          capability_name = <ls_scenario>-capability_name
          scenario_name   = <ls_scenario>-scenario_name
          required_api    = lv_required_api
          covered_api     = lv_covered_api
          api_satisfied   = lv_api_satisfied
          api_warning     = lv_api_warning
        ) INTO TABLE lt_api_summary.

      ENDLOOP.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Build the final Role -> Scenario matrix result.
    "
    " FULL:
    "   TM and API requirements are completely satisfied, without warning.
    "
    " PARTIAL:
    "   At least some required content is covered, or an ANY / partial-V2
    "   condition produced a warning.
    "
    " NONE:
    "   No actual requirement of the scenario is covered by the role.
    "--------------------------------------------------------------------
    LOOP AT it_roles ASSIGNING <ls_role>.

      LOOP AT lt_scenarios ASSIGNING <ls_scenario>.

        READ TABLE lt_tm_summary
          ASSIGNING FIELD-SYMBOL(<ls_tm_result>)
          WITH TABLE KEY
            role_name       = <ls_role>-role_name
            capability_name = <ls_scenario>-capability_name
            scenario_name   = <ls_scenario>-scenario_name.

        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.


        READ TABLE lt_api_summary
          ASSIGNING FIELD-SYMBOL(<ls_api_result>)
          WITH TABLE KEY
            role_name       = <ls_role>-role_name
            capability_name = <ls_scenario>-capability_name
            scenario_name   = <ls_scenario>-scenario_name.

        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.


        DATA lv_coverage TYPE zdrj_cra_result-coverage.


        "Everything required is satisfied and there is no warning.
        IF <ls_tm_result>-tm_satisfied   = abap_true
           AND <ls_api_result>-api_satisfied = abap_true
           AND <ls_tm_result>-tm_warning     = abap_false
           AND <ls_api_result>-api_warning   = abap_false.

          lv_coverage = 'FULL'.


        "Some usable coverage exists, but the scenario is not fully met.
        ELSEIF <ls_tm_result>-covered_tm > 0
            OR <ls_api_result>-covered_api > 0
            OR <ls_tm_result>-tm_warning = abap_true
            OR <ls_api_result>-api_warning = abap_true.

          lv_coverage = 'PARTIAL'.


        "Nothing required by the scenario is covered.
        ELSE.

          lv_coverage = 'NONE'.

        ENDIF.


        APPEND VALUE #(
          role_name       = <ls_role>-role_name
          capability_name = <ls_scenario>-capability_name
          scenario_name   = <ls_scenario>-scenario_name
          coverage        = lv_coverage
          required_tm     = <ls_tm_result>-required_tm
          covered_tm      = <ls_tm_result>-covered_tm
          required_api    = <ls_api_result>-required_api
          covered_api     = <ls_api_result>-covered_api
        ) TO et_results.

      ENDLOOP.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Build detailed missing Target Mapping requirements.
    "
    " LT_TM_CHECKS already contains one result for every
    " Role -> Scenario -> TM requirement, so no matching is repeated.
    "
    " REQUIREMENT_KEY is only the technical persistence key.
    " The actual TM details are stored in the dedicated fields below.
    "--------------------------------------------------------------------
    LOOP AT lt_tm_checks
      ASSIGNING <ls_tm_check>
      WHERE matched = abap_false.

      "LT_TM_CHECKS is sorted, therefore its row index gives us a simple
      "and deterministic technical key within this analysis result.
      DATA(lv_tm_missing_index) = sy-tabix.

      APPEND VALUE #(
        role_name          = <ls_tm_check>-role_name
        capability_name    = <ls_tm_check>-capability_name
        scenario_name      = <ls_tm_check>-scenario_name
        requirement_type   = 'TM'
        requirement_key    =
          CONV zdrj_cra_missing-requirement_key(
            |TM:{ lv_tm_missing_index }| )
        semantic_object    = <ls_tm_check>-semantic_object
        semantic_action    = <ls_tm_check>-semantic_action
        catalog_id         = <ls_tm_check>-catalog_id
      ) TO et_missing.

    ENDLOOP.

    "--------------------------------------------------------------------
    " Build detailed missing / incomplete API requirements.
    "
    " LT_API_CHECKS already contains the final result for every
    " Role -> Scenario -> API requirement.
    "
    " FULL matches are complete and therefore not written here.
    " V2 PARTIAL matches are deliberately included because the API
    " requirement is still not completely authorized.
    "--------------------------------------------------------------------
    LOOP AT lt_api_checks
      ASSIGNING <ls_api_check>
      WHERE full_match = abap_false.

      DATA(lv_api_missing_index) = sy-tabix.

      APPEND VALUE #(
        role_name          = <ls_api_check>-role_name
        capability_name    = <ls_api_check>-capability_name
        scenario_name      = <ls_api_check>-scenario_name
        requirement_type   = 'API'
        requirement_key    =
          CONV zdrj_cra_missing-requirement_key(
            |API:{ lv_api_missing_index }| )
        odata_service_name = <ls_api_check>-odata_service_name
        api_version        = <ls_api_check>-api_type
      ) TO et_missing.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
