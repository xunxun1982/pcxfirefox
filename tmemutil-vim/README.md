### What is the difference between this module and 'tmemutil-3rd'?

I believe that it would be pretty good to make Vimperator/Pentadactyl extension portable. I consider that if the module 'tmemutil' can put the config files of Vimperator/Pentadactyl in the same folder of where the 'PortableDataPath' directs and let Vimperator/Pentadactyl know where its config files lie in, it makes Vimperator/Pentadactyl portable along with Firefox.

So, I modified the module 'tmemutil-3rd' and added the feature. I added a key 'VimpPentaHome' in the file 'tmemutil.ini' to specify the path of the config files of Vimperator/Pentadactyl as follows.

```ini
;MOZ_NO_REMOTE -- Mozilla 's -no-remote Environment Variables
;TmpDataPath -- Custom Temp File Directory ( including Internet Cache and Mozilla Temp files, must set SafeEx=1 )
;NpluginPath -- Custom Plugin Path
;VimpPentaHome为自定义Vimperator/Pentadactyl的配置文件路径
;VimpPentaHome -- Custom config file directory of Vimperator/Pentadactyl extension

[Env]
MOZ_NO_REMOTE=
TmpDataPath=
NpluginPath=
VimpPentaHome=

```

While the key 'VimpPentaHome' exists, the module tells the Vimperator/Pentadactyl extension where its config files are, so that it could load its config files correctly. The value can be either an absolute path (e.g. C:\Vimperator) or a relative path (e.g. Vimperator) . While we use the relative path such as 'Vimperator', it means the path is the sub-folder 'Vimperator' in the path of 'PortableDataPath'. In this way, we can bring the config files of Vimperator/Pentadactyl together with the profiles of Firefox and the Firefox program itself as well as use them across computers.


----

#### Relative discussion:

http://bbs.kafan.cn/thread-1651432-18-1.html


====

### HOW TO BUILD 'tmemutil-vimp'
=================

#### System requirements
------------------

    - C compiler 
	
     mingw64, msys

     MinGW project on:
     http://sourceforge.net/projects/mingw-w64/

     msys project on
     https://sourceforge.net/projects/mingw/files/MSYS/

     Microsoft Visual Studio .


#### Build!
------------------

* mingw64 compiler 

build x86:

```
make clean
make
```

build x64:

```
make clean
make BITS=64
```

--------------------

* vc compiler 

```
nmake -f Makefile.msvc clean
nmake -f Makefile.msvc
```
