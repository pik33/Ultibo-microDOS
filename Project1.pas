program Project1;

{$mode objfpc}{$H+}

uses
  GlobalConfig,
  GlobalConst,
  GlobalTypes,
  Platform,
  BCM2837,
  SysUtils,
  Classes,
  FileSystem,  {Include the file system core and interfaces}
  FATFS,       {Include the FAT file system driver}
  MMC,         {Include the MMC/SD core to access our SD card}
  BCM2710,
  Keyboard,    {Keyboard uses USB so that will be included automatically}
  DWCOTG,
  retromalina,
  umain;


var s,currentdir,currentdir2:string;
    sr:tsearchrec;
    filenames:array[0..1000,0..1] of string;
    l,i,j,ilf,ild:integer;
    sel:integer=0;
    selstart:integer=0;
    fn:string;
    fs:integer;
    workdir:string;
    pause1a:boolean=true;
    ch:tkeyboardreport;
    keyboardstatus:array[0..255]of byte;
    activekey:byte=0;
    rptcnt:byte=0;
    buf:Pbyte;

// ---- procedures


procedure sort;

// A simple bubble sort for filenames

var i,j:integer;
    s,s2:string;

begin
repeat
  j:=0;
  for i:=0 to ilf-2 do
    begin
    if lowercase(filenames[i,0])>lowercase(filenames[i+1,0]) then
      begin
      s:=filenames[i,0]; s2:=filenames[i,1];
      filenames[i,0]:=filenames[i+1,0];
      filenames[i,1]:=filenames[i+1,1];
      filenames[i+1,0]:=s; filenames[i+1,1]:=s2;
      j:=1;
      end;
    end;
until j=0;
end;


procedure dirlist(dir:string);

begin
currentdir2:=dir;
setcurrentdir(currentdir2);
currentdir2:=getcurrentdir;
if copy(currentdir2,length(currentdir2),1)<>'\' then currentdir2:=currentdir2+'\';
ilf:=0;


currentdir:=currentdir2+'*.u';
if findfirst(currentdir,faAnyFile,sr)=0 then
  repeat
  filenames[ilf,0]:=sr.name;
  filenames[ilf,1]:='';
  ilf+=1;
  until (findnext(sr)<>0) or (ilf=1000);
sysutils.findclose(sr);

sort;

box(476,132,840,32,149);
if ilf<26 then ild:=ilf-1 else ild:=26;
for i:=0 to ild do
  begin
  if filenames[i,1]='' then l:=length(filenames[i,0])-2 else  l:=length(filenames[i,0]);
  if filenames[i,1]='' then  s:=copy(filenames[i,0],1,length(filenames[i,0])-2) else s:=filenames[i,0];
  if length(s)>40 then begin s:=copy(s,1,40); l:=40; end;
  for j:=1 to length(s) do if s[j]='_' then s[j]:=' ';
  if filenames[i,1]='' then outtextxyz(896-8*l,132+32*i,s,157,2,2);
  end;
sel:=0; selstart:=0;
end;


procedure copyfile2(src,dest:string);

var fh1,fh2,il:integer;

begin

buf:=Pbyte($3000000);
fh1:=fileopen(src,$40);
fh2:=filecreate(dest);
il:=fileread(fh1,buf^,16000000);
filewrite(fh2,buf^,il);
fileclose(fh1);
fileclose(fh2);
end;


//------------------- The main loop

begin

initmachine;

fs:=1;
workdir:='C:\ultibo\';
songtime:=0;
pause1a:=true;
siddelay:=20000;
setcurrentdir(workdir);

