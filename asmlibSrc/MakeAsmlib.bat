rem           MakeAsmlib.bat                   2011-07-01 Agner Fog

rem  Make function library from assembly source with multiple
rem  versions for different operating systems using objconv.


rem  Set path to assembler and objconv:
rem  You need to modify this path to fit your installation
set path=C:\Program Files\Microsoft Visual Studio 9.0\VC\bin;C:\Program Files\Microsoft Visual Studio 9.0\Common7\IDE;C:\Program Files\Microsoft Visual Studio 9.0\VC\bin\x86_amd64;E:\Program Files\Microsoft SDKs\Windows\v6.1\Bin\x64;%path%

rem  Make everything according to makefile asmlib.make
nmake /Fasmlib.make

wzzip asmlibbak.zip asmlib.zip asmlib-instructions.doc *.cpp

pause