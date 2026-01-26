# HandsOn_SDR_for_Wireless_Communication
This repository showcases SDR implementations for channel estimation, communication, and positioning. It is an addition to the other repository called [Basic of Wireless Communication Tutorial](https://github.com/barbaalba/Basic_of_Wireless_communication_Tutorial). Moreover, the repository provides implementations using GNU Radio and MATLAB. 

**NOTE**: To open *.grc, use GNU Radio Companion. See [LINK](https://wiki.gnuradio.org/index.php/MacInstall) for installation on Mac OS. 

# Small Projects
This folder includes simple projects with GNU RADIO.

- Spectrum analyzer: It is a simple building block to visualize the frequency spectrum and detect signals. The variables should be adapted to your hardware.
   
- QPSK Tx and Rx: Remember that the configurations for these two files should be the same — for instance, carrier frequency, excessive bandwidth for pulse shaping, etc. Note that in my simulation, I have a local oscillator at the receiver side to manually and roughly correct the carrier frequency offset. It was needed since my hardware had more than 100 KHz offset, and the receiver was locking to a different channel. Therefore, I had to guide my system to lock on the correct channel. After that, other building blocks correct for time, frequency, and phase offset. You may need to modify the costas loop bandwidth to demodulate your signal accurately. 

Under progress....
