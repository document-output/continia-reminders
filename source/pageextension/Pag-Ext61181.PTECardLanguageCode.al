pageextension 61181 "PTE CardLanguageCode" extends "CDC Continia User Setup Card"
{
    layout
    {
        addlast(General)
        {
            field("PTE User Language Code"; Rec."PTE User Language Code")
            {
                ToolTip = 'Specifies the preferred language code of the user.';
                ApplicationArea = All;
                Enabled = true;
            }
        }
    }
}
