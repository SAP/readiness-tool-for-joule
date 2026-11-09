CLASS zcl_drj_cdm_analysis_util DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    " Same underlying type as the ID field of a CDM entity
    TYPES ty_role_id TYPE /ui2/if_cdm3=>ts_cdm_3_entity-id.

    " Sorted and duplicate-free list of CDM role IDs
    TYPES tt_role_id TYPE SORTED TABLE OF ty_role_id
                     WITH UNIQUE KEY table_line.

    " Return roles exposed through CDM V1
    CLASS-METHODS get_cdm_v1_roles
      IMPORTING
        iv_commit TYPE /ui2/content_hash OPTIONAL
      EXPORTING
        et_roles  TYPE tt_role_id
        ev_commit TYPE /ui2/content_hash
      RAISING
        /ui2/cx_ra_repo_exception.

    " Return roles exposed through CDM V2
    CLASS-METHODS get_cdm_v2_roles
      IMPORTING
        iv_commit TYPE /ui2/content_hash OPTIONAL
      EXPORTING
        et_roles  TYPE tt_role_id
        ev_commit TYPE /ui2/content_hash
      RAISING
        /ui2/cx_ra_repo_exception.

  PRIVATE SECTION.

    " Shared implementation for both CDM exposure versions
    CLASS-METHODS get_cdm_roles_from_repository
      IMPORTING
        iv_repository_name TYPE /ui2/ra_repository_name
        iv_commit          TYPE /ui2/content_hash OPTIONAL
      EXPORTING
        et_roles           TYPE tt_role_id
        ev_commit          TYPE /ui2/content_hash
      RAISING
        /ui2/cx_ra_repo_exception.

ENDCLASS.



CLASS zcl_drj_cdm_analysis_util IMPLEMENTATION.

  METHOD get_cdm_v1_roles.

    get_cdm_roles_from_repository(
      EXPORTING
        iv_repository_name = /ui2/if_cdm3_exposure_api=>gc_repository
        iv_commit          = iv_commit
      IMPORTING
        et_roles           = et_roles
        ev_commit          = ev_commit
    ).

  ENDMETHOD.


  METHOD get_cdm_v2_roles.

    get_cdm_roles_from_repository(
      EXPORTING
        iv_repository_name = /ui2/if_cdm3_exposure_api=>gc_repository_v2
        iv_commit          = iv_commit
      IMPORTING
        et_roles           = et_roles
        ev_commit          = ev_commit
    ).

  ENDMETHOD.


  METHOD get_cdm_roles_from_repository.

    CLEAR:
      et_roles,
      ev_commit.

    " Repository access should respect the current user's authorisations
    DATA(lo_logger) = NEW /ui2/cl_logger_dummy( ).

    DATA(lo_ra_api) = NEW /ui2/cl_ra_repo_api(
      iv_logger                      = lo_logger
      iv_repository                  = iv_repository_name
      iv_skip_auth_check             = abap_false
      iv_suppress_content_token_file = abap_true
    ).

    " Use an explicitly supplied commit or the current checkout commit
    DATA(lv_commit) = iv_commit.

    IF lv_commit IS INITIAL.
      lv_commit = lo_ra_api->db_access->get_checkout_commit( ).
    ENDIF.

    ev_commit = lv_commit.

    " Read the root tree belonging to the selected commit
    DATA(lv_root_tree_hash) = lo_ra_api->db_access->read_commit( lv_commit ).

    DATA(lt_fullcommit_content) =
      lo_ra_api->db_access->read_tree_node(
        iv_hash = lv_root_tree_hash
      ).

    " Locate only the CDM role folder.
    "
    " Do not hard-code the role-folder hash because it can change
    " whenever the repository content is republished.
    READ TABLE lt_fullcommit_content
      ASSIGNING FIELD-SYMBOL(<ls_role_folder>)
      WITH KEY
        name = /ui2/if_cdm3=>gc_entity_type-role
        type = lo_ra_api->db_access->gc_content_types-tree.

    IF sy-subrc <> 0.
      " Repository exists but no role folder is available
      RETURN.
    ENDIF.

    " Read only the role tree
    DATA(lt_role_content) =
      lo_ra_api->db_access->read_tree_node(
        iv_hash = <ls_role_folder>-hash
      ).

    DATA:
      lv_role_id TYPE ty_role_id,
      lv_dummy   TYPE string.

    LOOP AT lt_role_content
      ASSIGNING FIELD-SYMBOL(<ls_role_entry>).

      CLEAR:
        lv_role_id,
        lv_dummy.

      " Repository filename:
      " SAP_BR_AP_ACCOUNTANT.json
      "
      " Returned role ID:
      " SAP_BR_AP_ACCOUNTANT
      SPLIT <ls_role_entry>-name
        AT '.json'
        INTO lv_role_id lv_dummy.

      IF lv_role_id IS NOT INITIAL.
        INSERT lv_role_id INTO TABLE et_roles.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
