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
        END;
    end;

    var
        EventMgt: Codeunit "DOADV Reminder Event Mgt";

    internal procedure InsertUserApprovalEntriesToEmailBody(var FilterUserRecord: RecordRef; var MailBody: Text): Boolean
    var
        DCSetup: Record "CDC Document Capture Setup";
        DCAppMgt: Codeunit "CDC Approval Management";
        ApprovalSharing: Record "CDC Approval Sharing";
        ContiniaUserSetup: Record "CTS-CBF Continia User Setup";
        ApprEntry: Record "Approval Entry";
        HtmlManipulator: Codeunit "DOADV HTML Manipulator";
        TableRowTemplate: Text;
        DocCount: Integer;
    begin
        FilterUserRecord.SetTable(ContiniaUserSetup);

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

        DCAppMgt.FilterApprovalSharingFromUser(ApprovalSharing, ContiniaUserSetup."Continia User ID");
        ApprovalSharing.SetFilter("Send E-mail To", '<>%1', ApprovalSharing."Send E-mail To"::"Only Original Approver");
        if ApprovalSharing.IsEmpty then begin
            ApprEntry.SetRange("Approver ID", ContiniaUserSetup."Continia User ID");
            if ApprEntry.FindSet() then
                repeat
                    if IncludeApprovalEntry(DCSetup, ApprEntry) then begin
                        AddApprovalEntryDataToMailBodyTable(MailBody, ApprEntry, TableRowTemplate);
                        DocCount += 1;
                    end;
                until (ApprEntry.Next() = 0);

        end else begin
            DCAppMgt.FilterApprovalSharingToUser(ApprovalSharing, ContiniaUserSetup."Continia User ID");
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
        MailBody := MailBody.Replace('%APPROVALLINK', DCAppMgt.GetApprovalHyperlink(ContiniaUserSetup."Continia User ID"));
        MailBody := MailBody.Replace('%DOCCOUNT', Format(DocCount));
    end;

    local procedure AddApprovalEntryDataToMailBodyTable(var MailBody: Text; ApprovalEntry: Record "Approval Entry"; TableRowTemplate: Text): Boolean
    var
        PurchaseHeader: Record "Purchase Header";
        Currency: Record Currency;
        HtmlManipulator: Codeunit "DOADV HTML Manipulator";
        Handled: Boolean;
        Success: Boolean;
        LblOnHold: Label '(On Hold)';
    begin
        if not PurchaseHeader.Get(ApprovalEntry."Document Type", ApprovalEntry."Document No.") then
            exit;

        PurchaseHeader.CalcFields(Amount, "Amount Including VAT");

        if PurchaseHeader."Currency Code" = '' then
            Currency.InitRoundingPrecision()
        else
            Currency.Get(PurchaseHeader."Currency Code");


        // Try to replace the pre-defined placeholders in the table row template with real data from the approval entry and related purchase header
        TableRowTemplate := TableRowTemplate.Replace('%ENTRYNO', Format(ApprovalEntry."Entry No."));
        TableRowTemplate := TableRowTemplate.Replace('%DOCTYPE', Format(ApprovalEntry."Document Type"));

        if PurchaseHeader."On Hold" = '' then
            TableRowTemplate := TableRowTemplate.Replace('%DOCNO', StrSubstNo('%1 %2', PurchaseHeader."Document Type", PurchaseHeader."No."))
        else
            TableRowTemplate := TableRowTemplate.Replace('%DOCNO', StrSubstNo('%1 %2 %3', PurchaseHeader."Document Type", PurchaseHeader."No.", LblOnHold));

        TableRowTemplate := TableRowTemplate.Replace('%VENDOR', StrSubstNo('%1 %2', PurchaseHeader."Buy-from Vendor No.", PurchaseHeader."Buy-from Vendor Name"));
        TableRowTemplate := TableRowTemplate.Replace('%DOCDATE', Format(PurchaseHeader."Document Date"));
        // #TODO Due date in red
        TableRowTemplate := TableRowTemplate.Replace('%DUEDATE', Format(PurchaseHeader."Due Date"));
        TableRowTemplate := TableRowTemplate.Replace('%CURRENCY', Format(PurchaseHeader."Currency Code"));
        TableRowTemplate := TableRowTemplate.Replace('%AMTEXCLVAT', Format(PurchaseHeader."Amount Including VAT", 0, StrSubstNo('<Precision,%1><Standard Format,0>', Currency."Amount Decimal Places")));
        TableRowTemplate := TableRowTemplate.Replace('%AMTINCLVAT', Format(PurchaseHeader.Amount, 0, StrSubstNo('<Precision,%1><Standard Format,0>', Currency."Amount Decimal Places")));

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

    procedure CreateEventReg(FromEntryNo: Integer; ToEntryNo: Integer; EventArea: Option Status,Reminder)
    var
        EventReg: Record "CDC Event Register";
    begin
        EventReg.LockTable();
        EventReg.Init();
        EventReg."From Entry No." := FromEntryNo;
        EventReg."To Entry No." := ToEntryNo;
        EventReg.Area := EventArea;
        EventReg.Insert(true);
    end;
}
#pragma warning restore AL0432