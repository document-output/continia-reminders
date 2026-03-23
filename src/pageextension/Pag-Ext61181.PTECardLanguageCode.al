pageextension 61181 "PTE CardLanguageCode" extends "CTS-CBF User Setup Card"
{
    layout
    {
        addlast(General)
        {
            field("PTE User Language Code"; Rec."DOADV User Language Code")
            {
                ToolTip = 'Specifies the preferred language code of the user.';
                ApplicationArea = All;
                Enabled = true;
            }
        }
    }
}
