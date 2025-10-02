FROM python:3.9-slim
COPY handshake_proxy.py /handshake_proxy.py
CMD ["python", "/handshake_proxy.py"]