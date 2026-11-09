CLASS zcl_drj_fdm_utility DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .
  "====================================================================
  " FDM Utility
  "
  " Central utility layer for Target Mapping resolution and
  " SAPUI5 / Web Dynpro dependency extraction using FDM, App Index
  " and Service Info APIs.
  "
  " TARGET MAPPING RESOLUTION
  "
  " ├─ get_all_tm_apps_info
  " │   ├─ Normalize supplied catalog
  " │   │   ├─ remove X-SAP-UI2-CATALOGPAGE prefix
  " │   │   ├─ remove X-SAP-UI2-ADCAT prefix
  " │   │   ├─ extract runtime system alias from ADCAT IDs
  " │   │   └─ optionally normalize *_APPS → *_BE_APPS
  " │   │
  " │   ├─ Determine catalog type
  " │   │   ├─ standard catalog
  " │   │   └─ replicated catalog
  " │   │
  " │   ├─ Resolve catalog scope
  " │   │   ├─ valid supplied catalog
  " │   │   │   └─ /ui2/cl_fdm_catalog_api->get_catalog_items
  " │   │   │       → strict Catalog + Semantic Object + Action lookup
  " │   │   │
  " │   │   └─ blank / invalid supplied catalog
  " │   │       └─ get_fdm_catalog_cache
  " │   │           → broad Semantic Object + Action fallback
  " │   │
  " │   └─ Return all matching Target Mappings
  " │       ├─ application type
  " │       ├─ application structure
  " │       ├─ application detail
  " │       └─ application descriptor ID
  " │
  " ├─ get_tm_app_info_first
  " │   └─ get_all_tm_apps_info
  " │       └─ first matching Target Mapping
  " │
  " ├─ get_tm_app_info_ui5
  " │   └─ get_all_tm_apps_info
  " │       └─ first SAPUI5 Target Mapping
  " │
  " ├─ get_tm_app_info_wda
  " │   └─ get_all_tm_apps_info
  " │       └─ first Web Dynpro Target Mapping
  " │
  " ├─ get_tm_app_info_sapgui
  " │   └─ get_all_tm_apps_info
  " │       └─ first SAP GUI Target Mapping
  " │
  " └─ get_tm_app_info
  "     └─ deprecated compatibility wrapper
  "         └─ get_all_tm_apps_info → first result
  "
  " FDM CATALOG CACHE
  "
  " └─ get_fdm_catalog_cache
  "     ├─ /ui2/cl_fdm_catalog_api
  "     ├─ get_all_catalog_keys
  "     └─ get_catalog_items
  "         └─ cached in mo_fdm_catalog_items
  "
  " SAPUI5 DEPENDENCY RESOLUTION
  "
  " ├─ get_component_ui5_dependencies
  " │   └─ get_multi_comp_ui5_dep
  " │
  " ├─ get_multi_comp_ui5_dep
  " │   ├─ /ui5/cl_ui5_app_api_factory
  " │   │   └─ get_app_index_instance
  " │   ├─ /ui5/if_ui5_app_index->get_ui5_app_info
  " │   └─ /ui2/cl_service_info_factory
  " │       └─ resolve dependency URLs / IDs to service objects
  " │
  " ├─ get_single_tm_ui5_dependencies
  " │   └─ SAPUI5 Target Mapping
  " │       → component
  " │       → App Index dependencies
  " │       → Service Info objects
  " │
  " └─ get_multi_tm_ui5_dependencies
  "     └─ multiple SAPUI5 Target Mappings
  "         → unique components
  "         → App Index dependencies
  "         → Service Info objects
  "
  " SAPUI5 DEPENDENCY FORMATTING
  "
  " ├─ get_ui5_dependency_details
  " │   └─ service object
  " │       ├─ type
  " │       ├─ service / group ID
  " │       ├─ version
  " │       └─ URL
  " │
  " ├─ get_ui5_comp_dep_details
  " │   └─ get_component_ui5_dependencies
  " │       └─ get_ui5_dependency_details
  " │
  " └─ get_ui5_mult_comp_dep_details
  "     └─ get_multi_comp_ui5_dep
  "         └─ get_ui5_dependency_details
  "
  " SAPUI5 MULTI-SERVICE V2 FLOW
  "
  " ├─ get_multicomp_ui5dep_v2
  " │   ├─ resolve dependencies from App Index
  " │   ├─ preserve service sequence
  " │   └─ return ty_service_v2[]
  " │
  " ├─ get_ui5_dependency_details_v2
  " │   └─ format sequenced service objects
  " │
  " ├─ get_ui5_multcomp_dep_det_v2
  " │   └─ get_multicomp_ui5dep_v2
  " │       └─ get_ui5_dependency_details_v2
  " │
  " └─ get_ui5_comp_dep_details_v2
  "     └─ single component wrapper
  "         └─ get_ui5_multcomp_dep_det_v2
  "
  " WEB DYNPRO DEPENDENCY RESOLUTION
  "
  " ├─ get_single_tm_wda_dependencies
  " │   ├─ build /sap/bc/webdynpro/... URL
  " │   ├─ preserve system alias
  " │   └─ /ui2/cl_service_info_factory
  " │       └─ create WDA service object
  " │
  " └─ get_multi_tm_wda_dependencies
  "     └─ same flow for multiple Web Dynpro Target Mappings
  "
  " MAIN APPLICATION HELPERS
  "
  " ├─ get_main_ui5_service
  " │   └─ SAPUI5 component
  " │       → App Index
  " │       → first dependency / main application service
  " │
  " └─ get_main_wda_service
  "     └─ return WDA application, configuration and system alias
  "====================================================================
  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_tm_app_info,
        found              TYPE abap_bool,
        application_type   TYPE string,
        application_detail TYPE string,
        appdescr_id        TYPE string,
        status_text        TYPE string,
        application        TYPE /ui2/if_fdm=>ts_tm_application,
      END OF ty_tm_app_info.
    TYPES:
      tt_tm_app_info TYPE STANDARD TABLE OF ty_tm_app_info
        WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_main_ui5_service,
        found          TYPE abap_bool,
        ui5_repository TYPE o2applname,
        url            TYPE string,
        status_text    TYPE string,
      END OF ty_main_ui5_service.

    TYPES:
      BEGIN OF ty_main_wda_service,
        found             TYPE abap_bool,
        wda_application   TYPE string,
        wda_configuration TYPE string,
        system_alias      TYPE /ui2/fdm_runtime_system_alias,
        status_text       TYPE string,
      END OF ty_main_wda_service.

    TYPES:
      BEGIN OF ty_dependency_formatter,
        app_type        TYPE string,
        service_name    TYPE string,
        service_version TYPE string,
        url             TYPE string,
      END OF ty_dependency_formatter.

    TYPES:
      tt_dependency_formatter TYPE STANDARD TABLE OF ty_dependency_formatter
        WITH EMPTY KEY.

