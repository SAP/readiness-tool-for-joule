CLASS zzcl_drj_excel_export DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_row,
        functional_area    TYPE string,
        capability_usecase TYPE string,
        api                TYPE string,
        semantic_obj_act   TYPE string,
        catalog            TYPE string,
        role               TYPE string,
        release_info       TYPE string,
        additional_info    TYPE string,
      END OF ty_row,
      tt_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    CLASS-METHODS export
      EXPORTING
        ev_xstring TYPE xstring
        ev_rows    TYPE i.

  PRIVATE SECTION.

    CLASS-METHODS read_db
      RETURNING VALUE(rt_rows) TYPE tt_rows.

    CLASS-METHODS build_xlsx
      IMPORTING it_rows        TYPE tt_rows
      RETURNING VALUE(rv_xlsx) TYPE xstring.

    CLASS-METHODS add_zip_string
      IMPORTING
        io_zip     TYPE REF TO cl_abap_zip
        iv_name    TYPE string
        iv_content TYPE string.

    CLASS-METHODS row_xml
      IMPORTING
        is_row          TYPE ty_row
        iv_index        TYPE i
      RETURNING
        VALUE(rv_xml)   TYPE string.

    CLASS-METHODS cell_xml
      IMPORTING
        iv_col          TYPE string
        iv_row          TYPE i
        iv_value        TYPE string
      RETURNING
        VALUE(rv_xml)   TYPE string.

    CLASS-METHODS esc
      IMPORTING iv_value       TYPE string
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zzcl_drj_excel_export IMPLEMENTATION.

  METHOD export.

    DATA(lt_rows) = read_db( ).

    ev_rows    = lines( lt_rows ).
    ev_xstring = build_xlsx( lt_rows ).

  ENDMETHOD.


  METHOD read_db.

    DATA lt_caps  TYPE HASHED TABLE OF zdrj_capability
                  WITH UNIQUE KEY capability_name.
    DATA lt_scens TYPE STANDARD TABLE OF zdrj_cp_scenario WITH EMPTY KEY.
    DATA lt_apis  TYPE STANDARD TABLE OF zdrj_scen_api WITH EMPTY KEY.
    DATA lt_tms   TYPE STANDARD TABLE OF zdrj_scen_tm WITH EMPTY KEY.
    DATA lt_roles TYPE STANDARD TABLE OF zdrj_cap_brole WITH EMPTY KEY.

    SELECT * FROM zdrj_capability INTO TABLE @lt_caps.
    SELECT * FROM zdrj_cp_scenario    INTO TABLE @lt_scens.
    SELECT * FROM zdrj_scen_api   INTO TABLE @lt_apis.
    SELECT * FROM zdrj_scen_tm    INTO TABLE @lt_tms.
    SELECT * FROM zdrj_cap_brole  INTO TABLE @lt_roles.

    SORT lt_scens BY capability_name scenario_name.
    SORT lt_apis  BY capability_name scenario_name odata_service_name.
    SORT lt_tms   BY capability_name scenario_name semantic_object semantic_action catalog_id.
    SORT lt_roles BY capability_name business_role.

    LOOP AT lt_scens INTO DATA(ls_scen).

      READ TABLE lt_caps INTO DATA(ls_cap)
        WITH TABLE KEY capability_name = ls_scen-capability_name.

      DATA(lv_functional_area) = COND string(
        WHEN sy-subrc = 0 AND ls_cap-capability_displayname IS NOT INITIAL
          THEN CONV string( ls_cap-capability_displayname )
        WHEN ls_scen-namespace IS NOT INITIAL
          THEN CONV string( ls_scen-namespace )
        ELSE
          CONV string( ls_scen-capability_name ) ).

      DATA(lv_release) = COND string(
        WHEN sy-subrc = 0 THEN CONV string( ls_cap-release_info )
        ELSE `` ).

      DATA(lv_usecase) = CONV string( ls_scen-scenario_description ).
      DATA(lv_additional_info) = ``.

      "Try to reverse the importer logic:
      "scenario_description = capability_usecase && ` [` && additional_info && `]`
      FIND REGEX ` \[[^\]]+\]$`
        IN lv_usecase
        MATCH OFFSET DATA(lv_off)
        MATCH LENGTH DATA(lv_len).

      IF sy-subrc = 0 AND lv_len > 3.
        lv_additional_info = substring(
          val = lv_usecase
          off = lv_off + 2
          len = lv_len - 3 ).

        lv_usecase = substring(
          val = lv_usecase
          len = lv_off ).
      ENDIF.

      DATA lt_api_text TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
      DATA lt_sem_text TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
      DATA lt_cat_text TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
      DATA lt_role_text TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

      LOOP AT lt_apis INTO DATA(ls_api)
        WHERE capability_name = ls_scen-capability_name
          AND scenario_name   = ls_scen-scenario_name.

        IF ls_api-odata_service_name IS NOT INITIAL.
          INSERT CONV string( ls_api-odata_service_name ) INTO TABLE lt_api_text.
        ENDIF.

      ENDLOOP.

      LOOP AT lt_tms INTO DATA(ls_tm)
        WHERE capability_name = ls_scen-capability_name
          AND scenario_name   = ls_scen-scenario_name.

        DATA(lv_sem_pair) = COND string(
          WHEN ls_tm-semantic_action IS INITIAL
            THEN CONV string( ls_tm-semantic_object )
          ELSE
            |{ CONV string( ls_tm-semantic_object ) }-{ CONV string( ls_tm-semantic_action ) }| ).

        IF lv_sem_pair IS NOT INITIAL.
          INSERT lv_sem_pair INTO TABLE lt_sem_text.
        ENDIF.

        IF ls_tm-catalog_id IS NOT INITIAL.
          INSERT CONV string( ls_tm-catalog_id ) INTO TABLE lt_cat_text.
        ENDIF.

      ENDLOOP.

      LOOP AT lt_roles INTO DATA(ls_role)
        WHERE capability_name = ls_scen-capability_name.

        IF ls_role-business_role IS NOT INITIAL.
          INSERT CONV string( ls_role-business_role ) INTO TABLE lt_role_text.
        ENDIF.

      ENDLOOP.

      APPEND VALUE #(
        functional_area    = lv_functional_area
        capability_usecase = lv_usecase
        api                = concat_lines_of( table = lt_api_text  sep = `, ` )
        semantic_obj_act   = concat_lines_of( table = lt_sem_text  sep = cl_abap_char_utilities=>newline )
        catalog            = concat_lines_of( table = lt_cat_text  sep = cl_abap_char_utilities=>newline )
        role               = concat_lines_of( table = lt_role_text sep = cl_abap_char_utilities=>newline )
        release_info       = lv_release
        additional_info    = lv_additional_info
      ) TO rt_rows.

    ENDLOOP.

  ENDMETHOD.


  METHOD build_xlsx.

    DATA(lo_zip) = NEW cl_abap_zip( ).

    DATA(lv_content_types) =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      `<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` &&
      `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>` &&
      `<Default Extension="xml" ContentType="application/xml"/>` &&
      `<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>` &&
      `<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>` &&
      `<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>` &&
      `<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>` &&
      `<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>` &&
      `</Types>`.

    DATA(lv_rels) =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` &&
      `<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>` &&
      `<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>` &&
      `<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>` &&
      `</Relationships>`.

    DATA(lv_workbook) =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ` &&
      `xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">` &&
      `<sheets>` &&
      `<sheet name="Sheet1" sheetId="1" r:id="rId1"/>` &&
      `</sheets>` &&
      `</workbook>`.

    DATA(lv_workbook_rels) =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` &&
      `<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>` &&
      `<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>` &&
      `</Relationships>`.

    DATA(lv_styles) =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      `<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">` &&
      `<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>` &&
      `<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>` &&
      `<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>` &&
      `<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>` &&
      `<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>` &&
      `<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>` &&
      `</styleSheet>`.

    DATA(lv_core) =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      `<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" ` &&
      `xmlns:dc="http://purl.org/dc/elements/1.1/" ` &&
      `xmlns:dcterms="http://purl.org/dc/terms/" ` &&
      `xmlns:dcmitype="http://purl.org/dc/dcmitype/" ` &&
      `xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">` &&
      `<dc:creator>SAP</dc:creator>` &&
      `<cp:lastModifiedBy>SAP</cp:lastModifiedBy>` &&
      `</cp:coreProperties>`.

    DATA(lv_app) =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      `<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" ` &&
      `xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">` &&
      `<Application>SAP ABAP</Application>` &&
      `</Properties>`.

    DATA(lv_sheet) =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      `<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">` &&
      `<dimension ref="A1:H` && |{ lines( it_rows ) + 1 }| && `"/>` &&
      `<sheetViews><sheetView workbookViewId="0"/></sheetViews>` &&
      `<sheetFormatPr defaultRowHeight="15"/>` &&
      `<cols>` &&
      `<col min="1" max="1" width="28" customWidth="1"/>` &&
      `<col min="2" max="2" width="55" customWidth="1"/>` &&
      `<col min="3" max="3" width="45" customWidth="1"/>` &&
      `<col min="4" max="4" width="40" customWidth="1"/>` &&
      `<col min="5" max="5" width="45" customWidth="1"/>` &&
      `<col min="6" max="6" width="35" customWidth="1"/>` &&
      `<col min="7" max="7" width="24" customWidth="1"/>` &&
      `<col min="8" max="8" width="55" customWidth="1"/>` &&
      `</cols>` &&
      `<sheetData>`.

    DATA(ls_header) = VALUE ty_row(
      functional_area    = `Functional Area`
      capability_usecase = `Capability - Use Case`
      api                = `API`
      semantic_obj_act   = `Semantic Object - Action`
      catalog            = `Technical catalog for the Semantic Object - Action`
      role               = `Role`
      release_info       = `Release`
      additional_info    = `Additional technical information`
    ).

    lv_sheet &&= row_xml(
      is_row   = ls_header
      iv_index = 1 ).

    DATA(lv_row_index) = 1.

    LOOP AT it_rows INTO DATA(ls_row).
      lv_row_index += 1.

      lv_sheet &&= row_xml(
        is_row   = ls_row
        iv_index = lv_row_index ).
    ENDLOOP.

    lv_sheet &&= `</sheetData></worksheet>`.

    add_zip_string( io_zip = lo_zip iv_name = `[Content_Types].xml`        iv_content = lv_content_types ).
    add_zip_string( io_zip = lo_zip iv_name = `_rels/.rels`                iv_content = lv_rels ).
    add_zip_string( io_zip = lo_zip iv_name = `xl/workbook.xml`            iv_content = lv_workbook ).
    add_zip_string( io_zip = lo_zip iv_name = `xl/_rels/workbook.xml.rels` iv_content = lv_workbook_rels ).
    add_zip_string( io_zip = lo_zip iv_name = `xl/styles.xml`              iv_content = lv_styles ).
    add_zip_string( io_zip = lo_zip iv_name = `xl/worksheets/sheet1.xml`   iv_content = lv_sheet ).
    add_zip_string( io_zip = lo_zip iv_name = `docProps/core.xml`          iv_content = lv_core ).
    add_zip_string( io_zip = lo_zip iv_name = `docProps/app.xml`           iv_content = lv_app ).

    rv_xlsx = lo_zip->save( ).

  ENDMETHOD.


  METHOD add_zip_string.

    DATA(lv_xstring) = cl_abap_codepage=>convert_to(
      source = iv_content ).

    io_zip->add(
      name    = iv_name
      content = lv_xstring ).

  ENDMETHOD.


  METHOD row_xml.

    rv_xml = |<row r="{ iv_index }">|.

    rv_xml &&= cell_xml( iv_col = `A` iv_row = iv_index iv_value = is_row-functional_area ).
    rv_xml &&= cell_xml( iv_col = `B` iv_row = iv_index iv_value = is_row-capability_usecase ).
    rv_xml &&= cell_xml( iv_col = `C` iv_row = iv_index iv_value = is_row-api ).
    rv_xml &&= cell_xml( iv_col = `D` iv_row = iv_index iv_value = is_row-semantic_obj_act ).
    rv_xml &&= cell_xml( iv_col = `E` iv_row = iv_index iv_value = is_row-catalog ).
    rv_xml &&= cell_xml( iv_col = `F` iv_row = iv_index iv_value = is_row-role ).
    rv_xml &&= cell_xml( iv_col = `G` iv_row = iv_index iv_value = is_row-release_info ).
    rv_xml &&= cell_xml( iv_col = `H` iv_row = iv_index iv_value = is_row-additional_info ).

    rv_xml &&= `</row>`.

  ENDMETHOD.


  METHOD cell_xml.

    DATA(lv_text) = esc( iv_value ).

    rv_xml =
      |<c r="{ iv_col }{ iv_row }" t="inlineStr">| &&
      |<is><t xml:space="preserve">{ lv_text }</t></is>| &&
      |</c>|.

  ENDMETHOD.


  METHOD esc.

    rv_text = iv_value.

    REPLACE ALL OCCURRENCES OF `&` IN rv_text WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN rv_text WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN rv_text WITH `&gt;`.

  ENDMETHOD.

ENDCLASS.
