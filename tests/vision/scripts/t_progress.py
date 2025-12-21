# Test charm.progress() and charm.spinner() functionality
import charm

# Basic progress bar
print("Progress bar tests:")
charm.progress(5, 10, label="Loading", width=20)
charm.progress_done()

# Progress with elapsed time
charm.progress(7, 10, label="Building", width=25, elapsed=3.5)
charm.progress_done()

# Full progress
charm.progress(10, 10, label="Complete", width=20)
charm.progress_done()

# Empty progress
charm.progress(0, 10, label="Starting", width=20)
charm.progress_done()

# Spinner test
print("\nSpinner tests:")
charm.spinner(0, "Frame 0")
charm.progress_done()
charm.spinner(3, "Frame 3")
charm.progress_done()

# Spinner frame function
print("\nSpinner frames:")
for i in range(10):
    frame = charm.spinner_frame(i)
    print(frame, end=" ")
print()