*****Enhancement to support multiple services.
    TYPES:
      BEGIN OF ty_service_v2,
        service_seqno TYPE i,
        url_type      TYPE /ui2/cl_service_info=>tv_service_type,
        pseudo_url    TYPE string,
        service_obj   TYPE REF TO /ui2/if_service_info,
      END OF ty_service_v2.

    TYPES:
      tt_service_v2 TYPE STANDARD TABLE OF ty_service_v2
        WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_dependency_formatter_v2,
        service_seqno   TYPE i,
        app_type        TYPE string,
        service_name    TYPE string,
        service_version TYPE string,
        url             TYPE string,
      END OF ty_dependency_formatter_v2.

    TYPES:
      tt_dependency_formatter_v2 TYPE STANDARD TABLE OF ty_dependency_formatter_v2
        WITH EMPTY KEY.

    CLASS-METHODS get_tm_app_info
      IMPORTING
        iv_catalog_id      TYPE string
        iv_semantic_object TYPE /ui2/fdm_semantic_object
        iv_semantic_action TYPE /ui2/fdm_semantic_action
      RETURNING
        VALUE(rs_info)     TYPE ty_tm_app_info.
    " DEPRECATED
    " Use:
    "   get_tm_app_info_ui5
    "   get_tm_app_info_wda
    "   get_tm_app_info_tr
    "   get_tm_app_info_first

    CLASS-METHODS get_all_tm_apps_info
      IMPORTING
        iv_catalog_id      TYPE string
        iv_semantic_object TYPE /ui2/fdm_semantic_object
        iv_semantic_action TYPE /ui2/fdm_semantic_action
      RETURNING
        VALUE(rt_info)     TYPE tt_tm_app_info.

    CLASS-METHODS get_tm_app_info_first
      IMPORTING
        iv_catalog_id      TYPE string
        iv_semantic_object TYPE /ui2/fdm_semantic_object
        iv_semantic_action TYPE /ui2/fdm_semantic_action
      RETURNING
        VALUE(rs_info)     TYPE ty_tm_app_info.

    CLASS-METHODS get_tm_app_info_ui5
      IMPORTING
        iv_catalog_id      TYPE string
        iv_semantic_object TYPE /ui2/fdm_semantic_object
        iv_semantic_action TYPE /ui2/fdm_semantic_action
      RETURNING
        VALUE(rs_info)     TYPE ty_tm_app_info.

    CLASS-METHODS get_tm_app_info_wda
      IMPORTING
        iv_catalog_id      TYPE string
        iv_semantic_object TYPE /ui2/fdm_semantic_object
        iv_semantic_action TYPE /ui2/fdm_semantic_action
      RETURNING
        VALUE(rs_info)     TYPE ty_tm_app_info.

    CLASS-METHODS get_tm_app_info_sapgui
      IMPORTING
        iv_catalog_id      TYPE string
        iv_semantic_object TYPE /ui2/fdm_semantic_object
        iv_semantic_action TYPE /ui2/fdm_semantic_action
      RETURNING
        VALUE(rs_info)     TYPE ty_tm_app_info.


    CLASS-METHODS get_component_ui5_dependencies
      IMPORTING
        iv_component       TYPE /ui5/app_index_component_id
      RETURNING
        VALUE(rt_services) TYPE /ui2/cl_service_info=>tt_service.

    CLASS-METHODS get_multi_comp_ui5_dep
      IMPORTING
        it_components      TYPE /ui5/app_index_component_id_t
      RETURNING
        VALUE(rt_services) TYPE /ui2/cl_service_info=>tt_service.

    CLASS-METHODS get_single_tm_ui5_dependencies
      IMPORTING
        it_target_mapping  TYPE /ui2/if_fdm=>ts_tm
      RETURNING
        VALUE(rt_services) TYPE /ui2/cl_service_info=>tt_service.

    CLASS-METHODS get_multi_tm_ui5_dependencies
      IMPORTING
        it_target_mappings TYPE /ui2/if_fdm=>tt_tm_sorted
      RETURNING
        VALUE(rt_services) TYPE /ui2/cl_service_info=>tt_service.

    CLASS-METHODS get_single_tm_wda_dependencies
      IMPORTING
        it_target_mapping  TYPE /ui2/if_fdm=>ts_tm
      RETURNING
        VALUE(rt_services) TYPE /ui2/cl_service_info=>tt_service.

    CLASS-METHODS get_multi_tm_wda_dependencies
      IMPORTING
        it_target_mappings TYPE /ui2/if_fdm=>tt_tm_sorted
      RETURNING
        VALUE(rt_services) TYPE /ui2/cl_service_info=>tt_service.


    CLASS-METHODS get_ui5_dependency_details
      IMPORTING
        it_services    TYPE /ui2/cl_service_info=>tt_service
      RETURNING
        VALUE(rt_info) TYPE tt_dependency_formatter.

    CLASS-METHODS get_ui5_comp_dep_details
      IMPORTING
        iv_component   TYPE /ui5/app_index_component_id
      RETURNING
        VALUE(rt_info) TYPE tt_dependency_formatter.

    CLASS-METHODS get_ui5_comp_dep_details_v2
      IMPORTING
        iv_component   TYPE /ui5/app_index_component_id
      RETURNING
        VALUE(rt_info) TYPE tt_dependency_formatter_v2.

    CLASS-METHODS get_ui5_mult_comp_dep_details
      IMPORTING
        it_components  TYPE /ui5/app_index_component_id_t
      RETURNING
        VALUE(rt_info) TYPE tt_dependency_formatter.


    CLASS-METHODS get_main_ui5_service
      IMPORTING
        it_target_mapping TYPE /ui2/if_fdm=>ts_tm
      RETURNING
        VALUE(rs_service) TYPE ty_main_ui5_service.

    CLASS-METHODS get_main_wda_service
      IMPORTING
        is_application    TYPE /ui2/if_fdm=>ts_tm_application
      RETURNING
        VALUE(rs_service) TYPE ty_main_wda_service.

