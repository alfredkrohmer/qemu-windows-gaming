Run Windows in QEMU for Gaming
==============================

This script allows you to easily start Windows in a VM on Linux with the following performance enhancing features:
* vCPU pinning and isolation
* hugepage memory
* PCI graphics card pass through
* direct disk access

It also offers the following convenience features:
* automatically attach USB devices
* attach / detach USB devices by MQTT (e.g. from a smartphone app)
* turns Linux monitor output on / off to allow the monitors to switch to another source
 
Configuration
-------------

Everything is configured in `config.yml`. There are plenty of comments for explanation.


Usage
-----

1. Install Ruby.

2. Customize `config.yml` to fit your system configuration.

3. 

```
bundle
sudo ruby qemu-windows-gaming.rb
```
