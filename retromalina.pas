// *****************************************************************************
// The retromachine unit for Raspberry Pi/Ultibo
// Ultibo v. 0.03 - 2016.11.19
// Piotr Kardasz
// pik33@o2.pl
// www.eksperymenty.edu.pl
// GPL 2.0 or higher
// uses combinedwaveforms.bin by Johannes Ahlebrand - MIT licensed
//******************************************************************************

// ----------------------------   This is still alpha quality code
// ----------------------------   Stripped version for MicroDOS

unit retromalina;

{$mode objfpc}{$H+}

interface

uses sysutils,classes,Platform,Framebuffer,keyboard,mouse,threads,GlobalConst,retro;

type Tsrcconvert=procedure(screen:pointer);

     // Retromachine main thread

TRetro = class(TThread)
     private
     protected
       procedure Execute; override;
     public
       Constructor Create(CreateSuspended : boolean);
     end;

TRaster = class(TThread)
     private
     protected
       procedure Execute; override;
     public
       Constructor Create(CreateSuspended : boolean);
     end;

var fh,filetype:integer;                // this needs cleaning...
    sfh:integer;                        // SID file handler
    play:word;
    p2:^integer;
    tim,t,t2,t3,ts,t6,time6502:int64;
    vblank1:byte;
    combined:array[0..1023] of byte;
    scope:array[0..959] of integer;
    db:boolean=false;
    debug:integer;
    sidtime:int64=0;
    timer1:int64=-1;
    siddelay:int64=20000;
    songtime,songfreq:int64;
    skip:integer;
    scj:integer=0;
    thread:TRetro;
    raster:TRaster;

    i,j,k,l,fh2,lines:integer;
    p,p3:pointer;
    b:byte;

    running:integer=0;

    scrconvert:Tsrcconvert;
    fb:pframebufferdevice;
    FramebufferProperties:TFramebufferProperties;
    kbd:array[0..15] of TKeyboarddata;
    m:array[0..128] of Tmousedata;


// prototypes

procedure initmachine;
procedure stopmachine;
procedure scrconvert16f(screen:pointer);
procedure setataripallette(bank:integer);
procedure cls(c:integer);
procedure putpixel(x,y,color:integer);
procedure putchar(x,y:integer;ch:char;col:integer);
procedure outtextxy(x,y:integer; t:string;c:integer);
procedure blit(from,x,y,too,x2,y2,length,lines,bpl1,bpl2:integer);
procedure box(x,y,l,h,c:integer);
procedure box2(x1,y1,x2,y2,color:integer);
function gettime:int64;
procedure poke(addr:integer;b:byte);
procedure dpoke(addr:integer;w:word);
procedure lpoke(addr:integer;c:cardinal);
procedure slpoke(addr,i:integer);
function peek(addr:integer):byte;
function dpeek(addr:integer):word;
function lpeek(addr:integer):cardinal;
function slpeek(addr:integer):integer;
procedure sethidecolor(c,bank,mask:integer);
procedure putcharz(x,y:integer;ch:char;col,xz,yz:integer);
procedure outtextxyz(x,y:integer; t:string;c,xz,yz:integer);


implementation

// ---- prototypes

procedure spritef(screen:pointer); forward;

constructor TRaster.Create(CreateSuspended : boolean);

begin
  FreeOnTerminate := True;
  inherited Create(CreateSuspended);
end;


procedure TRaster.Execute;
var i:int64;

begin
ThreadSetCPU(ThreadGetCurrent,CPU_ID_2);  sleep(1);
  repeat lpoke($206000c,random($1000000)); i:=gettime; repeat until gettime>i+random(40); until terminated;
end;

// ---- TRetro thread methods --------------------------------------------------

// ----------------------------------------------------------------------
// constructor: create the thread for the retromachine
// ----------------------------------------------------------------------

constructor TRetro.Create(CreateSuspended : boolean);