*****Enhancement to support multiple services.
    CLASS-METHODS get_multicomp_ui5dep_v2
      IMPORTING
        it_components      TYPE /ui5/app_index_component_id_t
      RETURNING
        VALUE(rt_services) TYPE tt_service_v2.

    CLASS-METHODS get_ui5_dependency_details_v2
      IMPORTING
        it_services    TYPE tt_service_v2
      RETURNING
        VALUE(rt_info) TYPE tt_dependency_formatter_v2.

    CLASS-METHODS get_ui5_multcomp_dep_det_v2
      IMPORTING
        it_components  TYPE /ui5/app_index_component_id_t
      RETURNING
        VALUE(rt_info) TYPE tt_dependency_formatter_v2.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA mt_fdm_catalog_keys
    TYPE /ui2/if_fdm=>tt_catalog_key.

    CLASS-DATA mo_fdm_catalog_items
      TYPE REF TO /ui2/if_fdm_catalog_items.

    CLASS-METHODS get_fdm_catalog_cache
      RETURNING
        VALUE(ro_catalog_items)
          TYPE REF TO /ui2/if_fdm_catalog_items.
ENDCLASS.



CLASS zcl_drj_fdm_utility IMPLEMENTATION.
  METHOD get_tm_app_info.

    "Deprecated compatibility method.
    "Returns the first matching Target Mapping while using the
    "centralized catalog resolution/fallback logic.

    DATA:
      lv_catalog_type TYPE /ui2/fdm_entity_type,
      lv_system_alias TYPE /ui2/fdm_system_alias.

    CLEAR rs_info.

    TRY.

        "------------------------------------------------------------
        " Determine catalog type only for legacy status text
        "------------------------------------------------------------
        DATA(lv_catalog_id) = iv_catalog_id.
        DATA(lv_be_catalog) = lv_catalog_id.

        IF lv_catalog_id CS 'X-SAP-UI2-CATALOGPAGE:'.

          REPLACE FIRST OCCURRENCE OF
            'X-SAP-UI2-CATALOGPAGE:'
            IN lv_catalog_id
            WITH ''.

        ENDIF.

        IF lv_catalog_id CS 'X-SAP-UI2-ADCAT:'.

          REPLACE FIRST OCCURRENCE OF
            'X-SAP-UI2-ADCAT:'
            IN lv_catalog_id
            WITH ''.

          SPLIT lv_catalog_id AT ':'
            INTO lv_catalog_id lv_system_alias.

        ENDIF.

        lv_be_catalog = lv_catalog_id.

        IF lv_catalog_id CP '*_APPS'
           AND lv_catalog_id NP '*_BE_APPS'.

          REPLACE '_APPS'
            IN lv_be_catalog
            WITH '_BE_APPS'.

          SELECT SINGLE catalog_id
            FROM /ui2/sysaliascat
            WHERE catalog_id = @lv_be_catalog
            INTO @DATA(lv_be_exists).

          IF sy-subrc = 0.
            lv_catalog_id = lv_be_catalog.
          ENDIF.

        ENDIF.

        IF lv_system_alias IS NOT INITIAL.

          lv_catalog_type =
            /ui2/if_fdm=>gc_catalog_type-replicated.

        ELSE.

          SELECT SINGLE sys_alias
            FROM /ui2/sysaliascat
            INTO @lv_system_alias
            WHERE catalog_id = @lv_catalog_id.

          IF sy-subrc = 0.

            lv_catalog_type =
              /ui2/if_fdm=>gc_catalog_type-replicated.

          ELSE.

            lv_catalog_type =
              /ui2/if_fdm=>gc_catalog_type-standard.

          ENDIF.

        ENDIF.

        "------------------------------------------------------------
        " Centralized Target Mapping lookup
        "------------------------------------------------------------
        DATA(lt_info) =
          get_all_tm_apps_info(
            iv_catalog_id      = iv_catalog_id
            iv_semantic_object = iv_semantic_object
            iv_semantic_action = iv_semantic_action ).

        "------------------------------------------------------------
        " Preserve original contract: return first matching TM
        "------------------------------------------------------------
        READ TABLE lt_info
          INTO rs_info
          INDEX 1.

        IF sy-subrc <> 0.

          rs_info-found = abap_false.

          rs_info-status_text =
            |Target Mapping not found ({ lv_catalog_type })|.

        ENDIF.

      CATCH cx_root INTO DATA(lx).

        CLEAR rs_info.

        rs_info-found = abap_false.

        rs_info-status_text =
          |Exception: { lx->get_text( ) }|.

    ENDTRY.

  ENDMETHOD.

  METHOD get_all_tm_apps_info.
    DATA:
      lo_catalog_api   TYPE REF TO /ui2/if_fdm_catalog_api,
      lo_catalog_items TYPE REF TO /ui2/if_fdm_catalog_items,
      lv_catalog_type  TYPE /ui2/fdm_entity_type,
      lv_system_alias  TYPE /ui2/fdm_system_alias,
      ls_info          TYPE ty_tm_app_info.

    CLEAR rt_info.

    TRY.

        "------------------------------------------------------
        " Normalize catalog
        "
        " Example:
        " SAP_TC_OIL_ACM_APPS
        " -> SAP_TC_OIL_ACM_BE_APPS
        "
        " Only if the BE catalog actually exists
        "------------------------------------------------------
        DATA(lv_catalog_id)       = iv_catalog_id.
        DATA(lv_original_catalog) = lv_catalog_id.
        DATA(lv_be_catalog)       = lv_catalog_id.

