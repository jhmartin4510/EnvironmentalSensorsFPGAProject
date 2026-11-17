"""
terminal_readout.py

Live terminal readout with automatic CSV logging for the ADXL345 I2C-to-UART integration.
Usage:
    python terminal_readout.py COM2
"""

import sys
from uart_receiver import ADXL345CsvLogger, ADXL345UartReceiver, parse_cli_args


def main() -> None:
    args = parse_cli_args("Live Terminal Readout & Auto-Logger for ADXL345 UART Stream")

    logger = ADXL345CsvLogger()
    print(f"Opening {args.port} at {args.baud} baud (Press Ctrl+C to stop & save)...")
    print(f"Logging automatically to: {logger.filepath.name}")

    try:
        with ADXL345UartReceiver(port=args.port, baud_rate=args.baud) as receiver, logger:
            print("-" * 80)
            print(
                f"{'RAW HEX LINE':<24} | {'X (LSB / g)':<15} | {'Y (LSB / g)':<15} | {'Z (LSB / g)':<15}"
            )
            print("-" * 80)

            for sample in receiver.stream_samples():
                logger.log(sample)
                x_str = f"{sample['raw_x']:>5d} ({sample['gx']:+.2f}g)"
                y_str = f"{sample['raw_y']:>5d} ({sample['gy']:+.2f}g)"
                z_str = f"{sample['raw_z']:>5d} ({sample['gz']:+.2f}g)"

                print(
                    f"\r{sample['raw_line']:<24} | {x_str:<15} | {y_str:<15} | {z_str:<15} | n={logger.sample_count}",
                    end="",
                    flush=True,
                )
    except KeyboardInterrupt:
        print(f"\nStopped. Saved {logger.sample_count} samples to {logger.filepath.name}")
    except Exception as exc:
        print(f"\nError on {args.port}: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()