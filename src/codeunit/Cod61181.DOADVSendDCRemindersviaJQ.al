codeunit 61181 "DOADV Send DC Reminders via JQ"
{
    Permissions = tabledata "Approval Entry" = rm,
                  tabledata "CDC Event Register" = ri,
                  tabledata "CDC Event Entry" = ri,
                  tabledata "CDC Event Entry Comment" = ri;

    trigger OnRun()
    begin
        SendApprovalEmails();
        //SendReminderEmails();
    end;

    var
        InvalidEmails: Text;

    internal procedure SendApprovalEmails()
    var
        DCSetup: Record "CDC Document Capture Setup";
        ContiniaUserSetup: Record "CTS-CBF Continia User Setup";
        ContiniaUserSetup2: Record "CTS-CBF Continia User Setup";
        ApprEntry: Record "Approval Entry";
#if not CLEAN27
#pragma warning disable AL0432
        ApprovalSharing: Record "CDC Approval Sharing";
#pragma warning restore AL0432
#endif
        DCAppMgt: Codeunit "CDC Approval Management";
        Window: Dialog;
        FromEventEntryNo: Integer;
        ToEventEntryNo: Integer;
        RecCount: Integer;
        i: Integer;
        SkipEmail: Boolean;
        SendMail: Boolean;
        LblSendFollowUpMails: Label 'Sending followup emails...\@1@@@@@@@@@@@@@@@@@@@@@@@@@@';
    begin
        DCSetup.Get();
        Clear(InvalidEmails);


        ApprEntry.SetCurrentKey("Approver ID", Status);
        ApprEntry.SetRange("Table ID", Database::"Purchase Header");
        ApprEntry.SetRange(Status, ApprEntry.Status::Open);

        if ContiniaUserSetup.FindSet() then begin
            if GuiAllowed then begin
                Window.Open(LblSendFollowUpMails);
                RecCount := ContiniaUserSetup.Count;
            end;

            FromEventEntryNo := GetLastEventEntry() + 1;
            ToEventEntryNo := FromEventEntryNo;

            repeat
                Clear(SendMail);

                if GuiAllowed then begin
                    i := i + 1;
                    Window.Update(1, CalcProgress(RecCount, i));
                end;
                SkipEmail := false;

#pragma warning disable AL0432
                DCAppMgt.FilterApprovalSharingFromUser(ApprovalSharing, ContiniaUserSetup."Continia User ID");
#pragma warning restore AL0432
                ApprovalSharing.SetFilter("Send E-mail To", '<>%1', ApprovalSharing."Send E-mail To"::"Only Original Approver");
                if ApprovalSharing.IsEmpty then begin
                    ApprEntry.SetRange("Approver ID", ContiniaUserSetup."Continia User ID");
                    if ApprEntry.FindSet() then
                        repeat
                            if IncludeApprovalEntry(DCSetup, ApprEntry) then
                                SendMail := true;
                        until ApprEntry.Next() = 0;

                end else begin
#pragma warning disable AL0432
                    DCAppMgt.FilterApprovalSharingToUser(ApprovalSharing, ContiniaUserSetup."Continia User ID");
#pragma warning restore AL0432
                    ApprovalSharing.SetFilter("Send E-mail To", '<>%1', ApprovalSharing."Send E-mail To"::"Only Original Approver");
                    if ApprovalSharing.FindSet() then
                        repeat
                            ApprEntry.SetRange("Approver ID", ApprovalSharing."Owner User ID");
                            if ApprEntry.FindSet() then begin
                                ContiniaUserSetup2.Get(ApprEntry."Approver ID");
                                repeat
                                    if IncludeApprovalEntry(DCSetup, ApprEntry) then
                                        SendMail := true;
                                until ApprEntry.Next() = 0;
                            end;
                        until ApprovalSharing.Next() = 0;
                end;
                // If the user has an own or shared approval entry we queue an email for him/her in DO
                if SendMail then
                    QueueMailToContiniaUser(ContiniaUserSetup);
            until ContiniaUserSetup.Next() = 0;
        end;
    end;

    procedure CalcProgress(var TotalCount: Integer; var Index: Integer): Integer
    begin
        exit(Round(Index / TotalCount * 10000, 1, '>'));
    end;

    procedure GetLastEventEntry(): Integer
    var
        EventEntry: Record "CDC Event Entry";
    begin
        EventEntry.LockTable();
        if EventEntry.FindLast() then
            exit(EventEntry."Entry No.");
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

    local procedure QueueMailToContiniaUser(UserSetup: record "CTS-CBF Continia User Setup")
    var
        EMailTemplateHeader: Record "CDO E-Mail Template Header";
        EMailTemplateLine: Record "CDO E-Mail Template Line";
        FilterRecord: RecordRef;
        VariantRecord: Variant;
    begin

        EMailTemplateHeader.GET('DC-REMINDER');
        UserSetup.SETRECFILTER;
        FilterRecord.GETTABLE(UserSetup);
        VariantRecord := UserSetup;

        if EMailTemplateLine.Get(EMailTemplateHeader."Code", UserSetup."DOADV User Language Code", '') then
            EMailTemplateLine.QueueMail(FilterRecord, VariantRecord, 0, 0);

        /*


                ConUserSetup.Copy(UserSetup);
                RecRef.GetTable(ConUserSetup);
                DocOutput.SetRecRefFilter(RecRef); // Includes Marks
                DocOutput.DocHandle(true, ConUserSetup, ConUserSetup.FieldNo("DOADV User Language Code"), ConUserSetup.GetView(true)); // Does not include marks
                */
    end;

}
