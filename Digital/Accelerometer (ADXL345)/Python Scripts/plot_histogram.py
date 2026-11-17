"""
plot_histogram.py

Live-updating 3-panel Matplotlib histogram with automatic CSV logging for the
ADXL345 UART stream. Connects directly to the specified COM/USB port, creates its
own adxl345_MMDDYYYY_HHMM.csv file automatically, and updates the X, Y, and Z
distributions in real time. Pressing Ctrl+C or closing the window stops recording
and saves the CSV file.

Usage:
    python plot_histogram.py COM2
"""

import signal
import statistics
import sys
from typing import List

import matplotlib.animation as animation
import matplotlib.pyplot as plt

from uart_receiver import ADXL345CsvLogger, ADXL345UartReceiver, parse_cli_args


BINS = 25


def main() -> None:
    args = parse_cli_args("Live Matplotlib Histogram & Auto-Logger for ADXL345 UART Stream")

    logger = ADXL345CsvLogger()
    print(f"Connecting to {args.port} at {args.baud} baud...")
    print(f"Logging automatically to: {logger.filepath.name} (Ctrl+C or close window to finish)")

    try:
        receiver = ADXL345UartReceiver(port=args.port, baud_rate=args.baud, timeout=0.01)
        receiver.open()
        logger.open()
    except Exception as exc:
        logger.close()
        print(f"Failed to start on {args.port}: {exc}", file=sys.stderr)
        sys.exit(1)

    stop_requested = False

    def handle_sigint(_sig, _frame):
        nonlocal stop_requested
        stop_requested = True
        plt.close("all")

    signal.signal(signal.SIGINT, handle_sigint)

    gx_data: List[float] = []
    gy_data: List[float] = []
    gz_data: List[float] = []

    fig, axes = plt.subplots(1, 3, figsize=(13, 4.5), sharey=True)
    fig.canvas.manager.set_window_title(f"ADXL345 Live Histogram ({args.port})")
    fig.suptitle(
        f"ADXL345 Live Distribution ({args.port} @ {args.baud} baud) — Log: {logger.filepath.name}",
        fontsize=11,
        fontweight="bold",
    )

    axes_meta = [
        (axes[0], gx_data, "X-Axis (g)", "#d95f02"),
        (axes[1], gy_data, "Y-Axis (g)", "#1b9e77"),
        (axes[2], gz_data, "Z-Axis (g)", "#7570b3"),
    ]

    def update(_frame):
        if stop_requested:
            plt.close(fig)
            return

        new_samples = 0
        for _ in range(10):
            sample = receiver.read_sample()
            if sample is None:
                break
            logger.log(sample)
            gx_data.append(sample["gx"])
            gy_data.append(sample["gy"])
            gz_data.append(sample["gz"])
            new_samples += 1

        if new_samples == 0 or len(gx_data) == 0:
            return

        n_samples = len(gx_data)
        for idx, (ax, vals, title, color) in enumerate(axes_meta):
            ax.cla()
            mean_val = statistics.mean(vals)
            stdev_val = statistics.stdev(vals) if n_samples > 1 else 0.0

            ax.hist(vals, bins=BINS, color=color, alpha=0.75, edgecolor="black", linewidth=0.6)
            ax.axvline(mean_val, color="black", linestyle="--", linewidth=1.4)

            stats_box = (
                f"N    = {n_samples}\n"
                f"Mean = {mean_val:+.4f} g\n"
                f"Std  = {stdev_val:.4f} g\n"
                f"Min  = {min(vals):+.4f} g\n"
                f"Max  = {max(vals):+.4f} g"
            )
            ax.text(
                0.04,
                0.95,
                stats_box,
                transform=ax.transAxes,
                verticalalignment="top",
                fontsize=8.5,
                family="monospace",
                bbox={"boxstyle": "round", "facecolor": "#ffffff", "alpha": 0.85},
            )
            ax.set_title(title)
            ax.set_xlabel("Acceleration (g)")
            if idx == 0:
                ax.set_ylabel("Sample Count")
            ax.grid(True, linestyle="--", alpha=0.4)

    ani = animation.FuncAnimation(fig, update, interval=100, blit=False, cache_frame_data=False)

    try:
        plt.tight_layout()
        plt.show()
    except KeyboardInterrupt:
        plt.close("all")
    finally:
        receiver.close()
        logger.close()
        print(f"Finished recording {logger.sample_count} samples to {logger.filepath.name}")


if __name__ == "__main__":
    main()