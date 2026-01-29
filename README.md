# HandsOn_SDR_for_Wireless_Communication
This repository showcases SDR implementations for channel estimation, communication, and positioning. It is an addition to the other repository called [Basic of Wireless Communication Tutorial](https://github.com/barbaalba/Basic_of_Wireless_communication_Tutorial). Moreover, the repository provides implementations using GNU Radio and MATLAB. 

**NOTE**: To open *.grc, use GNU Radio Companion. See [LINK](https://wiki.gnuradio.org/index.php/MacInstall) for installation on Mac OS. 

# GNU Radio Projects
This folder includes simple projects with GNU RADIO.

- Spectrum analyzer: It is a simple building block to visualize the frequency spectrum and detect signals. The variables should be adapted to your hardware.
- BPSK Tx/Rx: The building blocks do not demodulate the signal at the receiver side but are developed to analyze the effect of the carrier frequency offset. You can use the slider to change the local oscillator at the receiver side to observe this effect. 
- QPSK Tx and Rx: Remember that the configurations for these two files should be the same — for instance, carrier frequency, excessive bandwidth for pulse shaping, etc. Note that in my simulation, I have a local oscillator at the receiver side to manually and roughly correct the carrier frequency offset. It was needed since my hardware had more than 100 KHz offset, and the receiver was locking to a different channel. Therefore, I had to guide my system to lock on the correct channel. After that, other building blocks correct for time, frequency, and phase offset. You may need to modify the costas loop bandwidth to demodulate your signal accurately. 

# MATLAB Projects
- Spectrum analyzer: It captures and plots the spectrum of the signal. If you have another device transmitting over the same carrier frequency, the plot hints you about the existing carrier frequency offset.
- Simple Pulse Transmission: This code simply just transmit pulse shape with a wide bandwidth, allowing you to receive it in the RX host to visualize the existing carrier frequency offset between TX and RX.
- QPSK with RRC Tx: It sends RRC pulse-shaped QPSK data using SDR. The code checks for underruns, since they affect the spectrum of the tx data. When underruns occur, the chunk of zeros is transmitted over the air because the SDR buffer is empty. This results in a wider spectrum and broadens the signal bandwidth, affecting the adjacent channels. It is important to avoid it.  


Under progress....

# Reference and Tutorials
For learning about Gnu Radio Companion and SDRs watch this comprehensive tutorial on [YouTube](https://youtube.com/playlist?list=PLywxmTaHNUNyKmgF70q8q3QHYIw_LFbrX&si=QYRZKumKr65xjSI5). 
