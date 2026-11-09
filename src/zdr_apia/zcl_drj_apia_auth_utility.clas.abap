CLASS zcl_drj_apia_auth_utility DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES ty_api_type        TYPE c LENGTH 30.
    TYPES ty_api_name        TYPE c LENGTH 255.
    TYPES ty_api_version     TYPE c LENGTH 40.
    TYPES ty_text255         TYPE c LENGTH 255.
    TYPES ty_path255         TYPE c LENGTH 255.
    TYPES ty_systemalias     TYPE c LENGTH 120.
    TYPES ty_result_key      TYPE c LENGTH 200.
    TYPES ty_auth_match_type TYPE c LENGTH 30.

    TYPES:
      BEGIN OF ty_api_usage,
        api_name             TYPE ty_api_name,
        api_version          TYPE ty_api_version,
        api_type             TYPE ty_api_type,

        api_description      TYPE ty_text255,

        service_name         TYPE ty_api_name,
        service_version      TYPE ty_api_version,
        service_type         TYPE ty_api_type,

        service_namespace    TYPE ty_text255,
        service_path         TYPE ty_path255,

        system_alias         TYPE ty_systemalias,

        role_count           TYPE i,
        composite_role_count TYPE i,

        iwsg_hash            TYPE ust12-von,
        iwsv_hash            TYPE ust12-von,
        group_id             TYPE /iwfnd/v4_med_group_id,
      END OF ty_api_usage.

    TYPES tt_api_usage TYPE STANDARD TABLE OF ty_api_usage WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_role_usage,
        api_name                 TYPE ty_api_name,
        api_version              TYPE ty_api_version,
        api_type                 TYPE ty_api_type,

        service_name             TYPE ty_api_name,
        service_version          TYPE ty_api_version,
        service_type             TYPE ty_api_type,

        role_name                TYPE agr_name,
        role_description         TYPE ty_text255,

        authorization_count      TYPE i,
        service_count            TYPE i,

        has_wildcard_auth        TYPE abap_bool,
        authorization_match_type TYPE ty_auth_match_type,

        composite_role_count     TYPE i,
      END OF ty_role_usage.

    TYPES tt_role_usage TYPE STANDARD TABLE OF ty_role_usage WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_comp_role_usage,
        api_name                   TYPE ty_api_name,
        api_version                TYPE ty_api_version,
        api_type                   TYPE ty_api_type,

        service_name               TYPE ty_api_name,
        service_version            TYPE ty_api_version,
        service_type               TYPE ty_api_type,

        role_name                  TYPE agr_name,
        composite_role_name        TYPE agr_name,
        composite_role_description TYPE ty_text255,

        roles_contained            TYPE i,
        exclude_own_menu           TYPE c LENGTH 1,
      END OF ty_comp_role_usage.

    TYPES tt_comp_role_usage TYPE STANDARD TABLE OF ty_comp_role_usage WITH EMPTY KEY.

    TYPES tt_agr_name TYPE SORTED TABLE OF agr_name WITH UNIQUE KEY table_line.

    CLASS-METHODS get_api_usages
      IMPORTING
        iv_api_name    TYPE string
        iv_api_version TYPE string OPTIONAL
        iv_api_type    TYPE string OPTIONAL
      RETURNING
        VALUE(rt_api)  TYPE tt_api_usage.

    CLASS-METHODS get_roles_for_api
      IMPORTING
        iv_api_name     TYPE string
        iv_api_version  TYPE string OPTIONAL
        iv_api_type     TYPE string OPTIONAL
      RETURNING
        VALUE(rt_roles) TYPE tt_role_usage.

    CLASS-METHODS get_comp_roles_for_role
      IMPORTING
        iv_role_name       TYPE agr_name
        iv_api_name        TYPE string OPTIONAL
        iv_api_version     TYPE string OPTIONAL
        iv_api_type        TYPE string OPTIONAL
        iv_service_name    TYPE string OPTIONAL
        iv_service_version TYPE string OPTIONAL
        iv_service_type    TYPE string OPTIONAL
      RETURNING
        VALUE(rt_comp_rl)  TYPE tt_comp_role_usage.

    CLASS-METHODS get_comp_roles_for_api
      IMPORTING
        iv_api_name       TYPE string
        iv_api_version    TYPE string OPTIONAL
        iv_api_type       TYPE string OPTIONAL
      RETURNING
        VALUE(rt_comp_rl) TYPE tt_comp_role_usage.

  PRIVATE SECTION.

    CONSTANTS gc_match_exact    TYPE ty_auth_match_type VALUE 'EXACT_MATCH'.
    CONSTANTS gc_match_iwsg     TYPE ty_auth_match_type VALUE 'IWSG'.
    CONSTANTS gc_match_iwsv     TYPE ty_auth_match_type VALUE 'IWSV'.
    CONSTANTS gc_match_wildcard TYPE ty_auth_match_type VALUE 'WILD_CARD'.

    TYPES:
      BEGIN OF ty_role_match,
        role_name                TYPE agr_name,
        has_wildcard_auth        TYPE abap_bool,
        authorization_match_type TYPE ty_auth_match_type,
        authorization_count      TYPE i,
      END OF ty_role_match.

    TYPES tt_role_match TYPE STANDARD TABLE OF ty_role_match WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_auth_value_match,
        found             TYPE abap_bool,
        has_wildcard_auth TYPE abap_bool,
      END OF ty_auth_value_match.

    TYPES:
      BEGIN OF ty_role_auth_value,
        agr_name TYPE agr_name,
        auth     TYPE agr_1251-auth,
        low      TYPE agr_1251-low,
      END OF ty_role_auth_value.

    TYPES tt_role_auth_value TYPE STANDARD TABLE OF ty_role_auth_value WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_v2_name,
        namespace    TYPE /iwfnd/med_mdl_namespace,
        service_name TYPE /iwfnd/med_mdl_service_grp_id,
      END OF ty_v2_name.

    CLASS-METHODS normalize_api_type
      IMPORTING
        iv_api_type        TYPE string
      RETURNING
        VALUE(rv_api_type) TYPE ty_api_type.

    CLASS-METHODS split_v2_api_name
      IMPORTING
        iv_api_name       TYPE string
      RETURNING
        VALUE(rs_v2_name) TYPE ty_v2_name.

    CLASS-METHODS build_full_v2_name
      IMPORTING
        is_srh         TYPE /iwfnd/i_med_srh
      RETURNING
        VALUE(rv_name) TYPE string.

    CLASS-METHODS build_v2_path
      IMPORTING
        is_srh         TYPE /iwfnd/i_med_srh
      RETURNING
        VALUE(rv_path) TYPE string.

    CLASS-METHODS get_usobhash_name
      IMPORTING
        iv_object      TYPE usobhash-object
        iv_obj_name    TYPE usobhash-obj_name
      RETURNING
        VALUE(rv_hash) TYPE ust12-von.

    CLASS-METHODS get_v2_iwsg_hash
      IMPORTING
        is_srh         TYPE /iwfnd/i_med_srh
      RETURNING
        VALUE(rv_hash) TYPE ust12-von.

    CLASS-METHODS get_v2_iwsv_hash
      IMPORTING
        is_srh         TYPE /iwfnd/i_med_srh
      RETURNING
        VALUE(rv_hash) TYPE ust12-von.

    CLASS-METHODS get_role_description
      IMPORTING
        iv_role        TYPE agr_name
      RETURNING
        VALUE(rv_text) TYPE ty_text255.

    CLASS-METHODS get_composite_roles
      IMPORTING
        iv_role         TYPE agr_name
      RETURNING
        VALUE(rt_roles) TYPE tt_agr_name.

    CLASS-METHODS count_composite_roles
      IMPORTING
        iv_role         TYPE agr_name
      RETURNING
        VALUE(rv_count) TYPE i.

    CLASS-METHODS count_unique_composites
      IMPORTING
        it_roles        TYPE tt_agr_name
      RETURNING
        VALUE(rv_count) TYPE i.

    CLASS-METHODS count_roles_contained
      IMPORTING
        iv_comp_role    TYPE agr_name
      RETURNING
        VALUE(rv_count) TYPE i.

    CLASS-METHODS get_role_matches_for_s_service
      IMPORTING
        iv_hash         TYPE ust12-von
      RETURNING
        VALUE(rt_roles) TYPE tt_role_match.

    CLASS-METHODS get_role_matches_for_v2_hashes
      IMPORTING
        iv_iwsg_hash    TYPE ust12-von
        iv_iwsv_hash    TYPE ust12-von
      RETURNING
        VALUE(rt_roles) TYPE tt_role_match.

    CLASS-METHODS get_auth_value_match
      IMPORTING
        iv_role         TYPE agr_name
        iv_auth         TYPE agr_1251-auth
        iv_object       TYPE agr_1251-object
        iv_field        TYPE agr_1251-field
        iv_value        TYPE string
      RETURNING
        VALUE(rs_match) TYPE ty_auth_value_match.

    CLASS-METHODS get_role_matches_for_v4_group
      IMPORTING
        iv_group_id     TYPE /iwfnd/v4_med_group_id
      RETURNING
        VALUE(rt_roles) TYPE tt_role_match.

