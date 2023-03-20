# RMS Installation

- This document details how to install the `seafaring_RMS` on a Linux box
- Tested on Ubuntu 22.04 LTS on a regular ol' Intel laptop
- Largely following these resources from the GMN
  - [RMS GitHub README](https://github.com/CroatianMeteorNetwork/RMS#setting-up)
  - [RPi4 install instructions](https://docs.google.com/document/d/19ImeNqBTD1ml2iisp5y7CjDrRV33wBeF9rtx3mIVjh4/edit)

## Just straight run the following commands (in order)

- [X] Copy and paste into terminal (ensure you are mounted in RMS repo root directory)

```bash
# Creating a conda environment
conda create -n RMS_3_8 -y
conda activate RMS_3_8
conda install python=3.8.6 -y

# Installing Python dependencies in newly created conda environment
conda install -y numpy scipy gitpython cython matplotlib
conda install -y -c conda-forge ephem Pillow imreg_dft imageio pyqtgraph'<=0.12.1'
conda install -y -c astropy astropy
pip install rawpy

# Installing OpenCV with FFmpeg and Gstreamer support
# In addition to installing the opencv-contrib modules too
./opencv4_install_pro_max.sh

# Install gstreamer through conda
# Since running `gst-launch-1.0` through the RMS_3_8 environment will use the conda version
# Which doesn't have the rtsp plugin
# Running this command will do the following however:
  # May downgrade Python to 3.8.6 from 3.8.16
  # Will take ages to run
conda install -y -c conda-forge gstreamer=1.20.3
conda install -y -c conda-forge gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav

# Setting up Kernel-based Hough Transform (KHT) module
python setup.py install
```

- [X] Add the following to your shell startup file (either `~/.zshrc` or `~/.bashrc`)

```bash
conda activate RMS_3_8
```

## Post-Install Configuration

### VScode Config

- [X] Add the following to your user settings (so the config file doesn't get nuked by vscode)

```json
"[config]": {
        // Important for the RMS config file (trailing whitespace NECESSARY)
        "files.trimTrailingWhitespace": false,
    },
```

### [The Config File](./../.config)

- [X] Configuration complete?
- This is covered in the [`README`](./../README.md#editing-the-configuration-file)
- Must set the following settings in it:
  - Station ID
    - Leaving as `XX0001` for testing
  - GPS Location
    - Excluding from GitHub repo
  - Device
    - `device: rtspsrc location="rtsp://192.168.42.10:554/user=admin&password=&channel=1&stream=0.sdp" ! rtph264depay ! h264parse ! decodebin ! videoconvert ! appsink sync=1`
    - H264 encoded headless gstreamer pipeline
  - Resolution
    - 1280x720
  - FPS
    - 30

### OS Config

- [X] Set timezone to UTC
  - Do this in the graphical settings menu

- [X] Increase GPU memory (>= 256MB)
  - `sudo lshw -C display`
  - Copy bus info (for example: `bus info: pci@0000:00:02.0`)
  - Paste last part into this command: `sudo lspci -v -s 00:02.0`
  - Will tell you how much memory is assigned to the GPU
- [X] Increase swap memory (>= 1GB)
  - `swapon -s` lists swap memory in MiB
  - Divide `size` value by 1024 to get size in GiB
- [X] Increase terminal scrollback

#### Will enable post-testing

- [ ] Disable FKMS
  - Think this is raspberry pi specific
- [ ] Add RMS to run on startup
- [ ] Enable watchdog (auto-reboot) service

### Network Config

### Camera Config

### RMS Config

- [ ] Generate desktop links for ease of use
- [ ] RMS capture watchdog
- [ ] Increase imagemagick memory allowance

## Further Installation (extra utilities)

- May need to install `PyQt5`? Likely not

### Remote Desktop Application

- Parsec Remote Desktop
- Google Chrome Remote Desktop
- etc.

### CMN_binViewer

### RTC

- Will need to set that up if using an embedded computer without one installed already
