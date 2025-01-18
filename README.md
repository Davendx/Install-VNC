# Guide to Install VNC, Desktop Environment, and Google Chrome on a Linux VPS

## Install Main Packages
```
sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libasound2 libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev  -y
```
## Install XFCE Desktop Environment
First, install the XFCE graphical user interface:
```
sudo apt update
sudo apt install xfce4 xfce4-goodies -y
```

## Install VNC Server
Install VNC Server to allow remote access to the graphical interface of your VPS:
```
sudo apt install tightvncserver -y
sudo apt install autocutsel
```

## Config VNC Server
**1. Start VNC Server for the first time to set up a password:**
```
vncserver
```
* This will run a VNC screen on `:1` port

**2. Stop VNC Server to config it:**
```
vncserver -kill :1
```

**3. Configure VNC to use XFCE and automatically open Terminal**
Open the xstartup configuration file and edit it to start XFCE along with the Terminal:
```
nano ~/.vnc/xstartup
```

Replace the content of the file with:
```
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
xfce4-terminal &
autocutsel &
-geometry 1920x1080 -depth 24
-rfbport 6001
```

**4. Make the xstartup file executable:**
```
chmod +x ~/.vnc/xstartup
```

## Connect VNC from a Windows Machine
**1. Download VNC Viewer from [RealVNC](https://www.realvnc.com/en/connect/download/viewer/) and install it on your Windows machine.**

**2. Open VNC Viewer and connect to  IP_VPS:6001, then enter the VNC password when prompted.**

**3. Now, you should see the desktop interface of your VPS, with the Terminal automatically opened upon login.**

## Install Google Chrome on the VPS
**1. Open Terminal (if it hasn't automatically opened in the VNC session).**

**2.Download Google Chrome:**
```
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
```

**3. Install Google Chrome:**
```
sudo apt install ./google-chrome-stable_current_amd64.deb
```

If you encounter dependency errors, run:
```
sudo apt --fix-broken install
```

**4. Launch Chrome in VNC (add --no-sandbox if necessary):**
```
google-chrome --no-sandbox
```


