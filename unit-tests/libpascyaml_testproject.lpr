program libpascyaml_testproject;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, GuiTestRunner, pascyamltestcase, libpascyaml;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

