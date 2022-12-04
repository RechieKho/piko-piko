# Piko-piko OS

> A simplistic, minimalistic, 16-bit toy OS.
> Perfect for entertainment & education. 
> 0 practicality, 100% messing around.
>
> *From the author, Rechie Kho*

Packed with a bootloader and an interpreter, it is able to run the commands like how
BASIC does in the 80s. It is much user-unfriendly as the language is closer to
assembly. It can: 

- Do basic arithmetics (`add`, `sub`, `mul` & `div`)
- Do conditional jumps (`jse`, `jsne`, `jue`,...)
- Save and load (`save` & `load`)
- And most importantly, print colorful text (`say`)

All the commands are in [the commands reference](https://github.com/RechieKho/piko-piko/wiki/commands-reference).

You are very welcome to fork this project and add your own commands.

It is written in *pure* nasm assembly, so brace yourself.

## Hello world in Piko-piko

First, clone the project if you haven't do it [as stated in 'Build the source' section](#build-from-source).

Then, enter the world of Piko-piko.
```sh 
$ make
```

At this point, you'll see "Welcome to piko-piko!" printed on the screen proceeds with `>`. Welcome to Piko-piko!

Then, type this command to print "Hello world!".
```sh
> say n 'Hello world!'
```

Yay, your first "Hello world!" in Piko-piko!

Let's spice things up by making our "Hello world!" colorful!
```sh 
> say Cn 'Hello world!'
```

It is time to take a rest and say goodbye to Piko-piko since we have printed "Hello world!".
```sh
> bye
```

We will discuss more commands in the [wiki](https://github.com/RechieKho/piko-piko/wiki).

## Build from source

**NOTE:** For Windows and Mac OS, it is not tested and unsupported.(?)

Software required: 
- `make`
- `nasm`
- `python` (optional)

First, clone this project. 
```sh
$ git clone https://www.github.com/RechieKho/piko-piko.git
```

Then, to build the source.
```sh
$ make piko-piko.bin
```

Or if you want to experience Piko-piko right away. 
```sh
$ make
```

To clean (remove) the generated files. 
```sh
$ make clean
```

After doing some serious assembly programming, you can format the code before commiting.
```sh
$ make fmt
```
**NOTE:** This needs `python`

## Make a bootable Piko-piko USB.

**NOTE:** For Windows and Mac OS, it is not tested and unsupported.(?)

**WARNING:** Once you made the bootable USB, the old data in the USB will not be able to recovered. Please consider backing up the data of USB before doing such dangerous act.

Piko-piko OS is an 16-bit x86 OS so it is able to boot on computer with intel-based CPU.

To make a bootable Piko-piko USB, you'll need to have:
- `piko-piko.bin` file from [building the source](#build-from-source),
- A USB that can store the size of `piko-piko.bin`.

Then, directly copy it onto your USB.
```
# dd if=piko-piko.bin of=/dev/YOUR_USB bs=512 conv=notrunc
```
Replace `YOUR_USB` with the device file of your USB.

**WARNING**: Please make sure the device file is really the USB file you are looking for, it is possible that you write to the wrong file and corrupt the hard disk. **No one wants Piko-piko as daily main OS.**

Then, you have created a bootable Piko-piko USB!