ENDCLASS.


CLASS zcl_drj_apia_auth_utility IMPLEMENTATION.

  METHOD normalize_api_type.

    DATA(lv_type) = to_upper( condense( iv_api_type ) ).

    CASE lv_type.
      WHEN 'V2' OR 'ODATA_V2' OR 'ODATA'.
        rv_api_type = 'V2'.

      WHEN 'V4' OR 'ODATA_V4' OR 'ODATA4'.
        rv_api_type = 'V4'.

      WHEN OTHERS.
        rv_api_type = lv_type.
    ENDCASE.

  ENDMETHOD.


  METHOD split_v2_api_name.

    DATA lt_parts TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    DATA(lv_api_name) = condense( iv_api_name ).

    CLEAR rs_v2_name.

    IF lv_api_name CP '/*/*'.

      SPLIT lv_api_name AT '/' INTO TABLE lt_parts.

      IF lines( lt_parts ) >= 3.

        rs_v2_name-namespace =
          '/' &&
          lt_parts[ 2 ] &&
          '/'.

        rs_v2_name-service_name =
          lt_parts[ 3 ].

      ENDIF.

    ELSE.

      rs_v2_name-service_name =
        CONV /iwfnd/med_mdl_service_grp_id( lv_api_name ).

    ENDIF.

  ENDMETHOD.


  METHOD build_full_v2_name.

    rv_name =
      is_srh-namespace &&
      is_srh-service_name.

  ENDMETHOD.


  METHOD build_v2_path.

    IF is_srh-namespace IS INITIAL.

      rv_path =
        |/sap/opu/odata/sap/{ is_srh-service_name }|.

    ELSE.

      rv_path =
        |/sap/opu/odata{ is_srh-namespace }{ is_srh-service_name }|.

    ENDIF.

  ENDMETHOD.


  METHOD get_usobhash_name.

    CLEAR rv_hash.

    SELECT SINGLE name
      FROM usobhash
      INTO @DATA(lv_hash)
      WHERE object   = @iv_object
        AND obj_name = @iv_obj_name.

    IF sy-subrc = 0.
      rv_hash = CONV ust12-von( lv_hash ).
    ENDIF.

  ENDMETHOD.


  METHOD get_v2_iwsg_hash.

    rv_hash =
      get_usobhash_name(
        iv_object   = 'IWSG'
        iv_obj_name = CONV usobhash-obj_name( is_srh-srv_identifier ) ).

  ENDMETHOD.


  METHOD get_v2_iwsv_hash.

    DATA lv_iwsv_name TYPE usobhash-obj_name.
    DATA lv_version   TYPE char4.

    CLEAR rv_hash.

    lv_iwsv_name =
      is_srh-namespace &&
      is_srh-service_name.

    lv_version =
      |{ is_srh-service_version WIDTH = 4 PAD = '0' }|.

    lv_iwsv_name+35(4) = lv_version.

    rv_hash =
      get_usobhash_name(
        iv_object   = 'IWSV'
        iv_obj_name = lv_iwsv_name ).

  ENDMETHOD.


  METHOD get_role_description.

    CLEAR rv_text.

    SELECT SINGLE text
      FROM agr_texts
      INTO @DATA(lv_text)
      WHERE agr_name = @iv_role
        AND spras    = @sy-langu.

    IF sy-subrc <> 0.

      SELECT SINGLE text
        FROM agr_texts
        INTO @lv_text
        WHERE agr_name = @iv_role.

    ENDIF.

    rv_text = CONV #( lv_text ).

  ENDMETHOD.


  METHOD get_composite_roles.

    CLEAR rt_roles.

    SELECT DISTINCT agr_name
      FROM agr_agrs
      INTO TABLE @rt_roles
      WHERE child_agr = @iv_role.

  ENDMETHOD.


  METHOD count_composite_roles.

    DATA lt_composites TYPE tt_agr_name.

    lt_composites =
      get_composite_roles(
        iv_role = iv_role ).

    rv_count = lines( lt_composites ).

  ENDMETHOD.


  METHOD count_unique_composites.

    DATA lt_unique TYPE tt_agr_name.

    CLEAR rv_count.

    LOOP AT it_roles ASSIGNING FIELD-SYMBOL(<lv_role>).

      DATA(lt_comp) =
        get_composite_roles(
          iv_role = <lv_role> ).

      LOOP AT lt_comp ASSIGNING FIELD-SYMBOL(<lv_comp>).
        INSERT <lv_comp> INTO TABLE lt_unique.
      ENDLOOP.

    ENDLOOP.

    rv_count = lines( lt_unique ).

  ENDMETHOD.


  METHOD count_roles_contained.

    CLEAR rv_count.

    SELECT COUNT( * )
      FROM agr_agrs
      INTO @rv_count
      WHERE agr_name = @iv_comp_role.

  ENDMETHOD.


  METHOD get_role_matches_for_s_service.

    DATA lt_exact TYPE SORTED TABLE OF agr_name WITH UNIQUE KEY table_line.
    DATA lt_wild  TYPE SORTED TABLE OF agr_name WITH UNIQUE KEY table_line.

    CLEAR rt_roles.

    IF iv_hash IS INITIAL.
      RETURN.
    ENDIF.

