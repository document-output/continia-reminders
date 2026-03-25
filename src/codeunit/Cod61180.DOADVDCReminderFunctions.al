#pragma warning disable AL0432
codeunit 61180 "DOADV DC Reminder Functions"
{
    TableNo = 6175277;
    trigger OnRun()
    var
        RecRef: RecordRef;
        FRef: FieldRef;
    begin
        RecRef.Open(Rec."Table No.");
        RecRef.SetPosition(Rec.Position);

        If NOT RecRef.Find() then
            EXIT;

        CASE Rec.Parameter OF
            'GetApprovalURL':
                Rec.ReturnValue := GetApprovalURL(RecRef);
            'ApprovalEntries':
                Rec.ReturnValue := GetApprovalEntries(RecRef);
        END;
    end;

    var
        EventMgt: Codeunit "DOADV Reminder Event Mgt";
        Text001: Label '(On Hold)';
        Text002: Label '#DOCUMENTS#';
        Text003: Label '#VALUE#';
        Text004: Label '<td style="border-width: 1px 1px 0 0; border-style: solid; border-color: #e7e8e6; font-size: 11px; font-family: Tahoma,Verdana;">#VALUE#</td>';
        Text005: Label '<td align=right style="border-width: 1px 1px 0 0; border-style: solid; border-color: #e7e8e6; font-size: 11px; font-family: Tahoma,Verdana;">#VALUE#</td>';
        Text006: Label '<td style="border-width: 1px 1px 0 0; border-style: solid; border-color: #e7e8e6; font-size: 11px; font-family: Tahoma,Verdana; color: #d80d0d">#VALUE#</td>';
        Text007: Label '<td align=right style="border-width: 1px 1px 0 0; border-style: solid; border-color: #e7e8e6; font-size: 11px; font-family: Tahoma,Verdana; color: #d80d0d">#VALUE#</td>';
        Text008: Label 'Sending followup emails...\@1@@@@@@@@@@@@@@@@@@@@@@@@@@';
        Text012: Label 'Document Capture email Error: Email is blank on user %1 - %2';
        Text013: Label 'Document';
        Text014: Label 'Vendor';
        Text015: Label 'Date';
        Text016: Label 'Due Date';
        Text017: Label 'Currency';
        Text018: Label 'Amount Excl. VAT';
        Text019: Label 'Amount Incl. VAT';
        Text021: Label '<table style="border-width: 0 0 1px 1px; border-style: solid; border-color: #e7e8e6;" cellspacing=0 cellpadding=3>';
        Text022: Label '</table>';
        Text023: Label '<p style="font-weight: bold">%1</p>';
        Text024: Label 'The following documents await your approval';
        Text025: Label 'Shared by %1 (out of office)';
        Text026: Label 'Shared by %1';
        Text027: Label '<td style="border-width: 1px 1px 0 0; border-style: solid; border-color: #e7e8e6; font-size: 11px; font-family: Tahoma,Verdana; font-weight:bold">#VALUE#</td>';
        Text028: Label '<td align=right style="border-width: 1px 1px 0 0; border-style: solid; border-color: #e7e8e6; font-size: 11px; font-family: Tahoma,Verdana; font-weight: bold">#VALUE#</td>';
        Text029: Label 'Sending reminder emails...\@1@@@@@@@@@@@@@@@@@@@@@@@@@@';
        Text030: Label '%1<br />';
        Text031: Label '<b>%1</b><br />';
        Text032: Label '<br />';
        ApprovalTemplateTxt: Label '<html><head></head><body style="font-size: 11px; font-family: Tahoma, Verdana; color: #000a1b">#DOCUMENTS#<p style="font-weight: bold"><a href="#APPROVALFORMLINK#">%1</a></p></body></html>';
        ApprovalLinkTxt: Label 'Click here to access your documents for approval';
        SubjectEmailTxt: Label 'Your Invoices for Approval';
        ReminderSubjectEmailTxt: Label 'You have overdue document for approval';
        InvalidEmails: Text;
        InvalidEmailMsg: Label 'The following users do not have a valid email:\\%1';

    internal procedure UpdateMailBodyWithApprovalEntries(var MailBody: Text; var FilterUserRecord: RecordRef): Boolean
    var

        ContiniaUserSetup: Record "CTS-CBF Continia User Setup";
        CurrTableRow: text;
    begin
        FilterUserRecord.SetTable(ContiniaUserSetup);

        //CurrTableRow := HtmlManipulator.GetTableRowById(MailBody, 'approvalentries', 'entries-line');
        //CurrTableRow := CurrTableRow.Replace('%ENTRYNO', '12345');
        //CurrTableRow := CurrTableRow.Replace('%DOCNO', ContiniaUserSetup."Continia User ID");
        //CurrTableRow := CurrTableRow.Replace('%DOCDATE', '25.03.2026');
        //exit(HtmlManipulator.ReplaceTableRowById(MailBody, 'approvalentries', 'entries-line', CurrTableRow));

        exit(InsertUserApprovalEntriesToEmailBody(ContiniaUserSetup."Continia User ID", MailBody));
    end;



    internal procedure InsertUserApprovalEntriesToEmailBody(ContiniaUserId: Code[50]; var MailBody: Text): Boolean
    var
        DCSetup: Record "CDC Document Capture Setup";
        DCAppMgt: Codeunit "CDC Approval Management";
        ApprovalSharing: Record "CDC Approval Sharing";
        //ContiniaUserSetup: Record "CTS-CBF Continia User Setup";
        ApprEntry: Record "Approval Entry";
        HtmlManipulator: Codeunit "DOADV HTML Manipulator";
        TableRowTemplate: Text;
        DocCount: Integer;
    begin
        TableRowTemplate := HtmlManipulator.GetTableRowById(MailBody, 'approvalentries', 'entries-line');
        if TableRowTemplate = '' then
            exit(false);

        // Remove the placeholder table row from the mail body and add the new table row with real data as the last row of the approval entries table
        HtmlManipulator.ReplaceTableRowById(MailBody, 'approvalentries', 'entries-line', '');

        DCSetup.Get();

        // If the user doesn't exist in Continia User Setup, we should not include any approval entries in the mail
        // Pre-filter approval entries
        ApprEntry.SetCurrentKey("Approver ID", Status);
        ApprEntry.SetRange("Table ID", Database::"Purchase Header");
        ApprEntry.SetRange(Status, ApprEntry.Status::Open);

        DCAppMgt.FilterApprovalSharingFromUser(ApprovalSharing, ContiniaUserId);
        ApprovalSharing.SetFilter("Send E-mail To", '<>%1', ApprovalSharing."Send E-mail To"::"Only Original Approver");
        if ApprovalSharing.IsEmpty then begin
            ApprEntry.SetRange("Approver ID", ContiniaUserId);
            if ApprEntry.FindSet() then
                repeat
                    if IncludeApprovalEntry(DCSetup, ApprEntry) then begin
                        AddApprovalEntryDataToMailBodyTable(MailBody, ApprEntry, TableRowTemplate);
                        DocCount += 1;
                    end;
                until (ApprEntry.Next() = 0);

        end else begin
            DCAppMgt.FilterApprovalSharingToUser(ApprovalSharing, ContiniaUserId);
            ApprovalSharing.SetFilter("Send E-mail To", '<>%1', ApprovalSharing."Send E-mail To"::"Only Original Approver");
            if ApprovalSharing.FindSet() then
                repeat
                    ApprEntry.SetRange("Approver ID", ApprovalSharing."Owner User ID");
                    if ApprEntry.FindSet() then begin
                        //ContiniaUserSetup2.Get(ApprEntry."Approver ID");
                        repeat
                            if IncludeApprovalEntry(DCSetup, ApprEntry) then begin
                                AddApprovalEntryDataToMailBodyTable(MailBody, ApprEntry, TableRowTemplate);
                                DocCount += 1;
                            end;
                        until ApprEntry.Next() = 0;
                    end;
                until (ApprovalSharing.Next() = 0);
        end;
        MailBody := MailBody.Replace('#DOCCOUNT', Format(DocCount));
    end;

    local procedure AddApprovalEntryDataToMailBodyTable(var MailBody: Text; ApprovalEntry: Record "Approval Entry"; TableRowTemplate: Text): Boolean
    var
        PurchaseHeader: Record "Purchase Header";
        HtmlManipulator: Codeunit "DOADV HTML Manipulator";
        Handled: Boolean;
        Success: Boolean;
    begin
        if not PurchaseHeader.Get(ApprovalEntry."Document Type", ApprovalEntry."Document No.") then
            exit;

        // Try to replace the pre-defined placeholders in the table row template with real data from the approval entry and related purchase header
        TableRowTemplate := TableRowTemplate.Replace('%ENTRYNO', Format(ApprovalEntry."Entry No."));
        TableRowTemplate := TableRowTemplate.Replace('%DOCTYPE', Format(ApprovalEntry."Document Type"));
        TableRowTemplate := TableRowTemplate.Replace('%DOCNO', StrSubstNo('%1 %2', PurchaseHeader."Document Type", PurchaseHeader."No."));
        TableRowTemplate := TableRowTemplate.Replace('%VENDOR', StrSubstNo('%1 %2', PurchaseHeader."Buy-from Vendor No.", PurchaseHeader."Buy-from Vendor Name"));
        TableRowTemplate := TableRowTemplate.Replace('%DOCDATE', Format(PurchaseHeader."Document Date"));
        TableRowTemplate := TableRowTemplate.Replace('%DUEDATE', Format(PurchaseHeader."Due Date"));
        TableRowTemplate := TableRowTemplate.Replace('%CURRENCY', Format(PurchaseHeader."Currency Code"));
        TableRowTemplate := TableRowTemplate.Replace('%AMTEXCLVAT', Format(PurchaseHeader."Amount Including VAT"));
        TableRowTemplate := TableRowTemplate.Replace('%AMTINCLVAT', Format(PurchaseHeader.Amount));

        // Raise an event to give the possibility to adjust the generated table row before it is inserted into the mail body
        EventMgt.OnBeforeAddApprovalEntryRowToMailBody(ApprovalEntry, TableRowTemplate, PurchaseHeader, Handled, Success);
        if Handled then
            exit(Success);

        exit(HtmlManipulator.AddTableRowLast(MailBody, 'approvalentries', TableRowTemplate));
    end;


    /// <summary>
    /// Procedure to identify if the given user needs to be informed by mail about open approval entries
    /// </summary>
    /// <param name="DCSetup">Document Capture Setup record</param>
    /// <param name="ContiniaUserId">User ID from Continia User Setup</param>
    /// <returns></returns>
    internal procedure SendApprovalEmailtoUser(DCSetup: Record "CDC Document Capture Setup"; ContiniaUserId: Code[50]) SendMail: Boolean
    var
        DCAppMgt: Codeunit "CDC Approval Management";
        ApprovalSharing: Record "CDC Approval Sharing";
        //ContiniaUserSetup: Record "CTS-CBF Continia User Setup";
        ApprEntry: Record "Approval Entry";
    begin
        // Pre-filter approval entries
        ApprEntry.SetCurrentKey("Approver ID", Status);
        ApprEntry.SetRange("Table ID", Database::"Purchase Header");
        ApprEntry.SetRange(Status, ApprEntry.Status::Open);

        DCAppMgt.FilterApprovalSharingFromUser(ApprovalSharing, ContiniaUserId);
        ApprovalSharing.SetFilter("Send E-mail To", '<>%1', ApprovalSharing."Send E-mail To"::"Only Original Approver");
        if ApprovalSharing.IsEmpty then begin
            ApprEntry.SetRange("Approver ID", ContiniaUserId);
            if ApprEntry.FindSet() then
                repeat
                    if IncludeApprovalEntry(DCSetup, ApprEntry) then
                        SendMail := true;
                until (ApprEntry.Next() = 0) or SendMail;

        end else begin
            DCAppMgt.FilterApprovalSharingToUser(ApprovalSharing, ContiniaUserId);
            ApprovalSharing.SetFilter("Send E-mail To", '<>%1', ApprovalSharing."Send E-mail To"::"Only Original Approver");
            if ApprovalSharing.FindSet() then
                repeat
                    ApprEntry.SetRange("Approver ID", ApprovalSharing."Owner User ID");
                    if ApprEntry.FindSet() then begin
                        //ContiniaUserSetup2.Get(ApprEntry."Approver ID");
                        repeat
                            if IncludeApprovalEntry(DCSetup, ApprEntry) then
                                SendMail := true;
                        until ApprEntry.Next() = 0;
                    end;
                until (ApprovalSharing.Next() = 0) or SendMail;
        end;
    end;

    local procedure IncludeApprovalEntry(DCSetup: Record "CDC Document Capture Setup"; ApprovalEntry: Record "Approval Entry"): Boolean
    var
        PurchHeader: Record "Purchase Header";
    begin
        if DCSetup."Include Appr. Entries On Hold" then
            exit(true);

        if PurchHeader.Get(ApprovalEntry."Document Type", ApprovalEntry."Document No.") and (PurchHeader."On Hold" <> '') then
            exit(false);

        exit(true);
    end;


    local procedure GetApprovalURL(var RecRef: RecordRef): Text[1024]
    var
        ContiniaUserSetup: Record "CTS-CBF Continia User Setup";
        CDCApprovalManagement: Codeunit 6085722;
        DCAppMgt: Codeunit "CDC Approval Management";
    begin
        RecRef.SetTable(ContiniaUserSetup);
        EXIT(DCAppMgt.GetApprovalHyperlink(ContiniaUserSetup."Continia User ID"));
    end;

    procedure GetApprovalEntries(var RecRef: RecordRef): Text
    var
        ContiniaUser: Record "CTS-CBF Continia User Setup";
        ApprEntry: Record "Approval Entry";
        ApprEntry2: Record "Approval Entry";
        ApprovalSharing: Record "CDC Approval Sharing";
        ContiniaUserSetup: Record "CTS-CBF Continia User Setup";
        ContiniaUserSetup2: Record "CTS-CBF Continia User Setup";
        DocumentHTML: Codeunit "CDC BigString Management";
        PurchHeader: Record "Purchase Header";
        PurchApprovalEMail: Codeunit "CDC Purch. Approval E-Mail";
        TableRow: Codeunit "CDC BigString Management";

        DCAppMgt: Codeunit "CDC Approval Management";
        HTML: Codeunit "CDC BigString Management";
        ApprovalEntries: Text;
    begin
        /*RecRef.SetTable(ContiniaUserSetup);
        RecRef.SetTable(ContiniaUserSetup2);
        ApprEntry.SETRANGE("Approver ID", ContiniaUserSetup."Continia User ID");
        IF ApprEntry.FINDSET THEN BEGIN
            DocumentHTML.Append(STRSUBSTNO(Text023, Text024));

            DocumentHTML.Append(Text021);
            CreateTableHeaderRow(TableRow);
            DocumentHTML.Append('#####');
            DocumentHTML.Replace2('#####', TableRow);

            REPEAT
                PurchHeader.GET(ApprEntry."Document Type", ApprEntry."Document No.");
                CreateTableRow(PurchHeader, ApprEntry, TableRow);
                DocumentHTML.Append('#####');
                DocumentHTML.Replace2('#####', TableRow);
            UNTIL ApprEntry.NEXT = 0;

            DocumentHTML.Append(Text022);
        END;

        DCAppMgt.FilterApprovalSharingToUser(ApprovalSharing, ContiniaUserSetup."Continia User ID");
        IF ApprovalSharing.FINDSET THEN BEGIN
            REPEAT
                ApprEntry.SETRANGE("Approver ID", ApprovalSharing."Owner User ID");
                IF ApprEntry.FINDSET THEN BEGIN
                    ContiniaUserSetup2.GET(ApprEntry."Approver ID");
                    IF ApprovalSharing."Sharing Type" = ApprovalSharing."Sharing Type"::Normal THEN
                        DocumentHTML.Append(STRSUBSTNO(Text023, STRSUBSTNO(Text026, ContiniaUserSetup2.GetName)))
                    ELSE
                        DocumentHTML.Append(STRSUBSTNO(Text023, STRSUBSTNO(Text025, ContiniaUserSetup2.GetName)));

                    DocumentHTML.Append(Text021);
                    CreateTableHeaderRow(TableRow);
                    DocumentHTML.Append('#####');
                    DocumentHTML.Replace2('#####', TableRow);

                    REPEAT
                        PurchHeader.GET(ApprEntry."Document Type", ApprEntry."Document No.");
                        CreateTableRow(PurchHeader, ApprEntry, TableRow);
                        DocumentHTML.Append('#####');
                        DocumentHTML.Replace2('#####', TableRow);

                        ApprEntry2 := ApprEntry;
                        ApprEntry2."Approver ID" := ApprovalSharing."Shared to User ID";
                    UNTIL ApprEntry.NEXT = 0;

                    DocumentHTML.Append(Text022);
                END;
            UNTIL ApprovalSharing.NEXT = 0;
        END;
        EXIT(DocumentHTML.Text());
        */
    END;

    procedure CreateTableHeaderRow(var BigString: Codeunit "CDC BigString Management")
    var
        CaptureMgnt: Codeunit "CDC Capture Management";
        LeftAlignedTd: Text[1024];
        RightAlignedTd: Text[1024];
        Handled: Boolean;
    begin
        Handled := FALSE;
        IF Handled THEN
            EXIT;

        CLEAR(BigString);

        LeftAlignedTd := Text027;
        RightAlignedTd := Text028;

        BigString.Append('<tr>');
        BigString.Append(CaptureMgnt.Replace(LeftAlignedTd, Text003, Text013, FALSE));
        BigString.Append(CaptureMgnt.Replace(LeftAlignedTd, Text003, Text014, FALSE));
        BigString.Append(CaptureMgnt.Replace(LeftAlignedTd, Text003, Text015, FALSE));
        BigString.Append(CaptureMgnt.Replace(LeftAlignedTd, Text003, Text016, FALSE));
        BigString.Append(CaptureMgnt.Replace(LeftAlignedTd, Text003, Text017, FALSE));
        BigString.Append(CaptureMgnt.Replace(RightAlignedTd, Text003, Text018, FALSE));
        BigString.Append(CaptureMgnt.Replace(RightAlignedTd, Text003, Text019, FALSE));

        BigString.Append('</tr>');
    end;

    procedure CreateTableRow(PurchHeader: Record "Purchase Header"; ApprEntry: Record "Approval Entry"; var String: Text)
    var
        Currency: Record Currency;
        CaptureMgnt: Codeunit "CDC Capture Management";
        Handled: Boolean;
        TotalAmountExclVAT: Decimal;
        TotalAmountInclVAT: Decimal;
        LeftAlignedTd: Text[1024];
        RightAlignedTd: Text[1024];
    begin
        Handled := false;
        //OnBeforeCreateTableRow2(PurchHeader, ApprEntry, String, Handled);
        if Handled then
            exit;

        String := '';

        if (PurchHeader."Document Type" = PurchHeader."Document Type"::Invoice) and (PurchHeader."Due Date" <= Today) then begin
            LeftAlignedTd := Text006;
            RightAlignedTd := Text007;
        end else begin
            LeftAlignedTd := Text004;
            RightAlignedTd := Text005;
        end;

        TotalAmountExclVAT := ApprEntry.Amount;
        TotalAmountInclVAT := ApprEntry."CDC Amount Incl. VAT";

        if PurchHeader."Currency Code" = '' then
            Currency.InitRoundingPrecision()
        else
            Currency.Get(PurchHeader."Currency Code");

        String += '<tr>';
        if PurchHeader."On Hold" = '' then
            String += CaptureMgnt.Replace(LeftAlignedTd, Text003, Format(PurchHeader."Document Type") + ' ' + PurchHeader."No.", false)
        else
            String += CaptureMgnt.Replace(LeftAlignedTd, Text003, Format(PurchHeader."Document Type") + ' ' + PurchHeader."No." + ' ' + Text001, false);
        String += CaptureMgnt.Replace(LeftAlignedTd, Text003, PurchHeader."Buy-from Vendor No." + ' - ' + PurchHeader."Buy-from Vendor Name", false);
        String += CaptureMgnt.Replace(LeftAlignedTd, Text003, Format(PurchHeader."Document Date"), false);
        String += CaptureMgnt.Replace(LeftAlignedTd, Text003, Format(PurchHeader."Due Date"), false);
        String += CaptureMgnt.Replace(LeftAlignedTd, Text003, PurchHeader."Currency Code", false);
        String += CaptureMgnt.Replace(RightAlignedTd, Text003,
          Format(TotalAmountExclVAT, 0, StrSubstNo('<Precision,%1><Standard Format,0>', Currency."Amount Decimal Places")), false);
        String += CaptureMgnt.Replace(RightAlignedTd, Text003,
          Format(TotalAmountInclVAT, 0, StrSubstNo('<Precision,%1><Standard Format,0>', Currency."Amount Decimal Places")), false);

        //OnCreateTableRowOnBeforeAppendRow2(PurchHeader, ApprEntry, String);
        String += '</tr>';
    end;

    procedure GetAmountInclVAT(PurchHeader: Record "Purchase Header") Amount: Decimal
    var
        PurchLine: Record "Purchase Line";
        TempVATAmountLine0: Record "VAT Amount Line" temporary;
    begin
        PurchLine.SetPurchHeader(PurchHeader);
        PurchLine.CalcVATAmountLines(1, PurchHeader, PurchLine, TempVATAmountLine0);

        IF TempVATAmountLine0.FINDSET THEN
            REPEAT
                Amount := Amount + TempVATAmountLine0."Amount Including VAT";
            UNTIL TempVATAmountLine0.NEXT = 0;
    end;

}
#pragma warning restore AL0432