- Spectrum analyzer: It captures and plots the spectrum of the signal. If you have another device transmitting over the same carrier frequency, the plot hints you about the existing carrier frequency offset.
- Simple Pulse Transmission: This code simply just transmit pulse shape with a wide bandwidth, allowing you to receive it in the RX host to visualize the existing carrier frequency offset between TX and RX.
- QPSK with RRC Tx: It sends RRC pulse-shaped QPSK data using SDR. The code checks for underruns, since they affect the spectrum of the tx data. When underruns occur, the chunk of zeros is transmitted over the air because the SDR buffer is empty. This results in a wider spectrum and broadens the signal bandwidth, affecting the adjacent channels. It is important to avoid it.
- QPSK with RRC Rx: It implements RRC filter, Carrier synchronization, time synchronization, and phase recovery at the receiver. 

# Visualization of QPSK RX Outputs