*--------------------------------------------------------------------
*   Exact S_SERVICE / SRV_NAME match
*--------------------------------------------------------------------
    SELECT DISTINCT agr_name
      FROM agr_1251
      INTO TABLE @lt_exact
      WHERE object  = 'S_SERVICE'
        AND field   = 'SRV_NAME'
        AND deleted <> 'X'
        AND low     = @iv_hash.

    LOOP AT lt_exact ASSIGNING FIELD-SYMBOL(<lv_exact_role>).

      INSERT VALUE ty_role_match(
        role_name                = <lv_exact_role>
        has_wildcard_auth        = abap_false
        authorization_match_type = gc_match_exact
        authorization_count      = 1
      ) INTO TABLE rt_roles.

    ENDLOOP.

*--------------------------------------------------------------------
*   Wildcard S_SERVICE / SRV_NAME match
*   WILD_CARD wins if the role has both exact and wildcard.
*--------------------------------------------------------------------
    SELECT DISTINCT agr_name
      FROM agr_1251
      INTO TABLE @lt_wild
      WHERE object  = 'S_SERVICE'
        AND field   = 'SRV_NAME'
        AND deleted <> 'X'
        AND low     = '*'.

    LOOP AT lt_wild ASSIGNING FIELD-SYMBOL(<lv_wild_role>).

      READ TABLE rt_roles ASSIGNING FIELD-SYMBOL(<ls_existing>)
        WITH KEY role_name = <lv_wild_role>.

      IF sy-subrc = 0.

        <ls_existing>-has_wildcard_auth        = abap_true.
        <ls_existing>-authorization_match_type = gc_match_wildcard.
        <ls_existing>-authorization_count      = 1.

      ELSE.

        INSERT VALUE ty_role_match(
          role_name                = <lv_wild_role>
          has_wildcard_auth        = abap_true
          authorization_match_type = gc_match_wildcard
          authorization_count      = 1
        ) INTO TABLE rt_roles.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_role_matches_for_v2_hashes.

    DATA lt_iwsg_roles TYPE tt_role_match.
    DATA lt_iwsv_roles TYPE tt_role_match.

    DATA lt_all_roles TYPE SORTED TABLE OF agr_name WITH UNIQUE KEY table_line.

    CLEAR rt_roles.

    lt_iwsg_roles =
      get_role_matches_for_s_service(
        iv_hash = iv_iwsg_hash ).

    lt_iwsv_roles =
      get_role_matches_for_s_service(
        iv_hash = iv_iwsv_hash ).

