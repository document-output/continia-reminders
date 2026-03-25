pageextension 61180 "DOADV User Setup List Ext" extends "CTS-CBF User Setup List"
{
    layout
    {
        addlast(UserSetupList)
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