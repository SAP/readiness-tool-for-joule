CLASS zcl_drj_cra_excel_proc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_role,
        role_name        TYPE agr_name,
        role_description TYPE agr_title,
      END OF ty_role,

      tt_roles TYPE STANDARD TABLE OF ty_role
        WITH EMPTY KEY.

    TYPES tt_invalid_roles TYPE STANDARD TABLE OF string
      WITH EMPTY KEY.

    CLASS-METHODS process
      IMPORTING
        iv_xstring TYPE xstring
      EXPORTING
        et_roles           TYPE tt_roles
        et_invalid_roles   TYPE tt_invalid_roles
        ev_parsed_count    TYPE i
        ev_resolved_count  TYPE i
        ev_invalid_count   TYPE i
        ev_duplicate_count TYPE i.

  PRIVATE SECTION.

ENDCLASS.


CLASS zcl_drj_cra_excel_proc IMPLEMENTATION.

  METHOD process.

    CLEAR:
      et_roles,
      et_invalid_roles,
      ev_parsed_count,
      ev_resolved_count,
      ev_invalid_count,
      ev_duplicate_count.

    "Read the uploaded workbook using the same SAP Excel parser
    "already used by the existing Joule Inspector import functions.
    DATA(lo_excel) = NEW cl_fdt_xl_spreadsheet(
      document_name = `upload`
      xdocument     = iv_xstring
    ).

    DATA lt_sheet_names TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    lo_excel->if_fdt_doc_spreadsheet~get_worksheet_names(
      IMPORTING
        worksheet_names = lt_sheet_names
    ).

    "CRA always reads the first worksheet.
    IF lt_sheet_names IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_first_sheet) = lt_sheet_names[ 1 ].

    DATA(lr_sheet_data) =
      lo_excel->if_fdt_doc_spreadsheet~get_itab_from_worksheet(
        worksheet_name = lv_first_sheet
      ).

    IF lr_sheet_data IS NOT BOUND.
      RETURN.
    ENDIF.


    "The Excel sheet has no header.
    "Every non-empty cell in column 1 is treated as a role name.
    FIELD-SYMBOLS:
      <lt_excel_data> TYPE STANDARD TABLE,
      <ls_excel_row>  TYPE any,
      <lv_excel_role> TYPE any.

    ASSIGN lr_sheet_data->* TO <lt_excel_data>.

    IF <lt_excel_data> IS NOT ASSIGNED.
      RETURN.
    ENDIF.


    "Keep the first occurrence order from Excel while using a hashed
    "table for case-insensitive duplicate detection after normalization.
    DATA lt_unique_roles TYPE STANDARD TABLE OF agr_name
      WITH EMPTY KEY.

    DATA lt_seen_roles TYPE HASHED TABLE OF agr_name
      WITH UNIQUE KEY table_line.


    LOOP AT <lt_excel_data> ASSIGNING <ls_excel_row>.

      UNASSIGN <lv_excel_role>.

      ASSIGN COMPONENT 1
        OF STRUCTURE <ls_excel_row>
        TO <lv_excel_role>.

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_role_text) =
        condense( CONV string( <lv_excel_role> ) ).

      IF lv_role_text IS INITIAL.
        CONTINUE.
      ENDIF.

      "Count every non-empty first-column row before deduplication.
      ev_parsed_count += 1.

      "PFCG role names are normalized for case-insensitive comparison.
      TRANSLATE lv_role_text TO UPPER CASE.

      DATA(lv_role_name) = CONV agr_name( lv_role_text ).

      INSERT lv_role_name INTO TABLE lt_seen_roles.

      IF sy-subrc = 0.

        APPEND lv_role_name TO lt_unique_roles.

      ELSE.

        ev_duplicate_count += 1.

      ENDIF.

    ENDLOOP.


    IF lt_unique_roles IS INITIAL.
      RETURN.
    ENDIF.


    "Resolve all unique Excel role names in one database operation.
    "Use the same CDS source as the CRA manual type-ahead so both
    "selection paths have identical role validity/description semantics.
    DATA lt_resolved_roles TYPE HASHED TABLE OF ty_role
      WITH UNIQUE KEY role_name.

    SELECT RoleName        AS role_name,
           RoleDescription AS role_description
      FROM ZI_DRJ_CRA_RoleVH
      FOR ALL ENTRIES IN @lt_unique_roles
      WHERE RoleName = @lt_unique_roles-table_line
      INTO TABLE @lt_resolved_roles.


    "Return resolved roles in the same order as their first occurrence
    "in the Excel file. Unknown role names are returned separately.
    LOOP AT lt_unique_roles INTO lv_role_name.

      READ TABLE lt_resolved_roles
        INTO DATA(ls_resolved_role)
        WITH TABLE KEY
          role_name = lv_role_name.

      IF sy-subrc = 0.

        APPEND ls_resolved_role TO et_roles.

      ELSE.

        APPEND CONV string( lv_role_name )
          TO et_invalid_roles.

      ENDIF.

    ENDLOOP.


    ev_resolved_count = lines( et_roles ).
    ev_invalid_count  = lines( et_invalid_roles ).

  ENDMETHOD..

ENDCLASS.