*------------------------------------------------------------------
* Remove FLP catalog prefixes
*------------------------------------------------------------------
        IF lv_catalog_id CS 'X-SAP-UI2-CATALOGPAGE:'.

          REPLACE FIRST OCCURRENCE OF
            'X-SAP-UI2-CATALOGPAGE:'
            IN lv_catalog_id
            WITH ''.

        ENDIF.

        IF lv_catalog_id CS 'X-SAP-UI2-ADCAT:'.

          REPLACE FIRST OCCURRENCE OF
            'X-SAP-UI2-ADCAT:'
            IN lv_catalog_id
            WITH ''.

          "Actual replicated TM catalog IDs may contain the
          "runtime system alias as the final suffix:
          "  <catalog_id>:<system_alias>
          SPLIT lv_catalog_id AT ':'
            INTO lv_catalog_id lv_system_alias.

        ENDIF.

        lv_original_catalog = lv_catalog_id.
        lv_be_catalog       = lv_catalog_id.

        IF lv_catalog_id CP '*_APPS'
           AND lv_catalog_id NP '*_BE_APPS'.

          REPLACE '_APPS'
            IN lv_be_catalog
            WITH '_BE_APPS'.

          SELECT SINGLE catalog_id
            FROM /ui2/sysaliascat
            WHERE catalog_id = @lv_be_catalog
            INTO @DATA(lv_be_exists).

          IF sy-subrc = 0.

            lv_catalog_id = lv_be_catalog.

          ELSE.

            lv_catalog_id = lv_original_catalog.

          ENDIF.

        ENDIF.

*------------------------------------------------------------------
* Determine catalog type + alias
*------------------------------------------------------------------

        IF lv_system_alias IS NOT INITIAL.

          "Alias came directly from an actual ADCAT TM catalog ID:
          "X-SAP-UI2-ADCAT:<catalog_id>:<system_alias>
          lv_catalog_type =
            /ui2/if_fdm=>gc_catalog_type-replicated.

        ELSE.

          "Logical/source catalog ID:
          "determine whether it is a replicated catalog locally.
          SELECT SINGLE sys_alias
            FROM /ui2/sysaliascat
            INTO @lv_system_alias
            WHERE catalog_id = @lv_catalog_id.

          IF sy-subrc = 0.

            lv_catalog_type =
              /ui2/if_fdm=>gc_catalog_type-replicated.

          ELSE.

            lv_catalog_type =
              /ui2/if_fdm=>gc_catalog_type-standard.

          ENDIF.

        ENDIF.

*------------------------------------------------------------------
* Resolve catalog scope
*------------------------------------------------------------------

        IF iv_catalog_id IS NOT INITIAL.

          lo_catalog_api =
            NEW /ui2/cl_fdm_catalog_api(
              /ui2/if_fdm=>gc_scope-customization ).

          DATA(lt_catalog_keys) =
            lo_catalog_api->get_all_catalog_keys( ).

          READ TABLE lt_catalog_keys
            TRANSPORTING NO FIELDS
            WITH KEY
              id           = lv_catalog_id
              type         = lv_catalog_type
              system_alias = lv_system_alias.

          IF sy-subrc = 0.

            "Valid supplied catalog:
            "stay strictly inside this catalog.
            DATA(lt_requested_catalog_keys) =
              VALUE /ui2/if_fdm=>tt_catalog_key(
                (
                  id           = lv_catalog_id
                  type         = lv_catalog_type
                  system_alias = lv_system_alias
                )
              ).

            lo_catalog_items =
              lo_catalog_api->get_catalog_items(
                it_catalog_key          = lt_requested_catalog_keys
                iv_include_support_data = abap_true ).

          ELSE.

            "Supplied catalog does not exist locally:
            "treat it exactly like no catalog was supplied.
            lo_catalog_items =
              get_fdm_catalog_cache( ).

          ENDIF.

        ELSE.

          "No catalog supplied:
          "preserve existing broad SO/Action fallback.
          lo_catalog_items =
            get_fdm_catalog_cache( ).

        ENDIF.

        CHECK lo_catalog_items IS BOUND.

*------------------------------------------------------------------
* Find ALL matching target mappings
*------------------------------------------------------------------
        LOOP AT lo_catalog_items->target_mappings
             ASSIGNING FIELD-SYMBOL(<ls_tm>).

          IF <ls_tm>-navigation-semantic_object = iv_semantic_object
             AND <ls_tm>-navigation-semantic_action = iv_semantic_action.

            CLEAR ls_info.

            ls_info-found = abap_true.

            ls_info-application_type =
              <ls_tm>-application-type.

            ls_info-application =
              <ls_tm>-application.

            ls_info-application_detail =
              /ui2/cl_fdm_ui_util=>get_app_detail_from_tm(
                is_tm = <ls_tm> ).

            IF <ls_tm>-replication_context IS NOT INITIAL.

              ls_info-appdescr_id =
                <ls_tm>-replication_context-appdescr_id.

            ENDIF.

            ls_info-status_text =
              |Target Mapping Found ({ lv_catalog_type })|.

            APPEND ls_info TO rt_info.

          ENDIF.

        ENDLOOP.

      CATCH cx_root INTO DATA(lx).

        APPEND VALUE ty_tm_app_info(
          found       = abap_false
          status_text = |Exception: { lx->get_text( ) }|
        ) TO rt_info.

    ENDTRY.

  ENDMETHOD.

  METHOD get_component_ui5_dependencies.

    DATA lt_components TYPE /ui5/app_index_component_id_t.
    CHECK iv_component IS NOT INITIAL.
    APPEND iv_component TO lt_components.

    rt_services =
      get_multi_comp_ui5_dep(
        it_components = lt_components ).

  ENDMETHOD.

  METHOD get_multi_comp_ui5_dep.

    DATA:
      lo_app_index       TYPE REF TO /ui5/if_ui5_app_index,
      lo_service_factory TYPE REF TO /ui2/if_service_info_factory,
      lt_components      TYPE /ui5/app_index_component_id_t,
      lt_ui5_app_info    TYPE /ui5/app_index_ui5_info_t,
      lv_url             TYPE string.

*--------------------------------------------------------------------
* Validate Input
*--------------------------------------------------------------------
    CHECK it_components IS NOT INITIAL.

*--------------------------------------------------------------------
* Remove duplicates
*--------------------------------------------------------------------
    lt_components = it_components.

    SORT lt_components.
    DELETE ADJACENT DUPLICATES FROM lt_components.

*--------------------------------------------------------------------
* App Index
*--------------------------------------------------------------------
    lo_app_index =
      /ui5/cl_ui5_app_api_factory=>get_app_index_instance( ).

    lo_service_factory =
      NEW /ui2/cl_service_info_factory( ).

*--------------------------------------------------------------------
* Read UI5 App Index
*--------------------------------------------------------------------
    lo_app_index->get_ui5_app_info(
      EXPORTING
        it_components = lt_components
      IMPORTING
        et_info       = lt_ui5_app_info ).

