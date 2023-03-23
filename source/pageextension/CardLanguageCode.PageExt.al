pageextension 61181 "PTE CardLanguageCode" extends "CDC Continia User Setup Card"
{
    layout
    {
        addlast(General)
        {
            field("PTE Language Code"; Rec."PTE Language Code")
            {
                ToolTip = 'Specifies the preferred language code of the user.';
                ApplicationArea = All;
                Enabled = true;
            }
        }
    }
}
