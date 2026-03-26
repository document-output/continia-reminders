#pragma warning disable AL0432
/// <summary>
/// This codeunit is intended to be executed as Business Central Job Queue entry
/// </summary>
codeunit 61181 "DOADV Send DC Mails"
{
    Permissions = tabledata "Approval Entry" = rm,
                  tabledata "CDC Event Register" = ri,
                  tabledata "CDC Event Entry" = ri,
                  tabledata "CDC Event Entry Comment" = ri;

    trigger OnRun()
    begin
        SendApprovalEmails();
        // #TODO SendReminderEmails();
    end;

    var
        InvalidEmails: Text;

    /// <summary>
    /// This procedures is identifying users that needs to be informed about their open approval entries
    /// </summary>
    internal procedure SendApprovalEmails()
    var
        ApprovalFunctions: Codeunit "DOADV DC Approval Notif. Mgt.";
        DCSetup: Record "CDC Document Capture Setup";
        ContiniaUserSetup: Record "CTS-CBF Continia User Setup";
        Window: Dialog;
        QueuedMailsCounter: Integer;
        RecCount: Integer;
        i: Integer;
        SendMail: Boolean;
        LblSendFollowUpMails: Label 'Sending followup emails...\@1@@@@@@@@@@@@@@@@@@@@@@@@@@';
        LblQueuenMails: Label '%1 email(s) have been queued for sending.';
    begin
        DCSetup.Get();
        Clear(InvalidEmails);

        if ContiniaUserSetup.FindSet() then begin
            if GuiAllowed then begin
                Window.Open(LblSendFollowUpMails);
                RecCount := ContiniaUserSetup.Count;
            end;

            repeat
                Clear(SendMail);

                if GuiAllowed then begin
                    i := i + 1;
                    Window.Update(1, CalcProgress(RecCount, i));
                end;

                // Find out if user has open approval entries that requires email notification
                if ApprovalFunctions.SendApprovalEmailtoUser(DCSetup, ContiniaUserSetup."Continia User ID") then begin
                    // Queue email for current user
                    QueueMailToContiniaUser(ContiniaUserSetup, 'DC-APPROVAL-MAIL');
                    QueuedMailsCounter += 1;
                end;
            until ContiniaUserSetup.Next() = 0;
        end;

        // Inform the user about the number of queued emails
        if GuiAllowed then begin
            Window.Close();
            Message(LblQueuenMails, QueuedMailsCounter);
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

    /// <summary>
    /// Creates a Document Output queue record for the passed Continia User Setup user
    /// </summary>
    /// <param name="UserSetup">Continia User Setup record</param>
    /// <param name="TemplateCode">Document Ouput Template Code</param>
    local procedure QueueMailToContiniaUser(UserSetup: record "CTS-CBF Continia User Setup"; TemplateCode: Code[20])
    var
        EMailTemplateHeader: Record "CDO E-Mail Template Header";
        EMailTemplateLine: Record "CDO E-Mail Template Line";
        FilterRecord: RecordRef;
        VariantRecord: Variant;
    begin

        EMailTemplateHeader.GET(TemplateCode);
        UserSetup.SETRECFILTER;
        FilterRecord.GETTABLE(UserSetup);
        VariantRecord := UserSetup;

        if EMailTemplateLine.Get(EMailTemplateHeader."Code", UserSetup."DOADV User Language Code", '') then
            EMailTemplateLine.QueueMail(FilterRecord, VariantRecord, 0, 0);
    end;

}
#pragma warning restore AL0432