*--------------------------------------------------------------------
*   Union of IWSG and IWSV candidates.
*   This lets us show partial roles too.
*--------------------------------------------------------------------
    LOOP AT lt_iwsg_roles ASSIGNING FIELD-SYMBOL(<ls_iwsg_u>).
      INSERT <ls_iwsg_u>-role_name INTO TABLE lt_all_roles.
    ENDLOOP.

    LOOP AT lt_iwsv_roles ASSIGNING FIELD-SYMBOL(<ls_iwsv_u>).
      INSERT <ls_iwsv_u>-role_name INTO TABLE lt_all_roles.
    ENDLOOP.

*--------------------------------------------------------------------
*   V2 classification:
*   EXACT_MATCH = exact IWSG + exact IWSV
*   IWSG        = IWSG exists but IWSV missing
*   IWSV        = IWSV exists but IWSG missing
*   WILD_CARD   = both are satisfied, but wildcard is involved
*--------------------------------------------------------------------
    LOOP AT lt_all_roles ASSIGNING FIELD-SYMBOL(<lv_role>).

      READ TABLE lt_iwsg_roles ASSIGNING FIELD-SYMBOL(<ls_iwsg>)
        WITH KEY role_name = <lv_role>.

      DATA(lv_has_iwsg) = xsdbool( sy-subrc = 0 ).
      DATA(lv_iwsg_wildcard) = abap_false.

      IF lv_has_iwsg = abap_true.
        lv_iwsg_wildcard = <ls_iwsg>-has_wildcard_auth.
      ENDIF.

      READ TABLE lt_iwsv_roles ASSIGNING FIELD-SYMBOL(<ls_iwsv>)
        WITH KEY role_name = <lv_role>.

      DATA(lv_has_iwsv) = xsdbool( sy-subrc = 0 ).
      DATA(lv_iwsv_wildcard) = abap_false.

      IF lv_has_iwsv = abap_true.
        lv_iwsv_wildcard = <ls_iwsv>-has_wildcard_auth.
      ENDIF.

      DATA lv_match_type TYPE ty_auth_match_type.
      DATA(lv_has_wildcard) = abap_false.
      DATA(lv_auth_count) = 0.

      IF lv_has_iwsg = abap_true AND lv_has_iwsv = abap_true.

        lv_auth_count = 2.

        IF lv_iwsg_wildcard = abap_true
        OR lv_iwsv_wildcard = abap_true.

          lv_match_type   = gc_match_wildcard.
          lv_has_wildcard = abap_true.

        ELSE.

          lv_match_type   = gc_match_exact.
          lv_has_wildcard = abap_false.

        ENDIF.

      ELSEIF lv_has_iwsg = abap_true AND lv_has_iwsv = abap_false.

        lv_auth_count    = 1.
        lv_match_type    = gc_match_iwsg.
        lv_has_wildcard  = abap_false.

      ELSEIF lv_has_iwsg = abap_false AND lv_has_iwsv = abap_true.

        lv_auth_count    = 1.
        lv_match_type    = gc_match_iwsv.
        lv_has_wildcard  = abap_false.

      ENDIF.

      INSERT VALUE ty_role_match(
        role_name                = <lv_role>
        has_wildcard_auth        = lv_has_wildcard
        authorization_match_type = lv_match_type
        authorization_count      = lv_auth_count
      ) INTO TABLE rt_roles.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_auth_value_match.

    CLEAR rs_match.