*--------------------------------------------------------------------
* Resolve Dependencies
*--------------------------------------------------------------------
    LOOP AT lt_ui5_app_info
         ASSIGNING FIELD-SYMBOL(<ls_app>).

      LOOP AT <ls_app>-dependencies
           ASSIGNING FIELD-SYMBOL(<ls_dep>).

        IF <ls_dep>-url CS '/sap/'
           AND <ls_dep>-url NS '/sap/bc/lrep/'.

          lv_url = <ls_dep>-url.

          INSERT lo_service_factory->get_instance_by_url(
                    iv_url = lv_url
                 )->get_me_as_service_struct( )
            INTO TABLE rt_services.

        ENDIF.

        IF <ls_dep>-id CS '/sap/'
           AND <ls_dep>-id NS '/sap/bc/lrep/'.

          lv_url = CONV string( <ls_dep>-id ).

          INSERT lo_service_factory->get_instance_by_url(
                    iv_url = lv_url
                 )->get_me_as_service_struct( )
            INTO TABLE rt_services.

        ENDIF.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_single_tm_ui5_dependencies.

    DATA:
      lo_app_index       TYPE REF TO /ui5/if_ui5_app_index,
      lo_service_factory TYPE REF TO /ui2/if_service_info_factory,
      lt_components      TYPE /ui5/app_index_component_id_t,
      lt_ui5_app_info    TYPE /ui5/app_index_ui5_info_t,
      lv_url             TYPE string.

    "--------------------------------------------------------
    " Validate Input
    "--------------------------------------------------------
    CHECK it_target_mapping-application-type =
            /ui2/if_fdm=>gc_app_type-sapui5.

    CHECK it_target_mapping-application-target-ui5-component
            IS NOT INITIAL.

    lo_app_index =
      /ui5/cl_ui5_app_api_factory=>get_app_index_instance( ).

    lo_service_factory =
      NEW /ui2/cl_service_info_factory( ).

    "--------------------------------------------------------
    " Read UI5 App Index
    "--------------------------------------------------------
    APPEND it_target_mapping-application-target-ui5-component
      TO lt_components.

    lo_app_index->get_ui5_app_info(
      EXPORTING
        it_components = lt_components
      IMPORTING
        et_info       = lt_ui5_app_info ).

    READ TABLE lt_ui5_app_info
      ASSIGNING FIELD-SYMBOL(<ls_app>)
      INDEX 1.

    CHECK sy-subrc = 0.

    "--------------------------------------------------------
    " Equivalent of GET_DEPENDENT_UI_SERVICES
    "--------------------------------------------------------
    LOOP AT <ls_app>-dependencies
      ASSIGNING FIELD-SYMBOL(<ls_dep>).

      IF <ls_dep>-url CS '/sap/'
         AND <ls_dep>-url NS '/sap/bc/lrep/'.

        lv_url = <ls_dep>-url.

        INSERT lo_service_factory->get_instance_by_url(
                  iv_url = lv_url
               )->get_me_as_service_struct( )
          INTO TABLE rt_services.

      ENDIF.

      IF <ls_dep>-id CS '/sap/'
         AND <ls_dep>-id NS '/sap/bc/lrep/'.

        lv_url = CONV string( <ls_dep>-id ).

        INSERT lo_service_factory->get_instance_by_url(
                  iv_url = lv_url
               )->get_me_as_service_struct( )
          INTO TABLE rt_services.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_multi_tm_ui5_dependencies.

    DATA:
      lo_app_index       TYPE REF TO /ui5/if_ui5_app_index,
      lo_service_factory TYPE REF TO /ui2/if_service_info_factory,
      lt_components      TYPE /ui5/app_index_component_id_t,
      lt_ui5_app_info    TYPE /ui5/app_index_ui5_info_t,
      lv_url             TYPE string.

    lo_app_index =
      /ui5/cl_ui5_app_api_factory=>get_app_index_instance( ).

    lo_service_factory =
      NEW /ui2/cl_service_info_factory( ).

    "--------------------------------------------------------
    " Collect UI5 Components
    "--------------------------------------------------------
    LOOP AT it_target_mappings ASSIGNING FIELD-SYMBOL(<ls_tm>)
      WHERE application-target-ui5-component IS NOT INITIAL.

      APPEND <ls_tm>-application-target-ui5-component
        TO lt_components.

    ENDLOOP.

    SORT lt_components.
    DELETE ADJACENT DUPLICATES FROM lt_components.

    "--------------------------------------------------------
    " Read UI5 App Index
    "--------------------------------------------------------
    lo_app_index->get_ui5_app_info(
      EXPORTING
        it_components = lt_components
      IMPORTING
        et_info       = lt_ui5_app_info ).

    SORT lt_ui5_app_info BY component_id.

    "--------------------------------------------------------
    " Equivalent of GET_DEPENDENT_UI_SERVICES
    "--------------------------------------------------------
    LOOP AT it_target_mappings ASSIGNING <ls_tm>
      WHERE application-type = /ui2/if_fdm=>gc_app_type-sapui5.

      READ TABLE lt_ui5_app_info
        ASSIGNING FIELD-SYMBOL(<ls_app>)
        WITH KEY component_id =
          <ls_tm>-application-target-ui5-component
        BINARY SEARCH.

      CHECK sy-subrc = 0.

      LOOP AT <ls_app>-dependencies
        ASSIGNING FIELD-SYMBOL(<ls_dep>).

        IF <ls_dep>-url CS '/sap/'
           AND <ls_dep>-url NS '/sap/bc/lrep/'.

          lv_url = <ls_dep>-url.

          INSERT lo_service_factory->get_instance_by_url(
                    iv_url = lv_url
                 )->get_me_as_service_struct( )
            INTO TABLE rt_services.

        ENDIF.

        IF <ls_dep>-id CS '/sap/'
           AND <ls_dep>-id NS '/sap/bc/lrep/'.

          lv_url = CONV string( <ls_dep>-id ).

          INSERT lo_service_factory->get_instance_by_url(
                    iv_url = lv_url
                 )->get_me_as_service_struct( )
            INTO TABLE rt_services.

        ENDIF.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_single_tm_wda_dependencies.

    DATA:
      lo_service_factory TYPE REF TO /ui2/if_service_info_factory,
      lv_url             TYPE string,
      lv_system_alias    TYPE /ui2/fdm_runtime_system_alias,
      ls_service         TYPE /ui2/cl_service_info=>ts_service.

    lo_service_factory =
      NEW /ui2/cl_service_info_factory( ).

    CHECK it_target_mapping-application-type =
            /ui2/if_fdm=>gc_app_type-web_dynpro.

    CHECK it_target_mapping-application-target-wda-application
            IS NOT INITIAL.

