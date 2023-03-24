codeunit 61180 "Continia Reminders Functions"
{
    TableNo = 6175277;
    trigger OnRun()
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
        RecRef: RecordRef;
        FRef: FieldRef;


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
        ContiniaUser: Record "CDC Continia User Setup";
        CDCApprovalManagement: Codeunit 6085722;
    begin
        RecRef.SetTable(ContiniaUser);
        EXIT(CDCApprovalManagement.GetApprovalHyperlink(ContiniaUser."Continia User ID"));
    end;
}
