# LinDev-Switch

LinDev-Switch is the Linux version of WinDev-Switch, designed to provide an interactive menu for managing the state of input devices on a Linux machine using xinput. 

## Features

- Quick interactive menu for enabling/disabling devices.
- Allows enabling/disabling all devices at once.
- Add and remove devices directly from the menu.
- Navigate using arrow keys or shortcuts [1-9].
- Multi-page support for handling many devices.

## Prerequisites

- `xinput` must be installed and accessible via the command line.
- `config.ini` will be created automatically in the same directory as the script on first run.

## Installing xinput

### Debian/Ubuntu-based Systems

```bash
sudo apt-get install xinput
```
### Arch Linux

```bash
sudo pacman -S xorg-xinput
```
### Fedora

```bash
sudo dnf install xinput
```
### openSUSE

```bash
sudo zypper install xinput
```
### Gentoo

```bash
sudo emerge -av x11-apps/xinput
```

## Usage

Run the script:

```bash
./LinDev-Switch.sh
```
Ensure the script is executable. If necessary, make it executable with:
```bash
chmod +x LinDev-Switch.sh
```
### config
While you can manage devices directly through the script, config.ini allows you to configure display settings like frame and colors.

Example config.ini:

```ini

[settings]
frame=true
colors=true

[devices]
Mouse="Logitech USB Optical Mouse"
Keyboard="AT Translated Set 2 keyboard"
```
- frame: If false, the display will miss the border.
- colors: If false, will show no color.

## Notes

- Ensure xinput is properly installed and the device names in config.ini are correct.
- Running the script may require appropriate permissions to enable/disable devices.
- This project is licensed under the MIT License.

Enjoy managing your devices with LinDev-Switch!
