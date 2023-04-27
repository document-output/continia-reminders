codeunit 61181 "Big String Management"
{
    trigger OnRun()
    begin
    end;

    var
        BigString: Text;

    procedure Append(Text: Text[1024])
    begin
        BigString += Text;
    end;

    procedure IndexOf(Text: Text[1024]): Integer
    begin
        // IndexOf is zero based
        EXIT(STRPOS(BigString, Text) - 1);
    end;

    internal procedure Clear()
    begin
        BigString := '';
    end;

    internal procedure SubString(StartIndex: Integer; Length: Integer): Text[1024]
    begin
        EXIT(COPYSTR(BigString, StartIndex + 1, Length))
    end;

    procedure Replace(OldValue: Text[1024]; NewValue: Text)
    var
        Index: Integer;
    begin
        IF OldValue = NewValue THEN
            EXIT;

        Index := 1;

        WHILE (Index >= 0) DO BEGIN
            IF (STRPOS(COPYSTR(BigString, Index), OldValue) > 0) THEN
                Index := STRPOS(COPYSTR(BigString, Index), OldValue) + (Index - 1)
            ELSE
                Index := -1;

            IF Index > 0 THEN BEGIN
                BigString := DELSTR(BigString, Index, STRLEN(OldValue));
                BigString := INSSTR(BigString, NewValue, Index);
                Index += STRLEN(NewValue);
            END;
        END;
    end;

    procedure Replace2(OldValue: Text[1024]; var NewBigStringMgnt: Codeunit "Big String Management")
    begin
        Replace(OldValue, NewBigStringMgnt.Text);
    end;

    procedure LoadFromStream(var ReadStream: InStream)
    var
        Data: Text[1024];
    begin
        WHILE NOT ReadStream.EOS DO BEGIN
            ReadStream.READTEXT(Data);
            Append(Data);
        END;
    end;

    procedure Length(): Integer
    begin
        EXIT(STRLEN(BigString));
    end;

    procedure Text(): Text
    begin
        EXIT(BigString);
    end;
}

