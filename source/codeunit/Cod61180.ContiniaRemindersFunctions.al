codeunit 61180 "Continia Reminders Functions"
{
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
}