lpoke($206000c,0);
lpoke ($2060008,0);
lpoke ($2060020,1792);
lpoke ($2060024,1120);
setataripallette(0);
main1;
dirlist('C:\ultibo\');
sleep(1);
outtextxyz(440,1060,'Select a program with up/down arrows, then Enter to run',157,2,2);
for i:=0 to 255 do keyboardstatus[i]:=0;
startreportbuffer;

repeat
  main2;

  ch:=getkeyboardreport;
  if (ch[2]<>0) and (ch[2]<>255) then activekey:=ch[2];
  if (ch[2]<>0) and (activekey>0) then inc(rptcnt);
  if ch[2]=0 then begin rptcnt:=0; activekey:=0; end;
  if rptcnt>26 then rptcnt:=24 ;
  if (rptcnt=1) or (rptcnt=24) then poke($2060028,byte(translatescantochar(activekey,0)));

  if peek($2060028)=23 then
    begin
    dpoke($2060028,0);
    if sel<ild then
      begin
      box(476,132+32*sel,840,32,147);
      if filenames[sel+selstart,1]='' then l:=length(filenames[sel+selstart,0])-2 else  l:=length(filenames[sel+selstart,0]);
      if filenames[sel+selstart,1]='' then  s:=copy(filenames[sel+selstart,0],1,length(filenames[sel+selstart,0])-2) else s:=filenames[sel+selstart,0];
      if length(s)>40 then begin s:=copy(s,1,40); l:=40; end;
      for j:=1 to length(s) do if s[j]='_' then s[j]:=' ';
      if filenames[sel+selstart,1]='' then outtextxyz(896-8*l,132+32*(sel),s,157,2,2);
      if filenames[sel+selstart,1]='[DIR]' then begin outtextxyz(896-8*l,132+32*(sel),s,157,2,2);  outtextxyz(1672,132+32*(sel),'[DIR]',157,2,2);   end;
      sel+=1;
      box(476,132+32*sel,840,32,149);
      if filenames[sel+selstart,1]='' then l:=length(filenames[sel+selstart,0])-2 else  l:=length(filenames[sel+selstart,0]);
      if filenames[sel+selstart,1]='' then  s:=copy(filenames[sel+selstart,0],1,length(filenames[sel+selstart,0])-2) else s:=filenames[sel+selstart,0];
      if length(s)>40 then begin s:=copy(s,1,40); l:=40; end;
      for j:=1 to length(s) do if s[j]='_' then s[j]:=' ';
      if filenames[sel+selstart,1]='' then outtextxyz(896-8*l,132+32*(sel),s,157,2,2);
      if filenames[sel+selstart,1]='[DIR]' then begin outtextxyz(896-8*l,132+32*(sel),s,157,2,2);  outtextxyz(1672,132+32*(sel),'[DIR]',157,2,2);   end;
      end
    else if sel+selstart<ilf-1 then
      begin
      selstart+=1;
      box2(460,118,1782,1008,147);
      box(476,132+32*sel,840,32,149);
      for i:=0 to ild do
        begin
        if filenames[i+selstart,1]='' then l:=length(filenames[i+selstart,0])-4 else  l:=length(filenames[i+selstart,0]);
        if filenames[i+selstart,1]='' then  s:=copy(filenames[i+selstart,0],1,length(filenames[i+selstart,0])-2) else s:=filenames[i+selstart,0];
        if length(s)>40 then begin s:=copy(s,1,40); l:=40; end;
        for j:=1 to length(s) do if s[j]='_' then s[j]:=' ';
        if filenames[i+selstart,1]='' then outtextxyz(896-8*l,132+32*i,s,157,2,2);
        if filenames[i+selstart,1]='[DIR]' then begin outtextxyz(896-8*l,132+32*i,s,157,2,2);  outtextxyz(1672,132+32*i,'[DIR]',157,2,2);   end;
        end;
      end;
    end;

  if peek($2060028)=24 then
     begin
      dpoke($2060028,0);
      if sel>0 then
        begin
        box(476,132+32*sel,840,32,147);
        if filenames[sel+selstart,1]='' then l:=length(filenames[sel+selstart,0])-2 else  l:=length(filenames[sel+selstart,0]);
        if filenames[sel+selstart,1]='' then  s:=copy(filenames[sel+selstart,0],1,length(filenames[sel+selstart,0])-2) else s:=filenames[sel+selstart,0];
        if length(s)>40 then begin s:=copy(s,1,40); l:=40; end;
        for j:=1 to length(s) do if s[j]='_' then s[j]:=' ';
        if filenames[sel+selstart,1]='' then outtextxyz(896-8*l,132+32*(sel),s,157,2,2);
        if filenames[sel+selstart,1]='[DIR]' then begin outtextxyz(896-8*l,132+32*(sel),s,157,2,2);  outtextxyz(1672,132+32*(sel),'[DIR]',157,2,2);   end;
        sel-=1;
        box(476,132+32*sel,840,32,149);
        if filenames[sel+selstart,1]='' then l:=length(filenames[sel+selstart,0])-2 else  l:=length(filenames[sel+selstart,0]);
        if filenames[sel+selstart,1]='' then  s:=copy(filenames[sel+selstart,0],1,length(filenames[sel+selstart,0])-2) else s:=filenames[sel+selstart,0];
        if length(s)>40 then begin s:=copy(s,1,40); l:=40; end;
        for j:=1 to length(s) do if s[j]='_' then s[j]:=' ';
        if filenames[sel+selstart,1]='' then outtextxyz(896-8*l,132+32*(sel),s,157,2,2);
        if filenames[sel+selstart,1]='[DIR]' then begin outtextxyz(896-8*l,132+32*(sel),s,157,2,2);  outtextxyz(1672,132+32*(sel),'[DIR]',157,2,2);   end;
        end
      else if sel+selstart>0 then
        begin
        selstart-=1;
        box2(460,118,1782,1008,147);
        box(476,132+32*sel,840,32,149);
        for i:=0 to ild do
          begin
          if filenames[i+selstart,1]='' then l:=length(filenames[i+selstart,0])-2 else  l:=length(filenames[i+selstart,0]);
          if filenames[i+selstart,1]='' then s:=copy(filenames[i+selstart,0],1,length(filenames[i+selstart,0])-2) else s:=filenames[i+selstart,0];
          if length(s)>40 then begin s:=copy(s,1,40); l:=40; end;
          for j:=1 to length(s) do if s[j]='_' then s[j]:=' ';
          if filenames[i+selstart,1]='' then outtextxyz(896-8*l,132+32*i,s,157,2,2);
          if filenames[i+selstart,1]='[DIR]' then begin outtextxyz(896-8*l,132+32*i,s,157,2,2);  outtextxyz(1672,132+32*i,'[DIR]',157,2,2);   end;
          end;
        end;
      end;


    if peek($2060028)=13 then
      begin
      dpoke($2060028,0);

      fn:= currentdir2+filenames[sel+selstart,0];
      cls(147);
      outtextxyz( 16,16,'Starting '+ copy(filenames[sel+selstart,0],1,length(filenames[sel+selstart,0])-2) +'...',157,2,2);
      DeleteFile('C:\kernel7_l.img');
      RenameFile('C:\kernel7.img','C:\kernel7_l.img');
      raster:=traster.create(true);
      raster.start;
      copyfile2(fn,'c:\kernel7.img');
      systemrestart(0);
      end;
  until false;
end.

