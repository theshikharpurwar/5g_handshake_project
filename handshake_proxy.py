import socket
import threading
import select
import os

# --- Configuration ---
# The IP and port where the proxy listens for the gNB
GNB_LISTEN_HOST = '0.0.0.0'
GNB_LISTEN_PORT = 38412

# The real Open5GS AMF address (inside Docker, we use the container name)
AMF_HOST = 'open5gs-core'
AMF_PORT = 38412

# The port where the proxy listens for our custom handshake
HANDSHAKE_LISTEN_HOST = '0.0.0.0'
HANDSHAKE_LISTEN_PORT = 9999

# The secret password for our custom handshake
SECRET_CHALLENGE = "HELLO123"
SECRET_RESPONSE = "ACK"

# A flag to track if the handshake was successful
handshake_completed = False

def forward_traffic(source_socket, dest_socket):
    """Forwards data between two sockets until one is closed."""
    try:
        while True:
            # Wait until source socket is ready to be read
            r, _, _ = select.select([source_socket], [], [], 5)
            if r:
                data = source_socket.recv(4096)
                if not data:
                    break
                dest_socket.sendall(data)
            else:
                # Timeout
                continue
    except Exception as e:
        print(f"[FORWARDER] Error forwarding traffic: {e}")
    finally:
        print("[FORWARDER] Closing sockets.")
        source_socket.close()
        dest_socket.close()

def handle_gnb_connection(gnb_socket):
    """Handles the connection from the UERANSIM gNB."""
    global handshake_completed
    print(f"[GNB-HANDLER] Received connection from gNB at {gnb_socket.getpeername()}")

    if not handshake_completed:
        print("[GNB-HANDLER] Custom handshake not completed. Closing gNB connection.")
        gnb_socket.close()
        return

    print("[GNB-HANDLER] Handshake OK. Connecting to real AMF...")
    try:
        amf_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        amf_socket.connect((AMF_HOST, AMF_PORT))
        print("[GNB-HANDLER] Connected to AMF. Starting traffic forwarding.")

        # Start forwarding traffic in both directions
        threading.Thread(target=forward_traffic, args=(gnb_socket, amf_socket)).start()
        threading.Thread(target=forward_traffic, args=(amf_socket, gnb_socket)).start()

    except Exception as e:
        print(f"[GNB-HANDLER] Could not connect to AMF: {e}")
        gnb_socket.close()

def gnb_listener():
    """Listens for the gNB connection and passes it to a handler."""
    # Note: SCTP is connection-oriented, and for this proxy, we can
    # treat the initial connection like TCP. Python's default socket
    # with IPPROTO_SCTP can be complex, so we use TCP for simplicity
    # to proxy the byte stream, which works for this use case.
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.bind((GNB_LISTEN_HOST, GNB_LISTEN_PORT))
    server_socket.listen(1)
    print(f"[*] Proxy listening for gNB on {GNB_LISTEN_HOST}:{GNB_LISTEN_PORT}")

    while True:
        gnb_sock, _ = server_socket.accept()
        threading.Thread(target=handle_gnb_connection, args=(gnb_sock,)).start()

def handshake_listener():
    """Listens for and validates the custom handshake."""
    global handshake_completed
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.bind((HANDSHAKE_LISTEN_HOST, HANDSHAKE_LISTEN_PORT))
    server_socket.listen(1)
    print(f"[*] Proxy listening for custom handshake on {HANDSHAKE_LISTEN_HOST}:{HANDSHAKE_LISTEN_PORT}")

    while not handshake_completed:
        client_socket, addr = server_socket.accept()
        print(f"[HANDSHAKE] Received handshake attempt from {addr}")
        try:
            data = client_socket.recv(1024).decode().strip()
            if data == SECRET_CHALLENGE:
                print("[HANDSHAKE] Correct secret received. Sending ACK.")
                client_socket.send(SECRET_RESPONSE.encode())
                handshake_completed = True
                print("\n *** GATE OPENED: Proxy will now forward gNB traffic! ***\n")
            else:
                print(f"[HANDSHAKE] Incorrect secret: '{data}'. Closing connection.")
        except Exception as e:
            print(f"[HANDSHAKE] Error: {e}")
        finally:
            client_socket.close()
    
    # Once handshake is done, we can stop this listener
    server_socket.close()
    print("[HANDSHAKE] Handshake listener stopped.")


if __name__ == "__main__":
    print("--- Custom Handshake Proxy Starting ---")
    # Run both listeners in separate threads
    threading.Thread(target=handshake_listener).start()
    threading.Thread(target=gnb_listener).start()