unit umain;

// this version cropped for microdos 20161128

{$mode objfpc}{$H+}

interface

uses sysutils,classes,retromalina,platform;

const ver='Ultibo MicroDOS v. 0.03 --- 2017.01.07';

procedure main1;
procedure main2;

implementation


procedure main1 ;

var i:integer;

begin

// hide all sprites

for i:=0 to 15 do lpoke($2060040+4*i,$11041104);

// --------- main program start

lpoke ($2060008,0);
lpoke ($2060020,1792);
lpoke ($2060024,1120);
setataripallette(0);
cls(147);
outtextxyz(296,16,ver,157,4,2);

end;


procedure main2;

var k:integer;

begin
k:=lpeek($2060000);
repeat sleep(1) until lpeek($2060000)<>k;
end;

end.

