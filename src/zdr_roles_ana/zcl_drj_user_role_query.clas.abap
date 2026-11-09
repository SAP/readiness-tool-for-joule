CLASS zcl_drj_user_role_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_drj_user_role_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

*--------------------------------------------------------------------
* Local assignment structure
*--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_assignment,
        agr_name  TYPE agr_users-agr_name,
        uname     TYPE agr_users-uname,
        from_dat  TYPE agr_users-from_dat,
        to_dat    TYPE agr_users-to_dat,
        exclude   TYPE agr_users-exclude,
        org_flag  TYPE agr_users-org_flag,
        col_flag  TYPE agr_users-col_flag,
        role_text TYPE agr_texts-text,
      END OF ty_assignment.

    TYPES tt_assignment TYPE STANDARD TABLE OF ty_assignment
      WITH EMPTY KEY.

*--------------------------------------------------------------------
* Local data
*--------------------------------------------------------------------
    DATA lv_user TYPE syuname.

    DATA lt_assignment TYPE tt_assignment.

    DATA lt_result TYPE STANDARD TABLE OF zr_drj_userrole
      WITH EMPTY KEY.

    DATA lt_page TYPE STANDARD TABLE OF zr_drj_userrole
      WITH EMPTY KEY.

*--------------------------------------------------------------------
* Read paging before any possible early return
*
* RAP expects the requested paging feature to be handled even when
* the query produces no records.
*--------------------------------------------------------------------
    DATA(lo_paging) =
      io_request->get_paging( ).

    DATA(lv_offset) =
      lo_paging->get_offset( ).

    DATA(lv_page_size) =
      lo_paging->get_page_size( ).

*--------------------------------------------------------------------
* Default to logged-on user
*--------------------------------------------------------------------
    lv_user = sy-uname.

*--------------------------------------------------------------------
* Read optional USERNAME filter
*
* Supported:
*   UserName eq 'TESTUSER'
*
* No USERNAME filter:
*   SY-UNAME is used
*--------------------------------------------------------------------
    TRY.

        DATA(lt_filter_ranges) =
          io_request->get_filter( )->get_as_ranges( ).

        READ TABLE lt_filter_ranges
          WITH KEY name = 'USERNAME'
          INTO DATA(ls_user_filter).

        IF sy-subrc = 0
           AND lines( ls_user_filter-range ) = 1.

          READ TABLE ls_user_filter-range
            INDEX 1
            INTO DATA(ls_user_range).

          IF sy-subrc = 0
             AND ls_user_range-sign = 'I'
             AND ls_user_range-option = 'EQ'
             AND ls_user_range-low IS NOT INITIAL.

            lv_user = ls_user_range-low.

          ENDIF.

        ENDIF.

      CATCH cx_rap_query_filter_no_range.

        "No compatible USERNAME range was supplied.
        "Continue with SY-UNAME.

    ENDTRY.

    TRANSLATE lv_user TO UPPER CASE.

*--------------------------------------------------------------------
* Read effective roles through the shared utility
*--------------------------------------------------------------------
    DATA(lt_roles) = zcl_drj_flp_start_up_utility=>get_fiori_roles_of_user( iv_user = lv_user ).

    SORT lt_roles BY table_line.

    DELETE ADJACENT DUPLICATES FROM lt_roles
      COMPARING table_line.

*--------------------------------------------------------------------
* Nothing assigned
*
* This includes:
*   - username does not exist
*   - username exists but has no roles
*
* In both cases, return zero records.
*--------------------------------------------------------------------
    IF lt_roles IS INITIAL.

      IF io_request->is_total_numb_of_rec_requested( ).

        io_response->set_total_number_of_records( 0 ).

      ENDIF.

      IF io_request->is_data_requested( ).

        io_response->set_data( lt_result ).

      ENDIF.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Read only assignments active today
*
* An assignment is active when:
*   FROM_DAT <= today
*   TO_DAT   >= today
*--------------------------------------------------------------------
    SELECT FROM agr_users AS user_assignment

      LEFT OUTER JOIN agr_texts AS role_text
        ON  role_text~agr_name = user_assignment~agr_name
        AND role_text~spras    = @sy-langu
        AND role_text~line     = '00000'

      FIELDS
        user_assignment~agr_name,
        user_assignment~uname,
        user_assignment~from_dat,
        user_assignment~to_dat,
        user_assignment~exclude,
        user_assignment~org_flag,
        user_assignment~col_flag,
        role_text~text AS role_text

      FOR ALL ENTRIES IN @lt_roles

      WHERE user_assignment~uname    = @lv_user
        AND user_assignment~agr_name = @lt_roles-table_line
        AND user_assignment~from_dat <= @sy-datum
        AND user_assignment~to_dat   >= @sy-datum

      INTO CORRESPONDING FIELDS OF TABLE @lt_assignment.

*--------------------------------------------------------------------
* Several active assignments can exist for the same role.
*
* Selection rule:
*   1. Most recent active FROM_DAT
*   2. Furthest TO_DAT
*   3. Prefer non-excluded assignment
*   4. Prefer direct assignment over composite assignment
*
* This guarantees one result row per USERNAME + ROLENAME.
*--------------------------------------------------------------------
    SORT lt_assignment BY
      agr_name
      from_dat DESCENDING
      to_dat   DESCENDING
      exclude  ASCENDING
      col_flag ASCENDING
      org_flag ASCENDING.

    DELETE ADJACENT DUPLICATES FROM lt_assignment
      COMPARING agr_name.

*--------------------------------------------------------------------
* Build custom-entity result
*--------------------------------------------------------------------
    LOOP AT lt_assignment
      ASSIGNING FIELD-SYMBOL(<ls_assignment>).

      APPEND VALUE #(
        username =
          lv_user

        rolename =
          <ls_assignment>-agr_name

        roletext =
          <ls_assignment>-role_text

        validfrom =
          <ls_assignment>-from_dat

        validto =
          <ls_assignment>-to_dat

        isvalid =
          abap_true

        isexcluded =
          xsdbool(
            <ls_assignment>-exclude = abap_true )

        isorganisationalassignment =
          xsdbool(
            <ls_assignment>-org_flag = abap_true )

        iscompositeassignment =
          xsdbool(
            <ls_assignment>-col_flag = abap_true )
      ) TO lt_result.

    ENDLOOP.

    SORT lt_result BY
      username
      rolename.

*--------------------------------------------------------------------
* Total number of records before paging
*--------------------------------------------------------------------
    IF io_request->is_total_numb_of_rec_requested( ).

      io_response->set_total_number_of_records(
        lines( lt_result )
      ).

    ENDIF.

*--------------------------------------------------------------------
* Apply RAP paging
*
* LV_OFFSET and LV_PAGE_SIZE were already read at the beginning of
* the method so that paging is also covered for empty results.
*--------------------------------------------------------------------
    IF io_request->is_data_requested( ).

      IF lv_page_size =
           if_rap_query_paging=>page_size_unlimited
         OR lv_page_size IS INITIAL.

        lt_page = lt_result.

      ELSE.

        DATA(lv_from) =
          CONV i( lv_offset + 1 ).

        DATA(lv_to) =
          CONV i( lv_offset + lv_page_size ).

        LOOP AT lt_result
          INTO DATA(ls_result)
          FROM lv_from
          TO lv_to.

          APPEND ls_result TO lt_page.

        ENDLOOP.

      ENDIF.

      io_response->set_data( lt_page ).

    ENDIF.

  ENDMETHOD.

ENDCLASS.