*--------------------------------------------------------------------
*   Wildcard wins. If the same role/auth has wildcard, expose it.
*--------------------------------------------------------------------
    SELECT SINGLE low
      FROM agr_1251
      INTO @DATA(lv_low)
      WHERE agr_name = @iv_role
        AND auth     = @iv_auth
        AND object   = @iv_object
        AND field    = @iv_field
        AND deleted <> 'X'
        AND low      = '*'.

    IF sy-subrc = 0.
      rs_match-found             = abap_true.
      rs_match-has_wildcard_auth = abap_true.
      RETURN.
    ENDIF.

*--------------------------------------------------------------------
*   Exact fallback
*--------------------------------------------------------------------
    SELECT SINGLE low
      FROM agr_1251
      INTO @lv_low
      WHERE agr_name = @iv_role
        AND auth     = @iv_auth
        AND object   = @iv_object
        AND field    = @iv_field
        AND deleted <> 'X'
        AND low      = @iv_value.

    IF sy-subrc = 0.
      rs_match-found             = abap_true.
      rs_match-has_wildcard_auth = abap_false.
    ENDIF.

  ENDMETHOD.


  METHOD get_role_matches_for_v4_group.

    DATA lt_auth TYPE tt_role_auth_value.

    CLEAR rt_roles.

    IF iv_group_id IS INITIAL.
      RETURN.
    ENDIF.

