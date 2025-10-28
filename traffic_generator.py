#!/usr/bin/env python3
"""
Traffic generator for testing different application profiles over 5G.
Supports VoIP, video streaming, bulk transfer, IoT, and CSV dataset-based traffic patterns.
"""

import socket
import time
import argparse
import struct
import fcntl
from datetime import datetime
import random
import os
import sys

INTERFACE = 'uesimtun0'

def get_ip_address(ifname):
    """Get the IP address of a network interface."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        return socket.inet_ntoa(fcntl.ioctl(
            s.fileno(),
            0x8915,  # SIOCGIFADDR
            struct.pack('256s', ifname[:15].encode())
        )[20:24])
    except IOError:
        print(f"Error: Could not find IP for interface '{ifname}'")
        return None


def generate_voip_traffic(target_ip, port, duration):
    """
    Simulates VoIP traffic (like a phone call).
    Small packets sent at regular intervals (20ms typical for G.711 codec).
    """
    print(f"\n=== VoIP Traffic Profile ===")
    print(f"Target: {target_ip}:{port}")
    print(f"Duration: {duration}s")
    print(f"Pattern: 160 bytes every 20ms (50 packets/sec)")
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    packet_size = 160  # G.711 codec typical packet size
    interval = 0.020  # 20ms between packets
    
    start_time = time.time()
    packet_count = 0
    
    try:
        while time.time() - start_time < duration:
            # Create a simple payload with timestamp
            timestamp = time.time()
            payload = struct.pack('!d', timestamp) + b'\x00' * (packet_size - 8)
            
            sock.sendto(payload, (target_ip, port))
            packet_count += 1
            
            if packet_count % 50 == 0:  # Print every second
                elapsed = time.time() - start_time
                print(f"[{elapsed:.1f}s] Sent {packet_count} VoIP packets")
            
            time.sleep(interval)
    
    except KeyboardInterrupt:
        print("\nVoIP traffic stopped by user")
    finally:
        sock.close()
        elapsed = time.time() - start_time
        print(f"\nVoIP Summary:")
        print(f"  Duration: {elapsed:.1f}s")
        print(f"  Packets sent: {packet_count}")
        print(f"  Average rate: {packet_count/elapsed:.1f} pkt/s")


def generate_video_traffic(target_ip, port, duration):
    """
    Simulates video streaming traffic.
    Bursty UDP packets with variable sizes (mimics video frames).
    """
    print(f"\n=== Video Streaming Profile ===")
    print(f"Target: {target_ip}:{port}")
    print(f"Duration: {duration}s")
    print(f"Pattern: Variable bursts (~30 fps)")
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    frame_interval = 1.0 / 30.0  # 30 fps
    
    start_time = time.time()
    packet_count = 0
    total_bytes = 0
    
    try:
        while time.time() - start_time < duration:
            # Video frame sizes vary - some are keyframes (larger), others are smaller
            if random.random() < 0.1:  # 10% chance of keyframe
                frame_size = random.randint(8000, 15000)  # Keyframe
            else:
                frame_size = random.randint(1000, 4000)  # Regular frame
            
            # Split frame into MTU-sized packets (1400 bytes max)
            mtu = 1400
            chunks = (frame_size + mtu - 1) // mtu
            
            for i in range(chunks):
                chunk_size = min(mtu, frame_size - i * mtu)
                payload = b'\x00' * chunk_size
                sock.sendto(payload, (target_ip, port))
                packet_count += 1
                total_bytes += chunk_size
            
            if int(time.time() - start_time) % 5 == 0 and packet_count % 150 == 0:
                elapsed = time.time() - start_time
                mbps = (total_bytes * 8 / 1000000) / elapsed
                print(f"[{elapsed:.1f}s] Sent {packet_count} packets, {total_bytes/1024:.0f} KB ({mbps:.2f} Mbps)")
            
            time.sleep(frame_interval)
    
    except KeyboardInterrupt:
        print("\nVideo traffic stopped by user")
    finally:
        sock.close()
        elapsed = time.time() - start_time
        mbps = (total_bytes * 8 / 1000000) / elapsed
        print(f"\nVideo Summary:")
        print(f"  Duration: {elapsed:.1f}s")
        print(f"  Packets sent: {packet_count}")
        print(f"  Data sent: {total_bytes/1024/1024:.2f} MB")
        print(f"  Average bitrate: {mbps:.2f} Mbps")


def generate_bulk_traffic(target_ip, port, duration):
    """
    Simulates bulk data transfer (like FTP or file download).
    Continuous TCP stream at maximum throughput.
    """
    print(f"\n=== Bulk Transfer Profile ===")
    print(f"Target: {target_ip}:{port}")
    print(f"Duration: {duration}s")
    print(f"Pattern: Continuous TCP stream")
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(10)
    
    try:
        print("Connecting to server...")
        sock.connect((target_ip, port))
        print("Connected! Starting bulk transfer...")
        
        chunk_size = 65536  # 64KB chunks
        payload = b'\x00' * chunk_size
        
        start_time = time.time()
        total_bytes = 0
        
        while time.time() - start_time < duration:
            bytes_sent = sock.send(payload)
            total_bytes += bytes_sent
            
            # Print stats every 2 seconds
            elapsed = time.time() - start_time
            if int(elapsed) % 2 == 0 and elapsed > 0:
                mbps = (total_bytes * 8 / 1000000) / elapsed
                if int(elapsed * 10) % 20 == 0:  # Avoid printing same second multiple times
                    print(f"[{elapsed:.1f}s] Transferred {total_bytes/1024/1024:.2f} MB ({mbps:.2f} Mbps)")
        
        elapsed = time.time() - start_time
        mbps = (total_bytes * 8 / 1000000) / elapsed
        print(f"\nBulk Transfer Summary:")
        print(f"  Duration: {elapsed:.1f}s")
        print(f"  Data sent: {total_bytes/1024/1024:.2f} MB")
        print(f"  Average throughput: {mbps:.2f} Mbps")
    
    except socket.timeout:
        print("Connection timed out")
    except ConnectionRefusedError:
        print(f"Connection refused. Make sure a server is listening on {target_ip}:{port}")
        print(f"Run this on the target: nc -l {port} > /dev/null")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        sock.close()


def generate_iot_traffic(target_ip, port, duration):
    """
    Simulates IoT/sensor traffic.
    Small, infrequent status updates.
    """
    print(f"\n=== IoT/Sensor Profile ===")
    print(f"Target: {target_ip}:{port}")
    print(f"Duration: {duration}s")
    print(f"Pattern: Small updates every 5 seconds")
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    packet_size = 64  # Small sensor reading
    interval = 5.0  # Update every 5 seconds
    
    start_time = time.time()
    packet_count = 0
    
    try:
        while time.time() - start_time < duration:
            # Simulate sensor data (timestamp + random values)
            timestamp = time.time()
            temp = random.uniform(20.0, 25.0)
            humidity = random.uniform(40.0, 60.0)
            
            payload = struct.pack('!dff', timestamp, temp, humidity)
            payload += b'\x00' * (packet_size - len(payload))
            
            sock.sendto(payload, (target_ip, port))
            packet_count += 1
            
            elapsed = time.time() - start_time
            print(f"[{elapsed:.1f}s] Sent update #{packet_count} (temp: {temp:.1f}°C, humidity: {humidity:.1f}%)")
            
            time.sleep(interval)
    
    except KeyboardInterrupt:
        print("\nIoT traffic stopped by user")
    finally:
        sock.close()
        elapsed = time.time() - start_time
        print(f"\nIoT Summary:")
        print(f"  Duration: {elapsed:.1f}s")
        print(f"  Updates sent: {packet_count}")


def generate_dataset_traffic(target_ip, port, duration, dataset_file):
    """
    Generates traffic based on a CSV dataset.
    Reads packet timing and sizes from the dataset and replays them.
    
    Expected CSV format:
    - 'Time' column: timestamp or time delta (in seconds or milliseconds)
    - 'Packet Size' or 'Length' column: size in bytes
    - 'Direction' column (optional): filter for uplink/downlink
    """
    print(f"\n=== Dataset-Based Traffic Profile ===")
    print(f"Target: {target_ip}:{port}")
    print(f"Duration: {duration}s")
    print(f"Dataset: {dataset_file}")
    
    # Check if file exists
    if not os.path.exists(dataset_file):
        print(f"ERROR: Dataset file not found: {dataset_file}")
        return
    
    # Try to import pandas
    try:
        import pandas as pd
    except ImportError:
        print("ERROR: pandas library not installed.")
        print("Install with: pip install pandas")
        return
    
    # Read the CSV file
    try:
        print("Loading dataset...")
        df = pd.read_csv(dataset_file)
        print(f"✓ Loaded {len(df)} rows from dataset")
        
        # Display column names for debugging
        print(f"Columns found: {list(df.columns)}")
        
        # Try to identify the relevant columns (case-insensitive)
        time_col = None
        size_col = None
        direction_col = None
        
        for col in df.columns:
            col_lower = col.lower()
            if 'time' in col_lower and time_col is None:
                time_col = col
            if any(keyword in col_lower for keyword in ['size', 'length', 'bytes']) and size_col is None:
                size_col = col
            if 'direction' in col_lower and direction_col is None:
                direction_col = col
        
        if time_col is None:
            print("ERROR: Could not find 'Time' column in dataset")
            return
        if size_col is None:
            print("ERROR: Could not find 'Packet Size' or 'Length' column in dataset")
            return
        
        print(f"Using columns: Time='{time_col}', Size='{size_col}'")
        
        # Filter for uplink traffic if direction column exists
        if direction_col:
            original_count = len(df)
            # Try to identify uplink packets (common markers: 'up', 'uplink', 'tx', 'send')
            df = df[df[direction_col].astype(str).str.lower().str.contains('up|tx|send', na=False)]
            print(f"Filtered to {len(df)} uplink packets (from {original_count} total)")
        
        if len(df) == 0:
            print("ERROR: No valid packets found in dataset")
            return
        
    except Exception as e:
        print(f"ERROR reading dataset: {e}")
        return
    
    # Create UDP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    start_time = time.time()
    packet_count = 0
    total_bytes = 0
    
    # Convert time column to numeric (handle string timestamps or datetime)
    try:
        # First try direct numeric conversion
        df[time_col] = pd.to_numeric(df[time_col], errors='coerce')
    except:
        pass
    
    # If that didn't work, try datetime parsing
    if df[time_col].isna().all() or not pd.api.types.is_numeric_dtype(df[time_col]):
        try:
            print("Attempting to parse timestamps as datetime...")
            df[time_col] = pd.to_datetime(df[time_col], errors='coerce')
            # Convert to seconds since first packet
            df[time_col] = (df[time_col] - df[time_col].min()).dt.total_seconds()
        except Exception as e:
            print(f"ERROR: Could not parse time column: {e}")
            return
    
    df = df.dropna(subset=[time_col])  # Remove rows with invalid time values
    
    if len(df) == 0:
        print("ERROR: No valid time values found after conversion")
        return
    
    # Normalize time column to start at 0
    df[time_col] = df[time_col] - df[time_col].min()
    
    # Convert time to seconds if it appears to be in milliseconds
    if df[time_col].max() > 10000:  # Likely milliseconds
        df[time_col] = df[time_col] / 1000.0
        print("Note: Converted time column from milliseconds to seconds")
    
    print(f"\nStarting dataset replay (dataset duration: {df[time_col].max():.2f}s)...\n")
    
    try:
        replay_start = time.time()
        last_packet_time = 0
        
        for idx, row in df.iterrows():
            # Check if we've exceeded the requested duration
            if time.time() - start_time >= duration:
                break
            
            packet_time = row[time_col]
            packet_size = int(row[size_col])
            
            # Limit packet size to reasonable values
            if packet_size <= 0:
                continue
            packet_size = min(packet_size, 9000)  # Cap at jumbo frame size
            
            # Wait until it's time to send this packet
            time_to_wait = packet_time - (time.time() - replay_start)
            if time_to_wait > 0:
                time.sleep(time_to_wait)
            
            # Create and send packet
            payload = b'\x00' * packet_size
            sock.sendto(payload, (target_ip, port))
            packet_count += 1
            total_bytes += packet_size
            
            # Print status every 100 packets
            if packet_count % 100 == 0:
                elapsed = time.time() - start_time
                mbps = (total_bytes * 8 / 1000000) / elapsed if elapsed > 0 else 0
                print(f"[{elapsed:.1f}s] Sent {packet_count} packets, {total_bytes/1024:.1f} KB ({mbps:.2f} Mbps)")
            
            # If we've reached the end of the dataset, loop back
            if idx == len(df) - 1 and time.time() - start_time < duration:
                print("Reached end of dataset, looping...")
                replay_start = time.time()
    
    except KeyboardInterrupt:
        print("\nDataset traffic stopped by user")
    except Exception as e:
        print(f"\nError during replay: {e}")
    finally:
        sock.close()
        elapsed = time.time() - start_time
        mbps = (total_bytes * 8 / 1000000) / elapsed if elapsed > 0 else 0
        print(f"\nDataset Traffic Summary:")
        print(f"  Duration: {elapsed:.1f}s")
        print(f"  Packets sent: {packet_count}")
        print(f"  Data sent: {total_bytes/1024/1024:.2f} MB")
        print(f"  Average bitrate: {mbps:.2f} Mbps")
        if elapsed > 0:
            print(f"  Average packet rate: {packet_count/elapsed:.1f} pkt/s")


def main():
    parser = argparse.ArgumentParser(
        description='5G Traffic Generator - Test different application profiles',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # VoIP call simulation
  python3 traffic_generator.py --profile voip --target 172.18.0.1 --duration 60

  # Video streaming
  python3 traffic_generator.py --profile video --target 172.18.0.1 --port 5001 --duration 120

  # Bulk file transfer (needs server: nc -l 5002 > /dev/null)
  python3 traffic_generator.py --profile bulk --target 172.18.0.1 --port 5002 --duration 60

  # IoT sensor updates
  python3 traffic_generator.py --profile iot --target 172.18.0.1 --duration 300

  # Dataset-based traffic replay
  python3 traffic_generator.py --profile dataset --target 172.18.0.1 --duration 120 --dataset_file /datasets/GeForce_Now_1.csv
        """
    )
    
    parser.add_argument('--profile', required=True, 
                       choices=['voip', 'video', 'bulk', 'iot', 'dataset'],
                       help='Traffic profile to simulate')
    parser.add_argument('--target', required=True,
                       help='Target IP address')
    parser.add_argument('--port', type=int, default=5000,
                       help='Target port (default: 5000)')
    parser.add_argument('--duration', type=int, default=60,
                       help='Duration in seconds (default: 60)')
    parser.add_argument('--dataset_file', type=str,
                       help='Path to CSV dataset file (required for dataset profile)')
    
    args = parser.parse_args()
    
    # Validate dataset_file argument for dataset profile
    if args.profile == 'dataset' and not args.dataset_file:
        parser.error("--dataset_file is required when using 'dataset' profile")
    
    # Check if we're on the UE interface
    source_ip = get_ip_address(INTERFACE)
    if source_ip:
        print(f"Using UE interface: {INTERFACE} ({source_ip})")
    else:
        print(f"Warning: Could not get IP from {INTERFACE}, using default interface")
    
    # Run the selected profile
    if args.profile == 'voip':
        generate_voip_traffic(args.target, args.port, args.duration)
    elif args.profile == 'video':
        generate_video_traffic(args.target, args.port, args.duration)
    elif args.profile == 'bulk':
        generate_bulk_traffic(args.target, args.port, args.duration)
    elif args.profile == 'iot':
        generate_iot_traffic(args.target, args.port, args.duration)
    elif args.profile == 'dataset':
        generate_dataset_traffic(args.target, args.port, args.duration, args.dataset_file)


if __name__ == "__main__":
    main()
