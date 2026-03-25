#pragma warning disable AL0640
codeunit 61184 "DOADV HTML Manipulator"
{
    Access = Public;

    // ===========================================================================
    // PUBLIC PROCEDURES
    // ===========================================================================

    /// Returns the first <tr>...</tr> block (including tags) within the table
    /// that matches TableIdentifier (searched as id or class on the <table> tag),
    /// where the opening <tr> tag has Attribute="AttributeValue".
    /// Returns '' when not found.
    /// Example: GetTableRowByAttribute(Html, 'my-table', 'class', 'approval-entries')
    procedure GetTableRowByAttribute(HtmlContent: Text; TableIdentifier: Text; Attribute: Text; AttributeValue: Text): Text
    var
        TableStart: Integer;
        TableEnd: Integer;
        TrStart: Integer;
        TrEnd: Integer;
    begin
        if not FindTableRange(HtmlContent, TableIdentifier, TableStart, TableEnd) then
            exit('');
        if not FindTrRangeByAttribute(HtmlContent, TableStart, TableEnd, Attribute, AttributeValue, TrStart, TrEnd) then
            exit('');
        exit(CopyStr(HtmlContent, TrStart, TrEnd - TrStart + 1));
    end;

    /// Replaces the first <tr> where Attribute="AttributeValue" inside the matching
    /// table with NewRowContent. Returns true when a replacement was made.
    procedure ReplaceTableRowByAttribute(var HtmlContent: Text; TableIdentifier: Text; Attribute: Text; AttributeValue: Text; NewRowContent: Text): Boolean
    var
        TableStart: Integer;
        TableEnd: Integer;
        TrStart: Integer;
        TrEnd: Integer;
    begin
        if not FindTableRange(HtmlContent, TableIdentifier, TableStart, TableEnd) then
            exit(false);
        if not FindTrRangeByAttribute(HtmlContent, TableStart, TableEnd, Attribute, AttributeValue, TrStart, TrEnd) then
            exit(false);

        HtmlContent :=
            CopyStr(HtmlContent, 1, TrStart - 1) +
            NewRowContent +
            CopyStr(HtmlContent, TrEnd + 1);
        exit(true);
    end;

    /// Inserts NewRowContent as the FIRST row in the matching table.
    /// Insertion point priority: after <tbody>, after </thead>, after <table...>.
    procedure AddTableRowFirst(var HtmlContent: Text; TableIdentifier: Text; NewRowContent: Text): Boolean
    var
        TableStart: Integer;
        TableEnd: Integer;
        InsertPos: Integer;
    begin
        if not FindTableRange(HtmlContent, TableIdentifier, TableStart, TableEnd) then
            exit(false);

        InsertPos := CalcFirstInsertPos(HtmlContent, TableStart, TableEnd);
        HtmlContent :=
            CopyStr(HtmlContent, 1, InsertPos - 1) +
            NewRowContent +
            CopyStr(HtmlContent, InsertPos);
        exit(true);
    end;

    /// Inserts NewRowContent as the LAST row in the matching table.
    /// Insertion point priority: before </tbody>, before </table>.
    procedure AddTableRowLast(var HtmlContent: Text; TableIdentifier: Text; NewRowContent: Text): Boolean
    var
        TableStart: Integer;
        TableEnd: Integer;
        InsertPos: Integer;
    begin
        if not FindTableRange(HtmlContent, TableIdentifier, TableStart, TableEnd) then
            exit(false);

        InsertPos := CalcLastInsertPos(HtmlContent, TableStart, TableEnd);
        HtmlContent :=
            CopyStr(HtmlContent, 1, InsertPos - 1) +
            NewRowContent +
            CopyStr(HtmlContent, InsertPos);
        exit(true);
    end;

    /// Inserts NewRowContent immediately AFTER the first <tr> where Attribute="AttributeValue".
    procedure AddTableRowAfter(var HtmlContent: Text; TableIdentifier: Text; Attribute: Text; AttributeValue: Text; NewRowContent: Text): Boolean
    var
        TableStart: Integer;
        TableEnd: Integer;
        TrStart: Integer;
        TrEnd: Integer;
    begin
        if not FindTableRange(HtmlContent, TableIdentifier, TableStart, TableEnd) then
            exit(false);
        if not FindTrRangeByAttribute(HtmlContent, TableStart, TableEnd, Attribute, AttributeValue, TrStart, TrEnd) then
            exit(false);

        HtmlContent :=
            CopyStr(HtmlContent, 1, TrEnd) +
            NewRowContent +
            CopyStr(HtmlContent, TrEnd + 1);
        exit(true);
    end;

    /// Inserts NewRowContent immediately BEFORE the first <tr> where Attribute="AttributeValue".
    procedure AddTableRowBefore(var HtmlContent: Text; TableIdentifier: Text; Attribute: Text; AttributeValue: Text; NewRowContent: Text): Boolean
    var
        TableStart: Integer;
        TableEnd: Integer;
        TrStart: Integer;
        TrEnd: Integer;
    begin
        if not FindTableRange(HtmlContent, TableIdentifier, TableStart, TableEnd) then
            exit(false);
        if not FindTrRangeByAttribute(HtmlContent, TableStart, TableEnd, Attribute, AttributeValue, TrStart, TrEnd) then
            exit(false);

        HtmlContent :=
            CopyStr(HtmlContent, 1, TrStart - 1) +
            NewRowContent +
            CopyStr(HtmlContent, TrStart);
        exit(true);
    end;

    // ===========================================================================
    // PRIVATE – TABLE RANGE
    // ===========================================================================

    /// Finds the character range [TableStart..TableEnd] of the <table> element
    /// whose id or class attribute matches TableIdentifier (case-insensitive).
    ///   TableStart = position of '<' in the opening <table> tag
    ///   TableEnd   = position of '>' in the closing </table> tag
    local procedure FindTableRange(HtmlContent: Text; TableIdentifier: Text; var TableStart: Integer; var TableEnd: Integer): Boolean
    var
        LowerHtml: Text;
        LowerId: Text;
        SearchPos: Integer;
        TagOpenEnd: Integer;
        OpenTag: Text;
    begin
        LowerHtml := LowerCase(HtmlContent);
        LowerId := LowerCase(TableIdentifier);
        SearchPos := 1;

        TableStart := PosFrom(LowerHtml, '<table', SearchPos);
        while TableStart > 0 do begin
            TagOpenEnd := PosFrom(LowerHtml, '>', TableStart);
            if TagOpenEnd = 0 then
                exit(false);

            // Confirm '<table' is not a prefix of another tag (e.g. <tablefoo>)
            if IsRealTag(LowerHtml, TableStart, 'table') then begin
                OpenTag := CopyStr(LowerHtml, TableStart, TagOpenEnd - TableStart + 1);
                if HasAttributeToken(OpenTag, 'id', LowerId) or HasAttributeToken(OpenTag, 'class', LowerId) then begin
                    TableEnd := FindMatchingTableClose(LowerHtml, TagOpenEnd + 1);
                    exit(TableEnd > 0);
                end;
            end;

            SearchPos := TagOpenEnd + 1;
            TableStart := PosFrom(LowerHtml, '<table', SearchPos);
        end;

        exit(false);
    end;

    /// Finds the position of '>' in the </table> that closes the table whose
    /// body starts at SearchFrom, handling arbitrarily nested inner tables.
    local procedure FindMatchingTableClose(LowerHtml: Text; SearchFrom: Integer): Integer
    var
        Depth: Integer;
        NextOpen: Integer;
        NextClose: Integer;
        OpenTagEnd: Integer;
    begin
        Depth := 1;

        while Depth > 0 do begin
            NextOpen := PosFrom(LowerHtml, '<table', SearchFrom);
            NextClose := PosFrom(LowerHtml, '</table>', SearchFrom);

            if NextClose = 0 then
                exit(0); // Malformed HTML

            if (NextOpen > 0) and (NextOpen < NextClose) then begin
                // A candidate nested <table> appears before the next </table>
                if IsRealTag(LowerHtml, NextOpen, 'table') then
                    Depth += 1;
                OpenTagEnd := PosFrom(LowerHtml, '>', NextOpen);
                if OpenTagEnd = 0 then
                    exit(0);
                SearchFrom := OpenTagEnd + 1;
            end else begin
                Depth -= 1;
                if Depth = 0 then
                    // Return position of '>' in '</table>'
                    exit(NextClose + StrLen('</table>') - 1);
                SearchFrom := NextClose + StrLen('</table>');
            end;
        end;

        exit(0);
    end;

    // ===========================================================================
    // PRIVATE – TR RANGE
    // ===========================================================================

    /// Within [SearchFrom..SearchTo], finds the first <tr> whose opening tag
    /// has Attribute="AttributeValue". Sets TrStart (position of '<') and TrEnd
    /// (position of '>' in </tr>). Returns false when not found.
    local procedure FindTrRangeByAttribute(HtmlContent: Text; SearchFrom: Integer; SearchTo: Integer; Attribute: Text; AttributeValue: Text; var TrStart: Integer; var TrEnd: Integer): Boolean
    var
        LowerHtml: Text;
        SearchPos: Integer;
        TagOpenEnd: Integer;
        OpenTag: Text;
    begin
        LowerHtml := LowerCase(HtmlContent);
        Attribute := LowerCase(Attribute);
        AttributeValue := LowerCase(AttributeValue);
        SearchPos := SearchFrom;

        TrStart := PosFrom(LowerHtml, '<tr', SearchPos);
        while (TrStart > 0) and (TrStart <= SearchTo) do begin
            TagOpenEnd := PosFrom(LowerHtml, '>', TrStart);
            if (TagOpenEnd = 0) or (TagOpenEnd > SearchTo) then
                exit(false);

            if IsRealTag(LowerHtml, TrStart, 'tr') then begin
                OpenTag := CopyStr(LowerHtml, TrStart, TagOpenEnd - TrStart + 1);
                if HasAttributeToken(OpenTag, Attribute, AttributeValue) then begin
                    TrEnd := FindTrClose(LowerHtml, TagOpenEnd + 1, SearchTo);
                    exit(TrEnd > 0);
                end;
            end;

            SearchPos := TagOpenEnd + 1;
            TrStart := PosFrom(LowerHtml, '<tr', SearchPos);
        end;

        exit(false);
    end;

    /// Finds the position of '>' in the </tr> that closes a <tr> whose body
    /// begins at SearchFrom, correctly skipping any nested tables (which may
    /// contain their own <tr>...</tr> pairs inside <td> cells).
    local procedure FindTrClose(LowerHtml: Text; SearchFrom: Integer; SearchTo: Integer): Integer
    var
        Depth: Integer;
        Pos: Integer;
        NextTableOpen: Integer;
        NextTableClose: Integer;
        NextTrClose: Integer;
        OpenTagEnd: Integer;
    begin
        // Depth tracks nested <table> elements inside this <tr>
        Depth := 0;
        Pos := SearchFrom;

        while true do begin
            NextTableOpen := PosFrom(LowerHtml, '<table', Pos);
            if (NextTableOpen > SearchTo) then NextTableOpen := 0;

            NextTableClose := PosFrom(LowerHtml, '</table>', Pos);
            if (NextTableClose > SearchTo) then NextTableClose := 0;

            NextTrClose := PosFrom(LowerHtml, '</tr>', Pos);
            if (NextTrClose = 0) or (NextTrClose > SearchTo) then
                exit(0);

            if (NextTableOpen > 0) and
               (NextTableOpen < NextTrClose) and
               ((NextTableClose = 0) or (NextTableOpen < NextTableClose))
            then begin
                // A nested table opens before the next </tr>
                if IsRealTag(LowerHtml, NextTableOpen, 'table') then
                    Depth += 1;
                OpenTagEnd := PosFrom(LowerHtml, '>', NextTableOpen);
                if OpenTagEnd = 0 then exit(0);
                Pos := OpenTagEnd + 1;

            end else if (NextTableClose > 0) and (NextTableClose < NextTrClose) then begin
                // A nested table closes before the next </tr>
                if Depth > 0 then
                    Depth -= 1;
                Pos := NextTableClose + StrLen('</table>');

            end else begin
                if Depth = 0 then
                    // This </tr> belongs to our row
                    exit(NextTrClose + StrLen('</tr>') - 1);
                // </tr> is inside a nested table row – skip it
                Pos := NextTrClose + StrLen('</tr>');
            end;
        end;

        exit(0);
    end;

    // ===========================================================================
    // PRIVATE – INSERT POSITION HELPERS
    // ===========================================================================

    /// Returns the position at which to insert the first new row.
    /// Priority: right after <tbody...>, right after </thead>, right after <table...>.
    local procedure CalcFirstInsertPos(HtmlContent: Text; TableStart: Integer; TableEnd: Integer): Integer
    var
        LowerHtml: Text;
        TbodyStart: Integer;
        TbodyTagEnd: Integer;
        TheadClosePos: Integer;
        TableTagEnd: Integer;
    begin
        LowerHtml := LowerCase(HtmlContent);

        TbodyStart := PosFrom(LowerHtml, '<tbody', TableStart);
        if (TbodyStart > 0) and (TbodyStart < TableEnd) then begin
            TbodyTagEnd := PosFrom(LowerHtml, '>', TbodyStart);
            if TbodyTagEnd > 0 then
                exit(TbodyTagEnd + 1);
        end;

        TheadClosePos := PosFrom(LowerHtml, '</thead>', TableStart);
        if (TheadClosePos > 0) and (TheadClosePos < TableEnd) then
            exit(TheadClosePos + StrLen('</thead>'));

        TableTagEnd := PosFrom(LowerHtml, '>', TableStart);
        exit(TableTagEnd + 1);
    end;

    /// Returns the position at which to insert the last new row.
    /// Priority: right before </tbody>, right before </table>.
    local procedure CalcLastInsertPos(HtmlContent: Text; TableStart: Integer; TableEnd: Integer): Integer
    var
        LowerHtml: Text;
        TbodyClosePos: Integer;
    begin
        LowerHtml := LowerCase(HtmlContent);

        TbodyClosePos := PosFrom(LowerHtml, '</tbody>', TableStart);
        if (TbodyClosePos > 0) and (TbodyClosePos < TableEnd) then
            exit(TbodyClosePos); // insert before </tbody>

        // TableEnd is the position of '>' in </table>
        // </table> starts at TableEnd - StrLen('</table>') + 1
        exit(TableEnd - StrLen('</table>') + 1);
    end;

    // ===========================================================================
    // PRIVATE – ATTRIBUTE HELPERS
    // ===========================================================================

    /// Returns true when AttrName in LowerTag (already lowercased) contains TokenValue
    /// as one of its space-separated tokens. Works for single-value attributes (id, href)
    /// and multi-token attributes (class, aria-describedby, etc.).
    local procedure HasAttributeToken(LowerTag: Text; AttrName: Text; TokenValue: Text): Boolean
    var
        AttrPos: Integer;
        ValueStart: Integer;
        ValueEnd: Integer;
        AttrValue: Text;
    begin
        // Double-quoted attribute: attrname="..."
        AttrPos := StrPos(LowerTag, AttrName + '="');
        if AttrPos > 0 then begin
            ValueStart := AttrPos + StrLen(AttrName + '="');
            ValueEnd := PosFrom(LowerTag, '"', ValueStart);
            if ValueEnd > 0 then begin
                AttrValue := CopyStr(LowerTag, ValueStart, ValueEnd - ValueStart);
                if ContainsWord(AttrValue, TokenValue) then
                    exit(true);
            end;
        end;

        // Single-quoted attribute: attrname='...'
        AttrPos := StrPos(LowerTag, AttrName + '=''');
        if AttrPos > 0 then begin
            ValueStart := AttrPos + StrLen(AttrName + '=''');
            ValueEnd := PosFrom(LowerTag, '''', ValueStart);
            if ValueEnd > 0 then begin
                AttrValue := CopyStr(LowerTag, ValueStart, ValueEnd - ValueStart);
                if ContainsWord(AttrValue, TokenValue) then
                    exit(true);
            end;
        end;

        exit(false);
    end;

    /// Returns true when the space-separated WordList contains Word as a token.
    local procedure ContainsWord(WordList: Text; Word: Text): Boolean
    var
        Parts: List of [Text];
        Part: Text;
    begin
        Parts := WordList.Split(' ');
        foreach Part in Parts do
            if Part.Trim() = Word then
                exit(true);
        exit(false);
    end;

    // ===========================================================================
    // PRIVATE – UTILITY
    // ===========================================================================

    /// Searches for SubText in MainText starting at StartPos (1-based).
    /// Returns 0 when not found.
    local procedure PosFrom(MainText: Text; SubText: Text; StartPos: Integer): Integer
    var
        RelPos: Integer;
    begin
        if (StartPos < 1) or (StartPos > StrLen(MainText)) then
            exit(0);
        RelPos := StrPos(CopyStr(MainText, StartPos), SubText);
        if RelPos = 0 then
            exit(0);
        exit(StartPos + RelPos - 1);
    end;

    /// Returns true when the tag starting at TagPos in LowerHtml has exactly
    /// TagName as its element name (i.e. the character right after the name is
    /// whitespace, '>', or '/'), preventing false matches like <tablefoo>.
    local procedure IsRealTag(LowerHtml: Text; TagPos: Integer; TagName: Text): Boolean
    var
        CharAfter: Char;
        CharPos: Integer;
        Tab: Char;
        LF: Char;
        CR: Char;
    begin
        Tab := 9;
        LF := 10;
        CR := 13;

        // TagPos points to '<', tag name starts at TagPos+1
        // Character after the name is at TagPos + 1 + StrLen(TagName)
        CharPos := TagPos + 1 + StrLen(TagName);
        if CharPos > StrLen(LowerHtml) then
            exit(true); // end of string right after name – treat as valid
        CharAfter := LowerHtml[CharPos];
        exit(
            (CharAfter = ' ') or (CharAfter = '>') or (CharAfter = '/') or
            (CharAfter = Tab) or (CharAfter = LF) or (CharAfter = CR)
        );
    end;
}
#pragma warning restore AL0640