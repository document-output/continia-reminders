codeunit 61183 "DOADV Reminder Event Mgt"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDO Events", 'OnPrepareMail', '', true, true)]
    local procedure CDOEvents_OnPrepareMail(var EMailTemplateLine: Record "CDO E-Mail Template Line"; var DOFile: Record "CDO File"; var FilterRecord: RecordRef; Recipients: Text; Cc: Text; Bcc: Text; var Subject: Text; var MailBody: Text)
    var
        ReminderFunctions: Codeunit "DOADV DC Reminder Functions";
    begin
        ReminderFunctions.InsertUserApprovalEntriesToEmailBody(FilterRecord, MailBody);
    end;

    [BusinessEvent(false)]
    procedure OnBeforeAddApprovalEntryRowToMailBody(ApprovalEntry: Record "Approval Entry"; var TableRowTemplate: Text; PurchaseHeader: Record "Purchase Header"; var Handled: Boolean; var Success: Boolean)
    begin
    end;
}
