unit pascyamltestcase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry;

type

  TTestCase1= class(TTestCase)
  published
    procedure TestHookUp;
  end;

implementation

procedure TTestCase1.TestHookUp;
begin
  Fail('Напишите ваш тест');
end;



initialization

  RegisterTest(TTestCase1);
end.