*------------------------------------------------------------------
* Build WDA URL exactly like FCM GET_WDA_SERVICE
*------------------------------------------------------------------
    IF it_target_mapping-application-target-wda-application CS '/'.

      DATA(lv_wda_application) =
        it_target_mapping-application-target-wda-application.

      SHIFT lv_wda_application.

      lv_url =
        |/sap/bc/webdynpro/{ lv_wda_application }|.

    ELSE.

      lv_url =
        |/sap/bc/webdynpro/sap/{ it_target_mapping-application-target-wda-application }|.

    ENDIF.

*------------------------------------------------------------------
* System Alias
*------------------------------------------------------------------
    lv_system_alias =
      it_target_mapping-application-target-wda-system_alias.

*------------------------------------------------------------------
* Create Service Object
*------------------------------------------------------------------
    ls_service =
      lo_service_factory->get_instance_by_url(
        iv_sys_alias = lv_system_alias
        iv_url       = lv_url
      )->get_me_as_service_struct( ).

    INSERT ls_service INTO TABLE rt_services.

  ENDMETHOD.

  METHOD get_multi_tm_wda_dependencies.

    DATA:
      lo_service_factory TYPE REF TO /ui2/if_service_info_factory,
      lv_url             TYPE string,
      lv_system_alias    TYPE /ui2/fdm_runtime_system_alias,
      ls_service         TYPE /ui2/cl_service_info=>ts_service.

    lo_service_factory =
      NEW /ui2/cl_service_info_factory( ).

    LOOP AT it_target_mappings ASSIGNING FIELD-SYMBOL(<ls_tm>)
      WHERE application-type = /ui2/if_fdm=>gc_app_type-web_dynpro.

      CHECK <ls_tm>-application-target-wda-application IS NOT INITIAL.

*------------------------------------------------------------------
* Build WDA URL exactly like FCM GET_WDA_SERVICE
*------------------------------------------------------------------
      IF <ls_tm>-application-target-wda-application CS '/'.

        DATA(lv_wda_application) =
          <ls_tm>-application-target-wda-application.

        SHIFT lv_wda_application.

        lv_url =
          |/sap/bc/webdynpro/{ lv_wda_application }|.

      ELSE.

        lv_url =
          |/sap/bc/webdynpro/sap/{ <ls_tm>-application-target-wda-application }|.

      ENDIF.

*------------------------------------------------------------------
* System Alias
*------------------------------------------------------------------
      lv_system_alias =
        <ls_tm>-application-target-wda-system_alias.

*------------------------------------------------------------------
* Create Service Object
*------------------------------------------------------------------
      ls_service =
        lo_service_factory->get_instance_by_url(
          iv_sys_alias = lv_system_alias
          iv_url       = lv_url
        )->get_me_as_service_struct( ).

      INSERT ls_service INTO TABLE rt_services.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_ui5_dependency_details.

    DATA:
      ls_info TYPE ty_dependency_formatter.

    FIELD-SYMBOLS:
      <ls_service> TYPE /ui2/cl_service_info=>ts_service.

    LOOP AT it_services ASSIGNING <ls_service>.

      CLEAR ls_info.

*--------------------------------------------------------------------
* Generic Service Interface
*--------------------------------------------------------------------
      DATA(lo_service) = <ls_service>-service_obj.

      CHECK lo_service IS BOUND.

*--------------------------------------------------------------------
* Type
*--------------------------------------------------------------------
      ls_info-app_type =
        lo_service->get_type( ).

*--------------------------------------------------------------------
* Service Name
*
* Examples:
*   CATALOGSERVICE
*   /IWFND/CATALOGSERVICE
*   C_SALESORDERMANAGE_SD
*   C_SALESORDERMANAGE_SRV   (ODATA V4 Group ID)
*   ATP_CHARTS1
*--------------------------------------------------------------------

      CASE ls_info-app_type.

        WHEN 'ODATA4'.

          TRY.

              DATA(lo_v4_service) =
                CAST /ui2/if_odata_v4_service_info( lo_service ).

              ls_info-service_name =
                lo_v4_service->get_service_group_id(
                  iv_with_non_sap_namespace = abap_true ).

            CATCH cx_sy_move_cast_error.

              ls_info-service_name =
                lo_service->get_service_id(
                  iv_with_non_sap_namespace = abap_true ).

          ENDTRY.

        WHEN OTHERS.

          ls_info-service_name =
            lo_service->get_service_id(
              iv_with_non_sap_namespace = abap_true ).

      ENDCASE.

*--------------------------------------------------------------------
* Version
*--------------------------------------------------------------------
      ls_info-service_version =
        lo_service->get_service_version( ).

*--------------------------------------------------------------------
* URL
*--------------------------------------------------------------------
      ls_info-url =
        lo_service->get_url( ).

*--------------------------------------------------------------------
* Add Row
*--------------------------------------------------------------------
      APPEND ls_info TO rt_info.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_main_ui5_service.

    DATA:
      lo_app_index    TYPE REF TO /ui5/if_ui5_app_index,
      lt_components   TYPE /ui5/app_index_component_id_t,
      lt_ui5_app_info TYPE /ui5/app_index_ui5_info_t.

    CLEAR rs_service.

*------------------------------------------------------------------
* Validate Input
*------------------------------------------------------------------
    CHECK it_target_mapping-application-type =
            /ui2/if_fdm=>gc_app_type-sapui5.

    CHECK it_target_mapping-application-target-ui5-component
            IS NOT INITIAL.

*------------------------------------------------------------------
* App Index
*------------------------------------------------------------------
    lo_app_index =
      /ui5/cl_ui5_app_api_factory=>get_app_index_instance( ).

    APPEND
      it_target_mapping-application-target-ui5-component
      TO lt_components.

    lo_app_index->get_ui5_app_info(
      EXPORTING
        it_components = lt_components
      IMPORTING
        et_info       = lt_ui5_app_info ).

