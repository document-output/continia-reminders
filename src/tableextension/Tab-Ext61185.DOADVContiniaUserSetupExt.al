tableextension 61185 "DOADV Continia User Setup Ext." extends "CTS-CBF Continia User Setup"
{
    fields
    {
        field(61180; "DOADV User Language Code"; Code[20])
        {
            DataClassification = CustomerContent;
            TableRelation = Language.Code;
            Caption = 'User Language Code';
        }
        field(61181; "Salesperson Code"; Code[20])
        {
            TableRelation = "Salesperson/Purchaser".Code;
            Caption = 'Salesperson Code';
            FieldClass = FlowField;
            CalcFormula = Lookup("User Setup"."Salespers./Purch. Code" where("User Id" = field("Continia User ID")));
        }
    }
}