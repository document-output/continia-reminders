tableextension 61180 "DOADV Continia User Setup Ext." extends "CTS-CBF Continia User Setup"
{
    fields
    {
        field(61180; "DOADV User Language Code"; Code[20])
        {
            DataClassification = ToBeClassified;
            TableRelation = Language.Code;
            Caption = 'User Language Code';
        }
    }
}