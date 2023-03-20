#!/bin/sh

# This script is a combination of the original RMS `opencv4_install.sh` file
# and the instructions from these sites:
    # https://galaktyk.medium.com/how-to-build-opencv-with-gstreamer-b11668fa09c
    # https://github.com/opencv/opencv_contrib (README.md How to Build section)
# Worked on my Intel laptop running Ubuntu 22.04 LTS

# Variables
HOME_DIR=$HOME

# Mount desired conda environment
# (this env should be auto-mounted in all terminals through ~/.zshrc or ~/.bashrc)
conda env list
conda init
conda activate RMS_3_8 # ! Doesn't work, need to mount beforehand

# Install required packages through apt
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y ubuntu-restricted-extras
sudo apt-get install -y build-essential cmake pkg-config
sudo apt-get install -y libjpeg-dev libtiff5-dev libjasper-dev libpng12-dev
sudo apt-get install -y libavcodec-dev libavformat-dev libswscale-dev libv4l-dev
sudo apt-get install -y libxvidcore-dev libx264-dev
sudo apt-get install -y gstreamer1.0*
sudo apt-get install -y gstreamer1.0-tools
sudo apt-get install -y gstreamer1.0-plugins-bad gstreamer1.0-libav
sudo apt-get install -y libgstreamer-plugins-good1.0-0 libgstreamer-plugins-good1.0-dev gstreamer1.0-plugins-good
sudo apt-get install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
sudo apt-get install -y libgtk-3-dev
sudo apt-get install -y libatlas-base-dev gfortran

# Clone OpenCV repo
cd ${HOME_DIR}
git clone https://github.com/opencv/opencv.git
cd opencv/
git checkout 4.7.0

# Clone OpenCV contrib repo
# Contains extra modules we need for OpenCV
cd ${HOME_DIR}
git clone https://github.com/opencv/opencv_contrib.git
cd opencv_contrib/
git checkout 4.x

# ------------------------------------------------------------------------------
# Go back to OpenCV directory, begin build
cd ${HOME_DIR}
cd opencv/

# cmake time
# ! THE FULL EXPERIENCE (ALL FLAGS (excluding ones that weren't recognised)) FROM PREVIOUS ATTEMPTS
    # Failed - made it to 52% (when compiling with OpenCV 4.5.5 and contrib 4.x)
    # Failed on ximgproc
    # Succeeded - 100% (when compiling with OpenCV 4.7.0 and contrib 4.x)
cmake -D CMAKE_BUILD_TYPE=RELEASE \
    -D OPENCV_EXTRA_MODULES_PATH=${HOME_DIR}/opencv_contrib/modules ${HOME_DIR}/opencv \
    -D CMAKE_INSTALL_PREFIX=$(python3 -c "import sys; print(sys.prefix)") \
    -D INSTALL_PYTHON_EXAMPLES=ON \
    -D PYTHON_EXECUTABLE=$(which python3) \
    -D WITH_opencv_python3=ON \
    -D BUILD_opencv_python2=OFF \
    -D PYTHON3_EXECUTABLE=$(which python3) \
    -D PYTHON2_EXECUTABLE=OFF \
    -D PYTHON3_INCLUDE_DIR=$(python3 -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
    -D PYTHON3_PACKAGES_PATH=$(python3 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
    -D BUILD_EXAMPLES=ON \
    -D INSTALL_C_EXAMPLES=OFF \
    -D WITH_OPENMP=ON \
    -D BUILD_TIFF=ON \
    -D WITH_TBB=ON \
    -D BUILD_TBB=ON \
    -D BUILD_TESTS=OFF \
    -D WITH_EIGEN=OFF \
    -D WITH_V4L=ON \
    -D WITH_LIBV4L=ON \
    -D WITH_VTK=OFF \
    -D OPENCV_ENABLE_NONFREE=ON \
    -D INSTALL_PYTHON_EXAMPLES=OFF \
    -D BUILD_NEW_PYTHON_SUPPORT=ON \
    -D BUILD_opencv_python3=TRUE \
    -D WITH_GSTREAMER=ON \
    -D WITH_FFMPEG=ON ..

# -D HAVE_opencv_python2=OFF \
# -D OPENCV_EXTRA_EXE_LINKER_FLAGS=-latomic \

# Then build it
sudo make -j$(nproc)

# ! Install python bindings I think????
sudo make install

# Do shared library linking stuff
sudo ldconfig

# Optionally remove the OpenCV build library and whatnot
# cd ${HOME_DIR}
# rm -rf opencv-${VERSION} opencv_contrib-${VERSION} opencv.zip opencv_contrib.zip

