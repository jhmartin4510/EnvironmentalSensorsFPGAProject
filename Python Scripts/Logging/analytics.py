import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation

#statistics 
def calculate_stats(data):
    """Returns mean, standard deviation, min and max"""
    return {
    "mean": np.mean(data),
    "std": np.std(data),
    "max": np.max(data),
    "min": np.min(data)
    }

def moving_avg(data, window_size =5):
    """Moving average to smooth the plot and look less jaggy"""
    return data.rolling(window=window_size, min_periods=1).mean()


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Terminal use: python analytics.py <csv_filename> <target_column>")
        sys.exit(1)

    csv_filename = sys.argv[1]
    target_column = sys.argv[2] #since different sensor have different column names

    fig, ax = plt.subplots(figsize=(10, 5))

    def animate(i):
        try:
            df = pd.read_csv(csv_filename)

            print(f"Loaded{len(df)} rows. Columns: {list(df.columns)}")

            df.columns = df.columns.str.strip()

            matched_col = None

            for col in df.columns:
                if col.lower() == target_column.lower():
                    matched_col = col
                    break

            if matched_col is None:
                print(f"Column '{target_column}' not found. Available: {len(df.columns)}")
                return


            if df.empty or target_column not in df.columns:
                print(f"Target column '{target_column}' not found in {list(df.columns)}")
                return #these two conditions need to be met


            raw_data = pd.to_numeric(df[target_column], errors='coerce').dropna()
            if raw_data.empty:
                return
            

            window_size = 10
            if len(raw_data) >= window_size:
                moving_avg = raw_data.rolling(window = window_size).mean()
                stats = calculate_stats(raw_data)
            else:
                moving_avg =raw_data
                
            ax.clear()

            ax.plot(df.index, raw_data, label=f"Raw {target_column}", alpha=0.35, color = 'gray')
            ax.plot(df.index, moving_avg, label = "1-Sec Moving Average", color = 'blue', linewidth =2)

            ax.set_title(f"Real-Time Data Reading")
            ax.set_xlabel("Sample Index") #this indicates what sample we are at
            ax.set_ylabel(target_column)
            ax.legend(loc="upper left")
            ax.grid(True, linestyle = "--", alpha = 0.6)

            stats_text = f"Mean: {stats['mean']:.2f} \nStd: {stats['std']:.2f}\nMax: {stats['max']:.2f}"
            ax.text(0.95, 0.95, stats_text, transform =ax.transAxes, verticalalignment = 'top',
                    horizontalalignment = 'right', bbox =dict(boxstyle = 'round', facecolor = 'white', alpha =0.8))

            fig.canvas.draw_idle()

        except Exception as e:
            print(f"Error reading CSV: {e}") #file read lock during CSV append


    #refresh plot every 1 second
    ani = animation.FuncAnimation(fig, animate, interval = 1000, cache_frame_data = False)
    plt.tight_layout()
    plt.show()