begin
  FreeOnTerminate := True;
  inherited Create(CreateSuspended);
end;



// ----------------------------------------------------------------------
// THIS IS THE MAIN RETROMACHINE THREAD
// - convert retromachine screen to raspberry screen
// - display sprites
// ----------------------------------------------------------------------

procedure TRetro.Execute;

var id:integer;

begin

running:=1;
id:=getcurrentthreadid  ;
ThreadSetCPU(ThreadGetCurrent,CPU_ID_3);
sleep(1);
repeat
  begin

  vblank1:=0;
  t:=clockgettotal;
  scrconvert16f(p2);
  tim:=clockgettotal-t;
  t:=clockgettotal;
  spritef(p2);
  ts:=clockgettotal-t;
  vblank1:=1;
  CleanDataCacheRange(integer(p2),9216000);
  lpoke($2060000,lpeek($2060000)+1);

  FramebufferDeviceSetOffset(fb,0,0,True);
  FramebufferDeviceWaitSync(fb);

  vblank1:=0;
  t:=clockgettotal;
  scrconvert16f(p2+2304000);
  tim:=clockgettotal-t;
  t:=clockgettotal;
  spritef(p2+2304000);
  ts:=clockgettotal-t;
  vblank1:=1;
  CleanDataCacheRange(integer(p2)+9216000,9216000);
  lpoke($2060000,lpeek($2060000)+1);

  FramebufferDeviceSetOffset(fb,0,1200,True);
  FramebufferDeviceWaitSync(fb);


  end;
until terminated;
running:=0;
end;

// ---- Retromachine procedures ------------------------------------------------

// ----------------------------------------------------------------------
// initmachine: start the machine
// constructor procedure: allocate ram, load data from files
// prepare all hardware things
// ----------------------------------------------------------------------

procedure initmachine;

var a,i:integer;
    bb:byte;
    fh2:integer;
    Entry:TPageTableEntry ;


begin

for i:=$2000000 to $20bFFFF do poke(i,0);
lpoke($2060004,$30000000);
lpoke($2060000,$00000000);

FramebufferInit;
//init the framebuffer
// TODO: if the screen is 1920x1080 init it to this resolution

