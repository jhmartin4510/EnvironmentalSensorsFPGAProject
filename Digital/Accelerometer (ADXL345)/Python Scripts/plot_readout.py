"""
plot_readout.py

Live scrolling Matplotlib plot with automatic CSV logging for the ADXL345 UART stream.
Pressing Ctrl+C in the terminal or closing the plot window cleanly stops recording and
saves the CSV file.

Usage:
    python plot_readout.py COM2
"""

from collections import deque
import signal
import sys

import matplotlib.animation as animation
import matplotlib.pyplot as plt

from uart_receiver import ADXL345CsvLogger, ADXL345UartReceiver, parse_cli_args


WINDOW_SIZE = 100  # Number of recent samples to display (~5 seconds at 20 Hz)


def main() -> None:
    args = parse_cli_args("Live Matplotlib Plot & Auto-Logger for ADXL345 UART Stream")

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

    x_hist = deque([0.0] * WINDOW_SIZE, maxlen=WINDOW_SIZE)
    y_hist = deque([0.0] * WINDOW_SIZE, maxlen=WINDOW_SIZE)
    z_hist = deque([0.0] * WINDOW_SIZE, maxlen=WINDOW_SIZE)

    fig, ax = plt.subplots(figsize=(9, 5))
    fig.canvas.manager.set_window_title(f"ADXL345 Live Readout ({args.port})")

    (line_x,) = ax.plot(range(WINDOW_SIZE), x_hist, label="X-Axis (g)", color="#d95f02", lw=1.8)
    (line_y,) = ax.plot(range(WINDOW_SIZE), y_hist, label="Y-Axis (g)", color="#1b9e77", lw=1.8)
    (line_z,) = ax.plot(range(WINDOW_SIZE), z_hist, label="Z-Axis (g)", color="#7570b3", lw=1.8)

    ax.set_ylim(-2.5, 2.5)
    ax.set_xlim(0, WINDOW_SIZE - 1)
    ax.set_title(f"ADXL345 Live Gravity Vector Readout ({args.port} @ {args.baud} baud)")
    ax.set_xlabel("Sample Index (20 Hz Stream)")
    ax.set_ylabel("Acceleration (g)")
    ax.grid(True, linestyle="--", alpha=0.5)
    ax.legend(loc="upper right")

    readout_text = ax.text(
        0.02,
        0.95,
        f"Waiting for UART data...\nLog: {logger.filepath.name}",
        transform=ax.transAxes,
        verticalalignment="top",
        family="monospace",
        bbox={"boxstyle": "round", "facecolor": "#f8f9fa", "alpha": 0.85},
    )

    def update(_frame):
        if stop_requested:
            plt.close(fig)
            return line_x, line_y, line_z, readout_text

        latest = None
        for _ in range(10):
            sample = receiver.read_sample()
            if sample is None:
                break
            logger.log(sample)
            latest = sample
            x_hist.append(sample["gx"])
            y_hist.append(sample["gy"])
            z_hist.append(sample["gz"])

        if latest is not None:
            line_x.set_ydata(x_hist)
            line_y.set_ydata(y_hist)
            line_z.set_ydata(z_hist)
            readout_text.set_text(
                f"X: {latest['gx']:+.3f}g ({latest['raw_x']:d} LSB)\n"
                f"Y: {latest['gy']:+.3f}g ({latest['raw_y']:d} LSB)\n"
                f"Z: {latest['gz']:+.3f}g ({latest['raw_z']:d} LSB)\n"
                f"|g|: {latest['g_mag']:.3f}g\n"
                f"REC: {logger.filepath.name} ({logger.sample_count})"
            )

        return line_x, line_y, line_z, readout_text

    ani = animation.FuncAnimation(fig, update, interval=30, blit=False, cache_frame_data=False)

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