*--------------------------------------------------------------------
*   Candidate S_START authorizations by AUTHOBJNAM
*--------------------------------------------------------------------
    SELECT DISTINCT agr_name, auth, low
      FROM agr_1251
      INTO TABLE @lt_auth
      WHERE object  = 'S_START'
        AND field   = 'AUTHOBJNAM'
        AND deleted <> 'X'
        AND ( low   = @iv_group_id OR low = '*' ).

    LOOP AT lt_auth ASSIGNING FIELD-SYMBOL(<ls_auth>).

      DATA(ls_pgmid_match) =
        get_auth_value_match(
          iv_role   = <ls_auth>-agr_name
          iv_auth   = <ls_auth>-auth
          iv_object = 'S_START'
          iv_field  = 'AUTHPGMID'
          iv_value  = 'R3TR' ).

      IF ls_pgmid_match-found = abap_false.
        CONTINUE.
      ENDIF.

      DATA(ls_objtyp_match) =
        get_auth_value_match(
          iv_role   = <ls_auth>-agr_name
          iv_auth   = <ls_auth>-auth
          iv_object = 'S_START'
          iv_field  = 'AUTHOBJTYP'
          iv_value  = 'G4BA' ).

      IF ls_objtyp_match-found = abap_false.
        CONTINUE.
      ENDIF.

      DATA(lv_has_wildcard_auth) =
        xsdbool(
             <ls_auth>-low = '*'
          OR ls_pgmid_match-has_wildcard_auth = abap_true
          OR ls_objtyp_match-has_wildcard_auth = abap_true ).

      DATA lv_match_type TYPE ty_auth_match_type.

      IF lv_has_wildcard_auth = abap_true.
        lv_match_type = gc_match_wildcard.
      ELSE.
        lv_match_type = gc_match_exact.
      ENDIF.

*--------------------------------------------------------------------
*     If role appears multiple times, WILD_CARD wins.
*--------------------------------------------------------------------
      READ TABLE rt_roles ASSIGNING FIELD-SYMBOL(<ls_existing>)
        WITH KEY role_name = <ls_auth>-agr_name.

      IF sy-subrc = 0.

        IF lv_has_wildcard_auth = abap_true.
          <ls_existing>-has_wildcard_auth        = abap_true.
          <ls_existing>-authorization_match_type = gc_match_wildcard.
          <ls_existing>-authorization_count      = 1.
        ENDIF.

      ELSE.

        INSERT VALUE ty_role_match(
          role_name                = <ls_auth>-agr_name
          has_wildcard_auth        = lv_has_wildcard_auth
          authorization_match_type = lv_match_type
          authorization_count      = 1
        ) INTO TABLE rt_roles.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_api_usages.

    DATA lv_api_type TYPE c LENGTH 30.
    DATA ls_v2_name  TYPE ty_v2_name.
    DATA lt_srh      TYPE STANDARD TABLE OF /iwfnd/i_med_srh WITH EMPTY KEY.
    DATA lt_roles    TYPE tt_agr_name.

    CLEAR rt_api.

    IF iv_api_name IS INITIAL.
      RETURN.
    ENDIF.

    lv_api_type = normalize_api_type( iv_api_type ).

