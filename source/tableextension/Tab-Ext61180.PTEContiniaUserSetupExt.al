tableextension 61180 "PTE Continia User Setup Ext." extends 6086002
{
    fields
    {
        field(61180; "PTE User Language Code"; Code[20])
        {
            DataClassification = ToBeClassified;
            TableRelation = Language.Code;
            Caption = 'User Language Code';
        }
    }
}