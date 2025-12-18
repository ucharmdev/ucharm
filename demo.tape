# μcharm Demo
# Run with: vhs demo.tape

Output demo.gif

Set Shell "bash"
Set FontSize 16
Set Width 720
Set Height 480
Set Theme "Catppuccin Mocha"
Set Padding 20
Set Framerate 24
Set TypingSpeed 40ms

# Setup - add ucharm to PATH
Hide
Type "export PATH=$PWD/cli/zig-out/bin:$PATH"
Enter
Type "clear"
Enter
Show
Sleep 300ms

# Show the code
Type "cat examples/quick_demo.py"
Enter
Sleep 2.5s

# Run it
Type "ucharm run examples/quick_demo.py"
Enter
Sleep 1.5s

# Navigate select
Down
Sleep 250ms
Enter
Sleep 600ms

# Confirm
Type "y"
Enter
Sleep 1.5s

# Build it
Type "ucharm build examples/quick_demo.py -o myapp"
Enter
Sleep 2s

# Show size
Type "ls -lh myapp"
Enter
Sleep 1.5s

# Run built binary
Type "./myapp"
Enter
Sleep 1s
Enter
Sleep 400ms
Type "y"
Enter
Sleep 2s

# Cleanup
Hide
Type "rm -f myapp"
Enter