*------------------------------------------------------------------
* Component Entry
*------------------------------------------------------------------
    READ TABLE lt_ui5_app_info
      ASSIGNING FIELD-SYMBOL(<ls_app>)
      INDEX 1.

    IF sy-subrc <> 0.
      rs_service-status_text =
        'Component not found in App Index'.
      RETURN.
    ENDIF.

*------------------------------------------------------------------
* First dependency = application itself
*------------------------------------------------------------------
    READ TABLE <ls_app>-dependencies
      ASSIGNING FIELD-SYMBOL(<ls_dep>)
      INDEX 1.
    IF sy-subrc <> 0.
      rs_service-status_text =
        'No dependencies returned by App Index'.
      RETURN.
    ENDIF.

    rs_service-found = abap_true.
    rs_service-ui5_repository = <ls_dep>-ui5_repository.
    rs_service-url = <ls_dep>-url.
    rs_service-status_text = 'Main service found'.

  ENDMETHOD.

  METHOD get_main_wda_service.

    CLEAR rs_service.

*------------------------------------------------------------------
* Validate Input
*------------------------------------------------------------------
    CHECK is_application-type =
            /ui2/if_fdm=>gc_app_type-web_dynpro.

    CHECK is_application-target-wda-application
            IS NOT INITIAL.

*------------------------------------------------------------------
* Return WDA Information
*------------------------------------------------------------------
    rs_service-found = abap_true.

    rs_service-wda_application = is_application-target-wda-application.

    rs_service-wda_configuration = is_application-target-wda-configuration.

    rs_service-system_alias = is_application-target-wda-system_alias.

    rs_service-status_text = 'WDA service found'.

  ENDMETHOD.

  METHOD get_ui5_comp_dep_details.

    DATA lt_services TYPE /ui2/cl_service_info=>tt_service.

*--------------------------------------------------------------------
* Resolve dependencies
*--------------------------------------------------------------------
    lt_services =
      get_component_ui5_dependencies(
        iv_component = iv_component ).

*--------------------------------------------------------------------
* Format dependency details
*--------------------------------------------------------------------
    rt_info =
      get_ui5_dependency_details(
        it_services = lt_services ).

  ENDMETHOD.

  METHOD get_ui5_comp_dep_details_v2.

    DATA lt_components TYPE /ui5/app_index_component_id_t.

*--------------------------------------------------------------------
* Validate input
*--------------------------------------------------------------------
    CHECK iv_component IS NOT INITIAL.

*--------------------------------------------------------------------
* Convert single component to component table
*--------------------------------------------------------------------
    APPEND iv_component TO lt_components.

*--------------------------------------------------------------------
* Resolve and format dependency details using V2 flow
*--------------------------------------------------------------------
    rt_info =
      get_ui5_multcomp_dep_det_v2(
        it_components = lt_components ).

  ENDMETHOD.

  METHOD get_ui5_mult_comp_dep_details.

    DATA lt_services TYPE /ui2/cl_service_info=>tt_service.

*--------------------------------------------------------------------
* Resolve dependencies
*--------------------------------------------------------------------
    lt_services =
      get_multi_comp_ui5_dep(
        it_components = it_components ).

*--------------------------------------------------------------------
* Format dependency details
*--------------------------------------------------------------------
    rt_info =
      get_ui5_dependency_details(
        it_services = lt_services ).

  ENDMETHOD.



  METHOD get_tm_app_info_first.

    DATA(lt_info) =
      get_all_tm_apps_info(
        iv_catalog_id      = iv_catalog_id
        iv_semantic_object = iv_semantic_object
        iv_semantic_action = iv_semantic_action ).

    READ TABLE lt_info
      INTO rs_info
      INDEX 1.

  ENDMETHOD.

  METHOD get_tm_app_info_sapgui.

    DATA(lt_info) =
      get_all_tm_apps_info(
        iv_catalog_id      = iv_catalog_id
        iv_semantic_object = iv_semantic_object
        iv_semantic_action = iv_semantic_action ).

    LOOP AT lt_info ASSIGNING FIELD-SYMBOL(<ls_info>).

      IF <ls_info>-application-type =
         /ui2/if_fdm=>gc_app_type-sapgui.

        rs_info = <ls_info>.
        RETURN.

      ENDIF.

    ENDLOOP.

    rs_info-found = abap_false.
    rs_info-status_text = 'No Transaction Target Mapping found'.

  ENDMETHOD.

  METHOD get_tm_app_info_ui5.

    DATA(lt_info) =
      get_all_tm_apps_info(
        iv_catalog_id      = iv_catalog_id
        iv_semantic_object = iv_semantic_object
        iv_semantic_action = iv_semantic_action ).

    LOOP AT lt_info ASSIGNING FIELD-SYMBOL(<ls_info>).

      IF <ls_info>-application-type =
         /ui2/if_fdm=>gc_app_type-sapui5.

        rs_info = <ls_info>.
        RETURN.

      ENDIF.

    ENDLOOP.

    rs_info-found = abap_false.
    rs_info-status_text = 'No SAPUI5 Target Mapping found'.

  ENDMETHOD.

  METHOD get_tm_app_info_wda.

    DATA(lt_info) =
      get_all_tm_apps_info(
        iv_catalog_id      = iv_catalog_id
        iv_semantic_object = iv_semantic_object
        iv_semantic_action = iv_semantic_action ).

    LOOP AT lt_info ASSIGNING FIELD-SYMBOL(<ls_info>).

      IF <ls_info>-application-type =
         /ui2/if_fdm=>gc_app_type-web_dynpro.

        rs_info = <ls_info>.
        RETURN.

      ENDIF.

    ENDLOOP.

    rs_info-found = abap_false.
    rs_info-status_text = 'No Web Dynpro Target Mapping found'.

  ENDMETHOD.

  METHOD get_fdm_catalog_cache.

    IF mo_fdm_catalog_items IS NOT BOUND.


      DATA lo_catalog_api TYPE REF TO /ui2/if_fdm_catalog_api.

      lo_catalog_api =
        NEW /ui2/cl_fdm_catalog_api(
          /ui2/if_fdm=>gc_scope-customization ).

      mt_fdm_catalog_keys = lo_catalog_api->get_all_catalog_keys( ).

      mo_fdm_catalog_items = lo_catalog_api->get_catalog_items(
          it_catalog_key          = mt_fdm_catalog_keys
          iv_include_support_data = abap_true ).

    ENDIF.

    ro_catalog_items = mo_fdm_catalog_items.

  ENDMETHOD.

  METHOD get_multicomp_ui5dep_v2.

    DATA:
      lo_app_index       TYPE REF TO /ui5/if_ui5_app_index,
      lo_service_factory TYPE REF TO /ui2/if_service_info_factory,
      lt_components      TYPE /ui5/app_index_component_id_t,
      lt_ui5_app_info    TYPE /ui5/app_index_ui5_info_t,
      lv_url             TYPE string,
      lv_service_seqno   TYPE i,
      ls_service_std     TYPE /ui2/cl_service_info=>ts_service,
      ls_service_v2      TYPE ty_service_v2.

