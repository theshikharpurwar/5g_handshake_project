import pandas as pd
import time
import socket
import fcntl
import struct
from scapy.all import send, IP, TCP, UDP, Raw

# --- Configuration ---
CSV_FILE_PATH = '/datasets/GeForce_Now_1.csv'  # Path inside the Docker container
INTERFACE = 'uesimtun0'  # The UE's network interface

def get_ip_address(ifname):
    """Gets the IP address of a given network interface."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        return socket.inet_ntoa(fcntl.ioctl(
            s.fileno(),
            0x8915,  # SIOCGIFADDR
            struct.pack('256s', ifname[:15].encode())
        )[20:24])
    except IOError:
        print(f"Error: Could not find IP for interface '{ifname}'. UE might not be connected.")
        return None

def generate_traffic():
    """Reads the CSV and generates network traffic mimicking the dataset."""
    print("--- Starting 5G Traffic Generator ---")
    
    # Get the UE's actual IP address to use as the source
    source_ip = get_ip_address(INTERFACE)
    if not source_ip:
        return

    print(f"UE is connected. Source IP for generated traffic: {source_ip}")

    # Use pandas to read the large CSV in chunks to save memory
    chunk_iter = pd.read_csv(CSV_FILE_PATH, chunksize=1000, usecols=['Time', 'Destination', 'Protocol', 'Length'])
    
    last_timestamp = None
    packet_count = 0

    for chunk in chunk_iter:
        for index, row in chunk.iterrows():
            packet_count += 1
            
            # --- Pacing: Wait for the correct amount of time between packets ---
            current_timestamp = row['Time']
            if last_timestamp is not None:
                delay = current_timestamp - last_timestamp
                if delay > 0:
                    time.sleep(delay)
            last_timestamp = current_timestamp

            # --- Packet Crafting ---
            dest_ip = row['Destination']
            protocol = row['Protocol']
            length = row['Length']

            # We need a payload to match the packet size. 
            # Scapy headers add ~40 bytes (IP+TCP/UDP).
            payload_size = max(0, length - 40)
            payload = b'\x00' * payload_size

            packet = None
            if protocol == 'TCP':
                packet = IP(src=source_ip, dst=dest_ip) / TCP() / Raw(load=payload)
            elif protocol == 'UDP':
                packet = IP(src=source_ip, dst=dest_ip) / UDP() / Raw(load=payload)
            
            if packet:
                send(packet, iface=INTERFACE, verbose=0)
                print(f"Sent packet {packet_count}: {protocol} to {dest_ip}, Length={length}")

    print("--- Finished sending all packets from CSV ---")


if __name__ == "__main__":
    # Wait a few seconds for the UE interface to be fully ready
    time.sleep(5)
    generate_traffic()