*--------------------------------------------------------------------
*   OData V2
*--------------------------------------------------------------------
    IF lv_api_type IS INITIAL OR lv_api_type = 'V2'.

      ls_v2_name =
        split_v2_api_name(
          iv_api_name = iv_api_name ).

      IF ls_v2_name-service_name IS NOT INITIAL.

        IF iv_api_version IS INITIAL.

          IF ls_v2_name-namespace IS INITIAL.

            SELECT *
              FROM /iwfnd/i_med_srh
              INTO TABLE @lt_srh
              WHERE service_name = @ls_v2_name-service_name.

          ELSE.

            SELECT *
              FROM /iwfnd/i_med_srh
              INTO TABLE @lt_srh
              WHERE namespace    = @ls_v2_name-namespace
                AND service_name = @ls_v2_name-service_name.

          ENDIF.

        ELSE.

          DATA(lv_v2_version) =
            CONV /iwfnd/med_mdl_version( iv_api_version ).

          IF ls_v2_name-namespace IS INITIAL.

            SELECT *
              FROM /iwfnd/i_med_srh
              INTO TABLE @lt_srh
              WHERE service_name    = @ls_v2_name-service_name
                AND service_version = @lv_v2_version.

          ELSE.

            SELECT *
              FROM /iwfnd/i_med_srh
              INTO TABLE @lt_srh
              WHERE namespace       = @ls_v2_name-namespace
                AND service_name    = @ls_v2_name-service_name
                AND service_version = @lv_v2_version.

          ENDIF.

        ENDIF.

        SORT lt_srh BY namespace service_name service_version.

        LOOP AT lt_srh ASSIGNING FIELD-SYMBOL(<ls_srh>).

          DATA(lv_iwsg_hash) =
            get_v2_iwsg_hash(
              is_srh = <ls_srh> ).

          DATA(lv_iwsv_hash) =
            get_v2_iwsv_hash(
              is_srh = <ls_srh> ).

          DATA(lt_role_matches_v2) =
            get_role_matches_for_v2_hashes(
              iv_iwsg_hash = lv_iwsg_hash
              iv_iwsv_hash = lv_iwsv_hash ).

          CLEAR lt_roles.

          LOOP AT lt_role_matches_v2 ASSIGNING FIELD-SYMBOL(<ls_role_match_v2>).
            INSERT <ls_role_match_v2>-role_name INTO TABLE lt_roles.
          ENDLOOP.

          APPEND VALUE ty_api_usage(
            api_name             = build_full_v2_name( <ls_srh> )
            api_version          = |{ <ls_srh>-service_version WIDTH = 4 PAD = '0' }|
            api_type             = 'V2'

            api_description      = ''

            service_name         = build_full_v2_name( <ls_srh> )
            service_version      = |{ <ls_srh>-service_version WIDTH = 4 PAD = '0' }|
            service_type         = 'ODATA'

            service_namespace    = CONV #( <ls_srh>-namespace )
            service_path         = build_v2_path( <ls_srh> )

            system_alias         = ''

            role_count           = lines( lt_role_matches_v2 )
            composite_role_count = count_unique_composites( lt_roles )

            iwsg_hash            = lv_iwsg_hash
            iwsv_hash            = lv_iwsv_hash
          ) TO rt_api.

        ENDLOOP.

      ENDIF.

    ENDIF.