*--------------------------------------------------------------------
* Validate Input
*--------------------------------------------------------------------
    CHECK it_components IS NOT INITIAL.

*--------------------------------------------------------------------
* Remove duplicates
*--------------------------------------------------------------------
    lt_components = it_components.

    SORT lt_components.
    DELETE ADJACENT DUPLICATES FROM lt_components.

*--------------------------------------------------------------------
* App Index
*--------------------------------------------------------------------
    lo_app_index =
      /ui5/cl_ui5_app_api_factory=>get_app_index_instance( ).

    lo_service_factory =
      NEW /ui2/cl_service_info_factory( ).

*--------------------------------------------------------------------
* Read UI5 App Index
*--------------------------------------------------------------------
    lo_app_index->get_ui5_app_info(
      EXPORTING
        it_components = lt_components
      IMPORTING
        et_info       = lt_ui5_app_info ).

*--------------------------------------------------------------------
* Resolve Dependencies
*--------------------------------------------------------------------
    LOOP AT lt_ui5_app_info
         ASSIGNING FIELD-SYMBOL(<ls_app>).

      LOOP AT <ls_app>-dependencies
           ASSIGNING FIELD-SYMBOL(<ls_dep>).

        IF <ls_dep>-url CS '/sap/'
           AND <ls_dep>-url NS '/sap/bc/lrep/'.

          lv_url = <ls_dep>-url.

          CLEAR ls_service_std.

          ls_service_std =
            lo_service_factory->get_instance_by_url(
              iv_url = lv_url
            )->get_me_as_service_struct( ).

          lv_service_seqno = lv_service_seqno + 1.

          CLEAR ls_service_v2.

          ls_service_v2-service_seqno = lv_service_seqno.
          ls_service_v2-url_type      = ls_service_std-url_type.
          ls_service_v2-pseudo_url    = ls_service_std-pseudo_url.
          ls_service_v2-service_obj   = ls_service_std-service_obj.

          APPEND ls_service_v2 TO rt_services.

        ENDIF.

        IF <ls_dep>-id CS '/sap/'
           AND <ls_dep>-id NS '/sap/bc/lrep/'.

          lv_url = CONV string( <ls_dep>-id ).

          CLEAR ls_service_std.

          ls_service_std =
            lo_service_factory->get_instance_by_url(
              iv_url = lv_url
            )->get_me_as_service_struct( ).

          lv_service_seqno = lv_service_seqno + 1.

          CLEAR ls_service_v2.

          ls_service_v2-service_seqno = lv_service_seqno.
          ls_service_v2-url_type      = ls_service_std-url_type.
          ls_service_v2-pseudo_url    = ls_service_std-pseudo_url.
          ls_service_v2-service_obj   = ls_service_std-service_obj.

          APPEND ls_service_v2 TO rt_services.

        ENDIF.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_ui5_dependency_details_v2.

    DATA:
      ls_info TYPE ty_dependency_formatter_v2.

    FIELD-SYMBOLS:
      <ls_service> TYPE ty_service_v2.

    LOOP AT it_services ASSIGNING <ls_service>.

      CLEAR ls_info.

*--------------------------------------------------------------------
* Generic Service Interface
*--------------------------------------------------------------------
      DATA(lo_service) = <ls_service>-service_obj.

      CHECK lo_service IS BOUND.

*--------------------------------------------------------------------
* Sequence Number
*--------------------------------------------------------------------
      ls_info-service_seqno =
        <ls_service>-service_seqno.

*--------------------------------------------------------------------
* Type
*--------------------------------------------------------------------
      ls_info-app_type =
        lo_service->get_type( ).

*--------------------------------------------------------------------
* Service Name
*
* Examples:
*   CATALOGSERVICE
*   /IWFND/CATALOGSERVICE
*   C_SALESORDERMANAGE_SD
*   C_SALESORDERMANAGE_SRV   " ODATA V4 Group ID
*--------------------------------------------------------------------
      CASE ls_info-app_type.

        WHEN 'ODATA4'.

          TRY.

              DATA(lo_v4_service) =
                CAST /ui2/if_odata_v4_service_info( lo_service ).

              ls_info-service_name =
                lo_v4_service->get_service_group_id(
                  iv_with_non_sap_namespace = abap_true ).

            CATCH cx_sy_move_cast_error.

              ls_info-service_name =
                lo_service->get_service_id(
                  iv_with_non_sap_namespace = abap_true ).

          ENDTRY.

        WHEN OTHERS.

          ls_info-service_name =
            lo_service->get_service_id(
              iv_with_non_sap_namespace = abap_true ).

      ENDCASE.

*--------------------------------------------------------------------
* Version
*--------------------------------------------------------------------
      ls_info-service_version =
        lo_service->get_service_version( ).

*--------------------------------------------------------------------
* URL
*--------------------------------------------------------------------
      ls_info-url =
        lo_service->get_url( ).

*--------------------------------------------------------------------
* Add Row
*--------------------------------------------------------------------
      APPEND ls_info TO rt_info.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_ui5_multcomp_dep_det_v2.
    DATA lt_services TYPE tt_service_v2.

*--------------------------------------------------------------------
* Resolve dependencies
*--------------------------------------------------------------------
    lt_services =
      get_multicomp_ui5dep_v2(
        it_components = it_components ).

*--------------------------------------------------------------------
* Format dependency details
*--------------------------------------------------------------------
    rt_info =
      get_ui5_dependency_details_v2(
        it_services = lt_services ).

  ENDMETHOD.

ENDCLASS.
