pageextension 61180 "PTE ListLanguageCode" extends "CDC Continia User Setup List"
{
    layout
    {
        addlast(Group)
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
