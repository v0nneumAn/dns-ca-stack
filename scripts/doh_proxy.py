#!/usr/bin/env python3
"""DNS-to-DoH proxy. Listens on UDP/TCP port 5053, forwards to Cloudflare DoH."""
import socket
import threading
import urllib.request
import ssl
import struct


def doh_query(data):
    """Forward a raw DNS query to Cloudflare DoH and return the raw response."""
    try:
        req = urllib.request.Request(
            "https://cloudflare-dns.com/dns-query",
            data=data,
            headers={"Content-Type": "application/dns-message", "Accept": "application/dns-message"},
            method="POST"
        )
        ctx = ssl.create_default_context()
        with urllib.request.urlopen(req, timeout=10, context=ctx) as resp:
            return resp.read()
    except Exception as e:
        print(f"DoH error: {e}")
        return None


def handle_udp(sock):
    while True:
        data, addr = sock.recvfrom(4096)
        if not data:
            continue
        response = doh_query(data)
        if response:
            sock.sendto(response, addr)


def handle_tcp_client(conn, addr):
    try:
        while True:
            length_prefix = conn.recv(2)
            if len(length_prefix) < 2:
                break
            length = struct.unpack('!H', length_prefix)[0]
            data = b''
            while len(data) < length:
                chunk = conn.recv(length - len(data))
                if not chunk:
                    break
                data += chunk
            if len(data) != length:
                break
            response = doh_query(data)
            if response:
                conn.sendall(struct.pack('!H', len(response)) + response)
    finally:
        conn.close()


def handle_tcp(sock):
    while True:
        conn, addr = sock.accept()
        threading.Thread(target=handle_tcp_client, args=(conn, addr), daemon=True).start()


def main():
    udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp_sock.bind(("0.0.0.0", 5053))
    print("DoH proxy listening on UDP 5053...", flush=True)
    udp_thread = threading.Thread(target=handle_udp, args=(udp_sock,), daemon=True)
    udp_thread.start()

    tcp_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    tcp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    tcp_sock.bind(("0.0.0.0", 5053))
    tcp_sock.listen(128)
    print("DoH proxy listening on TCP 5053...", flush=True)
    handle_tcp(tcp_sock)


if __name__ == "__main__":
    main()
