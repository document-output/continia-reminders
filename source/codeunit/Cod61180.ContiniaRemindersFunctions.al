codeunit 61180 "Continia Reminders Functions"
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


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDO Events", 'OnGetVariantRecord', '', true, true)]
    procedure OnGetVariantRecord(TableNo: Integer; VAR VariantRecord: Variant; VAR IsHandled: Boolean)
    var
        myInt: Integer;
        ContiniaUserSetup: Record 6086002;

    begin
        ContiniaUserSetup.FindSet();
        VariantRecord := ContiniaUserSetup;
        IsHandled := true;
    end;

    procedure GetApprovalURL(var RecRef: RecordRef): Text[1024]
    var
        ContiniaUserSetup: Record "CDC Continia User Setup";
        CDCApprovalManagement: Codeunit 6085722;
        DCAppMgt: Codeunit "CDC Approval Management";
    begin
        RecRef.SetTable(ContiniaUserSetup);
        EXIT(DCAppMgt.GetApprovalHyperlink(ContiniaUserSetup."Continia User ID"));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDO Events", 'OnPrepareMail', '', true, true)]
    local procedure OnPrepareMail(var EMailTemplateLine: Record 6175284; VAR DOFile: Record 6175301; VAR FilterRecord: RecordRef; Recipients: Text; Cc: Text; Bcc: Text; VAR Subject: Text; VAR MailBody: Text)
    begin
        MailBody := CopyOfCDO_InsertMergeField(MailBody, '%ApprovalEntries', GetApprovalEntries(FilterRecord));
    end;

    procedure CopyOfCDO_InsertMergeField(OldString: Text; Id: Text; SubString: Text): Text;
    var
        Pos: Integer;
    begin
        Pos := STRPOS(OldString, Id);
        WHILE Pos > 0 DO BEGIN
            OldString := DELSTR(OldString, Pos, STRLEN(Id));
            OldString := INSSTR(OldString, SubString, Pos);
            Pos := STRPOS(OldString, Id);
        end;
        EXIT(OldString);
    end;


    procedure GetApprovalEntries(var RecRef: RecordRef): Text
    var
        ContiniaUser: Record "CDC Continia User Setup";
        ApprEntry: Record "Approval Entry";
        ApprEntry2: Record "Approval Entry";
        ApprovalSharing: Record "CDC Approval Sharing";
        ContiniaUserSetup: Record "CDC Continia User Setup";
        ContiniaUserSetup2: Record "CDC Continia User Setup";
        DocumentHTML: Codeunit "Big String Management";
        PurchHeader: Record "Purchase Header";
        PurchApprovalEMail: Codeunit "CDC Purch. Approval E-Mail";
        TableRow: Codeunit "Big String Management";
        DCAppMgt: Codeunit "CDC Approval Management";
        HTML: Codeunit "Big String Management";
        ApprovalEntries: Text;
    begin
        RecRef.SetTable(ContiniaUserSetup);
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
    END;

    procedure CreateTableHeaderRow(var BigString: Codeunit "Big String Management")
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

    procedure CreateTableRow(PurchHeader: Record "Purchase Header"; ApprEntry: Record "Approval Entry"; var BigString: Codeunit "Big String Management")
    var
        Currency: Record Currency;
        CaptureMgnt: Codeunit "CDC Capture Management";
        LeftAlignedTd: Text[1024];
        RightAlignedTd: Text[1024];
        TotalAmountExclVAT: Decimal;
        TotalAmountInclVAT: Decimal;
        Handled: Boolean;
    begin
        CLEAR(BigString);

        IF (PurchHeader."Document Type" = PurchHeader."Document Type"::Invoice) AND (PurchHeader."Due Date" <= TODAY) THEN BEGIN
            LeftAlignedTd := Text006;
            RightAlignedTd := Text007;
        END ELSE BEGIN
            LeftAlignedTd := Text004;
            RightAlignedTd := Text005;
        END;

        TotalAmountExclVAT := ApprEntry.Amount;
        TotalAmountInclVAT := GetAmountInclVAT(PurchHeader);

        IF PurchHeader."Currency Code" = '' THEN
            Currency.InitRoundingPrecision
        ELSE
            Currency.GET(PurchHeader."Currency Code");

        WITH PurchHeader DO BEGIN
            BigString.Append('<tr>');
            IF "On Hold" = '' THEN
                BigString.Append(CaptureMgnt.Replace(LeftAlignedTd, Text003, FORMAT("Document Type") + ' ' + "No.", FALSE))
            ELSE
                BigString.Append(CaptureMgnt.Replace(LeftAlignedTd, Text003, FORMAT("Document Type") + ' ' + "No." + ' ' + Text001, FALSE));
            BigString.Append(CaptureMgnt.Replace(LeftAlignedTd, Text003, "Buy-from Vendor No." + ' - ' + "Buy-from Vendor Name", FALSE));
            BigString.Append(CaptureMgnt.Replace(LeftAlignedTd, Text003, FORMAT("Document Date"), FALSE));
            BigString.Append(CaptureMgnt.Replace(LeftAlignedTd, Text003, FORMAT("Due Date"), FALSE));
            BigString.Append(CaptureMgnt.Replace(LeftAlignedTd, Text003, "Currency Code", FALSE));
            BigString.Append(CaptureMgnt.Replace(RightAlignedTd, Text003,
              FORMAT(TotalAmountExclVAT, 0, STRSUBSTNO('<Precision,%1><Standard Format,0>', Currency."Amount Decimal Places")), FALSE));
            BigString.Append(CaptureMgnt.Replace(RightAlignedTd, Text003,
              FORMAT(TotalAmountInclVAT, 0, STRSUBSTNO('<Precision,%1><Standard Format,0>', Currency."Amount Decimal Places")), FALSE));
            BigString.Append('</tr>');
        END;
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
