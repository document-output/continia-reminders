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
    }
}