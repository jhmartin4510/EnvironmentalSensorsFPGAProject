"""
uart_receiver.py

Shared modular UART receiver, parser, and automatic CSV logger for the
ADXL345 I2C-to-UART integration.
Used by terminal_readout.py, plot_readout.py, and plot_histogram.py.
"""

import argparse
import csv
from datetime import datetime
import math
from pathlib import Path
import time
from typing import Dict, Generator, Optional

try:
    import serial
except ImportError:
    serial = None


SCALE_LSB_PER_G = 256.0  # Default ADXL345 +-2g range (10-bit resolution: ~3.9 mg/LSB)


def hex16_to_signed(hex_str: str) -> int:
    """Convert a 4-character hex string (e.g. 'FFEC') to a signed 16-bit integer."""
    val = int(hex_str, 16) & 0xFFFF
    if val >= 0x8000:
        val -= 0x10000
    return val


def parse_adxl_line(line: str) -> Optional[Dict[str, float]]:
    """
    Parse an incoming UART ASCII line of the form:
        X:001A,Y:FFEC,Z:0102
    Returns a dictionary with raw signed LSB counts, acceleration in g, and magnitude.
    Returns None if the line is incomplete or malformed (e.g. first partial line on connect).
    """
    clean = line.strip()
    if not clean:
        return None

    parts = clean.split(",")
    if len(parts) != 3:
        return None

    try:
        fields = {}
        for part in parts:
            key, val_str = part.split(":", 1)
            key = key.strip().upper()
            val_str = val_str.strip()
            fields[key] = hex16_to_signed(val_str)

        if not ("X" in fields and "Y" in fields and "Z" in fields):
            return None

        raw_x = fields["X"]
        raw_y = fields["Y"]
        raw_z = fields["Z"]

        gx = raw_x / SCALE_LSB_PER_G
        gy = raw_y / SCALE_LSB_PER_G
        gz = raw_z / SCALE_LSB_PER_G
        g_mag = math.sqrt(gx * gx + gy * gy + gz * gz)

        return {
            "raw_x": raw_x,
            "raw_y": raw_y,
            "raw_z": raw_z,
            "gx": gx,
            "gy": gy,
            "gz": gz,
            "g_mag": g_mag,
            "raw_line": clean,
        }
    except (ValueError, KeyError):
        return None


def parse_cli_args(description: str) -> argparse.Namespace:
    """
    Standardized CLI argument parser accepting positional USB/COM port name:
        python <script.py> COM2
    """
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument(
        "port",
        help="Serial port name (e.g. COM2 on Windows or /dev/ttyUSB1 on Linux)",
    )
    parser.add_argument(
        "--baud",
        type=int,
        default=115200,
        help="UART baud rate (default: 115200)",
    )
    return parser.parse_args()


def generate_log_filename(output_dir: Optional[Path] = None) -> Path:
    """
    Generate an automatic log filename using the local OS clock:
        adxl345_MMDDYYYY_HHMM.csv
    If a file with that exact minute already exists, appends _2, _3, etc.
    so previous captures in the same minute are never overwritten.
    """
    base_dir = Path(output_dir) if output_dir else Path.cwd()
    stamp = datetime.now().strftime("%m%d%Y_%H%M")
    candidate = base_dir / f"adxl345_{stamp}.csv"
    counter = 2
    while candidate.exists():
        candidate = base_dir / f"adxl345_{stamp}_{counter}.csv"
        counter += 1
    return candidate


class ADXL345CsvLogger:
    """Automatic CSV logger that flushes each sample as it arrives."""

    FIELDNAMES = [
        "timestamp_iso",
        "elapsed_s",
        "raw_x",
        "raw_y",
        "raw_z",
        "gx",
        "gy",
        "gz",
        "g_mag",
    ]

    def __init__(self, filepath: Optional[Path] = None):
        self.filepath = Path(filepath) if filepath else generate_log_filename()
        self._file = None
        self._writer = None
        self._start_time = 0.0
        self.sample_count = 0

    def open(self) -> None:
        self._file = open(self.filepath, mode="w", newline="", encoding="utf-8")
        self._writer = csv.DictWriter(self._file, fieldnames=self.FIELDNAMES)
        self._writer.writeheader()
        self._file.flush()
        self._start_time = time.perf_counter()
        self.sample_count = 0

    def log(self, sample: Dict[str, float]) -> None:
        if self._writer is None or self._file is None:
            return
        now = datetime.now()
        elapsed = time.perf_counter() - self._start_time
        self._writer.writerow(
            {
                "timestamp_iso": now.isoformat(timespec="milliseconds"),
                "elapsed_s": f"{elapsed:.4f}",
                "raw_x": int(sample["raw_x"]),
                "raw_y": int(sample["raw_y"]),
                "raw_z": int(sample["raw_z"]),
                "gx": f"{sample['gx']:.6f}",
                "gy": f"{sample['gy']:.6f}",
                "gz": f"{sample['gz']:.6f}",
                "g_mag": f"{sample['g_mag']:.6f}",
            }
        )
        self._file.flush()
        self.sample_count += 1

    def close(self) -> None:
        if self._file is not None and not self._file.closed:
            self._file.flush()
            self._file.close()

    def __enter__(self) -> "ADXL345CsvLogger":
        self.open()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.close()


class ADXL345UartReceiver:
    """Modular serial receiver for streaming ADXL345 ASCII frames over UART."""

    def __init__(self, port: str, baud_rate: int = 115200, timeout: float = 0.2):
        if serial is None:
            raise RuntimeError(
                "pyserial is not installed. Run: pip install pyserial"
            )
        self.port = port
        self.baud_rate = baud_rate
        self.timeout = timeout
        self.ser: Optional["serial.Serial"] = None

    def open(self) -> None:
        self.ser = serial.Serial(
            port=self.port,
            baudrate=self.baud_rate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=self.timeout,
        )
        self.ser.reset_input_buffer()

    def close(self) -> None:
        if self.ser is not None and self.ser.is_open:
            self.ser.close()

    def read_sample(self) -> Optional[Dict[str, float]]:
        """Read a single line from UART and return the parsed sample dictionary (or None)."""
        if self.ser is None or not self.ser.is_open:
            return None
        try:
            raw_bytes = self.ser.readline()
            if not raw_bytes:
                return None
            line = raw_bytes.decode("ascii", errors="ignore")
            return parse_adxl_line(line)
        except Exception:
            return None

    def stream_samples(self) -> Generator[Dict[str, float], None, None]:
        """Continuously yield valid parsed samples as they arrive over UART."""
        while True:
            sample = self.read_sample()
            if sample is not None:
                yield sample

    def __enter__(self) -> "ADXL345UartReceiver":
        self.open()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.close()