*--------------------------------------------------------------------
*   OData V4
*--------------------------------------------------------------------
    IF lv_api_type IS INITIAL OR lv_api_type = 'V4'.

      DATA(lv_group_id) =
        CONV /iwfnd/v4_med_group_id( condense( iv_api_name ) ).

      SELECT SINGLE group_id
        FROM /iwfnd/c_v4_msgr
        INTO @DATA(lv_found_group_id)
        WHERE group_id = @lv_group_id.

      IF sy-subrc = 0.

        DATA(lt_role_matches_v4) =
          get_role_matches_for_v4_group(
            iv_group_id = lv_found_group_id ).

        CLEAR lt_roles.

        LOOP AT lt_role_matches_v4 ASSIGNING FIELD-SYMBOL(<ls_role_match_v4>).
          INSERT <ls_role_match_v4>-role_name INTO TABLE lt_roles.
        ENDLOOP.

        APPEND VALUE ty_api_usage(
          api_name             = CONV #( lv_found_group_id )
          api_version          = ''
          api_type             = 'V4'

          api_description      = ''

          service_name         = CONV #( lv_found_group_id )
          service_version      = ''
          service_type         = 'ODATA'

          service_namespace    = ''
          service_path         = |/sap/opu/odata4{ lv_found_group_id }|

          system_alias         = ''

          role_count           = lines( lt_role_matches_v4 )
          composite_role_count = count_unique_composites( lt_roles )

          group_id             = lv_found_group_id
        ) TO rt_api.

      ENDIF.

    ENDIF.

  ENDMETHOD.


  METHOD get_roles_for_api.

    DATA lt_api          TYPE tt_api_usage.
    DATA lt_role_matches TYPE tt_role_match.

    CLEAR rt_roles.

    lt_api =
      get_api_usages(
        iv_api_name    = iv_api_name
        iv_api_version = iv_api_version
        iv_api_type    = iv_api_type ).

    LOOP AT lt_api ASSIGNING FIELD-SYMBOL(<ls_api>).

      CLEAR lt_role_matches.

      CASE <ls_api>-api_type.

        WHEN 'V2'.

          lt_role_matches =
            get_role_matches_for_v2_hashes(
              iv_iwsg_hash = <ls_api>-iwsg_hash
              iv_iwsv_hash = <ls_api>-iwsv_hash ).

        WHEN 'V4'.

          lt_role_matches =
            get_role_matches_for_v4_group(
              iv_group_id = <ls_api>-group_id ).

      ENDCASE.

      SORT lt_role_matches BY authorization_match_type ASCENDING role_name ASCENDING.

      LOOP AT lt_role_matches ASSIGNING FIELD-SYMBOL(<ls_role_match>).

        APPEND VALUE ty_role_usage(
          api_name                 = <ls_api>-api_name
          api_version              = <ls_api>-api_version
          api_type                 = <ls_api>-api_type

          service_name             = <ls_api>-service_name
          service_version          = <ls_api>-service_version
          service_type             = <ls_api>-service_type

          role_name                = <ls_role_match>-role_name
          role_description         = get_role_description( <ls_role_match>-role_name )

          authorization_count      = <ls_role_match>-authorization_count
          service_count            = 1

          has_wildcard_auth        = <ls_role_match>-has_wildcard_auth
          authorization_match_type = <ls_role_match>-authorization_match_type

          composite_role_count     = count_composite_roles( <ls_role_match>-role_name )
        ) TO rt_roles.

      ENDLOOP.

    ENDLOOP.

    SORT rt_roles BY authorization_match_type ASCENDING role_name ASCENDING.

  ENDMETHOD.


  METHOD get_comp_roles_for_role.

    CLEAR rt_comp_rl.

    IF iv_role_name IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_comp_roles) =
      get_composite_roles(
        iv_role = iv_role_name ).

    LOOP AT lt_comp_roles ASSIGNING FIELD-SYMBOL(<lv_comp_role>).

      APPEND VALUE ty_comp_role_usage(
        api_name                   = CONV #( iv_api_name )
        api_version                = CONV #( iv_api_version )
        api_type                   = CONV #( iv_api_type )

        service_name               = CONV #( iv_service_name )
        service_version            = CONV #( iv_service_version )
        service_type               = CONV #( iv_service_type )

        role_name                  = iv_role_name
        composite_role_name        = <lv_comp_role>
        composite_role_description = get_role_description( <lv_comp_role> )

        roles_contained            = count_roles_contained( <lv_comp_role> )
        exclude_own_menu           = ''
      ) TO rt_comp_rl.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_comp_roles_for_api.

    DATA lt_role_usage TYPE tt_role_usage.

    CLEAR rt_comp_rl.

    lt_role_usage =
      get_roles_for_api(
        iv_api_name    = iv_api_name
        iv_api_version = iv_api_version
        iv_api_type    = iv_api_type ).

    LOOP AT lt_role_usage ASSIGNING FIELD-SYMBOL(<ls_role_usage>).

      DATA(lt_comp_roles) =
        get_composite_roles(
          iv_role = <ls_role_usage>-role_name ).

      LOOP AT lt_comp_roles ASSIGNING FIELD-SYMBOL(<lv_comp_role>).

        APPEND VALUE ty_comp_role_usage(
          api_name                   = <ls_role_usage>-api_name
          api_version                = <ls_role_usage>-api_version
          api_type                   = <ls_role_usage>-api_type

          service_name               = <ls_role_usage>-service_name
          service_version            = <ls_role_usage>-service_version
          service_type               = <ls_role_usage>-service_type

          role_name                  = <ls_role_usage>-role_name
          composite_role_name        = <lv_comp_role>
          composite_role_description = get_role_description( <lv_comp_role> )

          roles_contained            = count_roles_contained( <lv_comp_role> )
          exclude_own_menu           = ''
        ) TO rt_comp_rl.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