fb:=FramebufferDevicegetdefault;
FramebufferDeviceRelease(fb);
Sleep(100);
FramebufferProperties.Depth:=32;
FramebufferProperties.PhysicalWidth:=1920;
FramebufferProperties.PhysicalHeight:=1200;
FramebufferProperties.VirtualWidth:=FramebufferProperties.PhysicalWidth;
FramebufferProperties.VirtualHeight:=FramebufferProperties.PhysicalHeight * 2;
FramebufferDeviceAllocate(fb,@FramebufferProperties);
sleep(100);
FramebufferDeviceGetProperties(fb,@FramebufferProperties);
p2:=Pointer(FramebufferProperties.Address);
cls(147);
while not DirectoryExists('C:\') do
  begin
  Sleep(10);
  end;
for i:=0 to 2047 do poke($2050000+i,st4font[i]);
thread:=tretro.create(true);                    // start frame refreshing thread
thread.start;
end;


//  ---------------------------------------------------------------------
//   procedure stopmachine
//   destructor for the retromachine
//   stop the process, free the RAM
//   rev. 2016.11.24
//  ---------------------------------------------------------------------

procedure stopmachine;
begin
thread.terminate;
repeat until running=0;
end;

function gettime:int64;

begin
result:=clockgettotal;
end;

//  ---------------------------------------------------------------------
//   BASIC type poke/peek procedures
//   works @ byte addresses
//   rev. 2016.11.24
// ----------------------------------------------------------------------

procedure poke(addr:integer;b:byte); inline;

begin
PByte(addr)^:=b;
end;

procedure dpoke(addr:integer;w:word); inline;

begin
PWord(addr and $FFFFFFFE)^:=w;
end;

procedure lpoke(addr:integer;c:cardinal); inline;

begin
PCardinal(addr and $FFFFFFFC)^:=c;
end;

procedure slpoke(addr,i:integer); inline;

begin
PInteger(addr and $FFFFFFFC)^:=i;
end;

function peek(addr:integer):byte; inline;

begin
peek:=Pbyte(addr)^;
end;

function dpeek(addr:integer):word; inline;

begin
dpeek:=PWord(addr and $FFFFFFFE)^;
end;

function lpeek(addr:integer):cardinal; inline;

begin
lpeek:=PCardinal(addr and $FFFFFFFC)^;
end;

function slpeek(addr:integer):integer;  inline;

begin
slpeek:=PInteger(addr and $FFFFFFFC)^;
end;


procedure blit(from,x,y,too,x2,y2,length,lines,bpl1,bpl2:integer);

// --- TODO - write in asm, add advanced blitting modes

var i,j:integer;
    b1,b2:integer;

begin
if lpeek($2060008)<16 then
  begin
  from:=from+x;
  too:=too+x2;
  for i:=0 to lines-1 do
    begin
    b2:=too+bpl2*(i+y2);
    b1:=from+bpl1*(i+y);
    for j:=0 to length-1 do
      poke(b2+j,peek(b1+j));
    end;
  end;
// TODO: use DMA; write for other color depths
end;


procedure scrconvert16f(screen:pointer);

var a,b:integer;
    e:integer;
label p1,p0,p002,p10,p11,p12,p20,p21,p22,p100,p101,p102,p103,p104,p111,p112,p999;

begin
a:=lpeek($2060004); // TODO! a:=0! Get a screen pointer from sys var !
e:=lpeek($206000c);
b:=$2010000;
                asm
                stmfd r13!,{r0-r12}   //Push registers
                ldr r1,a
               // add r1,#0x1000000
                mov r6,r1
                add r6,#1
                ldr r2,screen
                mov r12,r2
                add r12,#4
                ldr r3,b
  //              add r3,#0x10000
                mov r5,r2
                                    //upper border
                mov r0,#40
p111:           add r5,#7680
                mov r9,#0x2000000
                add r9,#0x60000
                add r9,#0x0c
                ldr r10,[r9]
                mov r9,r10
p10:            str r9,[r2],#8
                str r10,[r12],#8
                str r9,[r2],#8
                str r10,[r12],#8
                cmp r2,r5
                blt p10
                subs r0,#1
                bne p111

                mov r0,#1120
                                    //left border
p11:            add r5,#256
                mov r9,#0x2000000
                add r9,#0x60000
                add r9,#0x0c
                ldr r10,[r9]
                mov r9,r10
p0:             str r9,[r2],#8
                str r10,[r12],#8
                str r9,[r2],#8
                str r10,[r12],#8
                cmp r2,r5
                blt p0
                                    //active screen
                add r5,#7168
p1:             ldrb r7,[r1],#2
                ldrb r8,[r6],#2
                ldr r9,[r3,r7,lsl #2]
                ldr r10,[r3,r8,lsl #2]
                str r9,[r2],#8
                str r10,[r12],#8
                ldrb r7,[r1],#2
                ldrb r8,[r6],#2
                ldr r9,[r3,r7,lsl #2]
                ldr r10,[r3,r8,lsl #2]
                str r9,[r2],#8
                str r10,[r12],#8
                ldrb r7,[r1],#2
                ldrb r8,[r6],#2
                ldr r9,[r3,r7,lsl #2]
                ldr r10,[r3,r8,lsl #2]
                str r9,[r2],#8
                str r10,[r12],#8
                ldrb r7,[r1],#2
                ldrb r8,[r6],#2
                ldr r9,[r3,r7,lsl #2]
                ldr r10,[r3,r8,lsl #2]
                str r9,[r2],#8
                str r10,[r12],#8
                cmp r2,r5
                blt p1
                                  //right border
                add r5,#256
                mov r9,#0x2000000
                add r9,#0x60000
                add r9,#0x0c
                ldr r10,[r9]
                mov r9,r10
p002:           str r9,[r2],#8
                str r10,[r12],#8
                str r9,[r2],#8
                str r10,[r12],#8
                cmp r2,r5
                blt p002
                subs r0,#1
                bne p11

                 //lower border

                mov r0,#40
p112:                add r5,#7680
                mov r9,#0x2000000
                add r9,#0x60000
                add r9,#0x0c
                ldr r10,[r9]
                mov r9,r10
p12:            str r9,[r2],#8
                str r10,[r12],#8
                str r9,[r2],#8
                str r10,[r12],#8
                cmp r2,r5
                blt p12
                                subs r0,#1
                bne p112
p999:           ldmfd r13!,{r0-r12}
                end;


end;




procedure spritef(screen:pointer);

/// A real retromachine sprite procedure

label p100,p101,p102,p103,p104,p999;
var a:integer;
    spritebase:integer;

begin
//a:=$2000000;
spritebase:=$2060040;

               asm
               stmfd r13!,{r0-r12}     //Push registers
               mov r12,#0
                                       //sprite
               ldr r0,spritebase
            //   ldr r1,a
             //  add r0,r1
p103:          ldr r1,[r0],#4
               mov r2,r1               // sprite 0 position
               mov r3,r1
               ldr r5,p100
               and r2,r5               // x pos
               lsl r2,#2
               ldr r4,p100+4
               and r3,r4
               lsr r3,#16              // y pos
               cmp r2,#8192
               ble p104
               add r12,#1
               add r0,#4
               cmp r12,#8
               bge p999
               b p103

p104:          ldr r4,p100+8
               mul r3,r3,r4
               add r3,r2      // sprite pos
               ldr r4,screen
               add r3,r4      // pointer to upper left sprite pixel in r3
               ldr r4,p100+12
               add r4,r4,r12,lsl #12
            //   ldr r5,a
            //   add r4,r5      //pointer to sprite 0 data

               ldr r1,[r0],#4
               mov r2,r1
               ldr r5,p100
               and r2,r5
               lsr r1,#16
               cmp r1,#8
               movgt r1,#8
               cmp r2,#8
               movgt r2,#8
               cmp r1,#1
               movle r1,#1
               cmp r2,#1
               movle r2,#1
               mov r7,r2
               mov r8,#128
               mul r8,r8,r2
               mov r9,#32
               mul r9,r9,r1 //y zoom
               mov r10,r1
               mov r6,#32
p101:          ldr r5,[r4],#4
p102:          cmp r5,#0
               strne r5,[r3],#4
               addeq r3,#4
               subs r7,#1
               bne p102
               mov r7,r2
               subs r6,#1
               bne p101
               add r3,#7680
               sub r3,r8
               subs r10,#1
               subne r4,#128
               addeq r10,r1
               mov r6,#32
               subs r9,#1
               bne p101
               add r12,#1
               cmp r12,#8
               bne p103
               b p999

p100:          .long 0xFFFF
               .long 0xFFFF0000
               .long 7680
               .long 0x2052000

p999:          ldmfd r13!,{r0-r12}
               end;
end;


procedure setataripallette(bank:integer);

var i:integer;

begin
for i:=0 to 255 do lpoke($2010000+4*i+1024*bank,ataripallette[i]);
end;

procedure sethidecolor(c,bank,mask:integer);

begin
lpoke(($2010000+1024*bank+4*c),lpeek($2010000+1024*bank+4*c)+(mask shl 24));
end;

procedure cls(c:integer);

var c2, i,l:integer;
    c3: cardinal;
    screenstart:integer;

begin
screenstart:=lpeek($2060004);
c:=c mod 256;
l:=(lpeek($2060020)*lpeek($2060024)) div 4 ;
c3:=c+(c shl 8) + (c shl 16) + (c shl 24);
for i:=0 to l do lpoke(screenstart+4*i,c3);

end;

//  ---------------------------------------------------------------------
//   putpixel (x,y,color)
//   asm procedure - put color pixel on screen at position (x,y)
//   rev. 2015.10.14
//  ---------------------------------------------------------------------

procedure putpixel(x,y,color:integer);

var adr:integer;

begin
adr:=lpeek($2060004)+x+1792*y; if adr<lpeek($2060004)+$FFFFFF then poke(adr,color);
end;


//  ---------------------------------------------------------------------
//   box(x,y,l,h,color)
//   asm procedure - draw a filled rectangle, upper left at position (x,y)
//   length l, height h
//   rev. 2015.10.14
//  ---------------------------------------------------------------------

procedure box(x,y,l,h,c:integer);

label p1;

var adr,i,j,screenptr:integer;

begin

screenptr:=lpeek($2060004);
if x<0 then x:=0;
if x>1792 then x:=1792;
if y<0 then y:=0;
if y>1120 then y:=1120;
if x+l>1792 then l:=1792-x-1;
if y+h>1120 then h:=1120-y-1 ;
for j:=y to y+h-1 do begin


    asm
    stmfd r13!,{r0-r2}     //Push registers
    mov r0,#1792
    ldr r1,j
    mul r0,r0,r1
    ldr r1,screenptr
    add r0,r1
    ldr r1,c
    ldr r2,x
    add r0,r2
    ldr r2,l
p1: strb r1,[r0]
    add r0,#1
    subs r2,#1
    bne p1
    ldmfd r13!,{r0-r2}
    end;

  end;

end;

//  ---------------------------------------------------------------------
//   box2(x1,y1,x2,y2,color)
//   Draw a filled rectangle, upper left at position (x1,y1)
//   lower right at position (x2,y2)
//   wrapper for box procedure
//   rev. 2015.10.17
//  ---------------------------------------------------------------------

procedure box2(x1,y1,x2,y2,color:integer);

begin
if (x1<x2) and (y1<y2) then
   box(x1,y1,x2-x1+1, y2-y1+1,color);
end;


//  ---------------------------------------------------------------------
//   putchar(x,y,ch,color)
//   Draw a 8x16 character at position (x1,y1)
//   STUB, will be replaced by asm procedure
//   rev. 2015.10.14
//  ---------------------------------------------------------------------

procedure putchar(x,y:integer;ch:char;col:integer);

// --- TODO: translate to asm, use system variables

var i,j,start:integer;
  b:byte;

begin
start:=$2050000+16*ord(ch);
for i:=0 to 15 do
  begin
  b:=peek(start+i);
  for j:=0 to 7 do
    begin
    if (b and (1 shl j))<>0 then
      putpixel(x+j,y+i,col);
    end;
  end;
end;

procedure putcharz(x,y:integer;ch:char;col,xz,yz:integer);

// --- TODO: translate to asm, use system variables

var i,j,k,l,start:integer;
  b:byte;

begin
start:=$2050000+16*ord(ch);
for i:=0 to 15 do
  begin
  b:=peek(start+i);
  for j:=0 to 7 do
    begin
    if (b and (1 shl j))<>0 then
      for k:=0 to yz-1 do
        for l:=0 to xz-1 do
           putpixel(x+j*xz+l,y+i*yz+k,col);
    end;
  end;
end;

procedure outtextxy(x,y:integer; t:string;c:integer);

var i:integer;

begin
for i:=1 to length(t) do putchar(x+8*i-8,y,t[i],c);
end;

procedure outtextxyz(x,y:integer; t:string;c,xz,yz:integer);

var i:integer;

begin
for i:=0 to length(t)-1 do putcharz(x+8*xz*i,y,t[i+1],c,xz,yz);
end;


end.

