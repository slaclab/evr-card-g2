# CPSW Test Application

## Description 

This python script test the comminucation with the EVR G2 card using CPSW. 

It reads information about the firmware versions, available in the `AxiVersion` device. Optionally, it also write a value to the `ScratchPad` register.

## Usage

To run the script, you can use the `run.sh` wrapper bash script, which set the CPSW environment and then call the python script. You need to provide the path to the top YAML file `000TopLevel.yaml`.

The usage is:
```bash
usage: test.py [-h] --yaml YAML_TOP_FILE [--root-name ROOT_DEV_NAME]
               [--scratch-pad SCRATCH_PAD]

Test EVR Card G2 using CPSW

optional arguments:
  -h, --help            show this help message and exit
  --yaml YAML_TOP_FILE  Path to the top level YAML file (000TopLevel.yaml)
  --root-name ROOT_DEV_NAME
                        Root device name (default = "MemDev")
  --scratch-pad SCRATCH_PAD
                        Write this value to the AxiVersion/ScratchPad register
```

### Example:
```bash
[ laci@cpu-b084-sp12]$ ./run.sh --yaml ./yaml/000TopLevel.yaml --scratch-pad 3
Version     : 0xCED20019
DeviceDna   : 0x746D8470F10814
Up time     : 4816551 s
Git Hash    : 0x748fdb24fb22e055401e19afe5648783a699b5
Build stamp : EvrCardG2: Vivado v2019.1, rdsrv300 (x86_64), Built Mon 20 Jul 2020 10:50:35 PM PDT by weaver
Scratch Pad : 3
```
